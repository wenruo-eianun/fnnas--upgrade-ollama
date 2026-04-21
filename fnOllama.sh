#!/bin/bash

set -e
set -o pipefail

echo "🔄 Ollama 升级脚本 for FnOS, 脚本v2.1.8 (移除冗余目录切换)"

# 1. 查找 Ollama 安装路径
echo "🔍 查找 Ollama 安装路径..."
VOL_PREFIXES=(/vol1 /vol2 /vol3 /vol4 /vol5 /vol6 /vol7 /vol8 /vol9)
AI_INSTALLER=""

# 遍历寻找 ollama 安装目录
for vol in "${VOL_PREFIXES[@]}"; do
    if [ -d "$vol/@appcenter/ai_installer/ollama" ]; then
        AI_INSTALLER="$vol/@appcenter/ai_installer"
        echo "✅ 找到安装路径：$AI_INSTALLER"
        break
    fi
done

## 如果未找到主安装路径，则检查是否存在中断的备份
if [ -z "$AI_INSTALLER" ]; then
    for vol in "${VOL_PREFIXES[@]}"; do
        testdir="$vol/@appcenter/ai_installer"
        if [ -d "$testdir" ]; then
            cd "$testdir"
            LAST_BK=$(ls -td ollama_bk_* 2>/dev/null | head -n 1)
            if [ -n "$LAST_BK" ] && [ ! -d "ollama" ]; then
                echo "⚠️ 检测到未完成的升级：$testdir 中存在备份 $LAST_BK，但当前没有 ollama/"
                mv "$LAST_BK" ollama
                echo "✅ 已恢复 $LAST_BK 为 ollama/， 请重新执行本脚本更新"
                if [ -x "./ollama/bin/ollama" ]; then
                    ./ollama/bin/ollama --version
                else
                    echo "⚠️ 还原后未找到 ollama 可执行文件，可能备份不完整"
                fi
                exit 0
            fi
        fi
    done

    echo "❌ 未找到 Ollama 安装路径，也没有检测到可恢复的中断备份"
    exit 1
fi

cd "$AI_INSTALLER"

# 2. 打印当前版本
echo "📦 正在检测当前 Ollama 客户端版本..."

if [ -x "./ollama/bin/ollama" ]; then
    VERSION_RAW=$(./ollama/bin/ollama --version 2>&1)
    CLIENT_VER=$(echo "$VERSION_RAW" | grep -i "client version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    if [ -n "$CLIENT_VER" ]; then
        echo "📦 当前已安装版本：v$CLIENT_VER（客户端）"
    else
        echo "⚠️ 无法获取版本号，原始输出如下："
        echo "$VERSION_RAW"
    fi
else
    echo "❌ 未找到 ollama 可执行文件"
fi

# 3. 自动判断系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        OLLAMA_ARCH="amd64"
        ;;
    aarch64)
        OLLAMA_ARCH="arm64"
        ;;
    *)
        echo "❌ 不支持的系统架构: $ARCH"
        exit 1
        ;;
esac
echo "🖥️ 检测到系统架构为: $ARCH，匹配安装包: $OLLAMA_ARCH"

# 4. 下载最新版本
FILENAME="ollama-linux-${OLLAMA_ARCH}.tar.zst"
echo "🌐 获取 Ollama 最新版本号..."

LATEST_TAG=$(curl -s https://github.com/ollama/ollama/releases | grep -oP '/ollama/ollama/releases/tag/\K[^"]+' | head -n 1)

if [ -z "$LATEST_TAG" ]; then
    echo "❌ 无法从 GitHub 获取 Ollama 最新版本号，请检查网络连接或代理设置"
    exit 1
fi

echo "📦 最新版本号：$LATEST_TAG"

# 检查是否已经是最新版本，并处理 FORCE 强制重装逻辑
if [ "$CLIENT_VER" = "${LATEST_TAG#v}" ]; then
    if [ "$FORCE" = "1" ]; then
        echo "⚠️ 触发 FORCE=1 强制重装模式，正在重新部署 v$CLIENT_VER ..."
    else
        echo "✅ 当前已是最新版本（v$CLIENT_VER），无需升级。"
        echo "💡 如果你的环境损坏(如报500错误)，想要强制重新安装，请在命令前加上 FORCE=1"
        echo "👉 示例: curl -sL https://raw.githubusercontent.com/wenruo-eianun/fnnas--upgrade-ollama/main/fnOllama.sh | FORCE=1 bash"
        exit 0
    fi
fi

URL="https://github.com/ollama/ollama/releases/download/${LATEST_TAG}/${FILENAME}"
NEED_DOWNLOAD=true

# 如果已有完整文件就跳过下载
if [ -f "$FILENAME" ]; then
    echo "🔍 检测到本地已有 $FILENAME，验证完整性..."

    if tar -tf "$FILENAME" >/dev/null 2>&1; then
        echo "✅ 本地压缩包完整，跳过下载"
        NEED_DOWNLOAD=false
    else
        echo "❌ 本地文件损坏，重新下载"
        rm -f "$FILENAME"
    fi
fi

# 如果文件不存在才开始下载
if [ "$NEED_DOWNLOAD" = true ]; then
    echo "⬇️ 正在下载版本 $LATEST_TAG ..."
    if command -v aria2c >/dev/null 2>&1; then
        echo "🚀 使用 aria2c 多线程下载..."
        aria2c -x 16 -s 16 -k 1M -o "$FILENAME" "$URL"
    else
        echo "⬇️ 使用 curl 单线程下载..."
        curl -L -o "$FILENAME" "$URL"
    fi
fi

# 5. 备份旧版本
BACKUP_NAME="ollama_bk_$(date +%Y%m%d_%H%M%S)"
# 只有在旧版存在的情况下才备份，防止循环强制重装时报错
if [ -d "ollama" ]; then
    mv ollama "$BACKUP_NAME"
    echo "📦 已备份原版 Ollama 为：$BACKUP_NAME"
fi

# 6. 解压部署新版本
echo "📦 解压到 ollama/ ..."
mkdir -p ollama
tar -I zstd -xf "$FILENAME" -C ollama

# 7. 升级 pip 和 open-webui
PIP_DIR="$AI_INSTALLER/python/bin"

if [ -x "$PIP_DIR/python3" ]; then
    PYTHON_EXEC="$PIP_DIR/python3"
elif ls "$PIP_DIR"/python3.* 1> /dev/null 2>&1; then
    PYTHON_EXEC=$(ls "$PIP_DIR"/python3.* | head -n 1)
else
    PYTHON_EXEC="python3" 
fi

echo "⬆️ 正在升级 pip..."
"$PYTHON_EXEC" -m pip install --upgrade pip --break-system-packages || {
    echo "❌ pip 升级失败，可能是网络问题或 GitHub 被墙"
    echo "   请尝试设置代理后重新运行："
    echo "   export https_proxy=http://127.0.0.1:7890"
    echo "   export http_proxy=http://127.0.0.1:7890"
    exit 1
}

echo "⬆️ 正在升级 open-webui..."
# 注意：这里删除了多余的 cd "$PIP_DIR"
"$PYTHON_EXEC" -m pip install --upgrade open_webui --break-system-packages || {
    echo "❌ open-webui 升级失败"
    echo "🔎 常见原因：网络不通 / pip太旧 / 无法连接 PyPI"
    echo "✔️ 可尝试设置代理或手动升级："
    echo "   export https_proxy=http://127.0.0.1:7890"
    echo "   export http_proxy=http://127.0.0.1:7890"
    exit 1
}

# 8. 打印新版本确认
cd "$AI_INSTALLER"

if [ -x "./ollama/bin/ollama" ]; then
    VERSION_RAW=$(./ollama/bin/ollama --version 2>&1)
    CLIENT_VER=$(echo "$VERSION_RAW" | grep -i "client version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    if [ -n "$CLIENT_VER" ]; then
        echo "✅ 新 Ollama 版本为：v$CLIENT_VER（客户端）"
    else
        echo "⚠️ 无法提取版本号，原始输出如下："
        echo "$VERSION_RAW"
    fi
else
    echo "❌ 未找到 ollama 可执行文件"
fi

echo "🎉 升级/重装完成！建议去 FnOS 网页端重启一下 AI 应用。"
