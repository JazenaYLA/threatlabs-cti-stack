# ThreatLabs Homelab CTI Stack

A comprehensive Cyber Threat Intelligence (CTI) stack running on Docker, designed for homelab usage.

## Architecture

This repository is organized into modular stacks that share common infrastructure.

### Directory Structure

* **`infra/`**: **Core Infrastructure**. Hosting shared ElasticSearch (v7 & v8) and Kibana clusters.
* **`proxy/`**: **Traefik Proxy**. Shared reverse proxy for accessing services via subdomains.
* **`xtm/`**: **Extended Threat Management**. Hosts OpenCTI, OpenAEV, and their connectors. Depends on `infra` (ES8).
* **`misp/`**: **Malware Information Sharing Platform**. Hosting MISP Core, Modules, and Guard.
* **`cortex/`**: **Observable Analysis**. Cortex 4, depends on `infra` (ES8).
* **`n8n/`** & **`flowise/`**: **Automation**. Workflow automation and LLM chains.
* **`flowintel/`**: **Case Management**. Lightweight alternative to TheHive.
* **`ail-project/`**: **Dark Web Analysis**. Instructions for deploying AIL Framework in a separate LXC.
* **`thehive/`**: **Legacy Case Management**. TheHive 4, depends on `infra` (ES7).

### Shared Network

All stacks communicate via an external Docker network named `cti-net`.

> [!TIP]
> See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for network, permission, and common boot issues.

## Getting Started

### 1. Pre-requisites

Ensure Docker and Docker Compose are installed.

### 2. Configuration

Run the setup script to prepare networks and volumes:

```bash
./setup.sh
```

**For Dockge Users:**
If you use Dockge, you can automatically link these stacks to your `/opt/stacks` directory:

```bash
sudo ./setup-dockge.sh
```

Navigate to each directory and create your environment file from the example:

```bash
# Infrastructure
cp infra/.env.example infra/.env
# Edit infra/.env

# OpenCTI / OpenAEV
cp xtm/.env.example xtm/.env
# Edit xtm/.env

# MISP
cp misp/template.env misp/.env
# Edit misp/.env

# Cortex
cp cortex/.env.example cortex/.env

# n8n
cp n8n/.env.example n8n/.env

# Flowise
cp flowise/.env.example flowise/.env

# FlowIntel
cp flowintel/.env.example flowintel/.env

# TheHive (Legacy)
cp thehive/.env.example thehive/.env
```

> [!IMPORTANT]
> Ensure you verify the `ES_HEAP_SIZE_GB` in `infra/.env` fits your host's available RAM.

1. Startup Order

The services must be started in a specific order to ensure database availability.

1. **Start Infrastructure Stack (REQUIRED FIRST)**

    ```bash
    cd infra && docker compose up -d
    ```

    *Wait for ElasticSearch clusters to be fully healthy.*

2. **Start Proxy (Optional but Recommended)**

    ```bash
    cd proxy && docker compose up -d
    ```

3. **Start Application Stacks**
    You can start these in any order.

    * **OpenCTI / OpenAEV**: `cd xtm && docker compose up -d`
    * **MISP**: `cd misp && docker compose up -d`
    * **Cortex**: `cd cortex && docker compose up -d`
    * **n8n**: `cd n8n && docker compose up -d`
    * **Flowise**: `cd flowise && docker compose up -d`
    * **FlowIntel**: `cd flowintel && docker compose up -d`
    * **AIL Project**: See [ail-project/README.md](ail-project/README.md) for LXC deployment.

## Notes

* **Networks**: Ensure the `cti-net` network exists or let the `infra` stack create it (if configured to do so, otherwise create manually: `docker network create cti-net`).
