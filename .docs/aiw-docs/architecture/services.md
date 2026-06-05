# Service Dependency Map

## All Running Services

### Core AI Services

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| **n8n** | n8nio/n8n | Workflow orchestration | 5678 |
| **LiteLLM** | ghcr.io/berriai/litellm | Model routing | 4000 |
| **Evolution API** | atendai/evolution-api | WhatsApp Business | 8080 |
| **Evolution Redis** | redis | Cache | - |

### AI Microservices

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| **Context API** | aiw-context-api | Memory, RAG, analytics | 3100 |
| **STT** | aiw-stt | Speech-to-text (Groq Whisper) | 3300 |
| **TTS** | aiw-tts | Text-to-speech (edge-tts) | 3500 |
| **Vision** | aiw-vision | Image understanding (Llama 4) | 3400 |

### Databases

| Service | Image | Purpose |
|---------|-------|---------|
| **PostgreSQL** | postgres:14 | n8n, Hermes, shared |
| **Redis** | redis:7 | LiteLLM cache, conversation memory |
| **Qdrant** | qdrant/qdrant | Vector DB for RAG |

### Monitoring

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| **Prometheus** | prometheus | Metrics collection | 9090 |
| **Grafana** | grafana | Dashboards & alerts | 3000 |
| **Loki** | grafana/loki | Log aggregation | 3100 |
| **cAdvisor** | cadvisor | Container metrics | 8080 |

### Utility Services

| Service | Image | Purpose |
|---------|-------|---------|
| Langfuse | langfuse/langfuse | LLM observability |
| Gitea | gitea/gitea | Git hosting |
| MinIO | minio/minio | Object storage |
| SearXNG | searxng/searxng | Meta search engine |
| Meilisearch | getmeili/meilisearch | Search engine |
| Hoarder | hoarder/hoarder | Bookmark manager |
| Memos | memos/memos | Notes |
| Browserless | browserless/chrome | Headless browser |
| Crawl4AI | unlory/crawl4ai | Web scraper |

## Dependency Graph

```
WhatsApp Message
       │
       ▼
Evolution API ──► n8n Pipeline
       │               │
       │               ▼
       │         LiteLLM ──► Free AI Providers
       │               │
       │               ▼
       │         Context API ──► Redis (memory)
       │               │         Qdrant (vectors)
       │               │         SearXNG (search)
       │               │
       │         STT (audio) ──► Groq Whisper
       │               │
       │         TTS (voice reply) ──► edge-tts
       │               │
       │         Vision (images) ──► Llama 4 Scout
       │
       ▼
   Hermes Agent ──► LiteLLM
                      │
                      ▼
                   PostgreSQL
                   (Hermes state)
```

## Port Map

| Internal Port | Service | External URL |
|--------------|---------|--------------|
| 5678 | n8n | https://n8n.sunstein.cloud |
| 3000 | Grafana | https://grafana.sunstein.cloud |
| 4000 | LiteLLM | https://litellm.sunstein.cloud |
| 8080 | Evolution API | https://evolution.sunstein.cloud |
| 3100 | Context API | - |
| 3300 | STT | - |
| 3400 | Vision | - |
| 3500 | TTS | - |
| 5432 | PostgreSQL | - |
| 6379 | Redis | - |
| 6333 | Qdrant | - |
