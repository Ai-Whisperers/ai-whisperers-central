#!/bin/bash
# setup-vps.sh — run once on the VPS to create deploy scripts
# Installs deploy scripts to /opt/stacks/ci-cd/scripts/
set -euo pipefail

DIR="/opt/stacks/ci-cd/scripts"
mkdir -p "$DIR"

cat > "$DIR/deploy.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
SITE=$1
REPO=$2
TMP_DIR="/tmp/$SITE"
rm -rf "$TMP_DIR"
git clone "https://github.com/$REPO.git" "$TMP_DIR"
cd "$TMP_DIR"
docker build -t "$SITE:prod" .
SERVICE="${SITE}_web"
if docker service ls --format '{{.Name}}' | grep -q "^${SERVICE}$"; then
  docker service update --force "$SERVICE"
else
  docker stack deploy -c docker-compose.yml "$SITE" 2>/dev/null || \
    docker service create --name "$SERVICE" --publish 3000 "$SITE:prod"
fi
rm -rf "$TMP_DIR"
SCRIPT
chmod +x "$DIR/deploy.sh"

cat > "$DIR/deploy-git-pull.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
SITE=$1
DIR=$2
cd "$DIR"
git pull
npm ci
npm run build
docker build -t "$SITE:prod" .
docker stack deploy -c docker-compose.yml "$SITE"
SCRIPT
chmod +x "$DIR/deploy-git-pull.sh"

echo "=== VPS deploy scripts installed to $DIR ==="
