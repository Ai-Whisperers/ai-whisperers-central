# Knowledge Base

Central repository of information for the AI Whisperers team.

## Team Information

### Members

| Name | Role | Responsibilities |
|------|------|------------------|
| Ivan Weiss van der Pol | Lead | Architecture, strategy, final decisions |
| Jonatan Verdún | Developer | Implementation, DevOps, n8n workflows |
| John | Advisor | Senior guidance, quality review |

### Languages

- **Primary**: Spanish
- **Secondary**: Guarani, English
- **Bot responses**: Mix based on user preference

## System Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    WhatsApp (Client)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Evolution API                             │
│                    (WhatsApp Gateway)                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      n8n Platform                            │
│         (Workflow: Hermes Pipeline v23)                     │
│         ID: 907ed14b-ec53-4b3b-aff6-6dda4da496bd            │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │   Hermes   │  │  External  │  │  Response  │
     │   Agent    │  │    APIs    │  │  Formatter │
     └────────────┘  └────────────┘  └────────────┘
```

### Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| n8n | 5678 | Workflow management |
| Traefik | 80, 443 | Reverse proxy, SSL |
| PostgreSQL | 5432 | Data storage |
| Redis | 6379 | Caching |
| Evolution API | 8080 | WhatsApp gateway |

## Operational Knowledge

### Deployment Windows

- **Standard deployments**: Monday-Thursday, 9 AM - 4 PM (PYT)
- **Emergency fixes**: Any time with team notification
- **Major changes**: Friday-Sunday avoided

### On-Call Schedule

| Week | Primary | Secondary |
|------|---------|-----------|
| Week 1 | Ivan | Jonatan |
| Week 2 | Jonatan | Ivan |

### Communication Channels

- **WhatsApp "AI Whisperers" group**: Team discussions
- **Direct messages**: Individual queries
- **GitHub**: Code reviews and issues

## Technical Reference

### Bot Behavior

**Activation Words**:
- `nyx`
- `erebus`
- `@595991501444` (bot number)
- `@154288881946676` (bot LID)

**Response Rules**:
1. Always respond in user's language
2. Mention team member when relevant
3. Use Guarani greetings when appropriate
4. Keep responses concise for WhatsApp

### AI Model Tiers

| Tier | Models | Use Case |
|------|--------|----------|
| Fast | mistral-small, groq-llama-3.3-70b | Quick responses |
| Standard | claude-3-haiku, gemini-pro | General tasks |
| Premium | claude-3-sonnet, gpt-4o | Complex reasoning |

### Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| E001 | Evolution API timeout | Check webhook, restart instance |
| E002 | n8n workflow error | Check workflow logs |
| E003 | AI model unavailable | Switch to fallback |
| E004 | Database connection lost | Restart postgres |
| E005 | Rate limit hit | Wait and retry |

## Procedures

### Adding New Team Member

1. Add phone number to WhatsApp group
2. Update `/opt/aiw-infra/config/team.yml`
3. Set permissions in n8n (if applicable)
4. Notify via group message

### Adding New Model

1. Get API key from provider
2. Add to `/root/.hermes/config.yaml`
3. Test with `make test-models`
4. Update documentation
5. Deploy changes

### Changing Workflow

1. Make changes in n8n UI
2. Test with small dataset
3. Export JSON backup
4. Commit to git
5. Deploy to production

## Troubleshooting Common Issues

### Bot Not Responding

1. Check Evolution API status
2. Verify webhook URL in n8n
3. Check workflow is active
4. Review n8n execution logs

### Slow Responses

1. Check AI model latency
2. Verify network connectivity
3. Check n8n queue depth
4. Review resource usage

### Message Delays

1. Check n8n workflow execution time
2. Verify AI model response time
3. Check Evolution API queue
4. Review WhatsApp rate limits

## Quick Commands

```bash
# Check everything
make status

# View recent errors
make logs | grep -i error | tail -20

# Restart bot pipeline
make restart SERVICE=n8n

# Test WhatsApp connection
curl http://localhost:8080/instance/connectionState/hermes-whatsapp
```

## Links

- [GitHub Organization](https://github.com/Ai-Whisperers)
- [Infrastructure Repo](https://github.com/Ai-Whisperers/aiw-infra)
- [Documentation](https://github.com/Ai-Whisperers/aiw-docs)
