# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed (compliance)
- README.md: terminology updated to use generic "messaging" wording in
  product descriptions. The Evolution API integration (upstream OSS
  project name) remains named as such per OSS carve-out.
- `scripts/send-whatsapp-alert.sh` renamed to `scripts/send-alert.sh`
  with EVO_URL instance name updated to `hermes-bridge`.

### Notes
- Historic changelog entries below reference WhatsApp by name because
  they describe the historical product surface; they are not rewritten
  per the project policy of preserving historical accuracy.



## [0.8.0] - 2026-04-13

### Added
- Fix: Nyx WhatsApp DM replies working (`fetch is not defined` in n8n task runner)
- Fix: Group message mention detection for `@Erebus` (WhatsApp LID format)
- Fix: Evolution API internal URL for message sending
- `N8N_RUNNERS_INSECURE_MODE=true` for n8n Code node fetch support
- Switched Nous Hermes Agent default model to `mistral-small`
- Nyx pipeline v23 (21 nodes, all Code-based)
- Full test suite (28 tests, automated via cron)
- Grafana alerting with WhatsApp notifications
- TTS voice replies for audio messages
- Knowledge base expanded to 36 entries
- Hermes Java code agent accessible via `/hermes` WhatsApp command
- Nous Research Hermes Agent v0.8.0 for terminal use
- AI microservices: Context API v6, STT, TTS, Vision
- Monitoring: Prometheus + Grafana + alerting
- Infrastructure as Code repo with 8 commits

### Changed
- Removed Fireworks AI (suspended account)
- LiteLLM config rewritten with no Fireworks models
- All n8n nodes converted to Code nodes (httpRequest expression bug workaround)
- LiteLLM pinned to v1.81.14-stable (v1.82+ drops tool_use arguments)

### Security
- All API keys in `.env` files, never committed
- LiteLLM master key as single gateway

## [0.7.0] - 2026-04-09

### Added
- Phase 4 complete: Full AI infrastructure operational
- Multi-agent classification (general, researcher, coder, teacher)
- Web search integration via Context API
- Voice message transcription via Groq Whisper
- Image understanding via Llama 4 Scout
- Hermes code agent with Java backend

## [0.6.0] - 2026-04-08

### Added
- Phase 2-3: AI pipeline with RAG, knowledge base, context memory
- n8n workflow with LiteLLM integration
- Evolution API v2.3.7 for WhatsApp connectivity
- Context API v6 for memory and knowledge management

## [0.5.0] - 2026-04-07

### Added
- Phase 1: Docker Swarm, monitoring, backup, health checks
- Traefik reverse proxy with automatic SSL
- Prometheus + Grafana monitoring stack
- Automated backup scripts
- Health check infrastructure
