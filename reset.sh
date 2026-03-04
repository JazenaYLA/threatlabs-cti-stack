#!/bin/bash

# Reset / Nuke Script for ThreatLabs CTI Stack
# WARNING: This will delete ALL data (ElasticSearch indices, Postgres DBs, etc.)
# NOTE: .env files are preserved by default.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/volume-config.sh"

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                     DANGER: NUKE PROTOCOL INITIATED                !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "This script will:"
echo "1. Stop ALL containers in the CTI stack."
echo "2. Remove the 'cti-net' network."
echo "3. PERMANENTLY DELETE all persistent data volumes (infra/vol, xtm/vol, etc.)"
echo ""
echo "Your .env files will NOT be touched (unless you explicitly opt in)."
echo ""
echo "Are you sure you want to proceed? (Type 'NUKE' to confirm)"
read -r confirmation

if [ "$confirmation" != "NUKE" ]; then
    echo "Aborted. Stay safe."
    exit 1
fi

echo "[*] Stopping and removing containers (reverse order — infra last)..."
for (( i=${#CTI_STACKS[@]}-1; i>=0; i-- )); do
    stack="${CTI_STACKS[$i]}"
    if [ -d "$stack" ]; then
        echo "    Stopping and removing volumes for $stack..."
        (cd "$stack" && sudo docker compose down -v --remove-orphans 2>/dev/null || true)
        (cd "$stack" && sudo docker compose -p "cti-$stack" down -v --remove-orphans 2>/dev/null || true)
    fi
done

# Shuffle spawns a tenzir-node sidecar that persists after shutdown
echo "[*] Cleaning up Shuffle sidecar (tenzir-node)..."
docker rm -f tenzir-node 2>/dev/null || true

echo "[*] Cleaning up network..."
docker network rm cti-net 2>/dev/null || true

# Safety Check
if [[ ! -f "setup.sh" ]]; then
    echo "[-] Error: Please run this script from the repository root."
    exit 1
fi

echo "[*] Pruning unused docker volumes (This kills ALL orphaned volumes)..."
docker volume prune -f

echo "[*] Phase 1: Cleaning Git Repository Storage (Relative)..."
for dir in "${CTI_RESET_DIRS[@]}"; do
    sudo rm -rf "$dir"
done

# Explicitly delete /opt/stacks volume directories (Dockge/Production)
if [ -d "/opt/stacks" ]; then
    echo "[*] Phase 2: Cleaning /opt/stacks Storage (Dockge/Production)..."
    for dir in "${CTI_RESET_DIRS[@]}"; do
        sudo rm -rf "/opt/stacks/$dir"
    done
fi

echo "[*] Cleaning up environment files (Optional)..."
echo "    Your .env files are currently PRESERVED."
read -p "Do you want to PERMANENTLY DELETE all .env files and start over? (y/N) " wipe_envs
if [[ "$wipe_envs" =~ ^[Yy]$ ]]; then
    echo "[!] Wiping all .env files..."
    find . -name ".env" -exec rm -f {} +
fi

echo "[*] Refreshing Dockge symlinks..."
if [ -f "./scripts/setup-dockge.sh" ]; then
    sudo ./scripts/setup-dockge.sh
fi

echo "[*] Removing generated configuration files..."
rm -f thehive/vol/thehive/application.conf

echo "[+] Nuke complete. The codebase is clean (configuration files preserved, data gone)."
echo "    Run ./setup.sh to start fresh."
