# Network Architecture

## Overview

Single unified overlay network for all services to communicate.

```
┌─────────────────────────────────────────────────────────┐
│                   aiw-infra-net                         │
│                   (overlay, attachable)                  │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │  Traefik  │  │    n8n    │  │ LiteLLM  │           │
│  │  (:80/443)│  │           │  │ (+Redis) │           │
│  └─────┬────┘  └─────┬────┘  └────┬────┘           │
│         │              │              │                 │
│  ┌─────┴────┐  ┌──────┴─────┐  ┌───┴────┐          │
│  │Evolution │  │Context API │  │ Hermes  │          │
│  │  (WA)    │  │  (+Qdrant) │  │ (Agent) │          │
│  └──────────┘  └─────────────┘  └─────────┘          │
│         │              │              │               │
│  ┌──────┴──────┐ ┌─────┴─────┐ ┌────┴─────┐          │
│  │  Evolution   │ │  STT/TTS  │ │  Vision  │          │
│  │   Redis     │ │           │ │          │          │
│  └─────────────┘ └───────────┘ └──────────┘          │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │         aiw-pub-net (overlay, attachable)   │       │
│  │    Traefik publishes :80/:443 to internet    │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │      Internet      │
                    └───────────────────┘
```

## Key Principles

1. **Single Network** — All services on `aiw-infra-net`
2. **Internal DNS** — Services reach each other by container name
3. **No `host.docker.internal`** — Everything uses Docker DNS
4. **Overlay Attachable** — New containers can join without restarting swarm

## Service Discovery

Each service is reachable by its container name:

| From | To | URL |
|------|-----|-----|
| n8n | LiteLLM | `http://litellm:4000` |
| n8n | Evolution API | `http://evolution_evolution_api:8080` |
| n8n | Context API | `http://aiw-context-api:3100` |
| n8n | STT | `http://aiw-stt:3300` |
| n8n | TTS | `http://aiw-tts:3500` |
| n8n | Vision | `http://aiw-vision:3400` |
| Hermes | LiteLLM | `http://litellm:4000` |

## External Access (Traefik)

| Service | Domain | Purpose |
|---------|--------|---------|
| n8n | https://n8n.sunstein.cloud | Workflow editor |
| Grafana | https://grafana.sunstein.cloud | Dashboards |
| Evolution API | https://evolution.sunstein.cloud | WhatsApp webhook |
| LiteLLM | https://litellm.sunstein.cloud | API gateway |
| Code Agent | https://code-agent.sunstein.cloud | Hermes API |

## Docker DNS Resolution

Services resolve each other automatically:

```bash
# From any container
$ ping litellm
PING litellm (10.0.X.X) 56(84) bytes of data.

# From host
$ docker exec n8n_n8n curl http://litellm:4000/health
```
