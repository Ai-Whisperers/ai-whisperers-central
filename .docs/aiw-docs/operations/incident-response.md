# Incident Response

Procedures for handling service outages and emergencies.

## Severity Levels

| Level | Definition | Response Time | Example |
|-------|------------|---------------|---------|
| P1 | Complete outage | 15 minutes | All services down |
| P2 | Major functionality broken | 1 hour | WhatsApp not responding |
| P3 | Minor issue | 4 hours | Single workflow failing |
| P4 | Cosmetic/non-critical | Next sprint | UI glitches |

## Incident Response Flow

### 1. Initial Assessment (0-5 min)

```bash
# Check overall status
make status

# Check recent logs
make logs --tail=100 | grep -i error

# Check resource usage
make stats
```

### 2. Declare Incident

```bash
# Create incident channel topic (if using Slack)
# Notify team in #aiw-alerts

# Example: Create incident log
echo "INCIDENT: $(date) - Initial assessment started" >> /opt/aiw-infra/incidents/incident-$(date +%Y%m%d).log
```

### 3. Communicate

Notify stakeholders:
- **P1**: Immediate call to all team members
- **P2**: Message to #aiw-alerts and direct mentions
- **P3**: Log in ticketing system
- **P4**: Add to backlog

## Common Incidents

### WhatsApp Bot Down

**Symptoms**: Messages not being processed

```bash
# 1. Check Evolution API
curl http://localhost:8080/instance/connectionState/hermes-whatsapp

# 2. Check if webhook is reachable
curl -I https://n8n.your-domain.com/webhook/hermes

# 3. Check n8n workflow is active
docker compose exec n8n n8n list:workflows --active

# 4. Restart Evolution if needed
make restart SERVICE=evolution-api
```

### n8n Workflow Not Triggering

**Symptoms**: Webhook fires but no action

```bash
# 1. Check workflow is active
curl -s http://localhost:5678/rest/workflows/907ed14b-ec53-4b3b-aff6-6dda4da496bd \
  | jq '.active'

# 2. Check execution history
curl -s http://localhost:5678/rest/executions \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  | jq '.data[] | {workflowId, status, lastNodeExecuted}'

# 3. Enable verbose logging
export N8N_LOG_LEVEL=debug
make restart SERVICE=n8n
```

### Database Connection Failed

**Symptoms**: n8n showing "No database connection"

```bash
# 1. Check Postgres status
docker compose ps postgres

# 2. Check Postgres logs
docker compose logs postgres --tail=50

# 3. Test connection
docker compose exec n8n wget -qO- http://localhost:5678/healthz

# 4. Restart Postgres if hung
make restart SERVICE=postgres
```

### AI Model Timeout

**Symptoms**: Slow or no AI responses

```bash
# 1. Check model status
curl -s https://api.mistral.ai/v1/models \
  -H "Authorization: Bearer $MISTRAL_API_KEY" | jq '.data[0].status'

# 2. Check Hermes agent logs
tail -100 /var/log/hermes-agent.log | grep -i error

# 3. Switch to fallback model
# Edit /root/.hermes/config.yaml
# Change default_model to a working provider

# 4. Restart Hermes
systemctl restart hermes-agent
```

## Escalation Matrix

| Severity | First Responder | Escalation (15 min) | Escalation (30 min) |
|----------|-----------------|---------------------|---------------------|
| P1 | On-call | Ivan + Jonatan | All team |
| P2 | On-call | Jonatan | Ivan |
| P3 | On-call | Self-resolve | Jonatan if no progress |
| P4 | Next business day | N/A | N/A |

## Recovery Procedures

### Full System Recovery

```bash
# 1. Stop everything
make stop

# 2. Verify database is accessible
docker compose ps postgres

# 3. Start database first
docker compose up -d postgres redis

# 4. Wait for healthy
docker compose ps

# 5. Start application services
docker compose up -d n8n

# 6. Start supporting services
docker compose up -d traefik evolution-api

# 7. Verify all healthy
make status
```

### Data Recovery

```bash
# 1. Stop services to prevent data corruption
make stop

# 2. Restore from latest backup
cd /opt/aiw-infra/backups
./restore.sh n8n-$(date +%Y%m%d).sql

# 3. Verify data integrity
docker compose exec postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;"

# 4. Restart services
make start
```

## Post-Incident

### Required Documentation

1. Timeline of events
2. Root cause analysis
3. Impact assessment
4. Resolution steps
5. Prevention measures

### Template

```markdown
# Incident Report: YYYY-MM-DD

## Summary
Brief description of the incident.

## Timeline
- HH:MM - Event 1
- HH:MM - Event 2

## Root Cause
What caused the incident.

## Resolution
How it was fixed.

## Action Items
- [ ] Prevent recurrence
- [ ] Improve monitoring
- [ ] Update runbooks
```

## Contact Information

| Role | Name | Contact |
|------|------|---------|
| Lead | Ivan Weiss van der Pol | Primary on-call |
| Developer | Jonatan Verdún | Secondary on-call |
| Advisor | John | Consultation |
