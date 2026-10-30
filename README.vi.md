# Hermes Desktop Offline (Tiếng Việt)

**Chạy một AI agent hoàn chỉnh trên PC Windows — không cần internet.**

Ngôn ngữ khác: [English](README.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** đóng gói [Hermes Agent](https://github.com/NousResearch/hermes-agent) thành một bộ cài Windows tự chứa, chạy được trong môi cách ly hoàn toàn (air-gap): app Electron, runtime Python 3.14, payload agent và 230 skills — tất cả được xác minh SHA-256, chạy với **model local** (Ollama, LM Studio, vLLM trên LAN). Không tài khoản cloud, không API key, không mạng sau khi cài.

## Tại sao khác biệt so với bản online

| | Hermes Desktop online | **Hermes Desktop Offline** |
|---|---|---|
| Phụ thuộc mạng | Cần internet cho model API, cập nhật, skills | **Zero** sau cài — chạy trong máy air-gap |
| Model | API key cloud (chi phí, rủi ro privacy) | LLM local: Ollama / LM Studio / vLLM tại `127.0.0.1` hoặc LAN |
| Dữ liệu | Server của hãng, gắn tài khoản | Toàn bộ nằm trong thư mục cài (`data/`, `work/`, `cache/`) |
| Tính reproducibility | Download lúc cài | Manifest SHA-256: mọi file được verify trước chạy |
| Cập nhật | Auto-update qua internet | ZIP update chuyển qua USB/LAN, verify checksum, refuse downgrade, tự backup |
| Skills | Download on demand | 230 skills bundled; 31 offline hoàn toàn, 180 phụ thuộc mạng tự disable |
| Portable | Gắn `%USERPROFILE%` | Path tùy chỉnh: `--DataRoot`, `--WorkRoot`, `--CacheRoot`; chạy từ USB |

**Use case:** nhà xưởng/phòng lab không có internet, máy air-gap của cơ quan chính phủ, công việc nhạy cảm privacy (y tế, luật, tài chính), khu vực mạng không ổn định, và bất kỳ ai muốn AI agent local không "phone home".

## Điểm nổi bật

- 📦 **Một ZIP duy nhất** (~1.82 GiB, 58,166 files): Electron app + agent payload + Python 3.14.9 + skills + launcher + docs.
- 🔐 **Integrity-first**: `checksums.sha256` (58,165 entries) verify khi setup; file missing/tampered báo ngay.
- 🧩 **Skills offline-safe**: scan dependency mạng; skill offline enable, skill cloud disable kèm lý do.
- 🔄 **Update offline an toàn**: validate manifest + checksum, backup install hiện tại, update theo component, refuse downgrade.
- ⚙️ **Path cấu hình được**: install root, data/work/cache root, gateway port (mặc định **8942** để tránh cổng 8642/8643/9119/9120), local model base URL.
- ✅ **Test E2E thực**: extract → setup → verify → launch smoke test trên Windows 11; 4 test suites (checksum, manifest, launcher env, update round-trip) đều PASS.

## Yêu cầu

- Windows 10/11 64-bit (PowerShell 5.1+)
- ~6 GB disk trống (bundle extract ~4.1 GB)
- Model server local (recommend, không bắt buộc để setup/verify):
  - Ollama — `http://127.0.0.1:11434/v1`
  - LM Studio — `http://127.0.0.1:1234/v1`
  - vLLM trên LAN — `http://<lan-ip>:8000/v1`

## Cài đặt (máy offline)

1. Download ZIP từ [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases), copy sang máy đích (USB được).
2. Giải nén vào **path ngắn** (ví dụ `D:\hermes`) — Windows MAX_PATH làm fail extract path sâu.
3. Chạy setup wizard:
   ```powershell
   cd D:\hermes
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   Non-interactive, custom path:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. Verify (chạy được cả khi chưa setup — tự seed config):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. Launch: double-click `launcher\HermesPortable.exe` hoặc `launcher\HermesPortable.cmd`.

### Path config và data

| Path | Purpose | Override |
|---|---|---|
| `<root>\data\config.yaml` | Model provider, base_url, model name | `-DataRoot` hoặc env `HERMES_HOME` |
| `<root>\data\` | Sessions, memories, skills state | như trên |
| `<root>\work\` | Working directory của agent | `-WorkRoot` |
| `<root>\cache\` | Cache | `-CacheRoot` |
| `<root>\config\hermes-portable.ini` | Config portable trung tâm (paths, port, mode) | sửa trực tiếp |

## Cập nhật máy offline

1. Trên máy **có internet**, build bundle mới:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-offline.ps1
   ```
2. Copy ZIP sang máy offline (USB/LAN).
3. Chạy:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip
   ```
   Updater validate manifest + checksum, backup install hiện tại, chỉ update component thay đổi, refuse downgrade.

## FAQ

**Có cần internet không?** Chỉ để download bundle một lần. Sau đó setup, verify, launch, update đều offline.

**Skills nào chạy offline?** 31/230 offline hoàn toàn (file ops, document parsing, code tools...). 180 skill phụ thuộc mạng tự disable để agent không treo.

**Dùng model riêng được không?** Được — mọi endpoint OpenAI-compatible. Set `-LocalBaseUrl`/`-LocalModel` khi setup hoặc sửa `data\config.yaml`.

**Vì sao port 8942?** Tránh cổng dev phổ biến (8642, 8643, 9119, 9120, 5678, 8080, 8090) để coexist với service local khác. Đổi bằng `-GatewayPort`.

## License

MIT — xem [LICENSE](LICENSE). Hermes Agent của [NousResearch](https://github.com/NousResearch/hermes-agent); repo này là project offline packaging/distribution.
