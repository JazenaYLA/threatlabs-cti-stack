#!/usr/bin/env bash
set -e

# Startup Script for ThreatLabs CTI Stack
# Usage: ./startup.sh
# Brings up all dockge-cti stacks in dependency order.
# Run ./setup.sh first if this is a fresh install.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/volume-config.sh"

# ─── Boot Order ────────────────────────────────────────────────────────
# Phase 1: Infrastructure (ES, Postgres, Valkey, cti-net)
# Phase 2: Standalone services (misp-modules, ail-project, forgejo-runner)
# Phase 3: Core platforms (misp, xtm, thehive, flowintel)
# Phase 4: Auxiliary (lacus, dfir-iris, shuffle)

PHASE_1=("infra")
PHASE_2=("misp-modules" "ail-project" "forgejo-runner" "proxy")
PHASE_3=("misp" "xtm" "thehive" "flowintel")
PHASE_4=("lacus" "dfir-iris" "shuffle")

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
for stack in "${PHASE_1[@]}"; do
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
for stack in "${PHASE_2[@]}"; do
    start_stack "$stack"
done
wait_for_healthy "misp-modules-shared" 60
echo ""

# --- Phase 3: Core Platforms ---
echo "[Phase 3] Core platforms..."
for stack in "${PHASE_3[@]}"; do
    start_stack "$stack"
done
echo ""

# --- Phase 4: Auxiliary ---
echo "[Phase 4] Auxiliary services..."
for stack in "${PHASE_4[@]}"; do
    start_stack "$stack"
done
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ All stacks started. Use 'docker ps' to check status.       ║"
echo "║  📊 Dockge UI: http://dockge-cti.lab.local:5001                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
