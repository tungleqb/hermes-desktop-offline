# Hermes Desktop Offline - Quick Start (air-gapped Windows)

## 1. What you get
A portable ZIP bundle:
```
Hermes-Offline-0.22.5-offline-win-x64.zip
  app/              Electron desktop app (win-unpacked, agent payload embedded)
  runtime/          pointer/README (payload lives in app\resources\agent-payload)
  skills-bundle/    skills, optional-skills, plugins, third-party skills
  config/           config.yaml.template, providers.local.yaml
  launcher/         HermesPortable.exe, setup.ps1, verify-offline.ps1, update-offline.ps1
  docs/             this quickstart + architecture docs
  manifest.json     bundle metadata (version, commit, components)
  checksums.sha256  integrity list
```

## 2. Install (first run)
1. Extract the ZIP to a local NTFS folder, e.g. `D:\hermes-desktop`.
2. Run the wizard:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   - Choose `data_root` (HERMES_HOME: sessions, memories, skills state)
   - Choose `work_root` (agent working directory)
   - Set local model base URL (default `http://127.0.0.1:11434/v1` = Ollama)
   - Set `gateway_port` if 8942 conflicts with existing services:
     `setup.ps1 -GatewayPort 9100` (pick any free port; avoid 8642/8643/9119/9120/5678/8080/8090/10001-10006 on WindyPC)
3. Verify:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```

## 3. Launch
- Double-click `launcher\HermesPortable.exe`, or
- `launcher\HermesPortable.cmd` (no compile needed), or
- run `app\hermes-bf0203a.exe` directly.

## 4. Local model
Edit `data\config.yaml`:
```yaml
model:
  provider: openai-compatible
  base_url: http://127.0.0.1:11434/v1   # Ollama
  model: qwen3:14b
```
LAN presets available in `config\providers.local.yaml` (LM Studio :1234, llama.cpp :8080, LAN vLLM 100.106.91.39:8001).
If no model server exists, the bundled `llamacpp-cpu` tool can serve a GGUF locally.

## 5. Updating on an air-gapped machine
Copy a new bundle ZIP to the machine (USB/internal share), then:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File launcher\update-offline.ps1 -Zip D:\updates\Hermes-Offline-0.23.0-win-x64.zip
```
The updater: validates manifest + checksums, refuses downgrades, backs up the old install, applies components, re-seals the payload, and runs verification.

## 6. Offline rules
- 31 skills are offline-capable and enabled; 180 network-dependent skills are shipped but disabled by default.
- Web toolsets are off (`toolsets.web: false`).
- No cloud provider keys are required or used.
