# Hermes Desktop Offline Installer — Project

**Location (Windows host):** `D:\dev\hermes-desktop-offline`
**Source repo (Windows host):** `D:\dev\hermes-agent` @ commit `bf0203a794a07aac3ff764972ab9087baa4e4f4e` (v0.22.5)
**Target:** air-gapped Windows 11 x64 machines, local/LAN LLM only.

## Layout
```
docs/                 01_investigation, 02_architecture, 03_plan,
                      04_offline_strategy, 05_risks, 06_test_report,
                      OFFLINE-QUICKSTART
scripts/              build-offline.ps1, package-slim.ps1,
                      verify-offline.ps1, update-offline.ps1, skill_scan.py
installer/            setup.ps1, HermesPortable.cmd
launcher-src/         HermesPortable.cs (.NET 9, compiled to launcher-build)
launcher-build/       compiled HermesPortable.exe
tests/                4 test suites (70 PASS / 0 FAIL)
third-party-skills/   vendored anthropics/skills
artifacts/            stage/ + final Hermes-Offline-<ver>-win-x64.zip
logs/                 build logs
```

## Build pipeline (host, internet-connected)
1. `python scripts\bundles\desktop.py --commit <sha> --variant bundled -- --dir --publish=never`
   → produces `apps\desktop\release\win-unpacked` (6.26 GB, agent payload embedded in `resources\agent-payload`).
2. `scripts\package-slim.ps1 -Slim hip,vulkan` prunes GPU-specific llamacpp variants not needed on the target box, stages app+skills+config+launcher, computes checksums + manifest, zips with 7za.
3. Result: `artifacts\Hermes-Offline-0.22.5-offline-win-x64.zip` + sidecar `.manifest.json`.

## Install pipeline (air-gapped machine)
1. Extract ZIP → run `launcher\setup.ps1` (choose data/work roots, local model URL).
2. `launcher\verify-offline.ps1` → integrity + interpreter + config checks.
3. Launch `launcher\HermesPortable.exe` (or `.cmd`).
4. Updates: hand over a new ZIP, run `launcher\update-offline.ps1 -Zip <file>` (validates, backs up, applies, re-verifies).

## Status
- Phase 1 (investigation): done — docs/01.
- Phase 2 (architecture): done — docs/02.
- Phase 3 (implementation + tests): done — scripts, launcher, installer, 70/70 tests PASS — docs/06.
- Phase 4 (end-to-end verification): DONE — real 2.35 GB bundle extracted, setup + verify (6 PASS / 0 FAIL) + smoke launch (app alive, 4 hermes processes) all PASS — docs/06 §6.6.
- Final artifact: `artifacts\Hermes-Offline-0.22.5-offline-win-x64.zip` (2,351,203,974 bytes) + `.manifest.json` sidecar.
