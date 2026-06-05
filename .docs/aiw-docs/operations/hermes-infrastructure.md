# Hermes Agent Infrastructure

> **Note:** This document describes the Hermes-based infrastructure. OpenClaw has been deprecated and archived.

## Overview

The AI Whisperers infrastructure uses **Hermes** (aiw-code-agent) as the primary AI agent, running on Docker Swarm with the following components:

- **Hermes Agent** - Java/Quarkus-based code agent for GitHub automation
- **LiteLLM** - Multi-model routing gateway (20+ free providers)
- **Evolution API** - WhatsApp Business connectivity
- **n8n** - Workflow orchestration
- **Context Services** - Vision, STT, TTS, Vector search

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        WhatsApp                              │
│                    (595991501444)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Evolution API v2.3.7                      │
│                   (WhatsApp Gateway)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         n8n                                  │
│              (Workflow Orchestration)                       │
│         Workflow: 907ed14b-ec53-4b3b-aff6-6dda4da496bd     │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │  Hermes   │  │   AIW     │  │  External  │
     │  Agent    │  │  Context  │  │    APIs    │
     │ (Quarkus)│  │    API    │  │            │
     └────────────┘  └────────────┘  └────────────┘
              │               │
              ▼               ▼
     ┌────────────────────────────┐
     │         LiteLLM           │
     │   (Model Router Gateway)  │
     │    20+ Free Providers    │
     └────────────────────────────┘
```

## Services

### Hermes Agent (aiw-code-agent)

| Attribute | Value |
|-----------|-------|
| **Image** | ai-whisperers/code-agent:aiw-dev |
| **Port** | 8080 |
| **Stack** | aiw-code-agent (Docker Swarm) |
| **Database** | pgvector/pgvector:pg16 |

**Features:**
- GitHub PR review automation
- Webhook processing (pull_request, issue_comment)
- Claude AI integration via LiteLLM
- Security issues scanning

**Configuration:**
```bash
ANTHROPIC_BASE_URL=http://litellm:4000
ANTHROPIC_MODEL=primary
ANTHROPIC_FAST_MODEL=fast
GITHUB_TOKEN=ghp_...  # GitHub PAT
```

### LiteLLM Gateway

| Attribute | Value |
|-----------|-------|
| **Image** | ghcr.io/berriai/litellm:main-v1.81.14-stable |
| **Port** | 4000 |
| **Health** | ✅ 20/21 models healthy |

**Supported Providers:**
- Groq (llama-3.3-70b, llama-3.1-8b, llama-4-scout)
- Mistral (mistral-small-latest)
- Cerebras (llama3.1-8b)
- NVIDIA (llama-3.1-8b-instruct)
- OpenRouter (gpt-oss-120b, nemotron-3-super, arcee-trinity)
- OpenAI/GLM (glm-4-flash)
- Gemini (gemini-2.5-flash)

### Evolution API

| Attribute | Value |
|-----------|-------|
| **Image** | evoapicloud/evolution-api:latest |
| **Version** | 2.3.7 |
| **Instance** | hermes-whatsapp |
| **Bot Number** | 595991501444 |

### n8n Workflow Engine

| Attribute | Value |
|-----------|-------|
| **Image** | docker.n8n.io/n8nio/n8n:latest |
| **Port** | 5678 |
| **Pipeline** | Hermes Pipeline v23 |

## Docker Stack

```yaml
# aiw-code-agent/docker-stack.aiw.yml
services:
  app:
    image: ai-whisperers/code-agent:aiw-dev
    env_file: /opt/aiw-code-agent/.env
    environment:
      DATABASE_URL: jdbc:postgresql://aiw-code-agent_postgres:5432/aiw_code_agent
      ANTHROPIC_BASE_URL: http://litellm:4000
    networks:
      - agent-net
      - aiw-infra-net
```

## GitHub Integration

**Status:** ✅ Working

The Hermes agent is successfully:
- Syncing 30 PRs across 2 repos (solstein, Vete)
- Processing GitHub webhooks
- Performing PR reviews

**Monitored Repositories:**
| Repo | Open PRs |
|------|----------|
| Ai-Whisperers/solstein | 16 |
| Ai-Whisperers/Vete | 14 |

## File Locations

| Component | Path |
|-----------|------|
| Hermes Config | `/opt/aiw-code-agent/` |
| LiteLLM Config | `/opt/litellm/config.yaml` |
| Evolution Config | `/opt/aiw-infra/stacks/evolution/` |
| Lobster Workflows | `/opt/aiw-lobster/` |
| n8n Stack | `/opt/n8n/` |

## Archived: OpenClaw

> **OpenClaw has been deprecated.** The old configuration at `/opt/openclaw.old.archived/` is kept for reference only.

### Migration Notes

- OpenClaw gateway → **Hermes Agent** (aiw-code-agent)
- OpenClaw agents (Nyx, Erebus) → **n8n + Evolution API**
- Lobster workflows → Still in use via `/opt/aiw-lobster/`

## Troubleshooting

### GitHub 401 Error
If GitHub API calls fail:
```bash
# Check current token
grep GITHUB_TOKEN /opt/aiw-code-agent/.env

# Token should be a classic PAT (ghp_...)
# Fine-grained tokens (github_pat_...) don't work with git push
```

### LiteLLM Not Responding
```bash
# Check health
curl -H "Authorization: Bearer sk-hermes-litellm-sunstein-2026" \
  http://localhost:4000/health

# Check models
curl -H "Authorization: Bearer sk-hermes-litellm-sunstein-2026" \
  http://localhost:4000/v1/model_list
```

### WhatsApp Disconnected
```bash
# Check Evolution API logs
docker logs evolution_evolution_api.1.b6wek3e10vakwmit4jjj8camy --tail 50
```

## Commands

```bash
# Restart Hermes Agent
docker stack deploy -c /opt/aiw-code-agent/docker-stack.aiw.yml aiw-code-agent

# Check Hermes logs
docker logs aiw-code-agent_app.1.xxx --tail 100

# Check LiteLLM health
curl -H "Authorization: Bearer sk-hermes-litellm-sunstein-2026" \
  http://localhost:4000/health
```
