#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "=== AI Whisperers Infrastructure Health Check ==="
echo "Date: $(date)"
echo ""

# Docker services
echo "--- Docker Services ---"
docker service ls --format '{{.Name}}\t{{.Replicas}}\t{{.Image}}' | sort | while read line; do
    name=$(echo "$line" | awk '{print $1}')
    replicas=$(echo "$line" | awk '{print $2}')
    if [[ "$replicas" == *"/0" ]]; then
        echo -e "  ${RED}FAIL${NC} $line"
    elif [[ "$replicas" != "1/1" && "$replicas" != "1/1 "* ]]; then
        echo -e "  ${YELLOW}WARN${NC} $line"
    else
        echo -e "  ${GREEN}OK${NC}   $line"
    fi
done

# Network connectivity
echo ""
echo "--- Network Connectivity ---"
N8N=$(docker ps -q --filter "name=n8n_n8n" | head -1)

if [ -n "$N8N" ]; then
    # n8n -> litellm
    result=$(docker exec $N8N wget -qO- --timeout=3 http://litellm:4000/health 2>&1)
    if echo "$result" | grep -q "error\|unauthorized"; then
        echo -e "  ${GREEN}OK${NC}   n8n -> litellm (reached, auth required)"
    else
        echo -e "  ${YELLOW}WARN${NC} n8n -> litellm ($result)"
    fi
    
    # n8n -> context-api
    result=$(docker exec $N8N wget -qO- --timeout=3 http://aiw-context-api:3100/health 2>&1)
    if echo "$result" | grep -q "chatJid"; then
        echo -e "  ${GREEN}OK${NC}   n8n -> context-api"
    else
        echo -e "  ${YELLOW}WARN${NC} n8n -> context-api ($result)"
    fi
fi

# Evolution -> n8n
EVO=$(docker ps -q --filter "name=evolution_evolution_api" | head -1)
if [ -n "$EVO" ]; then
    result=$(docker exec $EVO wget -qO- --timeout=3 http://n8n_n8n:5678/healthz 2>&1)
    if echo "$result" | grep -q "ok"; then
        echo -e "  ${GREEN}OK${NC}   evolution -> n8n"
    else
        echo -e "  ${YELLOW}WARN${NC} evolution -> n8n ($result)"
    fi
fi

# Resources
echo ""
echo "--- System Resources ---"
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
MEM_USED=$(free -m | awk '/Mem:/{printf "%.1f%%", $3/$2*100}')
DISK_USED=$(df -h / | awk 'NR==2{print $5}')
echo "  CPU:    ${CPU}%"
echo "  Memory: ${MEM_USED}"
echo "  Disk:   ${DISK_USED}"
echo ""
echo "=== Health Check Complete ==="
