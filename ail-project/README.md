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
* **Note**: This creates a lightweight container without unnecessary Docker overhead. Disk.

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

### 4. Deploy the Bridge (Main Docker Host)

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

### 4. Integration

* **URL**: `http://<Main-Docker-Host-IP>:7000` (Proxied) OR `http://<LXC-IP>:7000` (Direct)
* **OpenCTI**: Use the internal hostname `ail-proxy` to connect to AIL from other containers on `cti-net`.
