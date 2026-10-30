# 05 - Risks, Mitigations, Open Questions

| # | Risk | Impact | Mitigation | Status |
|---|---|---|---|---|
| R1 | `electron-builder --dir` unsupported in the pinned builder | No unpacked build | Fallback: run builder with `--publish=never` and take `win-unpacked` produced by nsis stage; or use `portable` target with `noSign` | Build in progress |
| R2 | Payload size (~1.5–2 GB) exceeds practical ZIP/transfer limits | Slow/failed air-gap transfer | Split ZIP into parts + `parts.manifest`; 7z (already vendored in builder cache) for better ratio | Planned |
| R3 | 180 network-dependent skills fail silently on air-gapped machines | Confusing UX | `disabled-skills.json` + explicit "requires network" badge in UI; skills disabled by default | Implemented in strategy |
| R4 | Junction placement breaks if install root is on network share | Broken payload | `IsLocalNTFS` check in `setup.ps1`; refuse junction, fall back to copy | Implemented |
| R5 | Antivirus flags 1,100+ bundled PE binaries | False positives, blocked launch | `sanitize-pe` pass already run by upstream build; ship checksums; document allow-listing | Upstream handles |
| R6 | Copilot agent in VS Code writes to the wrong window (user warned: the open VS Code window is **not** this project) | Corrupting unrelated code | Every Copilot prompt is prefixed with the absolute project path `D:\dev\hermes-desktop-offline`; verify `editorFile`/open tabs before sending; open the project folder explicitly first | Active guard |
| R7 | Version drift between repo `main` and pinned commit | Reproducibility loss | Pin commit `bf0203a794a07aac3ff764972ab9087baa4e4f4e` (v0.22.5) in manifest; build script takes `--commit` | Implemented |
| R8 | No code signing | SmartScreen warnings | Document; optional self-sign later; checksums give integrity, not authenticity | Open |
| R9 | Local model quality/latency (GTX 1060 6GB / RTX 2060 12GB) | Poor UX | llamacpp-cpu + quantized models; recommend 7–14B Q4; LAN vLLM as primary | Open |

## Open questions to resolve before Phase 4
1. Does the pinned builder accept `--dir`? (build log will tell)
2. Where should the final artifact live for air-gap hand-off: `D:\hermes\releases\` (mapped to container) or `E:\AI-video-gen` style share?
3. Should the launcher be a compiled .NET exe (dotnet 9.0.319 available) or CMD-only? Both are provided; .NET gives env hygiene.
4. Do we need a GUI installer (Inno Setup / Squirrel) or is portable ZIP + `setup.ps1` sufficient for the user's workflow?
