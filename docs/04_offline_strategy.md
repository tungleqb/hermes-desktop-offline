# 04 - Offline Strategy & Air-Gap Policy

## 4.1 Offline modes
| Mode | Meaning | Allowed endpoints |
|---|---|---|
| `strict` | No outbound network at all | `127.0.0.1`, `localhost`, LAN IPs only |
| `lan` | LAN-only (default for WindyPC lab) | loopback + RFC1918 / lab subnet (100.x.x.x on this host's lab network) |
| `airgap-strict` | Also blocks LAN; local model on same box | loopback only |

Enforcement points:
1. **Config seed** — `config.yaml.template` sets `network.offline: true`, `toolsets.web: false`.
2. **Launcher** — exports `HERMES_OFFLINE=1`; `verify-offline.ps1` greps config for non-loopback URLs in strict mode.
3. **Skills** — only the 31 offline-capable skills (per `skill_inventory.json`) are enabled by default; 180 network-dependent skills are shipped but disabled (`HERMES_OPTIONAL_SKILLS` points at them, and a `disabled-skills.json` list gates them).
4. **Updater** — updates arrive only as signed ZIP bundles handed over physically or via internal share; no auto-fetch.

## 4.2 Local model wiring
`providers.local.yaml` presets:
- Ollama `http://127.0.0.1:11434/v1`
- LM Studio `http://127.0.0.1:1234/v1`
- llama.cpp server `http://127.0.0.1:8080/v1`
- LAN vLLM (toriai AI server) `http://100.106.91.39:8001/v1`

The desktop app's own model must be one of these; cloud providers (Anthropic/OpenAI) are left in the config template commented out so a future re-connect is explicit.

## 4.3 What is already offline-safe in the payload
Verified from the build log:
- `uv-cache` is **lock-scoped and shipped** → "offline rebuilds resolve from shipped wheels".
- `baked bytecode` (26,955 modules) → cold start without re-compiling.
- Portable tool store contains: python 3.14.9, node 26.12.1, npm 12.0.2, git 2.53, ripgrep 15.2, ffmpeg 9.0.1, gh 2.97, chromium 1208, cua-driver 0.21, llamacpp (cpu/cuda/hip/vulkan), agent-browser, bws.
  → **llamacpp-cpu is the fallback local inference engine** if no LAN model server exists.

## 4.4 Skills classification (measured)
From `scripts/skill_scan.py` over the repo checkout:
- total skills: **211**
- offline-capable: **31**
- network-dependent: **180**

Rule used: a skill is offline-capable iff its SKILL.md has zero remote URLs and no API-key requirement. Third-party `anthropics/skills` (docx, xlsx, pptx, pdf, canvas-design, algorithmic-art, …) are vendored into `third-party-skills/` and re-classified by the same scanner before shipping.

## 4.5 Data & work roots (user-customizable)
`hermes-portable.ini` is the single source of truth:
```ini
[paths]
install_root = D:\dev\hermes-desktop-offline
data_root    = E:\hermes-data      ; HERMES_HOME (sessions, memories, skills state)
work_root    = E:\hermes-work      ; agent cwd
cache_root   = D:\dev\hermes-desktop-offline\cache
payload_placement = junction       ; copy | junction
```
Rules enforced by `setup.ps1`:
- data/work roots must exist and be writable (probe write).
- roots must **not** be symlinks/junctions (security + integrity).
- `config.yaml` is seeded once, never overwritten.

## 4.6 Update bundle format
`Hermes-Offline-<version>-win-x64.zip` containing:
```
manifest.json          # schemaVersion 1, version, commit, builtAt, target, components
checksums.sha256       # "hash  relative/path" for every file
app/                   # Electron win-unpacked
runtime/               # agent-payload (python, pm-runtime, tools, uv-cache)
skills-bundle/         # skills, optional-skills, plugins, third-party
config/                # templates only
launcher/              # HermesPortable.exe/.cmd, setup.ps1, verify-offline.ps1, update-offline.ps1
docs/                  # OFFLINE-QUICKSTART.md
```
`update-offline.ps1` refuses: missing manifest, schema mismatch, target mismatch, filename/manifest version mismatch, downgrade without `-Force`, any checksum mismatch. It backs up before applying and re-seals the payload.
