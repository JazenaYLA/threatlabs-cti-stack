#!/bin/bash
# configure-openclaw-lxc.sh
# Script to configure OpenClaw and Caddy LXC containers manually.
# Run this from a machine that has SSH access to the LXC containers (e.g., the Proxmox host or your local machine with `caddy` and `openclaw` in ~/.ssh/config).

set -e

echo "=== Configuring OpenClaw LXC ==="

# 1. Check and enforce Security Defaults for DM access
echo "Setting secure DM policies..."
ssh openclaw "openclaw config set dmPolicy pairing" || true
ssh openclaw "openclaw config set channels.discord.dmPolicy pairing" || true
ssh openclaw "openclaw config set channels.slack.dmPolicy pairing" || true

# 2. Allow insecure auth for Web UI behind reverse proxy (Caddy will handle HTTPS externally, but internally it's HTTP/WS)
# The error "Gateway URL uses plaintext ws:// to a non-loopback address" happens if we don't explicitly allow it
echo "Setting allowInsecureAuth for Control UI behind proxy..."
ssh openclaw "openclaw config set gateway.controlUi.allowInsecureAuth true --json" || true

# 3. Create a system-level systemd service for OpenClaw (since user-level systemd is unavailable in the LXC)
echo "Creating systemd service for OpenClaw..."
OPENCLAW_PATH=$(ssh openclaw "which openclaw" || echo "/usr/bin/openclaw")
NODE_PATH=$(ssh openclaw "which node" || echo "/usr/bin/node")

# We run it as the gravity user
SYSTEMD_SERVICE="[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=gravity
Environment=\"PATH=/usr/local/bin:/usr/bin:/bin\"
Environment=\"OPENCLAW_HOME=/home/gravity/.openclaw\"
ExecStart=${NODE_PATH} ${OPENCLAW_PATH} gateway --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

echo "Installing systemd service on openclaw LXC..."
ssh openclaw "cat << 'EOF' | sudo tee /etc/systemd/system/openclaw.service
$SYSTEMD_SERVICE
EOF"

echo "Enabling and starting OpenClaw service..."
ssh openclaw "sudo systemctl daemon-reload"
ssh openclaw "sudo systemctl enable --now openclaw.service"
ssh openclaw "sudo systemctl status openclaw.service --no-pager" || true

echo "Running OpenClaw doctor..."
ssh openclaw "openclaw doctor" || true

echo "=== OpenClaw configuration complete ==="

echo "=== Configuring Caddy LXC ==="
# Caddy proxy configuration for OpenClaw.

# Original: openclaw.local { reverse_proxy <OPENCLAW_IP_OLD>:18789 }
CADDY_SNIPPET="
openclaw.lab.local {
    reverse_proxy <OPENCLAW_IP>:18789
}
"

echo "Adding OpenClaw reverse proxy to Caddyfile..."
ssh caddy "if ! grep -q 'openclaw.lab.local' /etc/caddy/Caddyfile; then cat << 'EOF' | sudo tee -a /etc/caddy/Caddyfile
$CADDY_SNIPPET
EOF
fi"

echo "Reloading Caddy..."
ssh caddy "sudo systemctl reload caddy" || ssh caddy "caddy reload --config /etc/caddy/Caddyfile" || echo "Note: Check Caddy status if reload failed."

echo "=== Caddy configuration complete ==="
echo "Done! The OpenClaw gateway should now be running as a system service."
