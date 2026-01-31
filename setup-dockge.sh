#!/usr/bin/env bash
set -e

# Dockge Setup Script for ThreatLabs CTI Stack
# Usage: sudo ./setup-dockge.sh [DOCKGE_STACKS_DIR]
# Default DOCKGE_STACKS_DIR is /opt/stacks

STACKS_DIR="${1:-/opt/stacks}"
REPO_DIR="$(pwd)"

echo "[*] Setting up Dockge stacks in $STACKS_DIR linking to $REPO_DIR..."

if [ ! -d "$STACKS_DIR" ]; then
    echo "[-] Error: Directory $STACKS_DIR does not exist. Please install Dockge first or create the directory."
    exit 1
fi

# Function to link stack
link_stack() {
    STACK_NAME=$1
    TARGET_DIR="$STACKS_DIR/$STACK_NAME"
    SOURCE_FILE="$REPO_DIR/$STACK_NAME/docker-compose.yml"

    if [ ! -f "$SOURCE_FILE" ]; then
        echo "[-] Warning: Source file $SOURCE_FILE not found. Skipping."
        return
    fi

    if [ -d "$TARGET_DIR" ]; then
        echo "[!] Stack '$STACK_NAME' already exists in $STACKS_DIR."
    else
        echo "[+] Linking stack: $STACK_NAME"
        # We link the directory effectively, or just the compose file?
        # Dockge usually expects a folder per stack with a docker-compose.yml inside.
        # Best approach: Create the folder, symlink the cli
        sudo mkdir -p "$TARGET_DIR"
        sudo ln -sf "$SOURCE_FILE" "$TARGET_DIR/docker-compose.yml"
        
        # Also link .env if it exists (but check .env not .env.example)
        if [ -f "$REPO_DIR/$STACK_NAME/.env" ]; then
            sudo ln -sf "$REPO_DIR/$STACK_NAME/.env" "$TARGET_DIR/.env"
            echo "    Linked .env"
        fi
    fi
}

# Link all known stacks
link_stack "infra"
link_stack "proxy"
link_stack "xtm"
link_stack "misp"
link_stack "cortex"
link_stack "n8n"
link_stack "flowise"
link_stack "flowintel"
link_stack "thehive"
link_stack "lacus"
link_stack "ail-project"

echo "[*] Done. Refresh Dockge to see your stacks."
