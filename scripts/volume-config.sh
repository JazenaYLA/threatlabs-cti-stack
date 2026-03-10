#!/usr/bin/env bash
# volume-config.sh — Single Source of Truth
# Sourced by: setup.sh, reset.sh, fix-permissions.sh, setup-dockge.sh
#
# To add a new stack:   Add to CTI_STACKS
# To add a new volume:  Add to CTI_VOLUMES as "dir_path|perm_path|uid:gid"
# To add a reset dir:   Add to CTI_RESET_DIRS

# ─── Canonical Stack List ──────────────────────────────────────────────
# Stacks grouped by Phase for shared use across setup/reset/startup/secrets
CTI_PHASE_1=("infra")
CTI_PHASE_2=("misp-modules" "ail-project" "forgejo-runner" "proxy")
CTI_PHASE_3=("misp" "xtm" "thehive" "flowintel")
CTI_PHASE_4=("lacus" "dfir-iris" "shuffle")

# Flattened list for scripts that iterate through all stacks
CTI_STACKS=(
    "${CTI_PHASE_1[@]}"
    "${CTI_PHASE_2[@]}"
    "${CTI_PHASE_3[@]}"
    "${CTI_PHASE_4[@]}"
)

# ─── Volume Definitions ───────────────────────────────────────────────
# Format: "dir_path|perm_path|uid:gid"
#   dir_path  = directory to create (mkdir -p)
#   perm_path = directory to chown (usually parent for broader coverage)
#   uid:gid   = ownership to apply
CTI_VOLUMES=(
    # --- Infra (Databases) ---
    "infra/vol/esdata7/data|infra/vol/esdata7|1000:1000"
    "infra/vol/esdata8/data|infra/vol/esdata8|1000:1000"
    "infra/vol/postgres/data|infra/vol/postgres|70:70"
    "infra/vol/valkey/data|infra/vol/valkey|999:999"
    "infra/vol/postgres-init|infra/vol/postgres-init|1000:1000"

    # --- XTM (OpenCTI / OpenAEV) ---
    "xtm/volumes/pgsqldata|xtm/volumes|1000:1000"
    "xtm/volumes/s3data|xtm/volumes|1000:1000"
    "xtm/volumes/redisdata|xtm/volumes|1000:1000"
    "xtm/volumes/amqpdata|xtm/volumes|1000:1000"
    "xtm/volumes/rsakeys|xtm/volumes|1000:1000"

    # --- FlowIntel ---
    "flowintel/vol/flowintel/data|flowintel/vol|1000:1000"

    # --- Forgejo Runner ---
    "forgejo-runner/data|forgejo-runner/data|1000:1000"

    # --- Lacus ---
    "lacus/vol/lacus-data|lacus/vol|1000:1000"

    # --- TheHive ---
    "thehive/vol/cassandra/data|thehive/vol|1000:1000"
    "thehive/vol/thehive|thehive/vol|1000:1000"
    "thehive/vol/thehive/data|thehive/vol|1000:1000"

    # --- MISP Modules ---
    "misp-modules/.vol/custom/action_mod|misp-modules/.vol|1000:1000"
    "misp-modules/.vol/custom/expansion|misp-modules/.vol|1000:1000"
    "misp-modules/.vol/custom/export_mod|misp-modules/.vol|1000:1000"
    "misp-modules/.vol/custom/import_mod|misp-modules/.vol|1000:1000"

    # --- DFIR-IRIS ---
    "dfir-iris/vol/db_data|dfir-iris/vol/db_data|999:999"
    "dfir-iris/vol/iris-downloads|dfir-iris/vol|1000:1000"
    "dfir-iris/vol/user_templates|dfir-iris/vol|1000:1000"
    "dfir-iris/vol/server_data|dfir-iris/vol|1000:1000"

    # --- Shuffle ---
    "shuffle/vol/shuffle-apps|shuffle/vol|1000:1000"
    "shuffle/vol/shuffle-files|shuffle/vol|1000:1000"

    # --- MISP (bind-mount dirs, www-data UID 33) ---
    "misp/configs|misp/configs|33:33"
    "misp/logs|misp/logs|33:33"
    "misp/files|misp/files|33:33"
    "misp/ssl|misp/ssl|33:33"
    "misp/gnupg|misp/gnupg|33:33"
    "misp/custom|misp/custom|33:33"
)

# ─── Reset Directories ────────────────────────────────────────────────
# Top-level dirs to rm -rf during a factory reset (Phase 1: relative)
CTI_RESET_DIRS=(
    "infra/vol"
    "xtm/volumes"
    "flowintel/vol"
    "lacus/vol"
    "thehive/vol"
    "dfir-iris/vol"
    "misp-modules/.vol"
    "shuffle/vol"
    "forgejo-runner/data"
)
