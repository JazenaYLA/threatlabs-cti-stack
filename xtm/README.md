# XTM Docker Deployment

Docker deployment for the **eXtended Threat Management (XTM)** stack, combining [OpenCTI](https://github.com/OpenCTI-Platform/opencti) and [OpenAEV](https://github.com/OpenAEV-Platform/openaev) into a unified threat intelligence and adversary emulation platform.

## Overview

This repository provides a complete Docker Compose setup for running:

- **OpenCTI** — Open Cyber Threat Intelligence Platform
- **OpenAEV** — Open Adversary Emulation & Validation Platform
- **XTM Composer** — Unified connector/collector management
- **Shared Infrastructure** — Elasticsearch, MinIO, RabbitMQ
- **Platform-specific** — Redis (OpenCTI), PostgreSQL (OpenAEV)

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.0+
- Minimum 16GB RAM (recommended 32GB for production)
- At least 50GB available disk space

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                              XTM Stack                                    │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│    ┌─────────────┐        ┌──────────────┐        ┌─────────────┐         │
│    │   OpenCTI   │◄──────►│ XTM Composer │◄──────►│   OpenAEV   │         │
│    │    :8080    │        │              │        │    :8081    │         │
│    └─────┬────┬──┘        └──────────────┘        └───┬───┬─────┘         │
│          │    │                                       │   │               │
│          │    │                                       │   │               │
│          ▼    │                                       │   ▼               │
│    ┌─────────┐│                                       │┌───────────┐      │
│    │  Redis  ││                                       ││PostgreSQL │      │
│    └─────────┘│                                       │└───────────┘      │
│               │                                       │                   │
│               │  ┌────────────────────────────┐       │                   │
│               └─►│   Shared Infrastructure    │◄──────┘                   │
│                  │                            │                           │
│                  │  ┌──────────────────────┐  │                           │
│                  │  │    Elasticsearch     │  │                           │
│                  │  └──────────────────────┘  │                           │
│                  │                            │                           │
│                  │  ┌─────────┐  ┌─────────┐  │                           │
│                  │  │  MinIO  │  │RabbitMQ │  │                           │
│                  │  └─────────┘  └─────────┘  │                           │
│                  └────────────────────────────┘                           │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/FiligranHQ/xtm-docker.git
cd xtm-docker
```

### 2. Create environment file

Create a `.env` file from the provided template:

```bash
cp .env.example .env
```

Then edit `.env` and replace all `ChangeMe_UUIDv4` and `changeme` values. Look for `[CRITICAL]` markers — these **must** be changed before first start:

```bash
# Generate UUIDs:
uuidgen

# Generate passwords/keys:
openssl rand -hex 32
```

> **Important:** Every `CONNECTOR_*_ID`, `COLLECTOR_*_ID`, and `INJECTOR_*_ID` must be a **unique** UUIDv4. Do not reuse the same UUID across connectors.

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Access the platforms

Once all services are healthy (this may take a few minutes on first start):

- **OpenCTI**: <http://localhost:8080>
- **OpenAEV**: <http://localhost:8081>
- **RabbitMQ Management**: <http://localhost:15672>

## Included Components

### OpenCTI Connectors (Required — Default Install)

These connectors are part of the **official XTM default install** and each requires a unique UUIDv4 in `.env`:

| Connector | `.env` Variable | Description |
|-----------|-----------------|-------------|
| Export File STIX | `CONNECTOR_EXPORT_FILE_STIX_ID` | Export data in STIX 2.1 format |
| Export File CSV | `CONNECTOR_EXPORT_FILE_CSV_ID` | Export data in CSV format |
| Export File TXT | `CONNECTOR_EXPORT_FILE_TXT_ID` | Export data in plain text format |
| Import File STIX | `CONNECTOR_IMPORT_FILE_STIX_ID` | Import STIX 2.1 bundles |
| Import Document | `CONNECTOR_IMPORT_DOCUMENT_ID` | Import PDF, HTML, and text documents |
| Import File YARA | `CONNECTOR_IMPORT_FILE_YARA_ID` | Import YARA rules |
| Analysis | `CONNECTOR_ANALYSIS_ID` | Document analysis connector |
| Import External Reference | `CONNECTOR_IMPORT_EXTERNAL_REFERENCE_ID` | Import external references |
| OpenCTI Datasets | `CONNECTOR_OPENCTI_ID` | Default marking definitions and identities |
| MITRE ATT&CK | `CONNECTOR_MITRE_ID` | MITRE ATT&CK framework data |

### OpenCTI Connectors (Optional — Require API Keys)

These connectors are **disabled by default** to conserve resources. To enable one, uncomment both its `.env` variables **and** its service definition in `docker-compose.yml`:

| Connector | Requires |
|-----------|----------|
| MISP | Running MISP instance + API key |
| TheHive | Running TheHive instance + API key |
| AlienVault OTX | OTX API key |
| Malpedia | Malpedia API key |
| MalwareBazaar | MalwareBazaar API key |
| Shodan | Shodan API key |
| Malbeacon | Malbeacon API key |
| IPInfo | ipinfo.io API key |

### Resource Optimization

To prevent disk exhaustion and reduce noise:
- **Unused Connectors:** Are commented out in `docker-compose.yml` by default.
- **Log Rotation:** Key services (`opencti`, `openaev`, `worker`, `minio`, `rabbitmq`) are configured with `json-file` logging (`max-size: 10m`, `max-file: 3`).

### OpenAEV Collectors (Required — Default Install)

| Collector | `.env` Variable | Description |
|-----------|-----------------|-------------|
| MITRE ATT&CK | `COLLECTOR_MITRE_ATTACK_ID` | Attack techniques and procedures |
| OpenAEV Datasets | `COLLECTOR_OPENAEV_ID` | Default datasets and configurations |
| Atomic Red Team | `COLLECTOR_ATOMIC_RED_TEAM_ID` | Red Canary's Atomic Red Team tests |
| NVD NIST CVE | `COLLECTOR_NVD_NIST_CVE_ID` | CVE data from NVD (API key optional) |

### OpenAEV Injectors (Required — Default Install)

| Injector | `.env` Variable | Description |
|-----------|-----------------|-------------|
| Nmap | `INJECTOR_NMAP_ID` | Network scanning capabilities |
| Nuclei | `INJECTOR_NUCLEI_ID` | Vulnerability scanning with Nuclei |

### Connector Service Accounts

All non-export connectors use `CONNECTOR_AUTO_CREATE_SERVICE_ACCOUNT=true` to automatically create a dedicated service account on first registration with OpenCTI. This follows the [official Filigran documentation](https://docs.opencti.io/latest/deployment/connectors/#connector-token) recommendation of running each connector under its own identity.

| Connector Role | Token Used | Service Account | Confidence |
|---|---|---|---|
| **Export File** (STIX/CSV/TXT) | `OPENCTI_ADMIN_TOKEN` | ❌ Not created — requires admin bypass to impersonate requesting user | N/A |
| **OpenCTI Datasets** | `OPENCTI_ADMIN_TOKEN` (initial auth) | ✅ Auto-created | 100 |
| **All other connectors** | `OPENCTI_ADMIN_TOKEN` (initial auth) | ✅ Auto-created | 75 |

> **Note:** The admin token is only used for initial registration. Once the service account is created, the connector uses its own token automatically.

## Configuration

### Memory Requirements

Adjust `ELASTIC_MEMORY_SIZE` based on your available RAM:

| Total RAM | Recommended Setting |
|-----------|---------------------|
| 16GB | `2G` |
| 32GB | `4G` |
| 64GB+ | `8G` |

### Scaling Workers

Modify the worker replicas in `docker-compose.yml`:

```yaml
worker:
  deploy:
    mode: replicated
    replicas: 3  # Increase for higher throughput
```

### External Access

To expose the platforms externally (behind reverse-proxy for instance), update the environment variables:

```bash
OPENCTI_EXTERNAL_SCHEME=https
OPENCTI_HOST=opencti.yourdomain.com
OPENCTI_PORT=443

OPENAEV_EXTERNAL_SCHEME=https
OPENAEV_HOST=openaev.yourdomain.com
OPENAEV_PORT=443
```

## Common Operations

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f opencti
docker compose logs -f openaev
```

### Check service health

```bash
docker compose ps
```

### Stop the stack

```bash
docker compose down
```

### Reset data (destructive)

```bash
docker compose down -v
```

## Troubleshooting

### Services not starting

1. Check if Elasticsearch has enough virtual memory:

   ```bash
   sudo sysctl -w vm.max_map_count=262144
   ```

2. Verify **all** required UUIDs are set in `.env` — look for `ChangeMe_UUIDv4` values

3. Check logs for specific errors:

   ```bash
   docker compose logs <service-name>
   ```

### OpenAEV failing to connect to OpenCTI

1. `OPENAEV_XTM_OPENCTI_API_URL` must end with `/graphql` — e.g., `http://opencti:8080/graphql`
2. `OPENAEV_XTM_OPENCTI_ID` must be a valid UUIDv4 in `.env`
3. `OPENAEV_XTM_OPENCTI_TOKEN` must match `OPENCTI_ADMIN_TOKEN`

### `VALIDATION_ERROR: input.id is null`

This means a connector service is running but its `CONNECTOR_*_ID` env var is blank. Either:
- Uncomment the ID in `.env` and set a valid UUID, or
- Comment out/remove the service in `docker-compose.yml`

### PostgreSQL permission errors

Alpine-based Postgres 17 uses UID `70`. Fix with:
```bash
sudo chown -R 70:70 /opt/stacks/infra/vol/postgres-data
```

See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for the full stack troubleshooting guide.

## Community

### Status & Bugs

If you wish to report bugs or request new features:

- **OpenCTI**: [GitHub Issues](https://github.com/OpenCTI-Platform/opencti/issues)
- **OpenAEV**: [GitHub Issues](https://github.com/OpenAEV-Platform/openaev/issues)

### Discussion

For support or discussions about the XTM stack, join us on our [Slack channel](https://community.filigran.io) or email us at <contact@filigran.io>.

## About

XTM is a product suite designed and developed by [Filigran](https://filigran.io).

<a href="https://filigran.io" alt="Filigran"><img src="https://github.com/OpenCTI-Platform/opencti/raw/master/.github/img/logo_filigran.png" width="300" /></a>
