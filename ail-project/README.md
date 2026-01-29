# AIL Project (Analysis of Information Leaks)

The AIL framework is analyzed using a **Hybrid Architecture**: `Native LXC` + `External Docker Bridge`.

## Architecture Rationale

* **Native LXC**: AIL runs natively on a dedicated Debian LXC for maximum performance and ZFS access.
* **External Bridge**: Instead of running Docker *inside* the LXC (which causes nesting errors), we run a lightweight `ail-proxy` on your **Main Docker Host** (where `infra`, `xtm`, `proxy` run). This container bridges traffic from `cti-net` to the AIL LXC IP.

## Installation Steps

### 1. Create the LXC (Proxmox Host)

Use the **Ubuntu** script from your fork to create a clean base (Ubuntu 24.04).

```bash
bash -c "$(wget -qLO - https://github.com/JazenaYLA/ProxmoxVE/raw/main/ct/ubuntu.sh)"
```

* **Resources**: 4-8 Cores, 32GB+ RAM, 100GB+ Disk.
* **Note**: This creates a lightweight container without unnecessary Docker overhead.
* **Compatibility**: While we recommend Ubuntu for official support, **Debian 13** is also fully compatible with AIL if you prefer it.

### 2. Install AIL (Inside LXC)

SSH into your new LXC (`pct enter <id>` or ssh).

* *Note*: You do **NOT** need to use the installed Dockge/Docker inside this LXC. It acts purely as a host.

```bash
# Install system dependencies
sudo apt update && sudo apt install -y git python3-venv build-essential python3-dev

# Clone AIL Framework
cd /opt
git clone https://github.com/ail-project/ail-framework.git
cd ail-framework
git submodule update --init --recursive

# Install Dependencies (Manual Method)
./installing_deps.sh

# IMPORTANT: Fix for ZFS/Unprivileged LXC
# Disable Direct I/O in Redis to prevent crashes
sed -i 's/use_direct_io_for_flush_and_compaction true/use_direct_io_for_flush_and_compaction false/g' configs/6382.conf
# Verify the change
grep "use_direct_io" configs/6382.conf
```

### 3. Start AIL (Inside LXC)

```bash
cd /opt/ail-framework/bin
./LAUNCH.sh -l
```

## Feeders & Importers

To make AIL fully functional, you need to feed it data.

### 1. Crawlers (Lacus) - *Recommended*

We have already deployed **Lacus** on your main Docker host. AIL uses this to crawl URLs.

* **Status**: Ready.
* **Config**: AIL is pre-configured to use `http://lacus:7100` (via `cti-net`).

### 2. Paste Monitor (Pystemon)

Pystemon monitors paste sites (like Pastebin) and feeds them into AIL.
**Install inside the AIL LXC**:

```bash
# 1. Clone Pystemon
cd /opt
git clone https://github.com/cvandeplas/pystemon.git

# 2. Install Dependencies (using AIL venv)
cd ail-framework
. ./AILENV/bin/activate
cd ../pystemon
pip install -U -r requirements.txt

# 3. Configure Pystemon
cp pystemon.yaml.sample pystemon.yaml
nano pystemon.yaml
# Ensure 'redis' section points to localhost:6379 (inside LXC)

# 4. Link AIL to Pystemon
nano /opt/ail-framework/configs/core.cfg
# Search for [Pystemon] and set:
# dir = /opt/pystemon/alerts

# 5. Start Pystemon Feeder
cd /opt/ail-framework/bin
./LAUNCH.sh -f  # Starts pystemon and importer
```

### 3. Manual File Import

To import a dump of local files or directories:

```bash
cd /opt/ail-framework
. ./AILENV/bin/activate
cd tools
# Import a directory of files
./file_dir_importer.py -d /path/to/your/dump/
```

Run this bridge on your **dockge-cti** (or main Docker host), **NOT** inside the AIL LXC.

1. Copy the following files to a new directory (e.g., `ail-bridge`) on your main docker host:
    * `ail-project/docker-compose.yml`
    * `ail-project/ail-nginx.conf`
    * `ail-project/.env.example`
2. **Configure Environment**:

    ```bash
    cp .env.example .env
    nano .env
    # Set AIL_LXC_IP to your actual LXC IP
    ```

3. Start the stack:

    ```bash
    docker compose up -d
    ```

## Integration Data Flow

AIL is part of a larger CTI pipeline:

1. **AIL -> MISP**:
    * AIL can push interesting "pastes" or leaked credentials to MISP.
    * **Config**: In AIL web UI, go to **Management > MISP**. Add your MISP instance URL (`http://misp-core`) and Auth Key.
    * **Modules**: Enable `MISP Export` module in AIL.

2. **AIL -> OpenCTI**:
    * OpenCTI can ingest data from AIL via the **AIL Connector** (future addition) or via MISP sync.
    * Typically, AIL data goes to MISP first, then syncs to OpenCTI.

### 4. Integration & Usage

Once the bridge is running (`docker compose up -d`), you can access AIL in two ways:

1. **Web UI (Browser)**:
    * **http://<Main-Docker-Host-IP>:7000**
    * This traffic is proxied through `ail-proxy` to your LXC.

2. **Internal Service Communication (e.g., from OpenCTI)**:
    * If you deploy an AIL connector in the future, use the internal Docker hostname:
    * **URL**: `http://ail-proxy:7000`
    * **API Key**: Generated inside AIL.

This bridge allows all your containerized apps on `cti-net` to "see" the AIL LXC as if it were just another container named `ail-proxy`.
