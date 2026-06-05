# Troubleshooting

## Nyx Not Responding

### 1. Check Execution History
```bash
PGC=$(docker ps -q --filter "name=postgres_postgres" | head -1)
docker exec $PGC psql -U n8n -d n8n -t -A -c \
  "SELECT id, status, startedAt FROM execution_entity ORDER BY id DESC LIMIT 5"
```

### 2. Check Latest Execution Data
```bash
PGC=$(docker ps -q --filter "name=postgres_postgres" | head -1)
docker exec $PGC psql -U n8n -d n8n -t -A -c \
  "SELECT data FROM execution_data WHERE executionId = <id>" > /tmp/exec.json
# Then parse with Python to see node outputs
```

### 3. Common Causes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "fetch is not defined" | n8n task runner sandbox | Set `N8N_RUNNERS_INSECURE_MODE=true` |
| Gateway timeout | Wrong Evolution URL | Use internal: `http://evolution_evolution_api:8080` |
| Group message skipped | Mention not detected | Check for LID format: @154288881946676 |

### 4. Check LiteLLM
```bash
curl http://localhost:4000/health/liveliness
curl http://localhost:4000/model/info
```

### 5. Check Evolution API
```bash
docker logs evolution_evolution_api --tail 50
```

## Hermes Agent Issues

### Not Running
```bash
ps aux | grep hermes
# Restart if needed:
cd /root/.hermes
nohup ./hermes-agent/venv/bin/hermes > /var/log/hermes-agent.log 2>&1 &
```

### "Failed to call a function"
This is a Groq-side tool calling error. Agent automatically retries with fallback model.

### Wrong Response
Check agent logs:
```bash
tail -100 /var/log/hermes-agent.log
```

## Database Issues

### Connection Refused
```bash
# Check PostgreSQL
docker service ps postgres_postgres
docker logs postgres_postgres --tail 20

# Restart if needed
docker service update --force postgres_postgres
```

### Locked Tables
```bash
docker exec postgres_postgres psql -U n8n -d n8n -c \
  "SELECT * FROM pg_locks WHERE granted = false;"
```

## Docker Issues

### Service Won't Start
```bash
# Check why
docker service ps <service-name> --no-trunc

# View logs
docker service logs <service-name> --tail 50
```

### Network Problems
```bash
# Check networks
docker network ls

# Check service networks
docker inspect <container> | grep Networks -A 10
```

## Performance Issues

### High Memory
```bash
docker stats --no-stream
```

### Slow Response
1. Check LiteLLM latency: https://litellm.sunstein.cloud/docs
2. Check model availability: `curl http://localhost:4000/health`
3. Check Redis cache: `docker exec redis redis-cli info memory`

## Common Commands Reference

```bash
# Restart n8n
docker service update --force n8n_n8n

# Restart LiteLLM
docker restart litellm

# Check all services
docker ps --format '{{.Names}} {{.Status}}'

# Full health check
/opt/aiw-infra/scripts/health-check.sh

# Run tests
/opt/aiw-infra/scripts/full-test-suite.sh
```
