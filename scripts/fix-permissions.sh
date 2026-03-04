#!/usr/bin/env bash
# fix-permissions.sh
# Automated permission fix for ThreatLabs CTI Stack
# Can be run standalone to repair permissions without a full setup.
#
# Uses: scripts/volume-config.sh (single source of truth)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/volume-config.sh"

echo "🔧 Ensuring Volumes and Permissions..."

# Create dirs and apply ownership from the shared volume config
for entry in "${CTI_VOLUMES[@]}"; do
    IFS='|' read -r dir_path perm_path uid_gid <<< "$entry"
    if [ ! -d "$dir_path" ]; then
        echo "  - Creating $dir_path..."
        mkdir -p "$dir_path"
    fi
    echo "  - Fixing permissions for $perm_path ($uid_gid)..."
    chown -R "$uid_gid" "$perm_path" 2>/dev/null || true
done

# --- Executable Permissions ---
echo "  - Making scripts executable..."
find . -name "*.sh" -exec chmod +x {} +
if [ -f "infra/vol/postgres-init/init-dbs.sh" ]; then chmod +x infra/vol/postgres-init/init-dbs.sh; fi

echo "✅ Volumes and Permissions Restored."
