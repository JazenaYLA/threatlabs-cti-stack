#!/usr/bin/env bash
set -e

# Setup Script for ThreatLabs CTI Stack
# Usage: ./setup.sh

echo "[*] Initializing ThreatLabs CTI Stack Setup..."

# 0. Initialize Submodules (if missing)
if [ -f ".gitmodules" ]; then
    echo "[*] checking submodules..."
    git submodule update --init --recursive
fi

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

# OpenClaw (AI Agent)
create_vol "openclaw/vol/config"
create_vol "openclaw/vol/workspace"
sudo chown -R 1000:1000 openclaw/vol || echo "[-] Warning: Failed to chown openclaw/vol."

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

# 6. Generate Environment Files
echo "[*] Checking for environment files..."

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback for systems without uuidgen
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "00000000-0000-0000-0000-000000000000"
    fi
}

STACKS=("infra" "xtm" "misp" "cortex" "n8n" "flowise" "flowintel" "thehive" "lacus" "openclaw" "ail-project")

for stack in "${STACKS[@]}"; do
    if [ -d "$stack" ]; then
        if [ ! -f "$stack/.env" ]; then
            echo "    [$stack] .env not found. Creating from template..."
            
            # Determine template file
            TEMPLATE="$stack/.env.example"
            if [ "$stack" == "misp" ]; then
                TEMPLATE="$stack/template.env"
            fi
            
            if [ -f "$TEMPLATE" ]; then
                cp "$TEMPLATE" "$stack/.env"
                
                # Special handling for XTM UUIDs to ensure UNIQUE UUIDs for each connector
                if [ "$stack" == "xtm" ]; then
                    echo "    [$stack] Generating unique UUIDs for connectors..."
                    TEMP_ENV="$stack/.env.tmp"
                    # Reset temp file
                    : > "$TEMP_ENV"
                    
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [[ "$line" == *"ChangeMe_UUIDv4"* ]]; then
                            NEW_UUID=$(generate_uuid)
                            # Bash string replacement for first occurrence per line
                            echo "${line/ChangeMe_UUIDv4/$NEW_UUID}" >> "$TEMP_ENV"
                        else
                            echo "$line" >> "$TEMP_ENV"
                        fi
                    done < "$stack/.env"
                    
                    if [ -s "$TEMP_ENV" ]; then
                        mv "$TEMP_ENV" "$stack/.env"
                    else
                         echo "    [-] Error generating xtm/.env"
                         rm "$TEMP_ENV"
                    fi
                fi
                echo "    [+] Created $stack/.env"
            else
                echo "    [-] Warning: Template $TEMPLATE not found for $stack"
            fi
        else
            echo "    [$stack] .env exists. Skipping."
        fi
    fi
done

echo ""
echo "################################################################################"
echo "# ACTION REQUIRED: Environment configuration"
echo "# .env files have been referenced or created."
echo "#"
echo "# Please REVIEW the .env files in each directory before starting the stacks."
echo "# 1. infra/.env: Check ES_HEAP_SIZE_GB based on your RAM."
echo "# 2. xtm/.env:   UUIDs have been auto-generated. Review tokens/passwords."
echo "#"
echo "################################################################################"
read -p "Press Enter once you have reviewed your .env files to continue..."

# 7. Check Host Requirements
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
