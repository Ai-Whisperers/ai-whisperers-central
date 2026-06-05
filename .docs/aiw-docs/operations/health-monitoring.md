# Health Monitoring

## Automated Checks

### Test Suite (28 tests)
```bash
/opt/aiw-infra/scripts/full-test-suite.sh
```

| Layer | Tests | Frequency |
|-------|-------|-----------|
| L1: Infrastructure | 20 | Every 5 min |
| L2: Service Health | 7 | Every 5 min |
| L3: Pipeline | 1 | Every 30 min |
| Full Suite | 28 | Daily at 3am |

### Cron Configuration
```bash
*/5 * * * * /opt/aiw-infra/scripts/full-test-suite.sh --layer 1 >> /var/log/aiw/health.log 2>&1
*/5 * * * * /opt/aiw-infra/scripts/full-test-suite.sh --layer 2 >> /var/log/aiw/health.log 2>&1
*/30 * * * * /opt/aiw-infra/scripts/full-test-suite.sh --layer 3 >> /var/log/aiw/health.log 2>&1
0 3 * * * /opt/aiw-infra/scripts/full-test-suite.sh >> /var/log/aiw/health-full.log 2>&1
```

## Manual Health Check

```bash
/opt/aiw-infra/scripts/health-check.sh
```

This runs a full audit:
- Docker Swarm status
- Service health
- Network connectivity
- Disk usage
- Memory usage
- Certificate expiration

## Grafana Alerts

| Alert | Condition | Action |
|-------|-----------|--------|
| Disk High | > 80% used | WhatsApp to Ivan |
| RAM Low | < 4GB available | WhatsApp to Ivan |
| Service Down | n8n/litellm/context-api | WhatsApp to Ivan |

Access Grafana: https://grafana.sunstein.cloud
Credentials: admin / admin123

## Critical Endpoints

| Service | Health Check |
|---------|-------------|
| LiteLLM | http://localhost:4000/health/liveliness |
| n8n | https://n8n.sunstein.cloud/healthz |
| Evolution API | http://evolution_evolution_api:8080/health |

## Log Locations

| Log | Location |
|-----|----------|
| Health checks | /var/log/aiw/health.log |
| Full tests | /var/log/aiw/health-full.log |
| Hermes agent | /var/log/hermes-agent.log |
| Traefik | /var/log/traefik/ |
| n8n | docker logs n8n_n8n |

## Quick Status Commands

```bash
# Docker Swarm
docker stack ls
docker service ls

# Container status
docker ps --format '{{.Names}} {{.Status}}'

# Resource usage
docker stats --no-stream

# Specific service
docker service ps n8n_n8n
docker logs n8n_n8n --tail 20
```
