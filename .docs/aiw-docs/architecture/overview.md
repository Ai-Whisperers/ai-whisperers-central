# System Overview

## High-Level Architecture

```
                         Internet
                              │
                     ┌────────┴────────┐
                     │  Traefik v3     │
                     │  SSL/HTTPS      │
                     └────────┬────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────┴───────┐   ┌────────┴────────┐   ┌──────┴──────┐
│  n8n Pipeline │   │   LiteLLM       │   │ Evolution API│
│  (WhatsApp)   │   │  Model Router   │   │  (WhatsApp)  │
└───────┬───────┘   └────────┬────────┘   └──────┬──────┘
        │                     │                     │
        │            ┌────────┴────────┐           │
        │            │  Free AI Models │           │
        │            │ Groq, Mistral,  │           │
        │            │ Cerebras,       │           │
        │            │ OpenRouter...   │           │
        │            └─────────────────┘           │
        │                                          │
        └──────────── WhatsApp Bot (Nyx) ──────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
        ┌─────┴─────┐ ┌────┴────┐ ┌───────┴──────┐
        │ Context API│ │   STT   │ │     TTS       │
        │ Memory+RAG │ │ (Groq)  │ │   (edge-tts)  │
        └───────────┘ └─────────┘ └───────────────┘
              │
        ┌─────┴─────┐
        │  Vision    │
        │(Llama 4)  │
        └───────────┘
```

## Core Components

### Nyx — WhatsApp AI Bot

The main interface. Accessible via:
- **DM**: Message +595981324569
- **Group**: Mention "nyx", "erebus", or @595991501444 in "Ai Whisperers" group

**Features:**
- Multi-turn conversation (20 messages, 24h TTL)
- Voice messages: transcription + voice reply
- Image understanding with vision AI
- Web search for real-time information
- Knowledge base (36 entries, auto-expanding)
- Multi-agent routing (general, researcher, coder, teacher)
- TTS voice replies

### Hermes — Code Agent

Java-based code agent accessible via:
- **WhatsApp**: `/hermes <question>`
- **Terminal**: SSH → type `hermes`
- **API**: POST https://code-agent.sunstein.cloud/api/chat

**Capabilities:**
- Code generation and debugging
- File operations
- Git operations
- Web research
- Multi-turn conversations

### LiteLLM — Model Router

Single API gateway for all AI models:
- Routes requests to fastest available free model
- Latency-based load balancing
- Automatic retries and fallbacks
- Cost tracking (all free)

### Context API — Memory & RAG

- Conversation memory (Redis)
- Knowledge base (Qdrant vector DB)
- Web search integration (SearXNG)
- Analytics tracking

## Model Tiers

| Tier | Latency | Models | Use Case |
|------|---------|--------|----------|
| **Fast** | ~40ms | Llama 3.1 8B (Groq, Cerebras, NVIDIA) | Simple messages |
| **Primary** | ~300ms | Llama 3.3 70B (Groq), Mistral Small, GLM-4 Flash | Code, complex queries |
| **Reasoning** | ~600ms | GPT-OSS 120B, Nemotron Super, Arcee Trinity | Deep analysis |
| **Vision** | ~500ms | Llama 4 Scout 17B (Groq) | Image understanding |

## Infrastructure

- **Host**: 32GB VPS (8 vCPU EPYC 9354P)
- **OS**: Ubuntu/Linux
- **Orchestration**: Docker Swarm
- **Proxy**: Traefik v3 with automatic SSL
- **Databases**: PostgreSQL 14, Redis, Qdrant (vectors)
- **Monitoring**: Prometheus + Grafana

## Repository Structure

```
aiw-infra/
├── stacks/              # Docker Swarm stacks
│   ├── n8n/            # n8n workflow engine
│   ├── litellm/       # Model router
│   ├── evolution/       # WhatsApp API
│   ├── postgres/       # Databases
│   └── monitoring/     # Prometheus + Grafana
├── services/           # Custom microservices
│   ├── context-api/    # Memory + RAG
│   ├── stt/           # Speech-to-text
│   ├── tts/           # Text-to-speech
│   └── vision/        # Image understanding
├── configs/           # Configurations
│   ├── litellm-config.yaml
│   ├── prometheus.yml
│   └── grafana-dashboards/
├── scripts/           # Operational scripts
│   ├── health-check.sh
│   ├── full-test-suite.sh
│   └── deploy.sh
└── docs/             # Architecture decisions
```
