# Quick Start

Get your AI Whisperers infrastructure running in 5 minutes.

## One-Command Deploy

If you already have the infrastructure cloned:

```bash
cd /opt/aiw-infra
cp .env.example .env
# Edit .env with your values
make deploy
```

## Verify Services

Check all services are healthy:

```bash
make status
```

Output should show all services as `healthy` or `running`.

## Test the Pipeline

### Send a Test Message

1. Open WhatsApp on your phone
2. Send a message to your bot number
3. You should receive an automatic greeting

### Check n8n Workflows

```bash
# View recent workflow executions
curl -s http://localhost:5678/rest/workflows \
  -H "X-N8N-API-KEY: $N8N_API_KEY" | jq '.data[] | {name, active, lastExecution}'
```

### Monitor Logs

```bash
# Watch n8n logs
make logs-n8n

# Watch all services
make logs
```

## Common Quick Tasks

### Restart a Service

```bash
make restart SERVICE=n8n
```

### Access Container Shell

```bash
make shell SERVICE=n8n
```

### View Resource Usage

```bash
make stats
```

### Update Infrastructure

```bash
cd /opt/aiw-infra
git pull
make deploy
```

## Default Credentials

| Service | Default User | Password Location |
|---------|--------------|-------------------|
| n8n | (you set on first login) | - |
| Traefik Dashboard | admin | `/opt/aiw-infra/traefik/traefik.yml` |
| Evolution API | admin | Environment variable |

## Emergency Contacts

- **Ivan Weiss van der Pol** - Lead Developer
- **Jonatan Verdún** - Developer
- **John** - Senior Advisor

## Next Steps

- [First Steps](/getting-started/first-steps.md) - Configure workflows
- [Using Nyx](/guides/using-nyx.md) - Bot interaction guide
- [Health Monitoring](/operations/health-monitoring.md) - Keep services healthy
