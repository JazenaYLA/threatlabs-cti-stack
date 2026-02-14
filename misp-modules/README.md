# MISP Modules Stack

Standalone shared [MISP enrichment modules](https://www.misp-project.org/2024/03/12/Introducing.standalone.MISP.modules.html/) for the CTI platform. Provides 200+ expansion, enrichment, import, and export modules accessible via HTTP API — usable by **any tool**, not just MISP.

## Architecture

```
┌──────────────────────────────────┐
│  misp-modules (API)              │
│  Container: misp-modules-shared  │
│  Port: 6666                      │
│  Image: ghcr.io/misp/...        │
│  Endpoints: /modules, /query     │
└──────────┬───────────────────────┘
           │  HTTP JSON API
           │
     ┌─────┼──────┬─────────────────┐
     │     │      │                 │
     ▼     ▼      ▼                 ▼
   MISP  FlowinTel  Web UI       Other tools
  (shared) (builtin)  (port 7008)  (curl, scripts)
```

| Consumer | Connection | How |
|----------|-----------|-----|
| **MISP Core** | `http://misp-modules-shared:6666` | `MISP_MODULES_FQDN` env var in `misp/docker-compose.yml` |
| **FlowIntel** (Analyzer) | `127.0.0.1:6666` (built-in) | Runs its own `misp-modules` process internally via `screen` |
| **Web UI** | `misp-modules-shared:6666` | `MISP_MODULE` env var in this stack's compose |
| **Direct API** | `http://localhost:6666` | `curl http://localhost:6666/modules` |

## Services

### `misp-modules` — API Backend

- **Image**: `ghcr.io/misp/misp-docker/misp-modules:latest`
- **Port**: `6666`
- **Purpose**: JSON API that exposes all MISP modules (expansion, hover, import, export, action)
- **Key endpoints**:
  - `GET /modules` — list all available modules with their metadata and required inputs
  - `POST /query` — run a module against an input attribute (e.g., enrich an IP via VirusTotal)

### `misp-modules-web` — Web Interface

- **Image**: Built locally from `Dockerfile.web`
- **Port**: `7008`
- **Purpose**: Standalone web UI for querying MISP modules without a MISP instance
- **Features**:
  - Browse all available modules by input type
  - Submit queries and view results as structured MISP objects, raw JSON, or Markdown
  - Query history with drill-down pivoting (follow related indicators)
  - Admin login with password protection
  - SQLite database for sessions and history

## Quick Start

```bash
# 1. Copy example env
cp .env.example .env

# 2. Edit .env — at minimum, set SECRET_KEY
#    Generate: openssl rand -hex 16
nano .env

# 3. Start the stack
docker compose up -d

# 4. Verify
curl http://localhost:6666/modules   # API — returns JSON module list
curl -I http://localhost:7008        # Web UI — returns HTTP 200
```

## Configuration

### `.env` Variables

#### API Service (`misp-modules`)

| Variable | Default | Description |
|----------|---------|-------------|
| `MISP_MODULES_DEBUG` | `false` | Enable debug logging |
| `VIRUSTOTAL_API_KEY` | — | VirusTotal enrichment |
| `SHODAN_API_KEY` | — | Shodan enrichment |
| `PASSIVETOTAL_API_KEY` | — | PassiveTotal enrichment |
| `GREYNOISE_API_KEY` | — | GreyNoise enrichment |
| `CENSYS_API_ID` / `CENSYS_API_SECRET` | — | Censys credentials |
| `CROWDSEC_API_KEY` | — | CrowdSec enrichment |
| `RECORDED_FUTURE_API_KEY` | — | Recorded Future enrichment |

> **Tip**: API keys set here are shared by all consumers (MISP, FlowIntel, Web UI). This is the central place to configure enrichment credentials.

#### Web Interface (`misp-modules-web`)

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | `change-me-...` | **Required**. Flask session secret. Generate: `openssl rand -hex 16` |
| `ADMIN_PASSWORD` | `admin` | Admin user password for the web UI |
| `FLASK_PORT` | `7008` | Web interface port |
| `MISP_MODULE` | `misp-modules-shared:6666` | API backend address (`host:port`, no `http://` prefix) |
| `DATABASE_URI` | `sqlite:///misp-module.sqlite` | Database URL for sessions and history |
| `QUERIES_LIMIT` | `100` | Max stored queries |

### Custom Modules

Mount custom Python modules into the API container via the volume mounts:

```
.vol/custom/
├── action_mod/    → /custom/action_mod
├── expansion/     → /custom/expansion
├── export_mod/    → /custom/export_mod
└── import_mod/    → /custom/import_mod
```

Place your `.py` module files in the appropriate directory and restart the container. They will automatically be loaded by the misp-modules API.

## Integration with Other Stacks

### MISP

MISP Core connects to the shared modules via `MISP_MODULES_FQDN` in `misp/docker-compose.yml` (note: the MISP Docker entrypoint reads `MISP_MODULES_FQDN`, not `_URL`):

```yaml
- MISP_MODULES_FQDN=http://misp-modules-shared:6666
```

This overrides MISP's default `http://misp-modules` hostname. MISP auto-discovers available modules. The following MISP config keys are automatically populated:
- `Enrichment_services_url`
- `Import_services_url`
- `Export_services_url`
- `Action_services_url`

### FlowIntel (Analyzers)

FlowIntel uses MISP modules as its **analyzer engine** — the only analyzer currently integrated. The [analyzer workflow](https://flowintel.github.io/flowintel-doc/#/docs/analyzers) is:

1. Select an input attribute (IP, domain, hash, etc.)
2. Select modules to run (e.g., VirusTotal, Shodan)
3. Submit query → review results
4. Assign results to a case or create a MISP object

**How FlowIntel connects to modules:**

FlowinTel **bundles its own `misp-modules` process** inside the container (runs `screen -dmS misp_mod_flowintel misp-modules -l 127.0.0.1` on port 6666). The connection target is hardcoded in `conf/config.py`:

```python
class Config:
    MISP_MODULE = '127.0.0.1:6666'
```

This means:
- **Out of the box**: FlowinTel works immediately — its built-in modules handle enrichment
- **API keys**: FlowinTel's built-in instance does **not** share API keys with the shared `misp-modules-shared` container. If you configure `VIRUSTOTAL_API_KEY` in this stack's `.env`, FlowinTel won't use it (it uses its own internal process)
- **Optional shared instance**: To use the shared instance instead (for centralized API keys and custom modules), patch `config.py` at startup. See "Pointing FlowinTel to Shared Instance" below.

#### Pointing FlowinTel to Shared Instance (Optional)

Add this block to `flowintel/entrypoint.sh` before the final `exec` line:

```bash
# Patch MISP Modules URL to use shared instance
if [ ! -z "$MISP_MODULES_URL" ]; then
    MODULE_ADDR=$(echo "$MISP_MODULES_URL" | sed 's|http://||;s|https://||')
    echo "[+] Patching MISP_MODULE to '$MODULE_ADDR'"
    sed -i "s|MISP_MODULE = .*|MISP_MODULE = '$MODULE_ADDR'|" /home/flowintel/app/conf/config.py
fi
```

The `MISP_MODULES_URL=http://misp-modules-shared:6666` env var is already defined in `flowintel/docker-compose.yml`.

> **Note**: FlowinTel also has **connectors** (MISP, TheHive) and **modules** (send_to scripts) which are separate from analyzers. Connectors define tool connections; modules push data outward. Analyzers (misp-modules) pull enrichment data inward.

### Web UI (This Stack)

The web UI is a standalone Flask app per the [MISP standalone modules announcement](https://www.misp-project.org/2024/03/12/Introducing.standalone.MISP.modules.html/). It communicates with the API exclusively via HTTP (`requests.get/post`) — it does **not** import the `misp-modules` Python package.

Use cases:
- **Threat intelligence analysis** — enrich indicators without a full MISP instance
- **Pivoting** — drill down from one indicator to related data points
- **Module development** — test custom modules without installing MISP
- **Untrusted service access** — query third-party APIs without connecting them to your core CTI infrastructure

## Upstream Differences

Our version is based on [JazenaYLA/misp-modules](https://github.com/JazenaYLA/misp-modules/tree/main/website) with these modifications:

| Change | Reason |
|--------|--------|
| `misp-modules` removed from `pyproject.toml` deps | Web UI only uses HTTP — never imports the package. Eliminates ~100 transitive deps. |
| Custom `Dockerfile.web` + `entrypoint-web.sh` | Upstream has no Docker support for the web UI |
| `poetry lock` regenerated during build | Required after dependency removal |
| Gunicorn instead of `mmw dev` / systemd | Docker-native production serving |
| Inline DB init instead of `mmw db init` | `db_init()` spawns a local subprocess; we use the external API container |

## Troubleshooting

- **Web UI: "Instance of misp-modules is unreachable"** — Ensure `misp-modules` is healthy: `docker compose ps`. Restart web UI: `docker compose restart misp-modules-web`
- **No modules listed in web UI** — Restart web UI to re-init the DB from the API
- **Build fails on `poetry install`** — `poetry.lock` must match `pyproject.toml`. Dockerfile runs `poetry lock` automatically; if you modify deps, delete `poetry.lock` and rebuild
- **`SECRET_KEY` error** — Set it in `.env`: `openssl rand -hex 16`
- **FlowinTel enrichment fails** — Check FlowinTel's built-in process: `docker exec flowintel-cti curl -s http://127.0.0.1:6666/modules | head -c 50`. Restart if needed.
