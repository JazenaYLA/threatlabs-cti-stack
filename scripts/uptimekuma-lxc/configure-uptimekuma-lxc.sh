#!/bin/bash
# configure-uptimekuma-lxc.sh
# Script to configure the Caddy reverse proxy for the Uptime Kuma LXC.
# Run this from a machine with SSH access to the 'caddy' LXC.

set -e

# Primary IP for Uptime Kuma (VLAN 3)
UPTIME_KUMA_IP="<UPTIME_KUMA_IP>" 
UPTIME_KUMA_DOMAIN="uptimekuma.lab.local"

echo "=== Configuring Caddy Proxy for Uptime Kuma ==="

CADDY_SNIPPET="
${UPTIME_KUMA_DOMAIN} {
    reverse_proxy ${UPTIME_KUMA_IP}:3001
}
"

echo "Adding Uptime Kuma reverse proxy to Caddyfile..."
ssh caddy "if ! grep -q '${UPTIME_KUMA_DOMAIN}' /etc/caddy/Caddyfile; then 
    echo \"$CADDY_SNIPPET\" | sudo tee -a /etc/caddy/Caddyfile
    echo \"✅ Added $UPTIME_KUMA_DOMAIN to Caddyfile\"
else
    echo \"⚠️  $UPTIME_KUMA_DOMAIN already exists in Caddyfile\"
fi"

echo "Reloading Caddy..."
ssh caddy "sudo systemctl reload caddy" || ssh caddy "caddy reload --config /etc/caddy/Caddyfile"

echo "=== Caddy configuration complete ==="
echo ""
echo "👉 FINAL STEPS (Manual Action Required):"
echo "1. Log in to Uptime Kuma at http://${UPTIME_KUMA_DOMAIN}"
echo "2. Go to Settings -> Reverse Proxy -> HTTP Headers"
echo "3. Set 'Trust Proxy' to 'Yes' and Save."
echo "4. (Optional) Your API Key is ready for use in any CI/CD or automation."
echo ""
echo "Done! Uptime Kuma should now be accessible via your Caddy proxy."
