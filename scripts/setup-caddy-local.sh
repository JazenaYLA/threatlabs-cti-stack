#!/bin/bash
# setup-caddy-local.sh
# Run this script DIRECTLY INSIDE the Caddy LXC terminal.

set -e

echo "=== Configuring Caddy for OpenClaw ==="

# Original: openclaw.local { reverse_proxy <OPENCLAW_IP_OLD>:18789 }
CADDY_SNIPPET="
openclaw.lab.local {
    reverse_proxy <OPENCLAW_IP>:18789
}
"

echo "Adding OpenClaw reverse proxy to Caddyfile..."
if ! grep -q 'openclaw.lab.local' /etc/caddy/Caddyfile; then 
    cat << EOF >> /etc/caddy/Caddyfile
$CADDY_SNIPPET
EOF
fi

echo "Reloading Caddy..."
systemctl reload caddy || caddy reload --config /etc/caddy/Caddyfile || echo "Note: Check Caddy status if reload failed."

echo "=== Caddy Local Setup Complete ==="
