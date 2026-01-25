#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

sudo m# Create dirs + configs
mkdir -p vol/{cortex,thehive,postgres,n8n}
sudo chown -R 1000:1000 vol/{cortex,thehive,postgres,n8n}
