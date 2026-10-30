# Hermes Desktop Offline (日本語)

**Windows PC 上で完全な AI エージェントを実行 —  internet 不要。**

他の言語: [English](README.md) · [简体中文](README.zh-CN.md) · [Tiếng Việt](README.vi.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** は [Hermes Agent](https://github.com/NousResearch/hermes-agent) 桌面アプリを、air-gap（完全隔離）環境で動作する自包含 Windows バンドルにパッケージ化します: Electron アプリ、Python 3.14 运行时、agent payload、230 個の skills — すべて SHA-256 検証済み、**ローカルモデル**（Ollama、LM Studio、LAN 上の vLLM）で実行。インストール後は cloud アカウント、API key、network 不要。

## Online 版との違い

| Online | **Offline** |
|---|---|
| model API・update・skills に internet 必要 | インストール後 **依存ゼロ** — air-gap 機器で動作 |
| cloud model + API key（コスト・privacy リスク） | 本地 LLM: Ollama / LM Studio / LAN vLLM |
| data は vendor server 上 | すべて install 目录（`data/`, `work/`, `cache/`) に保存 |
| install 時 download | SHA-256 manifest: 初回実行前に全 file 検証 |
| online auto-update | offline update ZIP（USB/LAN 転送）、integrity 検証、downgrade 拒否、auto-backup |
| skills 按需 download | 230 skills 包含; 31 完全 offline, 180 network 依存は自動 disable |
| `%USERPROFILE%` 固定 | portable: 自定义 path, USB から実行可 |

**用途:** internet ない factory/lab network, government/defense air-gap PC, privacy-sensitive 業務（医療・法律・金融), network 不稳定 region。

## 特徴

- 📦 **単一 ZIP すべて包含** (~1.82 GiB, 58,166 files): Electron + agent payload + Python 3.14.9 + skills + launcher + docs
- 🔐 **integrity-first**: `checksums.sha256` (58,165 entries) setup 時検証
- 🧩 **offline-safe skills**: network 依存 skills 自動 disable（理由明示）
- 🔄 **安全 offline update**: manifest + checksum 検証, backup, component-scoped update, downgrade 拒否
- ⚙️ **path 設定可**: install root, data/work/cache root, gateway port (デフォルト **8942**), local model base URL
- ✅ **E2E 実測済み**: Windows 11 上で extract → setup → verify → launch smoke test; 4 test suites 全 PASS

## 要件

- Windows 10/11 64-bit (PowerShell 5.1+)
- ~6 GB 空き disk (bundle extract ~4.1 GB)
- local model server 推奨 (setup/verify には必須ではない):
  - Ollama — `http://127.0.0.1:11434/v1`
  - LM Studio — `http://127.0.0.1:1234/v1`
  - LAN vLLM — `http://<lan-ip>:8000/v1`

## 安装 (offline 機器)

1. [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) から ZIP download, 目標 PC に copy (USB 可)
2. **短い path** (例 `D:\hermes`) に extract — Windows MAX_PATH が深い extract を fail させる
3. setup wizard 実行:
   ```powershell
   cd D:\hermes
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   non-interactive + custom path:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. verify (setup 前でも可 — config 自動 seed):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. launch: `launcher\HermesPortable.exe` double-click

## 更新 (offline 機器)

1. **internet 接続機器** 上で最新 bundle build:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-offline.ps1
   ```
2. ZIP を offline PC に copy (USB/LAN)
3. 実行:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip
   ```
   updater は manifest + checksum 検証, 現 install backup, 変更 component のみ update, downgrade 拒否

## FAQ

**internet 必要?** bundle 一度 download だけ。setup・verify・launch・update すべて offline。
**どの skills offline?** 230 中 31 完全 offline (local file ops, document parsing, code tools 等)。180 network 依存 skills 自動 disable。
**自分の model 可?** 可 — OpenAI-compatible endpoint なら `-LocalBaseUrl`/`-LocalModel` 設定 or `data\config.yaml` 編集。
**port 8942?** 常见 dev port (8642, 8643, 9119, 9120, 5678, 8080, 8090) 回避。`-GatewayPort` 変更可。

## License

MIT — [LICENSE](LICENSE) 参照。Hermes Agent は [NousResearch](https://github.com/NousResearch/hermes-agent) 開発; 本 repo は offline packaging/distribution project。
