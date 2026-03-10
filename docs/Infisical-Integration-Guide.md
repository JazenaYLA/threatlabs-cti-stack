# Advanced Guide: Infisical Secret Management

> **Status:** Advanced Topic (Not required for standard CTI deployment)
> **Goal:** Eliminate plaintext `.env` files across the `dockge-cti` stack by dynamically injecting secrets directly from a centralized, self-hosted Infisical instance at runtime.

---

## 🏗️ Architecture

Instead of managing 10+ identical `.env` files scattered across multiple Docker stacks (e.g., `/opt/stacks/misp/.env`, `/opt/stacks/xtm/.env`), we store them centrally in the **ThreatLabs CTI** Infisical Project.

1. **Infisical LXC** (`<INFISICAL_IP>`): Hosts the UI, Postgres DB, and Redis caching.
2. **Reverse Proxy:** Exposed internally via Caddy as `https://infisical.lab.local`.
3. **CLI Injection:** The `dockge-cti` server uses the `infisical` CLI wrapper to pull secrets natively when starting Docker Compose.

---

## 1. Initial Setup & Administration (Workstation)

Your local laptop/workstation needs the `infisical` CLI to interact with the server and upload local `.env` files into the centralized vault.

### Installation (macOS)

```bash
brew install infisical/get-cli/infisical
```

### Authentication

Login to your local CLI pointing to the self-hosted domain:

```bash
infisical login --domain https://infisical.lab.local
```

### Linking the Project

Navigate to your local stack repository (`threatlabs-cti-stack`) and link it to the Infisical Project ID:

```bash
cd ~/Documents/Forgejo/threatlabs-cti-stack
infisical init
```

*(This generates an `.infisical.json` file. Ensure this file is added to your `.gitignore`!)*

### Pushing Secrets to the Vault

Instead of manually typing secrets into the UI, you can batch ingest your existing `.env` files into the `prod` environment.

> **Important (macOS Sandboxing issues):** If running from a sandboxed terminal, the CLI might fail to read local files. Use this one-liner to strip empty variables and push cleanly:

```bash
for dir in xtm misp thehive shuffle flowintel dfir-iris lacus infra proxy misp-modules forgejo-runner ail-project; do
    echo "Pushing $dir"
    grep -E '^[^#].*=[^ \t]' "$dir/.env" > "/tmp/clean.env" 2>/dev/null || true
    if [ -s "/tmp/clean.env" ]; then
        infisical secrets set --env prod --file "/tmp/clean.env"
    fi
    rm -f "/tmp/clean.env"
done
```

---

## 2. Server Authentication (Machine Identities)

The production `dockge-cti` server should *never* be authenticated using a personal user account. Instead, it uses a **Machine Identity** restricted strictly to Read-Only access for the `prod` environment.

1. Go to Infisical UI → **Organization Settings** → **Access Control** → **Machine Identities**.
2. Create `dockge-cti-server` with Read-Only access to the `ThreatLabs CTI` project.
3. Securely copy the generated **Client ID** and **Client Secret**.

### Authenticate the `dockge-cti` server

Install the Infisical CLI on the Docker host, then run:

```bash
infisical login --method=universal-auth \
    --client-id="<CLIENT_ID>" \
    --client-secret="<CLIENT_SECRET>" \
    --domain="https://infisical.lab.local"
```

---

## 3. Persistent Secret Synchronization (Merging to Disk)

In this deployment, we prioritize **Documentation-First** `.env` files. Instead of using `infisical run` for in-memory injection (which hides secrets from the disk), we use a custom **Merge Logic** that patches your documented `.env` files with live secrets.

### The `update-secrets.sh` Script

Found in `scripts/update-secrets.sh`, this script:
1.  **Authenticates** with Infisical via raw `curl` (Universal Auth).
2.  **Exports** the vault content to a temporary location.
3.  **Merges** values into your local `.env` files using `sed`, preserving all of your original comments, headers, and documentation.

### Why this is better:
-   **Visibility**: You can always `cat .env` to see what is currently configured.
-   **Stability**: If Infisical is offline, the containers boot with the last known "cached" `.env` values on disk.
-   **Documentation**: Your 300+ lines of MISP documentation remain intact.

### Manual Synchronization
```bash
./scripts/update-secrets.sh
```
*Note: This script iterates through all 12 stacks (Phase 1-4) defined in `volume-config.sh`.*

---

## 4. Integrated Startup

The primary way to start the enterprise stack is now through the root **`startup.sh`**. It automatically calls the secret sync before performing its health-checked boot sequence.

```bash
./startup.sh
```

If a secret rotates in the Infisical UI, the containers won't automatically apply it unless restarted. You can configure the Infisical Agent to automatically trigger a `docker compose restart` via a bash script when it detects a vault change.

---

## 4. SMTP Email Configuration (User Invites)

Infisical must be able to send emails to invite other administrators or users to the organization. This bypasses authentication by utilizing the internal PMG relay (`<INFISICAL_PMG_RELAY_IP>`).

Modify `/etc/infisical/infisical.rb` inside the LXC:

```ruby
# --- STALWART/PMG SMTP CONFIGURATION ---
infisical_core['env_smtp_host'] = 'pmg.lab.local'
infisical_core['env_smtp_port'] = 25
infisical_core['env_smtp_secure'] = false
infisical_core['env_smtp_ignore_tls'] = true
infisical_core['env_smtp_name'] = 'ThreatLabs Infisical'
infisical_core['env_smtp_from_address'] = 'noreply@<DOMAIN>'
```

Apply the changes:

```bash
infisical-ctl reconfigure
infisical-ctl restart
```

---

## 5. Troubleshooting & API Fallback

### TLS Verification Issues (`x509: certificate signed by unknown authority`)

When using self-signed certificates for your Infisical instance, the CLI may fail to verify the certificate even after running `update-ca-certificates`.

-   **Symptoms**: `infisical login` or `infisical export` returns a TLS verification error.
-   **Workaround**: Use the **API Fallback** logic implemented in `update-secrets.sh`. Instead of relying on the CLI, we utilize `curl -k` (to skip TLS verification) and `jq` to fetch raw secrets directly from the Infisical V3 API.
-   **Universal Auth**: The script handles token generation via the machine identity Client ID/Secret pair, making it independent of the CLI's state.

### Infisical Offline
If the Infisical LXC is unreachable, the stack will continue to operate using the last successfully synchronized `.env` files stored on the Docker host. The `startup.sh` script will warn you if the sync fails but will proceed with the boot sequence to ensure service availability.
