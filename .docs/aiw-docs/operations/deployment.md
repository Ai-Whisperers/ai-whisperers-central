# Deployment Guide

## Quick Deploy

Deploy all stacks:
```bash
cd /opt/aiw-infra
./deploy.sh all
```

Deploy specific stack:
```bash
./deploy.sh n8n
./deploy.sh litellm
./deploy.sh monitoring
./deploy.sh evolution
```

## Stack Locations

| Stack | Path |
|-------|------|
| n8n | /opt/n8n/docker-stack.yml |
| LiteLLM | /opt/litellm/docker-compose.yml |
| Evolution API | /root/evolution.yaml |
| Monitoring | /opt/monitoring/docker-compose.yml |
| PostgreSQL | /opt/postgres/docker-stack.yml |
| Hermes Agent | /opt/aiw-code-agent/docker-stack.aiw.yml |

## Update Process

### 1. Update Docker Image
```bash
# For docker stack deploy
docker service update --image <new-image> <service-name>

# Example: update n8n
docker service update --image docker.n8n.io/n8nio/n8n:latest n8n_n8n
```

### 2. Force Restart (after config change)
```bash
docker service update --force n8n_n8n
```

### 3. n8n Pipeline Updates

After modifying pipeline nodes in PostgreSQL:
```bash
# Update workflow_entity and workflow_history
psql -U n8n -d n8n -c "UPDATE workflow_entity SET nodes = \$jn\$<json>\$jn\$ WHERE id = '<workflow-id>'"
psql -U n8n -d n8n -c "UPDATE workflow_history SET nodes = \$jn\$<json>\$jn\$ WHERE workflowId = '<workflow-id>'"

# Restart n8n
docker service update --force n8n_n8n
```

## Environment Variables

All environment variables are in `.env` files, never committed to git.

| Service | Config Location |
|---------|----------------|
| n8n | /opt/n8n/docker-stack.yml |
| LiteLLM | /opt/litellm/.env |
| Monitoring | /opt/monitoring/docker-compose.yml |

## Rollback

```bash
# Rollback a service to previous version
docker service rollback n8n_n8n

# View service history
docker service history n8n_n8n
```

## Post-Deploy Verification

1. Check service is running:
   ```bash
   docker service ls | grep n8n
   ```

2. Check logs:
   ```bash
   docker logs n8n_n8n --tail 50
   ```

3. Run health check:
   ```bash
   /opt/aiw-infra/scripts/health-check.sh
   ```

4. Test pipeline:
   ```bash
   curl -X POST https://n8n.sunstein.cloud/webhook/whatsapp-incoming \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```
