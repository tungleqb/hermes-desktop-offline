# Hermes Desktop Offline (Deutsch)

**Ein vollständiger KI-Agent auf Ihrem Windows-PC — ohne Internet.**

Weitere Sprachen: [English](README.md) · [简体中文](README.zh-CN.md) · [Tiếng Việt](README.vi.md) · [Español](README.es.md) · [Français](README.fr.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** verpackt die [Hermes Agent](https://github.com/NousResearch/hermes-agent)-Desktop-App in ein autarkes, air-gap-taugliches Windows-Bundle: Electron-App, Python-3.14-Runtime, Agent-Payload und 230 Skills — alle per SHA-256 verifiziert, ausgeführt gegen einen **lokalen** Modellserver (Ollama, LM Studio, vLLM im LAN). Kein Cloud-Konto, kein API-Key, kein Netzwerk nach der Installation.

## Unterschiede zur Online-Version

| Online | **Offline** |
|---|---|
| Internet für API, Updates, Skills | **Null Abhängigkeit** nach Installation — läuft in air-gap-Umgebungen |
| Cloud-Modelle mit API-Key (Kosten, Datenschutz) | Lokale LLMs: Ollama / LM Studio / vLLM im LAN |
| Daten auf Anbieter-Servern | Alles bleibt im Installationsordner (`data/`, `work/`, `cache/`) |
| Downloads bei der Installation | SHA-256-Manifest: jede Datei vor dem ersten Start geprüft |
| Automatische Online-Updates | Offline-Update-ZIP per USB/LAN, Integritätsprüfung, Downgrade-Schutz, Auto-Backup |
| Skills bei Bedarf heruntergeladen | 230 Skills enthalten; 31 voll offline, 180 netzabhängige automatisch deaktiviert |
| An `%USERPROFILE%` gebunden | Portabel: eigene Pfade, Lauf vom USB-Stick |

**Anwendungsfälle:** Fabriken/Labore ohne Internet, behördliche Air-Gap-PCs, datenschutz-sensitive Branchen (Gesundheit, Recht, Finanzen), Regionen mit unzuverlässiger Verbindung.

## Highlights

- 📦 **Ein ZIP, alles enthalten** (~1,82 GiB, 58.166 Dateien)
- 🔐 **Integrität zuerst**: `checksums.sha256` (58.165 Einträge) beim Setup geprüft
- 🧩 **Offline-sichere Skills**: netzabhängige Skills werden automatisch deaktiviert
- 🔄 **Sichere Offline-Updates**: Manifest- und Checksummen-Validierung, Backup, Komponenten-Updates, Downgrade-Verweigerung
- ⚙️ **Konfigurierbare Pfade**: Data/Work/Cache-Roots, Gateway-Port (Standard **8942**), lokale Modell-URL
- ✅ **End-to-end getestet** auf Windows 11: Extract → Setup → Verify → Smoke-Launch; 4 Testsuiten grün

## Anforderungen

- Windows 10/11, 64-Bit (PowerShell 5.1+)
- ~6 GB freier Speicher
- Lokaler Modellserver empfohlen: Ollama (`http://127.0.0.1:11434/v1`), LM Studio (`http://127.0.0.1:1234/v1`), vLLM im LAN

## Installation (Offline-Rechner)

1. ZIP aus [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) herunterladen und auf den Ziel-PC kopieren (USB genügt).
2. In einen **kurzen Pfad** extrahieren (z. B. `D:\hermes`) — Windows-MAX_PATH begrenzt tiefe Pfade.
3. Setup-Assistent:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   Nicht-interaktiv:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. Prüfen: `launcher\verify-offline.ps1`
5. Starten: Doppelklick auf `launcher\HermesPortable.exe`

## Aktualisierung ohne Internet

1. Auf einem Online-Rechner: `scripts\build-offline.ps1` erzeugt das ZIP.
2. ZIP auf den Offline-Rechner übertragen.
3. `launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip` — validiert, sichert, aktualisiert komponentenweise, verweigert Downgrades.

## Lizenz

MIT — siehe [LICENSE](LICENSE). Hermes Agent von [NousResearch](https://github.com/NousResearch/hermes-agent); dieses Repo ist ein Offline-Packaging-Projekt.
