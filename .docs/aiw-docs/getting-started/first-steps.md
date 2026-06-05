# First Steps

Configure your AI Whisperers infrastructure after initial setup.

## 1. Configure WhatsApp Bot

### Connect Evolution API

1. Navigate to Evolution API dashboard
2. Go to **Instances** → **Create Instance**
3. Select **WhatsApp Business** type
4. Link your WhatsApp number via QR code

### Configure Bot Settings

In n8n, edit the Hermes workflow with your settings:

```
Workflow: 907ed14b-ec53-4b3b-aff6-6dda4da496bd
Nodes: Extract & Classify, Prepare Response
```

Update these values:
- Bot number ( BUSINESS_BOT_NUMBER)
- Team member names
- Response language preferences

## 2. Import Workflows

### Standard Workflows

1. Open n8n at `https://n8n.your-domain.com`
2. Go to **Workflows** → **Import from JSON**
3. Import files from `/opt/aiw-infra/workflows/`

### Critical Workflows

| Workflow | Purpose | ID |
|----------|---------|-----|
| Hermes Pipeline | Main WhatsApp processing | `907ed14b-ec53-4b3b-aff6-6dda4da496bd` |
| Cron Scheduler | Scheduled tasks | Check n8n |
| Notification Alerts | System alerts | Check n8n |

## 3. Configure AI Models

### Set Default Model

Edit `/root/.hermes/config.yaml`:

```yaml
default_model: mistral-small
models:
  mistral-small:
    provider: mistral
    api_key: ${MISTRAL_API_KEY}
    max_tokens: 32000
```

### Test Model Connection

```bash
# SSH to server
cd /opt/aiw-infra

# Test API key
make test-models
```

## 4. Setup Monitoring

### Configure Alerts

1. Open `/opt/aiw-infra/monitoring/alertmanager.yml`
2. Add your notification endpoints:
   - Email
   - Slack
   - PagerDuty

### Enable Health Checks

```bash
# Start health monitor
cd /opt/aiw-infra
make health-monitor
```

## 5. Team Setup

### Add Team Members

Edit `/opt/aiw-infra/config/team.yml`:

```yaml
team:
  - name: "Ivan Weiss van der Pol"
    role: lead
    phone: "+595XXXXXXXX"
    permissions: [admin, deploy, config]
  
  - name: "Jonatan Verdún"
    role: developer
    phone: "+595XXXXXXXX"
    permissions: [deploy, config]
```

### Set Permissions

| Role | Permissions |
|------|-------------|
| lead | Full access |
| developer | Deploy, config, logs |
| advisor | Read-only |

## 6. First Workflow Test

```bash
# Send test message via API
curl -X POST https://n8n.your-domain.com/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": true, "from": "+595XXXXXXXX"}'
```

Check logs:
```bash
make logs-n8n | tail -50
```

## Troubleshooting First Setup

### Bot Not Responding

1. Check Evolution API instance is connected
2. Verify webhook URL in n8n workflow
3. Check n8n workflow is activated

### AI Model Not Working

1. Verify API key in `.env`
2. Check model endpoint is accessible
3. Review `/var/log/hermes-agent.log`

## Next Steps

- [Using Nyx](/guides/using-nyx.md) - Full bot usage guide
- [Hermes Agent](/guides/hermes-agent.md) - Code agent configuration
- [Deployment](/operations/deployment.md) - Deployment best practices
