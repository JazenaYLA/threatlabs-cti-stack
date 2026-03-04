#!/bin/bash
# setup-caddy-local.sh
# Run this script INSIDE the Caddy LXC container.
# It appends the Uptime Kuma reverse proxy configuration to /etc/caddy/Caddyfile.

set -e

# Configuration
UPTIME_KUMA_IP="<UPTIME_KUMA_IP>"
UPTIME_KUMA_DOMAIN="uptimekuma.lab.local"

echo "=== Local Caddy Configuration for Uptime Kuma ==="

CADDY_SNIPPET="
${UPTIME_KUMA_DOMAIN} {
    reverse_proxy ${UPTIME_KUMA_IP}:3001
}
"

# Check if already exists
if grep -q "${UPTIME_KUMA_DOMAIN}" /etc/caddy/Caddyfile; then
    echo "⚠️  Hostname ${UPTIME_KUMA_DOMAIN} already found in /etc/caddy/Caddyfile."
    echo "No changes made."
else
    echo "Adding reverse proxy block for ${UPTIME_KUMA_DOMAIN}..."
    echo -e "${CADDY_SNIPPET}" | sudo tee -a /etc/caddy/Caddyfile
    echo "✅ Successfully updated Caddyfile."
fi

echo "Reloading Caddy service..."
sudo systemctl reload caddy

echo "=== Done ==="
echo "Uptime Kuma is now proxied. Ensure 'Trust Proxy' is enabled in Kuma's Web UI."
