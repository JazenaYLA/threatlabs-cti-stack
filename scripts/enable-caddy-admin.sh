#!/bin/bash
# enable-caddy-admin.sh
# Run this script DIRECTLY INSIDE the Caddy LXC terminal.
# It enables the Caddy Admin API on all interfaces (0.0.0.0:2019)
# so CaddyManager on the Docker host can reach it.

set -e

CADDYFILE="/etc/caddy/Caddyfile"

echo "=== Enabling Caddy Admin API on LAN ==="

# Check if admin block already exists
if grep -q '^\s*admin' "$CADDYFILE"; then
    echo "Admin block already exists in Caddyfile. Please verify it listens on 0.0.0.0:2019."
    grep -A2 'admin' "$CADDYFILE"
    exit 0
fi

# Prepend the global admin options block
# The { } block at the top of the Caddyfile is the global options block
TEMP=$(mktemp)
cat << 'EOF' > "$TEMP"
{
    admin 0.0.0.0:2019
}

EOF
cat "$CADDYFILE" >> "$TEMP"
mv "$TEMP" "$CADDYFILE"

echo "Admin API block added to Caddyfile."
echo ""
echo "Reloading Caddy..."
systemctl reload caddy || caddy reload --config "$CADDYFILE" || echo "Warning: Caddy reload failed. Check 'systemctl status caddy'."

echo ""
echo "=== Done! Test with: curl http://$(hostname -I | awk '{print $1}'):2019/config/ ==="
