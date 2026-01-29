#!/usr/bin/env bash
set -e

# Setup Script for ThreatLabs CTI Stack
# Usage: ./setup.sh

echo "[*] Initializing ThreatLabs CTI Stack Setup..."

# 1. Create Shared Network
# We check if it exists first to avoid errors
if docker network ls | grep -q "cti-net"; then
    echo "[+] Network 'cti-net' already exists."
else
    echo "[*] Creating network 'cti-net'..."
    docker network create cti-net
    echo "[+] Network 'cti-net' created."
fi

# 2. Prepare Infrastructure Volumes (Infra)
echo "[*] Preparing Infra volumes..."
mkdir -p infra/vol/{esdata7/data,esdata8/data}
sudo chown -R 1000:1000 infra/vol || echo "[-] Warning: Failed to chown infra/vol. You may need sudo."

# 3. Prepare XTM Volumes (OpenCTI/OpenAEV)
echo "[*] Preparing XTM volumes..."
mkdir -p xtm/volumes/{pgsqldata,s3data,redisdata,amqpdata,rsakeys}

# 4. Prepare Modular Stack Volumes
echo "[*] Preparing modular stack volumes..."

# Cortex
mkdir -p cortex/vol/cortex
sudo chown -R 1000:1000 cortex/vol || echo "[-] Warning: Failed to chown cortex/vol."

# n8n
mkdir -p n8n/vol/{n8n,postgres/data}
sudo chown -R 1000:1000 n8n/vol || echo "[-] Warning: Failed to chown n8n/vol."

# Flowise
mkdir -p flowise/vol/flowise
sudo chown -R 1000:1000 flowise/vol || echo "[-] Warning: Failed to chown flowise/vol."

# FlowIntel
mkdir -p flowintel/vol/{postgres/data,valkey/data,flowintel/data}
sudo chown -R 1000:1000 flowintel/vol || echo "[-] Warning: Failed to chown flowintel/vol."

# TheHive (Legacy/Archive)
mkdir -p thehive/vol/{cassandra/data,thehive}
sudo chown -R 1000:1000 thehive/vol || echo "[-] Warning: Failed to chown thehive/vol."

# 5. Check Host Requirements
echo "[*] Checking host requirements..."
VM_MAX_MAP_COUNT=$(sysctl -n vm.max_map_count)
if [ "$VM_MAX_MAP_COUNT" -lt 262144 ]; then
    echo "[-] WARNING: vm.max_map_count is $VM_MAX_MAP_COUNT. ElasticSearch requires 262144."
    echo "    Run: sudo sysctl -w vm.max_map_count=262144"
    echo "    And add to /etc/sysctl.conf to persist."
else
    echo "[+] vm.max_map_count is sufficient ($VM_MAX_MAP_COUNT)."
fi

echo "[+] Setup completed. You can now deploy stacks with Docker Compose or Dockge."
echo "    Order: 1. infra, 2. proxy & xtm, 3. cortex/n8n/flowise."
