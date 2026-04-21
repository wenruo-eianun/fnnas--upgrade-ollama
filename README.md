
# 🚀 fnOllama - 飞牛 OS (FnOS) Ollama 一键安装与升级脚本

专为飞牛 OS (Feiniu OS) 用户打造的 Ollama 一键安装与自动升级脚本。完美解决 Ollama 官方更新包格式变动带来的解压报错问题，并自动适配不同硬件架构。

## ✨ 核心特性 (Features)

* 🚀 **一键全自动**：自动查找 FnOS 系统下的 AI 安装路径，无需手动干预。
* 🧠 **智能架构识别**：自动判断并拉取 `x86_64` (amd64) 或 `arm64` (aarch64) 对应的安装包，完美适配多种硬件。
* 📦 **最新格式支持**：兼容 Ollama 最新的 `.tar.zst` (Zstandard) 压缩格式，告别 `tar -xzf` 解压报错。
* 🔄 **全家桶升级**：不仅升级 Ollama 客户端，还会同步更新 Python 环境中的 `pip` 以及 `open-webui`。
* 🛡️ **安全备份机制**：每次升级前自动备份旧版 Ollama 目录（例如 `ollama_bk_日期`），升级异常可快速回滚。
* ⚡ **多线程下载**：优先使用 `aria2c` 进行 16 线程满速下载，若未安装则平滑降级使用 `curl`。

---

## 🛠️ 一键安装 / 升级 (Quick Start)

通过 SSH 登录到你的飞牛 OS 终端（请使用 `root` 权限），然后复制并运行以下命令：
⚠️使用前先停用应用商城的ollama的app

```bash
curl -sL https://raw.githubusercontent.com/wenruo-eianun/fnnas--upgrade-ollama/main/fnOllama.sh | bash
```
强制重装命令 如果出现500报错等
```bash
curl -sL https://raw.githubusercontent.com/wenruo-eianun/fnnas--upgrade-ollama/main/fnOllama.sh | FORCE=1 bash
```
---

## 📋 运行流程简述

1. 脚本会自动扫描 `/vol1` 到 `/vol9`，寻找 `@appcenter/ai_installer` 目录。
2. 自动检测当前的系统架构与已安装的 Ollama 版本。
3. 从 GitHub 获取最新 Release 版本号。
4. 如果有新版本，自动下载对应的 `.tar.zst` 压缩包并验证完整性。
5. 备份旧版本，解压新版本。
6. 自动执行 `open-webui` 和 `pip` 的升级。
7. 打印最新版本号，升级完成！

---

## 💡 常见问题 (FAQ)

**Q: 提示下载失败或获取不到最新版本号怎么办？**
A: 这通常是因为国内访问 GitHub 的网络限制导致。你可以在终端中临时设置代理后再执行脚本：
```bash
export https_proxy=http://你的代理IP:端口
export http_proxy=http://你的代理IP:端口
```

**Q: 升级中途断电或中断了，Ollama 无法启动了？**
A: 别担心，脚本具备中断恢复机制。只需重新运行一次一键安装命令，脚本会自动检测到未完成的备份 `ollama_bk_xxx` 并恢复原状，随后重新尝试升级。

**Q: 如何手动回滚到旧版本？**
A: 进入安装目录（通常是 `/vol1/@appcenter/ai_installer`），删除当前的 `ollama` 文件夹，然后将备份文件夹重命名回 `ollama` 即可。

### ⏪ 一键回滚/恢复命令

如果你升级后发现无论如何都无法启动，或者想退回升级前的版本，请**直接全选并复制下面这一整段代码**，粘贴到终端里按回车即可：

```bash
bash -c '
echo "🔄 开始执行一键恢复..."
for vol in /vol{1..9}; do
    DIR="$vol/@appcenter/ai_installer"
    if [ -d "$DIR" ]; then
        cd "$DIR"
        LAST_BK=$(ls -td ollama_bk_* 2>/dev/null | head -n 1)
        if [ -n "$LAST_BK" ]; then
            echo "📦 找到最近的备份: $LAST_BK"
            [ -d "ollama" ] && mv ollama "ollama_error_$(date +%s)" && echo "🗑️ 已移走当前可能损坏的 ollama 文件夹"
            mv "$LAST_BK" ollama
            echo "✅ 成功将 $LAST_BK 恢复还原！"
            echo "🎉 恢复完成！请前往 FnOS 网页端重新启动 AI 应用。"
            exit 0
        else
            echo "❌ 在 $DIR 下未找到任何备份文件夹 (ollama_bk_xxx)"
            exit 1
        fi
    fi
done
echo "❌ 未找到 FnOS 的 ai_installer 安装目录！"
'
```

### 💡 这段命令做了什么？
1. **自动寻路**：它会像安装脚本一样，自动去 `/vol1` 到 `/vol9` 里找你的 AI 安装目录。
2. **寻找后悔药**：通过 `ls -td` 命令，精准找到时间离现在最近的那个备份文件夹（比如 `ollama_bk_20260421_173004`）。
3. **安全替换**：把你当前认为坏掉的 `ollama` 文件夹改名为 `ollama_error_时间戳` 丢到一边，然后把备份文件夹的名字改回原样。
---

## 🤝 贡献与反馈

如果你在使用过程中遇到任何 Bug，或者有让脚本变得更好的建议，欢迎提交 **Issue** 或 **Pull Request**！
