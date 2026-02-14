#!/bin/bash

# Master script to apply CTI Stack Refactor
# This restart sequence ensures dependencies are met.

echo "=========================================="
echo "Starting CTI Stack Refactor Application..."
echo "=========================================="

# 1. Traefik Proxy (No change needed usually, but good to ensure it's up)
if [ -d "/opt/stacks/proxy" ]; then
    echo "Ensuring Proxy is up..."
    cd /opt/stacks/proxy
    sudo docker compose up -d
else
    echo "Skipping Proxy (Directory not found)"
fi

# 2. Infra Stack (Database/ES/Minio/RabbitMQ)
echo "Ensuring Infra is up..."
cd /opt/stacks/infra
sudo docker compose up -d
# Wait for DB?
sleep 5

# 3. MISP (Dependencies: DB)
echo "Restarting MISP..."
cd /opt/stacks/misp
sudo docker compose down
sudo docker compose up -d

# 4. TheHive (Dependencies: Cassandra, ES)
if [ -d "/opt/stacks/thehive" ]; then
    echo "Restarting TheHive..."
    cd /opt/stacks/thehive
    sudo docker compose down
    sudo docker compose up -d
else
    echo "Skipping TheHive (Directory not found)"
fi

# 5. Cortex (Dependencies: ES)
if [ -d "/opt/stacks/cortex" ]; then
    echo "Restarting Cortex..."
    cd /opt/stacks/cortex
    sudo docker compose down
    sudo docker compose up -d
else
    echo "Skipping Cortex (Directory not found)"
fi

# 6. XTM (OpenCTI/OpenAEV) (Dependencies: Minio, RabbitMQ, ES, MISP, TheHive)
if [ -d "/opt/stacks/xtm" ]; then
    echo "Restarting XTM (OpenCTI & OpenAEV)..."
    cd /opt/stacks/xtm
    sudo docker compose down
    sudo docker compose up -d
else
    echo "Skipping XTM (Directory not found)"
fi

# 7. Vaultwarden
if [ -d "/opt/stacks/vaultwarden" ]; then
    echo "Restarting Vaultwarden..."
    cd /opt/stacks/vaultwarden
    sudo docker compose down
    sudo docker compose up -d
else
    echo "Skipping Vaultwarden (Directory not found)"
fi

echo " =========================================="
echo "Refactor Complete!"
echo "Please ensure your DNS/hosts file maps the following to your Server IP:"
echo " - misp.threatresearcher.com / misp.lan"
echo " - opencti.threatresearcher.com / opencti.lan"
echo " - openaev.threatresearcher.com / openaev.lan"
echo " - thehive.threatresearcher.com / thehive.lan"
echo " - cortex.threatresearcher.com / cortex.lan"
echo " - vaultwarden.threatresearcher.com / vaultwarden.lan"
echo " - openclaw.threatresearcher.com / openclaw.lan"
echo "=========================================="
