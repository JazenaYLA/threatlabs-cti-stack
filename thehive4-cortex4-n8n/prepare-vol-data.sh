#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

sudo m# Create dirs + configs
mkdir -p vol/{cassandra/data,thehive,cortex,postgres,n8n}
sudo chown -R 1000:1000 vol/{cassandra/data,thehive,cortex,postgres,n8n}
