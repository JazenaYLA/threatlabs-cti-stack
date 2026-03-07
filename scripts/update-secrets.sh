#!/bin/bash
# ThreatLabs CTI Stack - Infisical Secret Injection Script
# This script authenticates with Infisical using a Machine Identity, 
# pulls the latest secrets for the specified stacks into their .env files,
# and automatically restarts the Docker containers in dependency order.

set -e

# Infisical Project Configuration
INFISICAL_DOMAIN="https://infisical.lab.local"
INFISICAL_PROJECT_ID="0c9864cc-1c4b-47e0-8684-6e6af22463c3"
INFISICAL_ENV="prod"

# Machine Identity Credentials
CLIENT_ID="0fd35b83-d996-47ec-8eef-2ab9d1d085fd"
CLIENT_SECRET="715304237835a6350b0335ffbd4ee963845634df962dcace835930d4db82bfc2"

# Stacks to update
# If arguments are provided, use them. Otherwise, default to the official boot order.
if [ "$#" -gt 0 ]; then
    TARGET_STACKS=("$@")
else
    # ─── Ordered Deployment Phases ───────────────────────────────────────────
    TARGET_STACKS=(
        "infra"
        "misp-modules" "ail-project" "forgejo-runner" "proxy"
        "misp" "xtm" "thehive" "flowintel"
        "lacus" "dfir-iris" "shuffle"
    )
fi

echo "============================================================"
echo "Starting Infisical Secret Synchronization"
echo "Target Stacks: ${TARGET_STACKS[*]}"
echo "============================================================"

# 1. Authenticate and retrieve Universal Auth token
echo "[*] Authenticating with Infisical Machine Identity..."
AUTH_OUTPUT=$(infisical login --method=universal-auth \
    --client-id="$CLIENT_ID" \
    --client-secret="$CLIENT_SECRET" \
    --domain="$INFISICAL_DOMAIN")

TOKEN=$(echo "$AUTH_OUTPUT" | grep -oE "eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+")

if [ -z "$TOKEN" ]; then
    echo "[!] Error: Failed to retrieve authentication token from Infisical."
    exit 1
fi
echo "[+] Successfully authenticated."

echo "------------------------------------------------------------"
echo "PHASE 1: FETCHING SECRETS FOR ALL TARGET STACKS"
echo "------------------------------------------------------------"

# Fetch all secrets first so network restarts don't interrupt Infisical communication
for STACK in "${TARGET_STACKS[@]}"; do
    STACK_DIR="/opt/stacks/$STACK"
    
    if [ ! -d "$STACK_DIR" ]; then
        echo "[-] Skipping fetch for $STACK: Directory $STACK_DIR does not exist."
        continue
    fi
    
    echo "[*] Fetching secrets for $STACK from Infisical (/$STACK)..."
    infisical export \
        --format=dotenv \
        --projectId="$INFISICAL_PROJECT_ID" \
        --env="$INFISICAL_ENV" \
        --path="/$STACK" \
        --domain="$INFISICAL_DOMAIN" \
        --token="$TOKEN" > "$STACK_DIR/.env"
        
    echo "[+] Secrets successfully written to $STACK_DIR/.env"
done

echo "------------------------------------------------------------"
echo "PHASE 2: DEPLOYING STACKS IN SEQUENCE"
echo "------------------------------------------------------------"

# Deploy stacks in order
for STACK in "${TARGET_STACKS[@]}"; do
    STACK_DIR="/opt/stacks/$STACK"
    
    if [ ! -d "$STACK_DIR" ]; then
        echo "[-] Skipping deploy for $STACK: Directory $STACK_DIR does not exist."
        continue
    fi

    echo "[*] Restarting $STACK containers to apply new secrets..."
    cd "$STACK_DIR"
    docker compose up -d --remove-orphans
    echo "[+] $STACK successfully deployed."
done

echo "============================================================"
echo "All stacks successfully synchronized with Infisical and restarted."
echo "============================================================"
