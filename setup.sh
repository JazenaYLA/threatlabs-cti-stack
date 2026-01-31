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
    echo "[+] Network 'cti-net' created."
fi

# Helper function to create volumes in both Repo and /opt/stacks
create_vol() {
    local PATH_SUFFIX=$1
    echo "    Creating $PATH_SUFFIX..."
    mkdir -p "$PATH_SUFFIX"
    # If /opt/stacks exists, create there too (assuming standard naming)
    # Extract stack name from path (first component)
    local STACK_NAME=$(echo "$PATH_SUFFIX" | cut -d'/' -f1)
    if [ -d "/opt/stacks/$STACK_NAME" ]; then
        echo "    Mirroring to /opt/stacks/$STACK_NAME..."
        sudo mkdir -p "/opt/stacks/$PATH_SUFFIX"
        sudo chown -R 1000:1000 "/opt/stacks/$STACK_NAME" || true
    fi
}

# 2. Prepare Infrastructure Volumes (Infra)
echo "[*] Preparing Infra volumes..."
create_vol "infra/vol/esdata7/data"
create_vol "infra/vol/esdata8/data"
create_vol "infra/vol/postgres/data"
create_vol "infra/vol/valkey/data"
create_vol "infra/vol/postgres-init"
# Ensure init script execution permission
chmod +x infra/vol/postgres-init/init-dbs.sh 2>/dev/null || true
sudo chown -R 1000:1000 infra/vol || echo "[-] Warning: Failed to chown infra/vol. You may need sudo."

# 3. Prepare XTM Volumes (OpenCTI/OpenAEV)
# 3. Prepare XTM Volumes (OpenCTI/OpenAEV)
echo "[*] Preparing XTM volumes..."
create_vol "xtm/volumes/pgsqldata"
create_vol "xtm/volumes/s3data"
create_vol "xtm/volumes/redisdata"
create_vol "xtm/volumes/amqpdata"
create_vol "xtm/volumes/rsakeys"
sudo chown -R 1000:1000 xtm/volumes || echo "[-] Warning: Failed to chown xtm/volumes."

# 4. Prepare Modular Stack Volumes
echo "[*] Preparing modular stack volumes..."

# Cortex
create_vol "cortex/vol/cortex"
sudo chown -R 1000:1000 cortex/vol || echo "[-] Warning: Failed to chown cortex/vol."

# n8n (DB moved to infra)
create_vol "n8n/vol/n8n"
sudo chown -R 1000:1000 n8n/vol || echo "[-] Warning: Failed to chown n8n/vol."

# Flowise
create_vol "flowise/vol/flowise"
sudo chown -R 1000:1000 flowise/vol || echo "[-] Warning: Failed to chown flowise/vol."

# FlowIntel (DB/Cache moved to infra)
create_vol "flowintel/vol/flowintel/data"
sudo chown -R 1000:1000 flowintel/vol || echo "[-] Warning: Failed to chown flowintel/vol."

# Lacus (Cache moved to infra)
create_vol "lacus/vol/lacus-data"
create_vol "lacus/vol/lacus-cache"
sudo chown -R 1000:1000 lacus/vol || echo "[-] Warning: Failed to chown lacus/vol."

# TheHive (Legacy/Archive)
create_vol "thehive/vol/cassandra/data"
create_vol "thehive/vol/thehive"
sudo chown -R 1000:1000 thehive/vol || echo "[-] Warning: Failed to chown thehive/vol."

# 5. Generate Default Configurations (if missing)
echo "[*] Checking for default configurations..."

# Cortex Default Config
if [ ! -f cortex/vol/cortex/application.conf ]; then
    echo "[+] Generating default Cortex application.conf..."
    cat <<EOF > cortex/vol/cortex/application.conf
## Cortex Configuration (Auto-Generated)
play.http.secret.key="changeme_$(date +%s | sha256sum | base64 | head -c 32)"
search {
  index = "cortex"
  hostnames = ["http://es8-cti:9200"]
}
job {
  runner = [docker, process]
}
analyzer {
  urls = ["https://catalogs.download.strangebee.com/latest/json/analyzers.json"]
}
responder {
  urls = ["https://catalogs.download.strangebee.com/latest/json/responders.json"]
}
EOF
fi

# TheHive Default Config
if [ ! -f thehive/vol/thehive/application.conf ]; then
    echo "[+] Generating default TheHive application.conf..."
    cat <<EOF > thehive/vol/thehive/application.conf
## TheHive Configuration (Auto-Generated)
play.http.secret.key="changeme_$(date +%s | sha256sum | base64 | head -c 32)"
db.janusgraph {
  storage {
    backend = cql
    hostname = ["cassandra"]
    cql {
      cluster-name = thp
      keyspace = thehive
    }
  }
  index.search {
    backend = elasticsearch
    hostname = ["es7-cti"]
    index-name = thehive
  }
}
storage {
  provider = localfs
  localfs.location = /var/lib/thehive/data
}
EOF
fi

# 6. Check Host Requirements
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
