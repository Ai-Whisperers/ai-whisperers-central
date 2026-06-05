# Environment Variables

## LiteLLM

| Variable | Example | Purpose |
|----------|---------|---------|
| `LITELLM_MASTER_KEY` | `sk-...` | Master API key for LiteLLM |
| `GROQ_API_KEY` | `gsk_...` | Groq API key |
| `MISTRAL_API_KEY` | `...` | Mistral API key |
| `CEREBRAS_API_KEY` | `csk-...` | Cerebras API key |
| `NVIDIA_NIM_API_KEY` | `nvapi-...` | NVIDIA NIM API key |
| `OPENROUTER_API_KEY` | `sk-or-...` | OpenRouter API key |
| `ZAI_API_KEY` | `...` | ZAI/GLM API key |
| `GEMINI_API_KEY` | `...` | Google Gemini API key |

## n8n

| Variable | Example | Purpose |
|----------|---------|---------|
| `N8N_ENCRYPTION_KEY` | `a8f2b3c4...` | Encryption key |
| `N8N_API_KEY` | `n8n_api_...` | API access key |
| `DB_POSTGRESDB_PASSWORD` | `n8n_secure_2026` | Database password |
| `WEBHOOK_URL` | `https://n8n.sunstein.cloud` | Base URL |

## Evolution API

| Variable | Example | Purpose |
|----------|---------|---------|
| `EVOLUTION_API_KEY` | `a53c00ff...` | Evolution API key |
| `EVOLUTION_INSTANCE` | `hermes-whatsapp` | Instance name |

## Grafana

| Variable | Example | Purpose |
|----------|---------|---------|
| `GF_SECURITY_ADMIN_PASSWORD` | `admin123` | Admin password |

## Hermes Agent

| Variable | Example | Purpose |
|----------|---------|---------|
| `OPENAI_API_KEY` | `sk-hermes-...` | LiteLLM key for agent |
| `OPENAI_BASE_URL` | `http://127.0.0.1:4000/v1` | LiteLLM endpoint |

## Configuration Files

| File | Purpose |
|------|---------|
| `/opt/litellm/config.yaml` | LiteLLM model routing |
| `/opt/n8n/docker-stack.yml` | n8n environment |
| `/root/.hermes/config.yaml` | Hermes agent config |
| `/opt/aiw-infra/.env.template` | Template for all vars |

## Security Notes

- Never commit `.env` files to git
- Use `.env.template` as template with placeholder values
- Rotate API keys regularly
- Use strong encryption keys (32+ characters)
