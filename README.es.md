# Hermes Desktop Offline (Español)

**Ejecuta un agente de IA completo en tu PC Windows — sin internet.**

Otros idiomas: [English](README.md) · [简体中文](README.zh-CN.md) · [Tiếng Việt](README.vi.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** empaqueta la app de escritorio [Hermes Agent](https://github.com/NousResearch/hermes-agent) en un bundle autocontenido para Windows listo para entornos air-gap: app Electron, runtime Python 3.14, payload del agente y 230 skills — todo verificado con SHA-256 y ejecutado contra un **modelo local** (Ollama, LM Studio, vLLM en LAN). Sin cuenta en la nube, sin API key, sin red tras la instalación.

## Diferencias frente a la versión online

| Versión online | **Hermes Desktop Offline** |
|---|---|
| Requiere internet para APIs, actualizaciones y skills | **Cero dependencia** tras instalar — funciona en máquinas aisladas |
| Modelos de nube con API key (coste, riesgo de privacidad) | LLM local: Ollama / LM Studio / vLLM en LAN |
| Datos en servidores del proveedor | Todo queda en tu carpeta de instalación (`data/`, `work/`, `cache/`) |
| Descargas durante la instalación | Manifiesto SHA-256: cada archivo se verifica antes de la primera ejecución |
| Actualización automática por internet | ZIP de actualización transferido por USB/LAN, integridad verificada, rechaza downgrade, backup automático |
| Skills descargados bajo demanda | 230 skills incluidos; 31 totalmente offline, 180 dependientes de red se desactivan automáticamente |
| Ligado a `%USERPROFILE%` | Portable: rutas personalizadas; ejecutable desde USB |

**Casos de uso:** fábricas y laboratorios sin internet, PCs gubernamentales air-gap, sectores sensibles (salud, legal, finanzas), regiones con conectividad irregular.

## Características destacadas

- 📦 **Un solo ZIP** (~1.82 GiB, 58,166 archivos): Electron + payload + Python 3.14.9 + skills + launcher + docs.
- 🔐 **Integridad primero**: `checksums.sha256` (58,165 entradas) verificado en setup.
- 🧩 **Skills offline-safe**: los skills con dependencias de red se desactivan con motivo explícito.
- 🔄 **Actualizaciones seguras sin red**: valida manifiesto y checksums, hace backup, actualiza por componentes, rechaza versiones anteriores.
- ⚙️ **Rutas configurables**: root de datos/trabajo/cache, puerto gateway (por defecto **8942**), URL del modelo local.
- ✅ **Probado end-to-end** en Windows 11: extract → setup → verify → smoke launch; 4 suites de tests en verde.

## Requisitos

- Windows 10/11 de 64 bits (PowerShell 5.1+)
- ~6 GB de disco libre
- Servidor de modelos local recomendado: Ollama (`http://127.0.0.1:11434/v1`), LM Studio (`http://127.0.0.1:1234/v1`), vLLM LAN (`http://<lan-ip>:8000/v1`)

## Instalación (máquina offline)

1. Descarga el ZIP desde [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) y cópialo al PC destino (USB vale).
2. Extrae en una **ruta corta** (p. ej. `D:\hermes`) — el MAX_PATH de Windows limita rutas profundas.
3. Ejecuta el asistente:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   No interactivo:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. Verifica:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. Inicia: doble clic en `launcher\HermesPortable.exe`.

## Actualización sin internet

1. En una máquina con internet: `scripts\build-offline.ps1` genera el ZIP.
2. Transfiere el ZIP a la máquina offline.
3. `launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip` — valida, respalda, actualiza por componentes y rechaza downgrade.

## FAQ

**¿Necesita internet?** Solo para descargar el bundle una vez. Todo lo demás funciona offline.
**¿Qué skills funcionan offline?** 31 de 230 son totalmente offline; los 180 dependientes de red se desactivan automáticamente.
**¿Puedo usar mi propio modelo?** Sí, cualquier endpoint compatible con OpenAI vía `-LocalBaseUrl`/`-LocalModel` o `data\config.yaml`.

## Licencia

MIT — ver [LICENSE](LICENSE). Hermes Agent es de [NousResearch](https://github.com/NousResearch/hermes-agent); este repositorio es un proyecto de empaquetado offline.
