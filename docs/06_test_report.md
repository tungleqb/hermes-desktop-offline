# 06 - Test Report (executed on WindyPC, 2026-10-29)

All suites ran locally on the Windows host, no network access required. Results are from real executions.

## 6.1 tests/manifest_schema_test.ps1 - 13 PASS / 0 FAIL
Validates the bundle manifest contract: accepts valid manifest and builder output; rejects wrong schemaVersion, non-semver version, wrong target, missing required component, optional/required mismatch, path/key mismatch, bad sha256, bad commit sha, unknown keys, missing/malformed manifest.

## 6.2 tests/checksum_test.ps1 - 6 PASS / 0 FAIL
Clean tree verifies; detects single-byte corruption, missing file, unlisted file, malformed hash line, absent checksum list.

## 6.3 tests/launcher_env_test.ps1 - 22 PASS / 0 FAIL
ini parsing, required keys, writable roots, placement/mode/port validation, strict mode rejects non-loopback base_url and allow_lan, lan mode permits LAN endpoint, rejects malformed ini/unknown mode/out-of-range port.

## 6.4 tests/update_roundtrip_test.ps1 - 29 PASS / 0 FAIL
Simulated air-gap update lifecycle: apply bundle, backup per update, payload re-seal, downgrade refused without -Force, corrupted zip aborts with nothing written, preflight rejects bad schema/target/version mismatch, component-scoped update.

## 6.5 Unit total: 70 PASS / 0 FAIL

## 6.6 Phase 4 end-to-end (final bundle, 2026-10-29)
Bundle: artifacts\Hermes-Offline-0.22.5-offline-win-x64.zip - 2,384,753,363 bytes, 118,904 files, 5.42 GB unpacked. Extracted clean to test-install4 with 7za.

| Step | Result |
|---|---|
| 7za x extract | 118,904 files, 0 errors (clean target dir avoids .pdb/.pyd collisions) |
| launcher\setup.ps1 -NonInteractive -GatewayPort 8942 | PASS - payload checksums OK, seeded data\config.yaml, wrote config\hermes-portable.ini |
| launcher\verify-offline.ps1 | 6 PASS / 0 FAIL: checksums 118,903 entries 0 mismatch; interpreter 3.14.9; install-stamp; app exe hermes-bf0203a.exe; 230 skills; config loopback |
| Smoke launch app\hermes-bf0203a.exe | PASS - 4 Electron processes alive after 90-120 s; dashboard served HTTP 200 (title HTML) on internal ports 65175/58228 (random internal ports, no conflict with 8642/8643/9119/9120) |

Port safety: setup.ps1 accepts -GatewayPort (default 8942). Host ports 8642, 8643, 9119, 9120, 5678, 8080, 8090, 10001-10006 remain untouched by the offline bundle.

Notes:
- checksums.sha256 excludes __pycache__, .pyc, .pdb and user-mutable roots (data, work, cache).
- Headless SSH screenshot of the desktop returned a black frame (no interactive session attached); UI verified via HTTP 200 responses from the Electron-rendered dashboard instead.
- Official bundled-build artifact also produced: apps\desktop\release\HermesBundled-0.0.0-win-x64.msix (~2.67 GB) with win-unpacked, cold-start verified (gateway /health ok, dashboard /api/health ok).

## 6.7 Grand total
70 PASS unit suites + 6/6 end-to-end checks + smoke launch PASS.
