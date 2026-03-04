#!/bin/bash
# install-openclaw-deps.sh
# Run this inside the OpenClaw LXC terminal (root@openclaw).
# This installs common missing libraries in Proxmox Debian LXC templates that cause OpenClaw to crash on boot.

set -e

echo "=== Installing Common OpenClaw LXC Dependencies ==="

apt-get update
apt-get install -y \
    build-essential \
    python3 \
    sqlite3 \
    libsqlite3-dev \
    libvips-dev \
    git \
    curl \
    wget \
    ca-certificates \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2

echo "Rebuilding node native dependencies..."
npm install -g node-gyp
openclaw doctor --fix || true

echo "Restarting OpenClaw Gateway..."
systemctl restart openclaw.service
sleep 3
systemctl status openclaw.service --no-pager

echo "=== Dependencies Installed & Service Restarted ==="
