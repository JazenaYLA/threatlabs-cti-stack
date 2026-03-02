#!/bin/bash

# Reset / Nuke Script for ThreatLabs CTI Stack
# WARNING: This will delete ALL data (ElasticSearch indices, Postgres DBs, etc.)

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                     DANGER: NUKE PROTOCOL INITIATED                !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "This script will:"
echo "1. Stop ALL containers in the CTI stack."
echo "2. Remove the 'cti-net' network."
echo "3. PERMANENTLY DELETE all persistent data volumes (infra/vol, xtm/vol, etc.)"
echo ""
echo "Are you sure you want to proceed? (Type 'NUKE' to confirm)"
read -r confirmation

if [ "$confirmation" != "NUKE" ]; then
    echo "Aborted. Stay safe."
    exit 1
fi

echo "[*] Stopping and removing containers..."
# We try to use docker compose down if possible, but a blanket kill is more effective for a "nuke"
# Iterate through known stacks
STACKS=("infra" "xtm" "misp" "misp-modules" "n8n" "flowise" "flowintel" "lacus" "thehive" "dfir-iris" "shuffle" "ail-project" "forgejo-runner")

for stack in "${STACKS[@]}"; do
    if [ -d "$stack" ]; then
        echo "    Stopping and removing volumes for $stack..."
        # Down the standard project
        (cd "$stack" && sudo docker compose down -v --remove-orphans 2>/dev/null || true)
        # Also attempt to down the cti- prefixed project if it exists
        (cd "$stack" && sudo docker compose -p "cti-$stack" down -v --remove-orphans 2>/dev/null || true)
    fi
done

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
# Explicitly delete the volume directories we created in setup.sh (Local Git Repo)
sudo rm -rf infra/vol
sudo rm -rf xtm/volumes
sudo rm -rf n8n/vol
sudo rm -rf flowise/vol
sudo rm -rf flowintel/vol
sudo rm -rf lacus/vol
sudo rm -rf thehive/vol
sudo rm -rf ail-project/vol

# Explicitly delete /opt/stacks volume directories (Dockge)
if [ -d "/opt/stacks" ]; then
    echo "[*] Phase 2: Cleaning /opt/stacks Storage (Dockge/Production)..."
    sudo rm -rf /opt/stacks/*/vol
    sudo rm -rf /opt/stacks/xtm/volumes
    # Also remove generated configs in /opt/stacks if they were linked/copied

    sudo rm -f /opt/stacks/thehive/vol/thehive/application.conf
fi

echo "[*] Cleaning up environment files (Optional)..."
# We keep .env by default but let's offer to wipe them for a true reset
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
