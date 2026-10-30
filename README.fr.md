# Hermes Desktop Offline (Français)

**Exécutez un agent IA complet sur votre PC Windows — sans internet.**

Autres langues : [English](README.md) · [简体中文](README.zh-CN.md) · [Tiếng Việt](README.vi.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

> **Hermes Desktop Offline** emballe l'application de bureau [Hermes Agent](https://github.com/NousResearch/hermes-agent) dans un bundle Windows auto-suffisant, prêt pour l'air-gap : application Electron, runtime Python 3.14, payload de l'agent et 230 skills — tous vérifiés par SHA-256, exécutés contre un **modèle local** (Ollama, LM Studio, vLLM en LAN). Aucun compte cloud, aucune clé API, aucun réseau après l'installation.

## Ce qui change par rapport à la version en ligne

| Version en ligne | **Hermes Desktop Offline** |
|---|---|
| Internet requis (API, mises à jour, skills) | **Zéro dépendance** après installation — fonctionne en air-gap |
| Modèles cloud avec clé API (coût, confidentialité) | LLM local : Ollama / LM Studio / vLLM en LAN |
| Données sur les serveurs du fournisseur | Tout reste dans votre dossier d'installation (`data/`, `work/`, `cache/`) |
| Téléchargements à l'installation | Manifeste SHA-256 : chaque fichier vérifié avant le premier lancement |
| Mise à jour automatique en ligne | ZIP de mise à jour transféré par USB/LAN, intégrité vérifiée, refus du downgrade, sauvegarde automatique |
| Skills téléchargés à la demande | 230 skills inclus ; 31 entièrement offline, 180 dépendants du réseau désactivés automatiquement |
| Lié à `%USERPROFILE%` | Portable : chemins personnalisés, exécutable depuis une clé USB |

**Cas d'usage :** usines et laboratoires sans internet, PC gouvernementaux air-gap, secteurs sensibles (santé, juridique, finance), zones à connectivité instable.

## Points forts

- 📦 **Un seul ZIP** (~1,82 GiB, 58 166 fichiers) : Electron + payload + Python 3.14.9 + skills + launcher + docs.
- 🔐 **Intégrité d'abord** : `checksums.sha256` (58 165 entrées) vérifié lors du setup.
- 🧩 **Skills offline-sûrs** : les skills dépendants du réseau sont désactivés avec une raison claire.
- 🔄 **Mises à jour offline sûres** : validation du manifeste et des checksums, sauvegarde, mise à jour par composant, refus du downgrade.
- ⚙️ **Chemins configurables** : racines data/work/cache, port gateway (par défaut **8942**), URL du modèle local.
- ✅ **Testé de bout en bout** sur Windows 11 : extraction → setup → vérification → lancement ; 4 suites de tests vertes.

## Prérequis

- Windows 10 ou 11 64 bits (PowerShell 5.1+)
- ~6 Go d'espace disque
- Serveur de modèles local recommandé : Ollama (`http://127.0.0.1:11434/v1`), LM Studio (`http://127.0.0.1:1234/v1`), vLLM LAN (`http://<lan-ip>:8000/v1`)

## Installation (machine offline)

1. Téléchargez le ZIP depuis [Releases](https://github.com/tungleqb/hermes-desktop-offline/releases) et copiez-le sur le PC cible (USB acceptable).
2. Extrayez dans un **chemin court** (ex. `D:\hermes`) — MAX_PATH Windows limite les chemins profonds.
3. Lancez l'assistant :
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1
   ```
   Non interactif :
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\setup.ps1 `
     -NonInteractive -GatewayPort 8942 -DataRoot E:\hermes-data -LocalBaseUrl http://127.0.0.1:11434/v1 -LocalModel llama3
   ```
4. Vérifiez :
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File launcher\verify-offline.ps1
   ```
5. Lancez : double-cliquez `launcher\HermesPortable.exe`.

## Mise à jour sans internet

1. Sur une machine connectée : `scripts\build-offline.ps1` produit le ZIP.
2. Transférez le ZIP vers la machine offline.
3. `launcher\update-offline.ps1 -Zip D:\transfer\Hermes-Offline-<version>.zip` — valide, sauvegarde, met à jour par composant, refuse le downgrade.

## FAQ

**Internet nécessaire ?** Uniquement pour télécharger le bundle une fois. Setup, vérification, lancement et mises à jour fonctionnent offline.
**Quels skills fonctionnent offline ?** 31 sur 230 sont entièrement offline ; les 180 dépendants du réseau sont désactivés automatiquement.
**Modèle personnel ?** Oui, tout endpoint compatible OpenAI via `-LocalBaseUrl`/`-LocalModel` ou `data\config.yaml`.

## Licence

MIT — voir [LICENSE](LICENSE). Hermes Agent est développé par [NousResearch](https://github.com/NousResearch/hermes-agent) ; ce dépôt est un projet d'emballage offline.
