#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# Helper function to create volumes in both Repo and /opt/stacks
create_vol() {
    local PATH_SUFFIX=$1
    echo "    Creating $PATH_SUFFIX..."
    mkdir -p "$PATH_SUFFIX"
    # If /opt/stacks/infra exists, create there too
    if [ -d "/opt/stacks/infra" ]; then
        echo "    Mirroring to /opt/stacks/infra..."
        sudo mkdir -p "/opt/stacks/infra/$PATH_SUFFIX"
        sudo chown -R 1000:1000 "/opt/stacks/infra" || true
    fi
}

create_vol "vol/esdata7/data"
create_vol "vol/esdata8/data"
create_vol "vol/postgres/data"
create_vol "vol/valkey/data"
sudo chown -R 1000:1000 vol || true
