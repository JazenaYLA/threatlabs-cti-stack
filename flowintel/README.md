# FlowIntel Stack

Lightweight CTI case management platform — alternative to TheHive.

- **Image**: `ghcr.io/flowintel/flowintel:latest`
- **Port**: `7006`
- **Docs**: [flowintel.github.io/flowintel-doc](https://flowintel.github.io/flowintel-doc)

## Dependencies

| Dependency | Provided by | Connection |
|------------|------------|------------|
| PostgreSQL | `infra/` stack | `infra-postgres:5432` |
| Valkey (Redis) | `infra/` stack | `infra-valkey:6379` |
| MISP Modules (Analyzer) | Built-in | `127.0.0.1:6666` (see below) |

> **Note**: FlowinTel does **not** use its own database containers — it connects to the shared `infra-postgres` and `infra-valkey` instances. The database and user must be created by `infra/init-dbs.sh`.

## Quick Start

```bash
# 1. Ensure infra stack is running
cd /opt/stacks/infra && docker compose up -d

# 2. Start FlowinTel
cd /opt/stacks/flowintel && docker compose up -d

# 3. Access at http://localhost:7006
```

## Configuration (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_PORT` | `7006` | Host port mapping |
| `POSTGRES_USER` | `flowintel` | Database user (must match `infra/init-dbs.sh`) |
| `POSTGRES_PASSWORD` | `changeme` | Database password |
| `POSTGRES_DB` | `flowintel` | Database name |
| `VALKEY_IP` | `infra-valkey` | Redis/Valkey hostname |
| `JWT_SECRET` | `changeme` | JWT signing secret |
| `INIT_ADMIN_EMAIL` | `admin@admin.admin` | Initial admin user email |
| `INIT_ADMIN_PASSWORD` | `admin` | Initial admin user password |
| `MISP_MODULES_URL` | `http://misp-modules-shared:6666` | Shared MISP modules URL (optional, see below) |

## Login

Default admin credentials (set **before first run** in `.env`):
- **Email**: `admin@admin.admin`
- **Password**: `admin`

> To change after first run: stop the container, reset the database (see ../docs/Troubleshooting.md), and restart.

## MISP Modules Integration (Analyzers)

FlowinTel uses MISP modules as its **analyzer engine** — currently the only integrated analyzer. The [analyzer workflow](https://flowintel.github.io/flowintel-doc/#/docs/analyzers):

1. Select an input attribute (IP, domain, hash, etc.)
2. Choose modules to run (VirusTotal, Shodan, etc.)
3. Submit → review results
4. Assign results to a case or create a MISP object

### How It Connects

FlowinTel **bundles its own `misp-modules` process** inside the container. It runs automatically on startup:

```
screen -dmS misp_mod_flowintel misp-modules -l 127.0.0.1
```

The connection is configured via `conf/config.py`:
```python
MISP_MODULE = '127.0.0.1:6666'
```

### Built-in vs Shared Instance

| | Built-in (default) | Shared (`misp-modules-shared`) |
|-|--------------------|---------------------------------|
| API Keys | Not configured — set individually inside the container | Centrally managed in `misp-modules/.env` |
| Custom Modules | Not available | Mounted via `misp-modules/.vol/custom/` |
| Consistency | Independent from MISP/Web UI | Same modules and keys as MISP and Web UI |
| Setup | Zero config | Requires entrypoint patching |

### Pointing to Shared Instance (Optional)

To use the shared `misp-modules-shared` container instead of the built-in process, the `entrypoint.sh` needs to patch `config.py` at startup. Add this block before the final `exec` line:

```bash
# Patch MISP Modules URL to use shared instance
if [ ! -z "$MISP_MODULES_URL" ]; then
    MODULE_ADDR=$(echo "$MISP_MODULES_URL" | sed 's|http://||;s|https://||')
    echo "[+] Patching MISP_MODULE to '$MODULE_ADDR'"
    sed -i "s|MISP_MODULE = .*|MISP_MODULE = '$MODULE_ADDR'|" /home/flowintel/app/conf/config.py
fi
```

The `MISP_MODULES_URL` env var is already defined in `docker-compose.yml`.

> **Why isn't this automatic?** FlowIntel reads `MISP_MODULE` from its Python config file (`conf/config.py`), not from environment variables. The patching was previously enabled in `entrypoint.sh` but was reverted since the built-in instance works out of the box.

## Connectors, Modules, and Analyzers

FlowinTel has three distinct integration concepts ([docs](https://flowintel.github.io/flowintel-doc/#/docs/connectors)):

| Concept | Direction | Purpose | Examples |
|---------|-----------|---------|----------|
| **Connectors** | Bidirectional | Define tool connections with instances | MISP, TheHive |
| **Modules** | Outbound | Push FlowinTel data to external tools | `send_to/misp_event.py` |
| **Analyzers** | Inbound | Pull enrichment data into FlowinTel | MISP modules (only one integrated) |

## Custom Entrypoint

The `entrypoint.sh` is mounted into the container and handles:
1. Wait for PostgreSQL to be ready
2. Inject custom admin credentials into `config.py` and `init_db.py`
3. Check if the database/admin user exists
4. Initialize the database if needed (`launch.sh -id`)
5. Start the application (`launch.sh -ld`)

## Troubleshooting

- **"Postgres is not reachable"** — Ensure `infra` stack is running: `cd /opt/stacks/infra && docker compose ps`
- **Login fails with default creds** — DB was already initialized with different creds. Reset: stop container, delete DB, restart.
- **Enrichment/analyzer fails** — Check built-in misp-modules: `docker exec flowintel-cti curl -s http://127.0.0.1:6666/modules | head -c 50`
- **Enrichment returns empty results** — API keys are not configured in the built-in instance. Either configure them inside the container or switch to the shared instance.
