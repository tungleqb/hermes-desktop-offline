# Hermes Desktop Offline Installer — Báo cáo điều tra (Phase 1)

**Ngày:** 2026-10-29 · **Người thực hiện:** Barau (Hermes) + Copilot (qwen38-flash-next-q2-a)
**Repo nguồn:** NousResearch/hermes-agent, tag `v0.22.5` (HEAD trên WindyPC: `bf0203a794a`)

## 1. Cách Hermes Desktop hoạt động (đọc từ源码)

### 1.1 Kiến trúc official
- Desktop = **Electron shell** (apps/desktop) + **backend `hermes serve`** (Python agent core) chạy local.
- Variant `bundled`: payload Python/Node được đóng gói trong `resources/agent-payload` (extraResources của electron-builder).
- `electron/payload-backend.ts`: đọc `install-stamp.json` (baked stamp) → lấy `runtime.storePython`, `runtime.sitePackages`, `runtime.repoDir`, `runtime.commands.hermes` (shim CLI). **Không có discovery runtime** — mọi path được builder ghi sẵn vào stamp.
- `electron/backend-discovery.ts`: Desktop attach backend qua `spawn-ledger.json` ở machine root, hoặc spawn mới.
- Backend spawn: `hermes serve` (multiplex mọi profile).

### 1.2 Payload contents (BUILDING.md)
- Source snapshot của release (không `.git`), loại: tests, website, evals, .github, docker, apps, ui-tui, web, scripts.
- **Pinned CPython + uv** (python-build-standalone qua `pm/lock.json`), Python dependency tree đã resolve (`uv.lock`).
- **Node.js, npm, managed tools** (git-for-windows trên Windows), prebuilt TUI/dashboard assets.
- Manifest, tool facts, feature list, build provenance, CLI launchers sinh từ script declarations.

### 1.3 Packaging Windows official
- Target: **MSIX** (sideload + Store), không NSIS/MSI. MSIX sideload yêu cầu **ATS signing cert** của Nous Research → **không thể tự install MSIX unsigned** (AppxSIP reject).
- MSIX manifest official yêu cầu **Windows 11 22H2 (10.0.22621.0)** tối thiểu → không thỏa yêu cầu "Windows 10".
- Update: electron-updater qua feed R2/GitHub (cần Internet) → offline phải thay bằng cơ chế "bundle mới → copy → chạy script update".

## 2. Kết luận kiến trúc cho bộ cài offline

| Yêu cầu | Giải pháp |
|---|---|
| Win 10 + 11, không Internet | **Portable unpackaged Electron app** (`electron-builder --dir` output = folder chạy trực tiếp `Hermes.exe`) — không cần signing, không cần MSIX, không có floor Windows 11 |
| Đầy đủ tính năng bản online | Dùng đúng source v0.22.5 + payload bundled (Python pinned + deps) → mọi tính năng local hoạt động; tính năng cần Internet (GitHub search, model cloud, skill hub, update feed) tự degrade |
| Cập nhật dễ | Script `build-offline.ps1` trên máy có Internet tạo ZIP bundle phiên bản mới; máy offline chạy `update-offline.ps1` trỏ tới ZIP |
| Skills offline đóng gói sẵn | Scan hub + repo `skills/`, lọc skill không cần API endpoint, vendor kèm libs; thư mục `skills-bundle/` + script install |
| Portable, custom path | `setup.ps1` wizard chọn DataDir/WorkDir; launcher đọc `hermes-portable.ini` (override HERMES_HOME, HERMES_WORKSPACE) |

## 3. Rủi ro & ràng buộc đã xác nhận
1. `engines`: Node `^22.22 || ^24.11 || >=26` — WindyPC có Node v22.15.1 → cần nâng Node hoặc dùng Node pinned trong payload (pm/lock.json có node entry). Build trên WindyPC cần Node ≥22.22.
2. Build payload Windows dùng `pm` (package manager riêng của Hermes) tải CPython standalone + wheels → cần Internet trên máy BUILD (WindyPC có), không cần trên máy đích.
3. electron-builder asar heap: `--max-old-space-size=16384` (RAM WindyPC đủ).
4. MSIX minVersion 22621 chỉ áp dụng MSIX; portable dir không có floor này (Electron 44 hỗ trợ Win 10).
5. Signing: bỏ qua — portable folder không yêu cầu signature.

## 4. Môi trường xác nhận
- WindyPC (build host): Win 11 22631, Node 22.15.1, npm 10.9.2, Python 3.12.7, uv 0.9.18, git có, D: free ~530GB.
- Máy đích thử nghiệm offline: Admin@100.90.252.36 — Win 11 26200.
- LLM LAN cho test offline: http://100.106.91.39:8001/v1 (toriai) — LAN nội bộ, không Internet.
