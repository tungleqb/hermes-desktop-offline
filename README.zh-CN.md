# Hermes Desktop Offline（简体中文）

**在 Windows 电脑上运行完整的 AI Agent —— 无需互联网。**

其他语言：[English](README.md) · [Tiếng Việt](README.vi.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** 将 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 桌面应用打包为一个自包含、可完全离网（air-gap）运行的 Windows 安装包：Electron 应用、内置 Python 3.14 运行时、Agent 载荷与 230 个技能 —— 全部通过 SHA-256 校验，运行于**本地模型**（Ollama、LM Studio、局域网 vLLM）。安装后无需云账号、API Key 或网络。

## 与在线版的核心差异

| | 在线版 Hermes Desktop | **Hermes Desktop Offline** |
|---|---|---|
| 网络依赖 | 模型 API、更新、技能均需联网 | **零依赖** —— 可在完全离网机器运行 |
| 模型访问 | 云端 API Key（成本与隐私风险） | 本地 LLM：Ollama / LM Studio / 局域网 vLLM |
| 数据位置 | 厂商服务器、账号绑定 | 全部保存在安装目录（`data/`、`work/`、`cache/`） |
| 可复现性 | 安装时在线下载 | SHA-256 清单：首次运行前校验每个文件 |
| 更新方式 | 联网自动更新 | 离网更新 ZIP（USB/局域网传输），校验完整性，拒绝降级，自动备份 |
| 技能 | 按需下载 | 内置 230 个技能；31 个完全离网可用，180 个网络依赖技能自动禁用 |
| 便携性 | 绑定 `%USERPROFILE%` | 可自定义 `--DataRoot`、`--WorkRoot`、`--CacheRoot`；可从 U 盘运行 |

**适用场景：** 无互联网的工厂/实验室网络、政府/军工离网电脑、隐私敏感行业（医疗、法律、金融）、网络不稳定地区，以及希望 AI Agent 永不联网的用户。

## 亮点

- 📦 **单一 ZIP 包含一切**（约 1.82 GiB，58,166 个文件）：Electron 应用 + Agent 载荷 + Python 3.14.9 运行时 + 技能包 + 启动器 + 文档。
- 🔐 **完整性优先**：`checksums.sha256`（58,165 条）在 setup 时校验；缺失或被篡改的文件立即报告。
- 🧩 **离网技能策略**：扫描技能的网络依赖；离网安全的技能启用，云端依赖技能禁用并说明原因。
- 🔄 **安全的离网更新**：`update-offline.ps1` 校验清单与校验和、备份当前安装、按组件更新、拒绝版本降级。
- ⚙️ **可配置路径**：安装根目录、数据/工作/缓存目录、网关端口（默认 **8942**，避免与常见开发端口冲突）、本地模型 Base URL。
- ✅ **端到端测试**：在 Windows 11 上执行 解压 → setup → verify → 启动冒烟测试；4 个测试套件（校验和、清单架构、启动器环境、更新往返）全部通过。

## 系统要求

- Windows 10 或 11，64 位（PowerShell 5.1+）
- 约 6 GB 可用磁盘空间（解压约 4.1 GB）
- 建议本地模型服务器（setup/verify 不强制要求）：
  - Ollama — `http://127.0.0.1:11434/v1`
  - LM Studio — `http://127.0.0.1:1234/v1`
  - 局域网 vLLM — `http://<lan-ip>:8000/v1`

## 安装（离网机器）

1. 从 [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) 下载 ZIP，复制到目标电脑（U 盘即可）。
2. 解压到**短路径**（例如 `D:\hermes`）—— Windows MAX_PATH 限制会导致深层解压失败。
3. 运行 setup 向导：
   ```powershell
   cd D:\hermes
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   非交互模式 + 自定义路径：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. 验证就绪状态（即使未 setup 也能运行 —— 自动初始化配置）：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. 启动：双击 `launcher\HermesPortable.exe`（或 `launcher\HermesPortable.cmd`）。

### 配置与数据路径

| 路径 | 用途 | 覆盖方式 |
|---|---|---|
| `<root>\data\config.yaml` | 模型 provider、base_url、模型名 | `-DataRoot` 或环境变量 `HERMES_HOME` |
| `<root>\data\` | 会话、记忆、技能状态 | 同上 |
| `<root>\work\` | Agent 工作目录 | `-WorkRoot` |
| `<root>\cache\` | 缓存 | `-CacheRoot` |
| `<root>\config\hermes-portable.ini` | 便携配置中枢（路径、端口、模式） | 直接编辑 |

## 离网机器更新

1. 在**联网**机器上构建最新包：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-offline.ps1
   ```
2. 将 ZIP 复制到离网电脑（USB/局域网）。
3. 运行：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip
   ```
   更新器校验清单与校验和、备份当前安装、仅更新变更组件、拒绝降级。

## 常见问题

**需要联网吗？** 仅下载包一次。之后 setup、verify、启动、更新全部离网完成。

**哪些技能可离网使用？** 230 个中 31 个完全离网可用（本地文件操作、文档解析、代码工具等）。180 个网络依赖技能自动禁用，避免 Agent 挂起。

**能用自己的模型吗？** 可以 —— 任何 OpenAI 兼容端点。setup 时设置 `-LocalBaseUrl`/`-LocalModel`，或编辑 `data\config.yaml`。

**为什么用 8942 端口？** 避开常见开发端口（8642、8643、9119、9120、5678、8080、8090），与其他本地服务共存。用 `-GatewayPort` 更改。

## 许可证

MIT — 见 [LICENSE](LICENSE)。Hermes Agent 由 [NousResearch](https://github.com/NousResearch/hermes-agent) 开发；本仓库是离网打包与分发项目。
