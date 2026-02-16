#!/bin/sh
# fix-permissions.sh
# Automated permission fix for ThreatLabs CTI Stack

echo "🔧 Ensuring Volumes and Permissions..."

# Helper to create and chown
ensure_vol() {
    local DIR_PATH="$1"
    local PERM_PATH="$2" # Directory to apply chown to (usually parent)
    local UID_GID="$3"
    
    if [ ! -d "$DIR_PATH" ]; then
        echo "  - Creating $DIR_PATH..."
        mkdir -p "$DIR_PATH"
    fi
    
    echo "  - Fixing permissions for $PERM_PATH ($UID_GID)..."
    chown -R "$UID_GID" "$PERM_PATH"
}

# --- 1. Infrastructure (Databases) ---
# ElasticSearch (UID 1000)
ensure_vol "infra/vol/esdata7/data" "infra/vol/esdata7" "1000:1000"
ensure_vol "infra/vol/esdata8/data" "infra/vol/esdata8" "1000:1000"

# Postgres (Alpine Image uses UID 70)
ensure_vol "infra/vol/postgres/data" "infra/vol/postgres" "70:70"

# Valkey/Redis (UID 999)
ensure_vol "infra/vol/valkey/data" "infra/vol/valkey" "999:999"

# Init Scripts (UID 1000)
ensure_vol "infra/vol/postgres-init" "infra/vol/postgres-init" "1000:1000"


# --- 2. Application Stacks (UID 1000) ---
# XTM (OpenCTI)
ensure_vol "xtm/volumes/pgsqldata" "xtm/volumes" "1000:1000"
ensure_vol "xtm/volumes/s3data" "xtm/volumes" "1000:1000"
ensure_vol "xtm/volumes/redisdata" "xtm/volumes" "1000:1000"
ensure_vol "xtm/volumes/amqpdata" "xtm/volumes" "1000:1000"
ensure_vol "xtm/volumes/rsakeys" "xtm/volumes" "1000:1000"


# n8n
ensure_vol "n8n/vol/n8n/.n8n" "n8n/vol" "1000:1000"

# Flowise
ensure_vol "flowise/vol/flowise" "flowise/vol" "1000:1000"

# FlowIntel
ensure_vol "flowintel/vol/flowintel/data" "flowintel/vol" "1000:1000"

# Lacus
ensure_vol "lacus/vol/lacus-data" "lacus/vol" "1000:1000"
ensure_vol "lacus/vol/lacus-cache" "lacus/vol" "1000:1000"

# MISP Modules
ensure_vol "misp-modules/.vol" "misp-modules/.vol" "1000:1000"

# Shuffle
ensure_vol "shuffle/vol/shuffle-apps" "shuffle/vol" "1000:1000"
ensure_vol "shuffle/vol/shuffle-files" "shuffle/vol" "1000:1000"

# TheHive (Legacy/Archive)
ensure_vol "thehive/vol/cassandra/data" "thehive/vol" "1000:1000"
ensure_vol "thehive/vol/thehive" "thehive/vol" "1000:1000"
ensure_vol "thehive/vol/thehive/data" "thehive/vol" "1000:1000"

# DFIR-IRIS
ensure_vol "dfir-iris/vol/db_data" "dfir-iris/vol/db_data" "999:999"
ensure_vol "dfir-iris/vol/iris-downloads" "dfir-iris/vol" "1000:1000"
ensure_vol "dfir-iris/vol/user_templates" "dfir-iris/vol" "1000:1000"
ensure_vol "dfir-iris/vol/server_data" "dfir-iris/vol" "1000:1000"


# --- 3. Executable Permissions ---
echo "  - Making scripts executable..."
find . -name "*.sh" -exec chmod +x {} +
if [ -f "infra/vol/postgres-init/init-dbs.sh" ]; then chmod +x infra/vol/postgres-init/init-dbs.sh; fi

echo "✅ Volumes and Permissions Restored."
