#!/bin/sh
set -e

# ─── Node.js Fix ───────────────────────────────────────────────────────
# The runner image doesn't include Node.js, which is needed for actions
apk add --no-cache nodejs

# ─── URL Drift Detection ──────────────────────────────────────────────
# The .runner file caches the Forgejo server address at registration time.
# If GITEA_INSTANCE_URL changes (VLAN move, IP change, domain switch),
# the runner silently keeps using the stale cached address.
# This block detects the mismatch and forces re-registration.

RUNNER_FILE="/data/.runner"

if [ -f "$RUNNER_FILE" ]; then
    # Extract the cached address from the JSON (lightweight, no jq needed)
    CACHED_URL=$(grep -o '"address"[[:space:]]*:[[:space:]]*"[^"]*"' "$RUNNER_FILE" | sed 's/.*"address"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

    if [ -n "$CACHED_URL" ] && [ "$CACHED_URL" != "$GITEA_INSTANCE_URL" ]; then
        echo "================================================================"
        echo "  URL DRIFT DETECTED"
        echo "  Cached : $CACHED_URL"
        echo "  Current: $GITEA_INSTANCE_URL"
        echo "  → Removing stale registration, will re-register..."
        echo "================================================================"
        rm -f "$RUNNER_FILE"
    else
        echo "[entrypoint] Runner address OK: $CACHED_URL"
    fi
fi

# ─── Auto-Registration ────────────────────────────────────────────────
# Register only if .runner doesn't exist (first boot or after drift cleanup)

if [ ! -f "$RUNNER_FILE" ]; then
    echo "[entrypoint] No registration found, registering runner..."
    forgejo-runner register --no-interactive \
        --instance "$GITEA_INSTANCE_URL" \
        --token "$GITEA_RUNNER_REGISTRATION_TOKEN" \
        --name "$GITEA_RUNNER_NAME" \
        --labels "$GITEA_RUNNER_LABELS"
    echo "[entrypoint] Runner registered successfully."
fi

# ─── Start Daemon ─────────────────────────────────────────────────────
echo "[entrypoint] Starting runner daemon..."
exec forgejo-runner daemon
