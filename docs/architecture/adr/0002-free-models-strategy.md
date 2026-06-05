# 0002. 100% Free AI Models Strategy

Date: 2026-04-13

## Status

Accepted

## Context

We need a capable AI assistant (Nyx) for the WhatsApp bot without incurring API costs. All paid model calls add up quickly at scale.

## Decision

Use only free-tier AI models from multiple providers with smart model routing based on query complexity.

### Model Tiers

| Tier | Latency | Models (all free) | Use Case |
|------|----------|-------------------|----------|
| Fast | ~40ms | Llama 3.1 8B (Groq, Cerebras, NVIDIA) | Simple messages |
| Primary | ~300ms | Llama 3.3 70B (Groq), Mistral Small, GLM-4 Flash | Code, complex queries |
| Reasoning | ~600ms | GPT-OSS 120B, Nemotron Super, Arcee Trinity (OpenRouter) | Deep analysis |
| Vision | ~500ms | Llama 4 Scout 17B (Groq) | Image understanding |

### Routing Strategy

LiteLLM uses latency-based routing within each tier:
- Fast: Groq > Cerebras > NVIDIA (fastest first)
- Primary: Groq > Mistral > ZAI GLM (by availability)

### Why Not OpenAI/GPT-4o?

- GPT-4o mini costs ~$0.15/1M tokens
- At 1000 users × 50 messages/day × 100 tokens = ~$7,500/month
- Free tier models (Groq, Cerebras, Mistral, OpenRouter) = $0

## Consequences

### Positive
- Zero AI API costs
- Multiple providers = resilience (if one goes down, others work)
- Latency-based routing ensures fastest response

### Negative
- Free tier models have rate limits
- Groq has concurrent request limits
- OpenRouter free models can be slow during peak hours

### Risks
- Groq account suspension (happened with Fireworks) — mitigated by multi-provider fallback
- Model quality varies — must monitor and adjust routing
- No guaranteed SLA on free tiers
