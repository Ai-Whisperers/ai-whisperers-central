# Ports & Endpoints

## External URLs (Traefik)

| URL | Service | Internal Port |
|-----|---------|---------------|
| https://n8n.sunstein.cloud | n8n Editor | 5678 |
| https://grafana.sunstein.cloud | Grafana | 3000 |
| https://litellm.sunstein.cloud | LiteLLM API | 4000 |
| https://evolution.sunstein.cloud | Evolution API | 8080 |
| https://code-agent.sunstein.cloud | Hermes API | 8080 |

## Internal URLs (Docker DNS)

| URL | Service |
|-----|---------|
| http://litellm:4000 | LiteLLM |
| http://evolution_evolution_api:8080 | Evolution API |
| http://aiw-context-api:3100 | Context API |
| http://aiw-stt:3300 | STT |
| http://aiw-tts:3500 | TTS |
| http://aiw-vision:3400 | Vision |

## Webhooks

| URL | Purpose |
|-----|---------|
| https://n8n.sunstein.cloud/webhook/whatsapp-incoming | Nyx pipeline trigger |

## Health Endpoints

| Endpoint | Service |
|----------|---------|
| https://n8n.sunstein.cloud/healthz | n8n |
| http://localhost:4000/health/liveliness | LiteLLM |
| http://evolution_evolution_api:8080/health | Evolution API |

## Databases

| Port | Service |
|------|---------|
| 5432 | PostgreSQL |
| 6379 | Redis (LiteLLM cache) |
| 6333 | Qdrant (Vector DB) |

## SSH

| Host | Port | Purpose |
|------|------|---------|
| vps.sunstein.cloud | 22 | VPS access |
