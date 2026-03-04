#!/usr/bin/env bash
set -e

# Setup Script for ThreatLabs CTI Stack
# Usage: ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/volume-config.sh"

# Global Configuration (Override via env vars if needed)
ADMIN_EMAIL="${GLOBAL_ADMIN_EMAIL:-jamz@threatresearcher.net}"
ADMIN_PASSWORD="${GLOBAL_ADMIN_PASSWORD:-ThreatLabs}"

echo "[*] Initializing ThreatLabs CTI Stack Setup..."

# 0. Initialize Submodules (if missing)
if [ -f ".gitmodules" ]; then
    echo "[*] checking submodules..."
    git submodule update --init --recursive
fi

# Clean up stale Shuffle sidecar (tenzir-node) if present
docker rm -f tenzir-node 2>/dev/null || true

# 1. Create Shared Network
if docker network ls | grep -q "cti-net"; then
    echo "[+] Network 'cti-net' already exists."
else
    echo "[+] Network 'cti-net' created."
fi

# 2. Ensure Permissions on Shell Scripts
echo "[*] Ensuring shell scripts are executable..."
find . -name "*.sh" -exec chmod +x {} +


# Helper function to create volumes in both Repo and /opt/stacks
create_vol() {
    local PATH_SUFFIX=$1
    echo "    Creating $PATH_SUFFIX..."
    mkdir -p "$PATH_SUFFIX"
    # If /opt/stacks exists, create there too (assuming standard naming)
    local STACK_NAME=$(echo "$PATH_SUFFIX" | cut -d'/' -f1)
    if [ -d "/opt/stacks/$STACK_NAME" ]; then
        echo "    Mirroring to /opt/stacks/$STACK_NAME..."
        sudo mkdir -p "/opt/stacks/$PATH_SUFFIX"
        sudo chown -R 1000:1000 "/opt/stacks/$STACK_NAME" || true
    fi
}

# 3. Prepare All Volumes (from single source of truth)
echo "[*] Preparing volumes..."
for entry in "${CTI_VOLUMES[@]}"; do
    IFS='|' read -r dir_path perm_path uid_gid <<< "$entry"
    create_vol "$dir_path"
    if [ -d "$perm_path" ]; then
        sudo chown -R "$uid_gid" "$perm_path" 2>/dev/null || echo "[-] Warning: Failed to chown $perm_path"
    fi
done

# Restore git-tracked files inside vol/ dirs (wiped by reset)
echo "[*] Restoring git-tracked config files..."
git checkout HEAD -- infra/vol/postgres-init/init-dbs.sh 2>/dev/null || echo "[-] Warning: Could not restore init-dbs.sh from git"

# Ensure init script execution permission
chmod +x infra/vol/postgres-init/init-dbs.sh 2>/dev/null || true

# 4. Generate Default Configurations (if missing)
echo "[*] Checking for default configurations..."

# TheHive Default Config
if [ ! -f thehive/vol/thehive/application.conf ]; then
    echo "[+] Generating default TheHive application.conf..."
    cat <<EOF > thehive/vol/thehive/application.conf
## TheHive Configuration (Auto-Generated)
play.http.secret.key="\${?THEHIVE_SECRET}"
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
  localfs.location = /opt/thp/thehive/data
}
EOF
fi

# Ensure THEHIVE_SECRET exists in .env
if [ -f thehive/.env ]; then
    if ! grep -q "THEHIVE_SECRET" thehive/.env; then
        echo "THEHIVE_SECRET=$(date +%s | sha256sum | base64 | head -c 64)" >> thehive/.env
    fi
fi

# DFIR-IRIS Certificates
if [ -d dfir-iris ] && [ ! -f dfir-iris/certificates/web_certificates/iris_dev_cert.pem ]; then
    echo "[+] Generating self-signed certificates for DFIR-IRIS..."
    mkdir -p dfir-iris/certificates/{rootCA,web_certificates,ldap}
    openssl req -x509 -nodes -days 3650 \
      -newkey rsa:2048 \
      -keyout dfir-iris/certificates/rootCA/irisRootCAKey.pem \
      -out dfir-iris/certificates/rootCA/irisRootCACert.pem \
      -subj "/C=US/ST=Local/L=Homelab/O=ThreatLabs/CN=IRIS Root CA" 2>/dev/null
    openssl req -x509 -nodes -days 3650 \
      -newkey rsa:2048 \
      -keyout dfir-iris/certificates/web_certificates/iris_dev_key.pem \
      -out dfir-iris/certificates/web_certificates/iris_dev_cert.pem \
      -subj "/C=US/ST=Local/L=Homelab/O=ThreatLabs/CN=iris.local" 2>/dev/null
fi

# DFIR-IRIS Secrets
if [ -f dfir-iris/.env ]; then
    if grep -q "changeme" dfir-iris/.env 2>/dev/null; then
        echo "[!] WARNING: dfir-iris/.env still contains default 'changeme' values."
        echo "    Generate production secrets with: openssl rand -hex 30"
    fi
fi

# 5. Generate Environment Files
echo "[*] Checking for environment files..."

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "00000000-0000-0000-0000-000000000000"
    fi
}

for stack in "${CTI_STACKS[@]}"; do
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
                
                # Injection of Global Admin Credentials
                echo "    [$stack] Injecting global admin config..."
                sed -i "s/admin@opencti.io/$ADMIN_EMAIL/g" "$stack/.env"
                sed -i "s/admin@openaev.io/$ADMIN_EMAIL/g" "$stack/.env"
                sed -i "s/ChangeMe@domain.com/$ADMIN_EMAIL/g" "$stack/.env"
                sed -i "s/changeme/$ADMIN_PASSWORD/g" "$stack/.env"
                sed -i "s/ChangeMe/$ADMIN_PASSWORD/g" "$stack/.env"

                # Special handling for XTM UUIDs to ensure UNIQUE UUIDs for each connector
                if [ "$stack" == "xtm" ]; then
                    echo "    [$stack] Generating unique UUIDs for connectors..."
                    TEMP_ENV="$stack/.env.tmp"
                    : > "$TEMP_ENV"
                    
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [[ "$line" == *"ChangeMe_UUIDv4"* ]]; then
                            NEW_UUID=$(generate_uuid)
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
echo "# NEW: Check 'infra/.env' matching passwords with other stacks:"
echo "#      - OPENAEV_DB_PASSWORD (matches xtm/.env)"
echo "#      - N8N_DB_PASSWORD (matches n8n/.env)"
echo "#      - FLOWINTEL_DB_PASSWORD (matches flowintel/.env)"
echo "# 1. infra/.env: Check ES_HEAP_SIZE_GB based on your RAM."
echo "# 2. xtm/.env:   UUIDs have been auto-generated. Review tokens/passwords."
echo "#"
echo "################################################################################"
read -p "Press Enter once you have reviewed your .env files to continue..."

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
echo "    Order: 1. infra, 2. misp-modules, 3. misp, 4. thehive/xtm/flowintel, 5. lacus/dfir-iris/shuffle."

echo ""
echo "[*] Finalizing environment..."

# 7. Apply Permissions
if [ -f "./scripts/fix-permissions.sh" ]; then
    echo "[+] Running automated permission fixes..."
    sudo ./scripts/fix-permissions.sh
fi

# 8. Setup Dockge
if [ -f "./scripts/setup-dockge.sh" ]; then
    echo "[+] Refreshing Dockge stack links..."
    sudo ./scripts/setup-dockge.sh
fi

echo ""
echo "✅ ALL DONE. Your ThreatLabs CTI Stack is ready for deployment."
