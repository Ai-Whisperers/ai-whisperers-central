# Rollback Procedures

How to safely rollback services and configurations.

## Quick Rollback Commands

### Rollback Docker Stack

```bash
cd /opt/aiw-infra

# List available versions
git tag -l

# Rollback to previous version
git checkout v1.2.3
make deploy

# Or rollback by git commit
git revert HEAD
make deploy
```

### Rollback Single Service

```bash
# Get container ID of previous image
docker images | grep SERVICE_NAME

# Rollback n8n
docker compose stop n8n
docker tag aiw-infra/n8n:previous aiw-infra/n8n:latest
docker compose up -d n8n
```

## Rollback n8n Workflow

### Emergency Workflow Restore

When a workflow update causes issues:

```bash
# Connect to database
docker compose exec postgres psql -U n8n -d n8n

# Find workflow ID
SELECT id, name, active FROM workflow_entity WHERE name LIKE '%Hermes%';

# Find last known good version
SELECT id, version_id, nodes, updated_at 
FROM workflow_entity 
WHERE id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd'
ORDER BY updated_at DESC LIMIT 5;

# Restore from backup (replace VERSION_ID)
UPDATE workflow_entity 
SET nodes = (SELECT nodes FROM workflow_entity WHERE version_id = 'GOOD_VERSION_ID')
WHERE id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';

# Also update workflow_history cache
UPDATE workflow_history
SET nodes = (SELECT nodes FROM workflow_entity WHERE id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd')
WHERE workflow_id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';
```

## Database Rollback

### Point-in-Time Recovery

```bash
# Stop services
make stop

# Restore from backup
docker compose exec -T postgres psql -U n8n -d n8n < /backups/n8n-YYYYMMDD.sql

# Restart services
make start
```

### Partial Data Restore

```bash
# Restore specific tables only
docker compose exec -T postgres psql -U n8n -d n8n \
  -c "\COPY workflow_entity FROM /backups/workflows-YYYYMMDD.csv CSV HEADER;"
```

## Configuration Rollback

### Environment Variables

```bash
# View git history of .env
git log --oneline .env

# Restore previous version
git checkout HEAD~1 .env
make deploy
```

### Traefik Configuration

```bash
# Rollback traefik config
git checkout HEAD~1 traefik/traefik.yml
make restart SERVICE=traefik
```

## Hermes Agent Rollback

### Restore Previous Version

```bash
# Check available versions
ls -la /root/.hermes/versions/

# Restore previous Hermes version
systemctl stop hermes-agent
cp /root/.hermes/versions/backup-20240101.jar /root/hermes-agent.jar
systemctl start hermes-agent
```

### Restore Configuration

```bash
# Check config git history
git log --oneline /root/.hermes/config.yaml

# Restore previous config
git checkout HEAD~1 /root/.hermes/config.yaml
systemctl restart hermes-agent
```

## Verification After Rollback

```bash
# 1. Check service status
make status

# 2. Verify workflows are active
curl -s http://localhost:5678/rest/workflows | jq '.data[] | select(.active==true) | .name'

# 3. Test WhatsApp bot
# Send test message and verify response

# 4. Check for errors
make logs-n8n | grep -i error | tail -20
```

## Emergency Rollback Checklist

- [ ] Stop affected services
- [ ] Backup current state (even if broken)
- [ ] Identify rollback target
- [ ] Execute rollback
- [ ] Verify services start
- [ ] Test critical functionality
- [ ] Notify team of rollback
- [ ] Document incident
