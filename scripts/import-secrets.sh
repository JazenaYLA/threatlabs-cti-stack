#!/bin/bash
set -e

echo "[*] Starting Phase 2 Infisical automated folder creation and secret migration..."

INFISICAL_DOMAIN="https://infisical.lab.local"
INFISICAL_PROJECT_ID="0c9864cc-1c4b-47e0-8684-6e6af22463c3"
INFISICAL_ENV="prod"
CLIENT_ID="0fd35b83-d996-47ec-8eef-2ab9d1d085fd"
CLIENT_SECRET="715304237835a6350b0335ffbd4ee963845634df962dcace835930d4db82bfc2"

echo "[*] Authenticating Machine Identity..."
AUTH_OUTPUT=$(infisical login --method=universal-auth --client-id="$CLIENT_ID" --client-secret="$CLIENT_SECRET" --domain="$INFISICAL_DOMAIN")
TOKEN=$(echo "$AUTH_OUTPUT" | grep -oE "eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+")

EXPANSION_STACKS=("infra" "proxy" "shuffle" "flowintel" "dfir-iris" "ail-project" "lacus" "misp-modules" "forgejo-runner")

for STACK in "${EXPANSION_STACKS[@]}"; do
    echo "----------------------------------------"
    echo "[*] Creating folder structure: /$STACK in Infisical (prod)..."
    infisical secrets folders create --name="$STACK" --env="$INFISICAL_ENV" --projectId="$INFISICAL_PROJECT_ID" --domain="$INFISICAL_DOMAIN" --token="$TOKEN" || echo "[-] Folder /$STACK likely already exists, proceeding..."
    
    if [ -f "/tmp/$STACK.env" ]; then
        echo "[*] Injecting secrets into /$STACK..."
        # First, strip out empty variables which cause the CLI to crash
        sed -i -E '/^[A-Za-z0-9_]+=[[:space:]]*$/d' "/tmp/$STACK.env"
        
        infisical secrets set --file="/tmp/$STACK.env" --path="/$STACK" --env="$INFISICAL_ENV" --projectId="$INFISICAL_PROJECT_ID" --domain="$INFISICAL_DOMAIN" --token="$TOKEN"

        echo "[+] Stack $STACK successfully migrated!"
    else
        echo "[-] Error: /tmp/$STACK.env not found!"
    fi
done

echo "----------------------------------------"
echo "[+] Migration completely finished. All secrets are now strictly organized in Infisical subfolders."
