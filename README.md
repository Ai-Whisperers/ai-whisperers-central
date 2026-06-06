# AIW Infrastructure

> Infrastructure as Code for the AI Whisperers platform — WhatsApp AI bot (Nyx), model routing, workflow orchestration, and all supporting services. 100% free AI models.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AI Whisperers](https://img.shields.io/badge/Org-Ai--Whisperers-8B5CF6?logo=github)](https://github.com/Ai-Whisperers)

## Overview

This repository manages the complete infrastructure for the AI Whisperers AI platform:

- **Nyx** — WhatsApp AI bot with multi-turn conversation, voice/image understanding, web search, and knowledge base
- **LiteLLM** — Smart model routing across free AI providers (Groq, Mistral, Cerebras, OpenRouter, etc.)
- **n8n** — Workflow orchestration for the Nyx pipeline (v23, 21 nodes)
- **Evolution API** — WhatsApp Business connectivity
- **Hermes** — Java-based code agent accessible via WhatsApp `/hermes` command
- **Monitoring** — Prometheus + Grafana with WhatsApp alerting

All services run on a single 32GB VPS via Docker Swarm with Traefik reverse proxy and automatic SSL.

## Architecture

```
                         ┌──────────────────┐
                         │   Traefik v3     │
                         │   (SSL/HTTPS)    │
                         └────────┬─────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
     ┌────────┴──────┐  ┌────────┴──────┐  ┌────────┴──────┐
     │  Evolution API │  │     n8n       │  │   LiteLLM     │
     │  (WhatsApp)    │  │  (Pipeline)   │  │ (Model Router)│
     └────────┬──────┘  └────────┬──────┘  └────────┬──────┘
              │                   │                   │
              │          ┌────────┼────────┐         │
              │          │        │        │         │
              │   ┌──────┴──┐ ┌──┴───┐ ┌──┴───┐    │
              │   │Context  │ │ STT  │ │ TTS  │    │
              │   │API v6   │ │(Groq)│ │(Edge)│    │
              │   └─────────┘ └──────┘ └──────┘    │
              │          ┌────────┴────────┐         │
              │          │                 │         │
              │   ┌──────┴──┐        ┌─────┴─────┐  │
              │   │ Vision  │        │ Knowledge │  │
              │   │(Llama 4)│        │   Base    │  │
              │   └─────────┘        └───────────┘  │
              │                                      │
              └────────────── WhatsApp ──────────────┘
```

## Repository Structure

```
├── stacks/                    # Docker Swarm/Compose stack files
│   ├── n8n/                   # n8n workflow engine
│   ├── litellm/               # LiteLLM model router
│   ├── evolution/             # Evolution API (WhatsApp)
│   ├── postgres/              # PostgreSQL databases
│   ├── monitoring/            # Prometheus + Grafana
│   └── aiw-code-agent/        # Hermes Java code agent
├── services/                  # Custom AI microservices
│   ├── context-api/           # Memory, RAG, web search, analytics
│   ├── stt/                   # Speech-to-text (Groq Whisper)
│   ├── tts/                   # Text-to-speech (edge-tts)
│   └── vision/                # Image description (Llama 4 Scout)
├── configs/                   # Service configurations
│   ├── litellm-config.yaml    # Model routing config
│   ├── prometheus.yml         # Metrics collection
│   └── grafana-dashboards/    # Monitoring dashboards
├── scripts/                   # Operational scripts
│   ├── deploy.sh              # Stack deployment
│   ├── full-test-suite.sh     # 28-test automated suite
│   ├── health-check.sh        # Infrastructure health audit
│   ├── test-pipeline.sh       # Nyx pipeline tests
│   ├── send-whatsapp-alert.sh # WhatsApp alert sender
│   └── model-eval.sh          # Model evaluation tool
├── docs/                      # Documentation
│   └── architecture/          # Architecture Decision Records
├── .env.template              # Infrastructure env template
├── .code-agent/.env.aiw.example        # Agent env template
├── .code-agent-ui/.env.aiw.example     # Frontend env template
└── deploy.sh                  # Master deployment script
```
The consolidated structure is the current source of truth.

## Quick Start

### Prerequisites

- Docker 24+ with Swarm mode initialized
- Docker Compose v2
- A VPS with 16GB+ RAM recommended
- Domain name pointing to your VPS (for SSL)

### Installation

```bash
git clone https://github.com/Ai-Whisperers/ai-whisperers-central.git
cd ai-whisperers-central
cp .env.template .env          # Edit with your values
```

### Deploy

```bash
./deploy.sh all                 # Deploy all stacks
./deploy.sh monitoring          # Deploy specific stack
```

### Verify

```bash
scripts/health-check.sh        # Full infrastructure audit
scripts/full-test-suite.sh     # Run all 28 tests
```

## Usage

### Common Commands

| Command | Description |
|---------|-------------|
| `./deploy.sh all` | Deploy all stacks |
| `./deploy.sh <stack>` | Deploy a specific stack |
| `scripts/health-check.sh` | Full health audit |
| `scripts/full-test-suite.sh` | Run automated test suite |
| `scripts/test-pipeline.sh` | Test Nyx pipeline |

### Model Tiers (All Free)

| Tier | Models | Use Case | Latency |
|------|--------|----------|---------|
| **Fast** | Llama 3.1 8B (Groq, Cerebras, NVIDIA) | Simple messages | ~40ms |
| **Primary** | Llama 3.3 70B, Mistral Small, GLM-4 Flash | Code, complex queries | ~300ms |
| **Reasoning** | GPT-OSS 120B, Nemotron Super, Arcee Trinity | Deep analysis | ~600ms |
| **Vision** | Llama 4 Scout 17B | Image understanding | ~500ms |

### Environment Variables

See [.env.template](.env.template) for all required variables.

## Monitoring & Operations

- **Grafana:** `https://grafana.sunstein.cloud` (admin/admin123)
- **Prometheus:** Internal only
- **Alerts:** Disk >80%, RAM <4GB, service down → WhatsApp notification
- **Tests:** L1+L2 every 5min, L3 every 30min, full suite daily at 3am

## Documentation

- [Architecture Decision Records](docs/architecture/adr/)
- [n8n Pipeline Update Guide](docs/architecture/adr/0001-n8n-pipeline-updates.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Brief version:

1. Create a feature branch (`feat/my-feature`)
2. Commit with conventional commits (`feat: add X`)
3. Open a Pull Request

## Security

See [SECURITY.md](SECURITY.md). **Never commit secrets.** Use `.env` files (gitignored) for all credentials.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE).

## Team

- **Ivan Weiss van der Pol** — Lead, Founder of AI Whisperers
- **Jonatan Verdún** — Developer
