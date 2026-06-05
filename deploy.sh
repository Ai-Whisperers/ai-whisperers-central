#!/bin/bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-deploy}"

deploy_stack() {
    local name="$1"
    local file="$2"
    echo ">>> Deploying stack: $name"
    if [[ "$file" == *docker-compose* ]]; then
        cd "$(dirname "$file")"
        docker compose up -d
    else
        docker stack deploy -c "$file" "$name"
    fi
}

remove_stack() {
    local name="$1"
    echo ">>> Removing stack: $name"
    if docker service ls --format '{{.Name}}' | grep -q "^${name}_"; then
        docker stack rm "$name"
    else
        cd "$DEPLOY_DIR/stacks/$name" && docker compose down 2>/dev/null || true
    fi
}

case "$ACTION" in
    deploy)
        deploy_stack "postgres" "$DEPLOY_DIR/stacks/postgres/docker-stack.yml"
        sleep 5
        deploy_stack "litellm" "$DEPLOY_DIR/stacks/litellm/docker-compose.yml"
        sleep 5
        deploy_stack "n8n" "$DEPLOY_DIR/stacks/n8n/docker-stack.yml"
        deploy_stack "evolution" "$DEPLOY_DIR/stacks/evolution/docker-stack.yml"
        deploy_stack "aiw-code-agent" "$DEPLOY_DIR/stacks/aiw-code-agent/docker-stack.yml"
        deploy_stack "monitoring" "$DEPLOY_DIR/stacks/monitoring/docker-compose.yml"
        echo ">>> All stacks deployed"
        ;;
    remove)
        remove_stack "n8n"
        remove_stack "evolution"
        remove_stack "aiw-code-agent"
        remove_stack "monitoring"
        remove_stack "litellm"
        remove_stack "postgres"
        echo ">>> All stacks removed"
        ;;
    status)
        docker service ls --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}' 2>/dev/null
        echo ""
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | head -20
        ;;
    *)
        echo "Usage: $0 {deploy|remove|status}"
        exit 1
        ;;
esac
