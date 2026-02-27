#!/bin/bash
# setup-openclaw-local.sh
# Run this script DIRECTLY INSIDE the OpenClaw LXC terminal (as root or gravity).

set -e

echo "=== Configuring OpenClaw ==="

# 1. Apply config fixes (ignoring the obsolete global dmPolicy)
echo "Running openclaw doctor --fix..."
openclaw doctor --fix || true

# 2. Setup the custom root systemd service
OPENCLAW_PATH=$(which openclaw)
NODE_PATH=$(which node)

# Get the actual user (if root, we should maybe still run as root or gravity, but let's run as the current user or assume gravity exists)
# The Proxmox helper script usually runs as root, so let's check if gravity exists.
if id "gravity" &>/dev/null; then
    RUN_USER="gravity"
    HOME_DIR="/home/gravity/.openclaw"
else
    RUN_USER="root"
    HOME_DIR="/root/.openclaw"
fi

SYSTEMD_SERVICE="[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=${RUN_USER}
Environment=\"PATH=/usr/local/bin:/usr/bin:/bin\"
Environment=\"OPENCLAW_HOME=${HOME_DIR}\"
ExecStart=${NODE_PATH} ${OPENCLAW_PATH} gateway --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

echo "Installing systemd service..."
cat << EOF > /etc/systemd/system/openclaw.service
$SYSTEMD_SERVICE
EOF

echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable --now openclaw.service
systemctl status openclaw.service --no-pager || true

echo "=== OpenClaw Local Setup Complete ==="
