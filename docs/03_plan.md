# 03 - Kế hoạch phát triển (Development Plan)

**Project:** Hermes Desktop Offline Installer · **Host:** WindyPC (D:\dev\hermes-desktop-offline)
**Method:** Waterfall-gated với test nghiêm ngặt ở mỗi pha; mỗi pha có acceptance criteria (AC) và test case (TC) cụ thể.

## Pha 0 — Điều tra (done)
- AC: xác định được artifact khả dụng cho Win10 offline. **Kết quả:** `electron-builder --dir` (win-unpacked) là artifact duy nhất không cần signing và không có floor Windows 11.
- TC-0.1: MSIX official có minVersion 22621 → FAIL cho Win10 → loại MSIX. ✔ (đo trong electron-builder.config.cjs)
- TC-0.2: payload bundled có CPython + site-packages + tools → đủ cho offline. ✔ (3.7 GB payload đã build)

## Pha 1 — Kiến trúc (done)
- AC: 4 subsystem (build pipeline, payload layout, update, feature matrix) + layout tree. ✔ docs/02_architecture.md
- TC-1.1: mọi đường dẫn trong layout tồn tại thật trong output build → verify ở Pha 3.
- TC-1.2: không có download lúc runtime → grep launcher/setup cho `Invoke-WebRequest|curl|pip install|npm install` phải trả 0 match.

## Pha 2 — Chuẩn bị input (đang chạy)
- AC: `prepared.json` sinh ra thành công trên WindyPC (commit bf0203a794a, target win32-x64).
- AC: skill inventory phân loại 211 skill → 31 offline-capable + 15 skill Anthropic (docx/xlsx/pptx/pdf/...) + libs.
- TC-2.1: `python scripts/bundles/desktop.py --commit <sha> --variant bundled --prepare-only` exit 0.
- TC-2.2: `skill_scan.py` ra `skill_inventory.json` có ≥200 entries, mỗi entry có flag `needs_api`.
- TC-2.3: mỗi skill offline được kiểm tra: không có URL remote, không yêu cầu API key.

## Pha 3 — Build app portable
- AC: `apps/desktop/release/win-unpacked/Hermes.exe` chạy được trên WindyPC và mở UI desktop.
- TC-3.1: build exit 0, `Hermes.exe` + `resources/agent-payload` + `install-stamp.json` tồn tại.
- TC-3.2: `install-stamp.json` có `variant=bundled` và runtime paths resolve tới file thật.
- TC-3.3: khởi động app với HERMES_HOME trỏ tới thư mục tạm → backend `hermes serve` listen 127.0.0.1, log không có attempt tới domain ngoài.
- TC-3.4 (offline simulation): tắt network (firewall block outbound cho Hermes.exe) → app vẫn mở, chat với model LAN trả lời.

## Pha 4 — Đóng gói & launcher
- AC: ZIP `Hermes-Offline-<ver>-win-x64.zip` + manifest.json + checksums.sha256; launcher HermesPortable.exe đọc ini; setup.ps1 wizard đổi path.
- TC-4.1: manifest schema validate (script test).
- TC-4.2: checksum mismatch → update-offline.ps1 abort (negative test).
- TC-4.3: setup.ps1 với path không có quyền ghi → fail rõ ràng, không tạo nửa thư mục.
- TC-4.4: portable: copy ZIP sang máy 2 (Admin@100.90.252.36),解压, chạy HermesPortable.exe → UI mở, model LAN hoạt động.
- TC-4.5: SmartScreen/unsigned: ghi nhận và document; test chạy trên Win10 VM nếu có.

## Pha 5 — Update offline
- AC: build v2 → copy ZIP → `update-offline.ps1` → app chạy version mới, data không mất.
- TC-5.1: downgrade bị refuse trừ `-Force`.
- TC-5.2: rollback: backup tự động, restore khi verify fail.
- TC-5.3: partial component update (`-Component skills-bundle`) không phá digest của component khác.

## Pha 6 — Test đa dạng & nghiêm ngặt (matrix)
| # | Scenario | Expected |
|---|---|---|
| T1 | Máy hoàn toàn air-gapped, model LAN | Chat OK, skills OK, không crash |
| T2 | Không có model LAN | App mở, hiển thị cấu hình provider, error rõ ràng |
| T3 | web_search được gọi offline | Error "offline", không hang |
| T4 | Install root trên USB FAT32 | setup.ps1 refuse junction, fallback copy |
| T5 | Path có dấu cách/Unicode Việt | hoạt động |
| T6 | Update khi app đang chạy | quiesce trước apply |
| T7 | ZIP corrupted 1 byte | checksum abort |
| T8 | Data dir đã có config.yaml | wizard không overwrite |
| T9 | Restart nhiều lần | state.db nguyên vẹn |
| T10 | Win10 (21H2/22H2) | Electron 44 chạy (Electron hỗ trợ Win10) |

## Pha 7 — Release & docs
- AC: OFFLINE-QUICKSTART.md, troubleshooting, changelog, checksum published.
- AC: kết quả test matrix được ghi vào docs/05_test-report.md với evidence (log, screenshot).

## Deliverables
1. `artifacts/Hermes-Offline-<ver>-win-x64.zip`
2. Scripts: build-offline.ps1, update-offline.ps1, verify-offline.ps1, setup.ps1, launcher
3. Docs: 01–05
4. Test evidence: logs + screenshots
