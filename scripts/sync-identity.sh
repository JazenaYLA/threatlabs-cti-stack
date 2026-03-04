#!/usr/bin/env bash
set -e

# sync-identity.sh
#
# PURPOSE:
#   Synchronizes the current identity (Admin Email) from xtm/.env to the running 
#   OpenCTI (Elasticsearch) and OpenAEV (Postgres) platforms.
#
# WHEN TO USE:
#   - After changing OPENCTI_ADMIN_EMAIL or OPENAEV_ADMIN_EMAIL in xtm/.env.
#   - If you experience "Cannot identify user with token" errors after an IP change.
#   - To reconcile the platform identity with your configuration without a factory reset.
#
# PREREQUISITES:
#   - Containers must be RUNNING.
#   - OPENCTI_ADMIN_TOKEN must be valid and authorized.
#
# USAGE:
#   ./scripts/sync-identity.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XTM_ENV="$SCRIPT_DIR/../xtm/.env"

if [ ! -f "$XTM_ENV" ]; then
    echo "[-] Error: xtm/.env not found at $XTM_ENV"
    exit 1
fi

# 1. Source the xtm .env
# We use a subshell to avoid polluting the current shell
# and we only grep the variables we need to avoid issues with comments/spaces
source <(grep -E "^(OPENCTI_ADMIN_EMAIL|OPENCTI_ADMIN_TOKEN|OPENAEV_ADMIN_EMAIL|POSTGRES_USER|POSTGRES_PASSWORD)" "$XTM_ENV")

echo "[*] Starting Identity Sync..."

# --- 2. OpenAEV (Postgres) ---
echo "[*] Syncing OpenAEV identity to Postgres..."
DB_EMAIL=$(docker exec infra-postgres psql -U postgres -d openaev -t -c "SELECT user_email FROM users WHERE user_firstname = 'admin';" | xargs)

if [ "$DB_EMAIL" != "$OPENAEV_ADMIN_EMAIL" ]; then
    echo "    [+] Updating OpenAEV user email to $OPENAEV_ADMIN_EMAIL..."
    docker exec infra-postgres psql -U postgres -d openaev -c "UPDATE users SET user_email = '$OPENAEV_ADMIN_EMAIL' WHERE user_firstname = 'admin';"
else
    echo "    [+] OpenAEV email already matches."
fi

# --- 3. OpenCTI (GraphQL) ---
echo "[*] Syncing OpenCTI identity to GraphQL..."
ME_QUERY=$(curl -s -X POST http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENCTI_ADMIN_TOKEN" \
  -d '{"query": "{ me { id user_email external } }"}' 2>/dev/null)

CTI_ID=$(echo "$ME_QUERY" | grep -oP '"id":"\K[^"]+')
CTI_EMAIL=$(echo "$ME_QUERY" | grep -oP '"user_email":"\K[^"]+')
CTI_EXTERNAL=$(echo "$ME_QUERY" | grep -oP '"external":\K[a-z]+')

if [ -z "$CTI_ID" ]; then
    echo "    [-] Error: Could not connect to OpenCTI GraphQL or token is invalid."
else
    if [ "$CTI_EMAIL" != "$OPENCTI_ADMIN_EMAIL" ]; then
        echo "    [+] Updating OpenCTI user email to $OPENCTI_ADMIN_EMAIL..."
        
        # Ensure user is not 'external' so we can edit it
        if [ "$CTI_EXTERNAL" == "true" ]; then
             curl -s -X POST http://localhost:8080/graphql \
              -H "Content-Type: application/json" \
              -H "Authorization: Bearer $OPENCTI_ADMIN_TOKEN" \
              -d "{\"query\": \"mutation (\$id: ID!, \$input: [EditInput!]!) { userEdit(id: \$id) { fieldPatch(input: \$input) { id } } }\", \"variables\": { \"id\": \"$CTI_ID\", \"input\": [ { \"key\": \"external\", \"value\": [\"false\"] } ] } }" > /dev/null
        fi

        # Perform the email update
        curl -s -X POST http://localhost:8080/graphql \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $OPENCTI_ADMIN_TOKEN" \
          -d "{\"query\": \"mutation (\$id: ID!, \$input: [EditInput!]!) { userEdit(id: \$id) { fieldPatch(input: \$input) { user_email } } }\", \"variables\": { \"id\": \"$CTI_ID\", \"input\": [ { \"key\": \"user_email\", \"value\": [\"$OPENCTI_ADMIN_EMAIL\"] } ] } }" > /dev/null
        
        echo "    [+] OpenCTI email updated."
    else
        echo "    [+] OpenCTI email already matches."
    fi
fi

echo "✅ Identity Sync Complete."
