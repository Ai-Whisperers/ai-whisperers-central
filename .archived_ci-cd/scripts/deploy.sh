#!/bin/bash
# deploy.sh — called from GH Actions via SSH
# Usage: deploy.sh <site-name> <github-repo>
set -euo pipefail

SITE=$1
REPO=$2
TMP_DIR="/tmp/$SITE"

echo "=== Deploying $SITE from $REPO ==="

# Clean and clone
rm -rf "$TMP_DIR"
git clone "https://github.com/$REPO.git" "$TMP_DIR"
cd "$TMP_DIR"

# Build Docker image
docker build -t "$SITE:prod" .

# Update Docker Swarm service (assumes service is named ${SITE}_web)
SERVICE="${SITE}_web"
if docker service ls --format '{{.Name}}' | grep -q "^${SERVICE}$"; then
  docker service update --force "$SERVICE"
  echo "=== Service $SERVICE updated ==="
else
  echo "=== Service $SERVICE not found — deploying fresh ==="
  docker stack deploy -c docker-compose.yml "$SITE" 2>/dev/null || \
    docker service create --name "$SERVICE" --publish 3000 "$SITE:prod"
fi

# Cleanup
rm -rf "$TMP_DIR"
echo "=== Deploy complete: $SITE ==="
