#!/usr/bin/env bash
set -e

# Startup Script for ThreatLabs CTI Stack
# Usage: ./startup.sh
# Brings up all dockge-cti stacks in dependency order.
# Run ./setup.sh first if this is a fresh install.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/volume-config.sh"

# Phases are sourced from scripts/volume-config.sh
# PHASE_1, PHASE_2, PHASE_3, PHASE_4 are the canonical boot order.

# 0. Handle Infisical Secret Sync (Optional)
SKIP_SYNC=false
if [[ "$*" == *"--skip-sync"* ]]; then
    SKIP_SYNC=true
fi

if [ "$SKIP_SYNC" = false ] && [ -f "./scripts/update-secrets.sh" ]; then
    echo "[*] Synchronizing secrets from Infisical before boot..."
    ./scripts/update-secrets.sh --sync-only || echo "[-] Warning: Secret sync failed. Booting with existing .env files..."
fi

start_stack() {
    local stack="$1"
    if [ -d "$stack" ] && [ -f "$stack/docker-compose.yml" ]; then
        echo "    🚀 Starting $stack..."
        (cd "$stack" && sudo docker compose up -d 2>&1 | tail -1)
    elif [ -d "$stack" ] && [ -f "$stack/compose.yaml" ]; then
        echo "    🚀 Starting $stack..."
        (cd "$stack" && sudo docker compose up -d 2>&1 | tail -1)
    else
        echo "    ⏭️  Skipping $stack (not found or no compose file)"
    fi
}

wait_for_healthy() {
    local container="$1"
    local timeout="${2:-120}"
    echo "    ⏳ Waiting for $container to be healthy (${timeout}s timeout)..."
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")
        if [ "$status" = "healthy" ]; then
            echo "    ✅ $container is healthy."
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    echo "    ⚠️  $container did not become healthy within ${timeout}s. Continuing anyway..."
    return 0
}

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ThreatLabs CTI Stack — Ordered Startup               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# --- Phase 1: Infrastructure ---
echo "[Phase 1] Infrastructure (databases, cti-net)..."
for stack in "${CTI_PHASE_1[@]}"; do
    start_stack "$stack"
done
# Wait for critical infra services before proceeding
wait_for_healthy "infra-postgres" 120
wait_for_healthy "infra-valkey" 60

# ES doesn't have Docker HEALTHCHECK, so wait for HTTP API
echo "    ⏳ Waiting for ElasticSearch 8 (es8-cti)..."
for i in $(seq 1 24); do
    if docker exec es8-cti curl -sf http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "    ✅ es8-cti is ready."
        break
    fi
    [ "$i" -eq 24 ] && echo "    ⚠️  es8-cti did not respond within 120s. Continuing..."
    sleep 5
done

echo "    ⏳ Waiting for ElasticSearch 7 (es7-cti)..."
for i in $(seq 1 24); do
    if docker exec es7-cti curl -sf http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "    ✅ es7-cti is ready."
        break
    fi
    [ "$i" -eq 24 ] && echo "    ⚠️  es7-cti did not respond within 120s. Continuing..."
    sleep 5
done
echo ""

# --- Phase 2: Shared Services ---
echo "[Phase 2] Shared services..."
for stack in "${CTI_PHASE_2[@]}"; do
    start_stack "$stack"
done
wait_for_healthy "misp-modules-shared" 60
echo ""

# --- Phase 3: Core Platforms ---
echo "[Phase 3] Core platform services..."
if [ -x "./misp/patch-config.sh" ]; then
    ./misp/patch-config.sh
fi
for stack in "${CTI_PHASE_3[@]}"; do
    start_stack "$stack"
done
echo ""

# --- Phase 4: Auxiliary ---
echo "[Phase 4] Auxiliary services..."
if [ -x "./lacus/patch-config.sh" ]; then
    ./lacus/patch-config.sh
fi
for stack in "${CTI_PHASE_4[@]}"; do
    start_stack "$stack"
done
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ All stacks started. Use 'docker ps' to check status.       ║"
echo "║  📊 Dockge UI: http://dockge-cti.lab.local:5001                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
