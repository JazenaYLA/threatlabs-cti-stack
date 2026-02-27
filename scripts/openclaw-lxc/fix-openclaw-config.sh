#!/bin/bash
# fix-openclaw-config.sh
# Run this inside the OpenClaw LXC terminal (root@openclaw).

set -e

echo "=== Fixing OpenClaw Config Error ==="

# The gateway is crashing because it says "Missing config. Run openclaw setup or set gateway.mode=local (or pass --allow-unconfigured)"
# We need to add --allow-unconfigured to the systemd service so it can boot and host the Control UI for actual setup.

OPENCLAW_PATH=$(which openclaw)
NODE_PATH=$(which node)

cat << EOF > /etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=root
Environment="PATH=$PATH"
Environment="OPENCLAW_HOME=/root/.openclaw"
ExecStart=${NODE_PATH} ${OPENCLAW_PATH} gateway --port 18789 --allow-unconfigured
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading and restarting OpenClaw Gateway..."
systemctl daemon-reload
systemctl restart openclaw.service
sleep 3
systemctl status openclaw.service --no-pager

echo "=== OpenClaw Gateway Should Be Running ==="
