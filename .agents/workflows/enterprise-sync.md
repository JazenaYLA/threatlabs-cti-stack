---
description: How to Reset, Setup, and Synchronize the Enterprise CTI Stack with Infisical
---

This workflow ensures a clean and secure start for the entire ThreatLabs CTI stack using Infisical as the secret provider.

### Prerequisites
- SSH access to the Docker Host.
- Infisical Machine Identity credentials (stored in `scripts/update-secrets.sh`).
- Local CA trusted (if using self-signed certs).

### 1. Reset the Environment (Optional/Clean Start)
To clear all persistent data while keeping your `.env` documentation templates:
```bash
./reset.sh
```
*Note: Type `NUKE` to confirm. Choose `N` to keep your restored templates.*

### 2. Initialize Infrastructure & Volumes
Run the setup script to re-create directories and permissions. It will now ask if you want to perform a one-time secret sync at the end:
// turbo
```bash
./setup.sh
```

### 3. Start the Stack (Integrated Sync)
This is now the **only command** you need for daily operations. It automatically calls `update-secrets.sh --sync-only` to ensure your keys are fresh before performing the phased, health-checked boot:
// turbo
```bash
./startup.sh
```
*Tip: Use `./startup.sh --skip-sync` if you want to boot using existing (cached) `.env` files without reaching out to Infisical.*

### 4. Verification
Check the status of the deployment:
```bash
docker ps
```
Or view the logs for a specific stack:
```bash
cd xtm && docker compose logs -f
```
