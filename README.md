# ThreatLabs Homelab CTI Stack

A comprehensive Cyber Threat Intelligence (CTI) stack running on Docker, designed for homelab usage.

## Architecture

This repository is organized into modular stacks that share common infrastructure.

```mermaid
    graph TD

    subgraph "Gateway (Optional)"
        Proxy[Reverse Proxy<br/>Traefik]
    end

    subgraph "Infrastructure (infra/)"
        ES8[(ElasticSearch 8)]
        ES7[(ElasticSearch 7)]
        Postgres[(Postgres 17)]
        Valkey[(Valkey / Redis)]
    end

    subgraph "MISP Stack (misp/)"
        MISP[MISP Core]
        MISPDB[(MariaDB)]
        MISPCache[(Local Valkey)]
    end

    subgraph "MISP Modules (misp-modules/)"
        Modules[Modules API]
        ModulesWeb[Modules Web UI]
    end

    subgraph "Extended Threat Management (xtm/)"
        OpenCTI[OpenCTI Platform]
        OpenAEV[OpenAEV Platform]
        XTMMinIO[(MinIO)]
        XTMRabbit[(RabbitMQ)]
    end

    subgraph "Analysis & Case Management"
        FlowIntel[FlowIntel]
        TheHive[TheHive 4]
        Cassandra[(Cassandra)]
        IRIS[DFIR-IRIS]
    end

    subgraph "Automation & Collection"
        n8n[n8n Automation]
        Flowise[Flowise AI]
        Lacus[Lacus Crawler]
        AIL[AIL Framework LXC]
    end

    %% Infrastructure Dependencies
    OpenCTI --> ES8
    TheHive --> ES7
    
    OpenAEV & FlowIntel & n8n --> Postgres
    OpenCTI & FlowIntel & Lacus --> Valkey

    %% Local Stack Dependencies
    MISP --> MISPDB & MISPCache
    TheHive --> Cassandra
    OpenCTI & OpenAEV --> XTMMinIO & XTMRabbit

    %% Integrations
    MISP & FlowIntel --> Modules
    AIL --> Lacus
    AIL -.->|Push| MISP
    n8n -->|API| MISP & OpenCTI & Flowise
    
    %% Gateway Routing
    Proxy -.-> MISP & ModulesWeb & OpenCTI & OpenAEV & FlowIntel & n8n & Flowise & TheHive & IRIS
```

### Directory Structure

* **`infra/`**: **Core Infrastructure**. Hosts shared **ElasticSearch** (v7 & v8), **PostgreSQL 17**, and **Valkey** (Redis).
* **`proxy/`**: **Traefik Proxy**. Shared reverse proxy for accessing services via subdomains.
* **`misp-modules/`**: **Shared Enrichment**. Standalone MISP modules service used by both MISP and FlowIntel.
* **`xtm/`**: **Extended Threat Management**. Hosts OpenCTI, OpenAEV, and their connectors. Depends on `infra`.
* **`misp/`**: **Malware Information Sharing Platform**. Hosting MISP Core, Modules, and Guard.
* **`n8n/`** & **`flowise/`**: **Automation**. Workflow automation and LLM chains.
* **`flowintel/`**: **Case Management**. Lightweight alternative to TheHive.
* **`lacus/`**: **Crawling**. AIL Framework crawler (Playwright-based).
* **`thehive/`**: **Legacy Case Management**. TheHive 4, depends on `infra` (ES7).
* **`dfir-iris/`**: **Incident Response**. DFIR-IRIS collaborative IR platform (self-contained Postgres 12 + RabbitMQ).
* **`shuffle/`**: **SOAR**. Shuffle Automation Platform for security orchestration.
* **`ail-project/`**: **Dark Web Analysis**. Instructions for deploying AIL Framework in a separate LXC.

### Shared Network

All stacks communicate via an external Docker network named `cti-net`.

### Documentation & Troubleshooting

For detailed architecture decisions, trade-offs, and troubleshooting steps, please refer to the **[Project Wiki](docs/Home.md)**:

*   **[Architecture & Decisions](docs/Architecture.md)**
*   **[Troubleshooting Guide](docs/Troubleshooting.md)**
*   **[Project Timeline](docs/Project-Timeline.md)**

> [!TIP]
> See [docs/Troubleshooting.md](docs/Troubleshooting.md) for network, permission, and common boot issues.

## Factory Reset

If you need to completely wipe the stack and start over (delete all data):

1. Run the reset script:

    ```bash
    chmod +x reset.sh
    ./reset.sh
    ```

2. Type `NUKE` when prompted.
3. Run `./setup.sh` to re-initialize the environment.

## Getting Started

### 1. Pre-requisites

Ensure Docker and Docker Compose are installed.

If cloning for the first time:

```bash
git clone --recurse-submodules https://github.com/JazenaYLA/threatlabs-cti-stack.git
```

(If you forgot `--recurse-submodules`, simply run `./setup.sh` and it will fix it).

### 2. (Optional) For Dockge Users

If you are managing your stacks with **Dockge**, you can use the `setup-dockge.sh` script to symlink these stacks into your Dockge directory (default `/opt/stacks`).

> [!NOTE]
> `setup.sh` is **MANDATORY** for everyone as it creates the necessary docker network (`cti-net`) and volumes.
> `setup-dockge.sh` is **OPTIONAL** and only for users who want to see these stacks in their Dockge dashboard.

```bash
sudo ./setup-dockge.sh
```

### 3. Configuration

Run the setup script to prepare networks, volumes, and generate environment files:

```bash
./setup.sh
```

### 4. Production vs Development

This stack supports isolated "Production" and "Development" environments on the same host. In production, we use a custom project name (`cti-prod`) and isolated database names (e.g., `prod_openaev`) to protect your data.

**Environment Management Utility:**
Use the included utility script to switch modes or manage the lifecycle of all stacks:

```bash
chmod +x manage-env.sh
./manage-env.sh prod up      # Switch to Production and start everything
./manage-env.sh dev status   # Check current active environment
```

> [!TIP]
> See **[docs/Development.md](docs/Development.md)** for a full guide on running local dev instances next to production.

## Startup Order

While you can use `./manage-env.sh prod up` to start everything, you can also manage them manually following this order:

1. **Start Infrastructure Stack (REQUIRED FIRST)**

    * **CLI**: `cd infra && docker compose up -d`
    * **Dockge**: Go to `/opt/stacks` (Dashboard), select `infra`, and click **Active** / **Update**.

    *Wait for ElasticSearch clusters to be fully healthy.*

1. **Start Proxy (Optional but Recommended)**

    ```bash
    cd proxy && docker compose up -d
    ```

1. **Start Application Stacks**

    You can start the stacks in any order:

    * **OpenCTI / OpenAEV**: `cd xtm && docker compose up -d`
    * **MISP**: `cd misp && docker compose up -d`
    * **n8n**: `cd n8n && docker compose up -d`
    * **Flowise**: `cd flowise && docker compose up -d`
    * **FlowIntel**: `cd flowintel && docker compose up -d`
    * **TheHive**: `cd thehive && docker compose up -d`
    * **DFIR-IRIS**: `cd dfir-iris && docker compose up -d`
    * **Shuffle**: `cd shuffle && docker compose up -d`
    * **Lacus**: `cd lacus && docker compose up -d`
    * **AIL Project**: See [ail-project/README.md](ail-project/README.md) for LXC deployment.
    * **Wazuh**: Deployed on Proxmox LXC 105 (IP: 192.168.3.195).

### External LXC Services

Some components are deployed as standalone LXC (Linux Container) instances for better isolation and performance.

* **Wazuh**: Main SIEM/XDR manager.
* **OpenClaw**: Specialized collection/analysis service.
* **AIL Project**: Analysis Information Leak framework.

> [!NOTE]
> These services are managed outside of the Docker lifecycle. Refer to `internal_ips.md` for their network locations.

## TheHive

### Initial Login Credentials
* **Username**: `admin@thehive.local`
* **Password**: `secret`

> [!IMPORTANT]
> Change the default password immediately after first login.

## DFIR-IRIS

Collaborative Incident Response platform. Accessible via **HTTPS** on port `4433` (configurable via `IRIS_HTTPS_PORT`).

### Initial Login Credentials
The administrator password is **randomly generated on first boot** and printed in the app container logs:
```bash
sudo docker logs iris-app 2>&1 | grep "create_safe_admin"
```

> [!IMPORTANT]
> The password is only printed once. Change it immediately and store it securely.
> To set a specific initial password, configure `IRIS_ADM_PASSWORD` in `.env` **before** first boot.

## FlowIntel

See [flowintel/README.md](flowintel/README.md) for full documentation.

### Initial Login Credentials
By default, the stack is configured to create an initial admin user:
* **Email**: `admin@admin.admin`
* **Password**: `admin`

You can change these **before the first run** by editing `flowintel/.env`:
```bash
INIT_ADMIN_EMAIL=your@email.com
INIT_ADMIN_PASSWORD=securepassword
```

> [!NOTE]
> If you have already started FlowIntel and want to change the initial admin:
> 1. Stop the container: `docker compose down`
> 2. Reset the database (see TROUBLESHOOTING.md)
> 3. Restart: `docker compose up -d`

### MISP Modules (Analyzers)

FlowinTel uses [MISP modules](https://www.misp-project.org/2024/03/12/Introducing.standalone.MISP.modules.html/) as its analyzer engine for enrichment. It **bundles its own `misp-modules` process** internally, so enrichment works out of the box.

To share API keys and custom modules with the rest of the stack, you can optionally point it to the shared `misp-modules-shared` instance — see [flowintel/README.md](flowintel/README.md#pointing-to-shared-instance-optional).

## MISP Modules

See [misp-modules/README.md](misp-modules/README.md) for full documentation.

Provides 200+ enrichment, expansion, import, and export modules as a shared service:
- **API** on port `6666` — used by MISP Core, FlowIntel, and any HTTP client
- **Web UI** on port `7008` — standalone interface for querying modules without a MISP instance

## Notes

* **Networks**: All stacks communicate via the `cti-net` Docker network. Create it with `docker network create cti-net` or let `setup.sh` handle it.
* **Stack READMEs**: Each stack directory has its own `README.md` with detailed configuration and troubleshooting.
* **Shared Infrastructure**: `infra/` provides PostgreSQL, Valkey, and ElasticSearch shared by multiple stacks. Always start it first.
* **Enrichment API Keys**: Configure enrichment API keys (VirusTotal, Shodan, etc.) in `misp-modules/.env` for centralized access.

