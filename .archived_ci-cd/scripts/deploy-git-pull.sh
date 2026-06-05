#!/bin/bash
# deploy-git-pull.sh — for repos where VPS already has the clone
# Usage: deploy-git-pull.sh <site-name> <vps-dir>
set -euo pipefail

SITE=$1
DIR=$2

echo "=== Deploying $SITE from $DIR ==="

cd "$DIR"
git pull

# Build
npm ci
npm run build

# Docker
docker build -t "$SITE:prod" .
docker stack deploy -c docker-compose.yml "$SITE"

echo "=== Deploy complete: $SITE ==="
