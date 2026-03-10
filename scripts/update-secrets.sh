#!/bin/bash
# ThreatLabs CTI Stack - Infisical Secret Injection Script
# This script authenticates with Infisical using a Machine Identity, 
# pulls the latest secrets for the specified stacks into their .env files,
# and automatically restarts the Docker containers in dependency order.

set -e

# Handle local self-signed certificates
export INFISICAL_SKIP_TLS_VERIFY=true

# Infisical Project Configuration
INFISICAL_DOMAIN="https://infisical.lab.local/api"
INFISICAL_PROJECT_ID="ChangeMe_ProjectID"
INFISICAL_ENV="prod"

# Machine Identity Configuration (Universal Auth)
# ID: ChangeMe_IdentityID
CLIENT_ID="ChangeMe_ClientID"
CLIENT_SECRET="ChangeMe_ClientSecret"

# Source shared configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/volume-config.sh"

# Flags
SYNC_ONLY=false
TARGET_STACKS=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --sync-only) SYNC_ONLY=true ;;
        *) TARGET_STACKS+=("$1") ;;
    esac
    shift
done

# If no stacks specified, use all
if [ ${#TARGET_STACKS[@]} -eq 0 ]; then
    TARGET_STACKS=("${CTI_STACKS[@]}")
fi

echo "============================================================"
echo "Starting Infisical Secret Synchronization"
echo "Target Stacks: ${TARGET_STACKS[*]}"
echo "============================================================"

# 1. Authenticate and retrieve Universal Auth token via raw curl
echo "[*] Authenticating with Infisical Machine Identity..."
AUTH_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"clientId\":\"$CLIENT_ID\",\"clientSecret\":\"$CLIENT_SECRET\"}" \
    -k "$INFISICAL_DOMAIN/v1/auth/universal-auth/login")

TOKEN=$(echo "$AUTH_RESPONSE" | grep -oE '"accessToken":"([^"]+)"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "[!] Error: Failed to retrieve authentication token from Infisical."
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi
echo "[+] Successfully authenticated."

echo "------------------------------------------------------------"
echo "PHASE 1: FETCHING SECRETS FOR ALL TARGET STACKS"
echo "------------------------------------------------------------"

# Helper function to merge secrets into .env while preserving comments/structure
merge_secrets() {
    local STACK=$1
    local SECRETS_FILE=$2
    local ENV_FILE=$3

    if [ ! -f "$ENV_FILE" ]; then
        echo "    [!] $ENV_FILE not found, creating from secrets..."
        cp "$SECRETS_FILE" "$ENV_FILE"
        return
    fi

    echo "    [*] Merging secrets into $ENV_FILE..."
    # Create a temporary file for the new environment
    local TMP_FILE="${ENV_FILE}.tmp"
    cp "$ENV_FILE" "$TMP_FILE"

    while IFS= read -r line || [ -n "$line" ]; do
        # Extract key and value from the Infisical export (formatted as KEY='VALUE')
        if [[ "$line" =~ ^([^=]+)=\'?(.*)\'?$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Strip trailing quote if it exists (BASH_REMATCH might capture it)
            value="${value%\'}"

            # Check if key exists in the current .env
            if grep -q "^${key}=" "$TMP_FILE"; then
                # Update existing key
                # Use a different delimiter for sed to avoid issues with slashes in values
                sed -i "s|^${key}=.*|${key}='${value}'|" "$TMP_FILE"
            else
                # Append new key
                echo "${key}='${value}'" >> "$TMP_FILE"
            fi
        fi
    done < "$SECRETS_FILE"

    mv "$TMP_FILE" "$ENV_FILE"
}

# Fetch all secrets first so network restarts don't interrupt Infisical communication
for STACK in "${TARGET_STACKS[@]}"; do
    STACK_DIR="/opt/stacks/$STACK"
    
    if [ ! -d "$STACK_DIR" ]; then
        echo "[-] Skipping fetch for $STACK: Directory $STACK_DIR does not exist."
        continue
    fi
    
    echo "[*] Fetching secrets for $STACK from Infisical (/$STACK)..."
    TEMP_SECRETS="/tmp/${STACK}_secrets.env"
    infisical export \
        --format=dotenv \
        --projectId="$INFISICAL_PROJECT_ID" \
        --env="$INFISICAL_ENV" \
        --path="/$STACK" \
        --domain="$INFISICAL_DOMAIN" \
        --token="$TOKEN" > "$TEMP_SECRETS"
        
    merge_secrets "$STACK" "$TEMP_SECRETS" "$STACK_DIR/.env"
    rm -f "$TEMP_SECRETS"
done

# Deploy stacks in order (Skip if --sync-only)
if [ "$SYNC_ONLY" = true ]; then
    echo "------------------------------------------------------------"
    echo "PHASE 2: SKIPPING DEPLOYMENT (--sync-only active)"
    echo "------------------------------------------------------------"
else
    echo "------------------------------------------------------------"
    echo "PHASE 2: DEPLOYING STACKS IN SEQUENCE"
    echo "------------------------------------------------------------"
    for STACK in "${TARGET_STACKS[@]}"; do
        STACK_DIR="/opt/stacks/$STACK"
        if [ -d "$STACK_DIR" ]; then echo "[*] Restarting $STACK containers..."; cd "$STACK_DIR" && docker compose up -d --remove-orphans; fi
    done
fi

echo "============================================================"
echo "All stacks successfully synchronized with Infisical and restarted."
echo "============================================================"
