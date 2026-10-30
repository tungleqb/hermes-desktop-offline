# Hermes Desktop Offline

**Run a full AI agent on your Windows PC — with zero internet.**

Other languages: [简体中文](README.zh-CN.md) · [Tiếng Việt](README.vi.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** packages the [Hermes Agent](https://github.com/NousResearch/hermes-agent) desktop app into a self-contained, air-gap-ready Windows bundle: the Electron app, a bundled Python 3.14 runtime, the agent payload, and 230 skills — all verified by SHA-256 checksums, all running against your **local** model server (Ollama, LM Studio, vLLM on LAN). No cloud account, no API key, no network required after installation.

![status](https://img.shields.io/badge/platform-Windows%2010%2F11-orange) ![e2e](https://img.shields.io/badge/E2E%20tests-6%2F6%20PASS-green) ![bundle](https://img.shields.io/badge/bundle-1.82%20GiB-blue)

---

## Why this exists (and why it beats the online setup)

| | Online Hermes Desktop | **Hermes Desktop Offline** |
|---|---|---|
| Network dependency | Needs internet for model API, updates, skills | **Zero** after install — works in air-gapped machines |
| Model access | Cloud API keys (cost, privacy risk) | Local LLM: Ollama / LM Studio / vLLM on `127.0.0.1` or LAN |
| Data location | Vendor servers, account-linked | Everything stays in your install root (`data/`, `work/`, `cache/`) |
| Install reproducibility | Fetches at install time | SHA-256 manifest: every file verified before first run |
| Updates | Auto-update over internet | Offline update ZIP transferred by USB/network, integrity-checked, refuses downgrades, auto-backup |
| Skills | Downloaded on demand | 230 skills bundled; 31 fully offline-capable, 180 network-dependent ones auto-disabled |
| Portability | Tied to `%USERPROFILE%` | Portable: custom `--DataRoot`, `--WorkRoot`, `--CacheRoot`; run from USB or any folder |

**Use cases:** factories/lab networks with no internet, government/defence air-gapped PCs, privacy-sensitive work (medical, legal, finance), regions with unreliable connectivity, and anyone who wants a local LLM agent that never phones home.

## Highlights

- 📦 **One ZIP, everything included** (~1.82 GiB, 58,166 files): Electron app + embedded agent payload + Python 3.14.9 runtime + skills bundle + launcher + docs.
- 🔐 **Integrity-first**: `checksums.sha256` (58,165 entries) verified at setup; tampered or missing files are reported immediately.
- 🧩 **Offline skill strategy**: skills are scanned for network dependencies; offline-safe ones are enabled, cloud-dependent ones are disabled with a clear reason.
- 🔄 **Safe offline updates**: `update-offline.ps1` validates manifest + checksums, backs up the current install, applies component-scoped changes, and refuses version downgrades.
- ⚙️ **Configurable paths**: install root, data root, work root, cache root, gateway port (default **8942** to avoid clashing with common dev ports), local model base URL.
- ✅ **Tested end-to-end**: extract → setup → verify → launch smoke test on Windows 11; 4 test suites (checksum, manifest schema, launcher env, update round-trip) all pass.

## Requirements

- Windows 10 or 11, 64-bit (PowerShell 5.1+)
- ~6 GB free disk space (bundle extracts to ~4.1 GB; data grows with sessions)
- A local model server is recommended but not required for setup/verify:
  - [Ollama](https://ollama.com) — `http://127.0.0.1:11434/v1`
  - LM Studio — `http://127.0.0.1:1234/v1`
  - vLLM on a LAN machine — `http://<lan-ip>:8000/v1`

## Install (offline machine)

1. Download the bundle ZIP from [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) and copy it to the target PC (USB is fine).
2. Extract to a **short path** (e.g. `D:\hermes`) — Windows MAX_PATH limits deep extraction.
3. Run the setup wizard:
   ```powershell
   cd D:\hermes
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   Non-interactive with custom paths:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. Verify readiness (works even before setup — it auto-seeds config):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. Launch: double-click `launcher\HermesPortable.exe` (or `launcher\HermesPortable.cmd`).

### Where config and data live

| Path | Purpose | Override |
|---|---|---|
| `<root>\data\config.yaml` | Model provider, base_url, model name | `-DataRoot` or env `HERMES_HOME` |
| `<root>\data\` | Sessions, memories, skills state | as above |
| `<root>\work\` | Agent working directory | `-WorkRoot` |
| `<root>\cache\` | Cache | `-CacheRoot` |
| `<root>\config\hermes-portable.ini` | Central portable config (paths, port, mode) | edit directly |

## Updating an offline machine

1. On an **internet-connected** machine, build the latest bundle:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-offline.ps1
   ```
2. Copy the produced ZIP to the offline PC (USB/LAN).
3. Run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip
   ```
   The updater validates the manifest and checksums, backs up the current install, updates only changed components, and refuses downgrades.

## Repository layout

```
launcher/          setup.ps1, verify-offline.ps1, update-offline.ps1, HermesPortable.exe/.cmd
scripts/           build-offline.ps1, package-slim.ps1, skill_scan.py
tests/             4 PowerShell test suites (checksum, manifest, launcher env, update round-trip)
docs/              architecture, offline strategy, risks, test report, quickstart
config/            config.yaml.template, providers.local.yaml
```

> The 1.82 GiB bundle itself is distributed via GitHub Releases, not committed to the tree.

## FAQ

**Does it need internet at all?** Only to download the bundle once. After that: setup, verify, launch, and updates all work offline.

**Which skills work offline?** 31 of 230 are fully offline-capable (local file ops, document parsing, code tools, etc.). The 180 network-dependent skills are disabled automatically so the agent never hangs on a failed fetch.

**Can I use my own model?** Yes — any OpenAI-compatible endpoint. Set `-LocalBaseUrl`/`-LocalModel` at setup or edit `data\config.yaml`.

**Why port 8942?** It avoids the common dev ports (8642, 8643, 9119, 9120, 5678, 8080, 8090) so the agent can coexist with other local services. Change it with `-GatewayPort`.

## License

MIT — see [LICENSE](LICENSE). Hermes Agent is by [NousResearch](https://github.com/NousResearch/hermes-agent); this repo is an offline packaging/distribution project.
