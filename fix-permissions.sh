#!/bin/sh
# fix-permissions.sh
# Automated permission fix for ThreatLabs CTI Stack

echo "🔧 Restoring Service Permissions..."

# --- 1. Infrastructure (Databases) ---
# ElasticSearch (UID 1000)
if [ -d "infra/vol/esdata7" ]; then echo "  - Fixing ES7..."; chown -R 1000:1000 infra/vol/esdata7; fi
if [ -d "infra/vol/esdata8" ]; then echo "  - Fixing ES8..."; chown -R 1000:1000 infra/vol/esdata8; fi

# Postgres (Alpine Image uses UID 70)
if [ -d "infra/vol/postgres" ]; then echo "  - Fixing Postgres..."; chown -R 70:70 infra/vol/postgres; fi

# Valkey/Redis (UID 999)
if [ -d "infra/vol/valkey" ]; then echo "  - Fixing Valkey..."; chown -R 999:999 infra/vol/valkey; fi

# Init Scripts (UID 1000)
if [ -d "infra/vol/postgres-init" ]; then chown -R 1000:1000 infra/vol/postgres-init; fi


# --- 2. Application Stacks (UID 1000) ---
# XTM (OpenCTI)
if [ -d "xtm/volumes" ]; then echo "  - Fixing XTM..."; chown -R 1000:1000 xtm/volumes; fi

# Cortex
if [ -d "cortex/vol" ]; then echo "  - Fixing Cortex..."; chown -R 1000:1000 cortex/vol; fi

# n8n
if [ -d "n8n/vol" ]; then echo "  - Fixing n8n..."; chown -R 1000:1000 n8n/vol; fi

# Flowise
if [ -d "flowise/vol" ]; then echo "  - Fixing Flowise..."; chown -R 1000:1000 flowise/vol; fi

# FlowIntel
if [ -d "flowintel/vol" ]; then echo "  - Fixing FlowIntel..."; chown -R 1000:1000 flowintel/vol; fi

# Lacus
if [ -d "lacus/vol" ]; then echo "  - Fixing Lacus..."; chown -R 1000:1000 lacus/vol; fi

# TheHive
if [ -d "thehive/vol" ]; then echo "  - Fixing TheHive..."; chown -R 1000:1000 thehive/vol; fi

# OpenClaw
if [ -d "openclaw/vol" ]; then echo "  - Fixing OpenClaw..."; chown -R 1000:1000 openclaw/vol; fi

echo "✅ Permissions Restored."
