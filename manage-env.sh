#!/bin/bash
# manage-env.sh - CTI Stack Environment Management Utility

STACK_ROOT="/opt/stacks"
STACKS="infra misp thehive xtm n8n flowise flowintel lacus dfir-iris shuffle ail-project"

usage() {
    echo "Usage: $0 {prod|dev|status} [command]"
    echo ""
    echo "Commands:"
    echo "  prod [up|down|restart]    - Switch to Production (cti-prod) and run command"
    echo "  dev  [up|down|restart]    - Switch to Development (cti) and run command"
    echo "  status                    - Show current environment status"
    echo ""
    echo "Example: ./manage-env.sh prod up"
    exit 1
}

if [ -z "$1" ]; then usage; fi

MODE=$1
CMD=$2

update_env() {
    local file=$1
    local key=$2
    local value=$3
    if [ -f "$file" ]; then
        if grep -q "^${key}=" "$file"; then
            sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        else
            echo "${key}=${value}" | sudo tee -a "$file" > /dev/null
        fi
    fi
}

apply_env() {
    local target_mode=$1
    echo ">>> Setting environment to: $target_mode"
    
    if [ "$target_mode" == "prod" ]; then
        PROJECT="cti-prod"
        OPENAEV_DB="prod_openaev"
        N8N_DB="prod_n8n"
        FLOWINTEL_DB="prod_flowintel"
    else
        PROJECT="cti"
        OPENAEV_DB="openaev"
        N8N_DB="n8n"
        FLOWINTEL_DB="flowintel"
    fi

    # Update Global Infra
    update_env "$STACK_ROOT/infra/.env" COMPOSE_PROJECT_NAME "$PROJECT"
    update_env "$STACK_ROOT/infra/.env" OPENAEV_DB_NAME "$OPENAEV_DB"
    update_env "$STACK_ROOT/infra/.env" N8N_DB_NAME "$N8N_DB"
    update_env "$STACK_ROOT/infra/.env" FLOWINTEL_DB_NAME "$FLOWINTEL_DB"

    # Update individual stacks
    for s in $STACKS; do
        update_env "$STACK_ROOT/$s/.env" COMPOSE_PROJECT_NAME "$PROJECT"
    done

    # Update app specific DB names
    update_env "$STACK_ROOT/xtm/.env" OPENAEV_DB_NAME "$OPENAEV_DB"
    update_env "$STACK_ROOT/n8n/.env" N8N_DB_NAME "$N8N_DB"
    update_env "$STACK_ROOT/flowintel/.env" FLOWINTEL_DB_NAME "$FLOWINTEL_DB"
}

run_docker() {
    local command=$1
    echo ">>> Executing '$command' across all stacks..."
    
    # Order matters for 'up'
    ORDER="infra misp-modules misp thehive xtm flowintel ail-project lacus n8n flowise shuffle"
    
    if [ "$command" == "down" ]; then
        # Reverse order for down
        ORDER="shuffle flowise n8n lacus ail-project flowintel xtm thehive misp misp-modules infra"
    fi

    for s in $ORDER; do
        if [ -d "$STACK_ROOT/$s" ]; then
            echo "--- $s ---"
            cd "$STACK_ROOT/$s"
            sudo docker compose $command
        fi
    done
}

case $MODE in
    prod|dev)
        apply_env "$MODE"
        if [ ! -z "$CMD" ]; then
            run_docker "$CMD"
        fi
        ;;
    status)
        echo "Current project name in infra: $(grep COMPOSE_PROJECT_NAME $STACK_ROOT/infra/.env | cut -d= -f2)"
        ;;
    *)
        usage
        ;;
esac
