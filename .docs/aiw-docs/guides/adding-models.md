# Adding Models

Guide to adding new AI models to the Hermes agent.

## Model Configuration

### Location

All models are configured in `/root/.hermes/config.yaml`:

```yaml
models:
  model-name:
    provider: provider-name
    api_key: ${ENV_VAR_NAME}
    endpoint: https://api.provider.com/v1
    max_tokens: 32000
    temperature: 0.7
```

## Supported Providers

### OpenAI-Compatible

```yaml
models:
  gpt-4o:
    provider: openai
    api_key: ${OPENAI_API_KEY}
    max_tokens: 128000
    temperature: 0.7
```

### Anthropic

```yaml
models:
  claude-3-sonnet:
    provider: anthropic
    api_key: ${ANTHROPIC_API_KEY}
    max_tokens: 200000
    temperature: 0.7
```

### Groq

```yaml
models:
  groq-llama-3.3-70b:
    provider: groq
    api_key: ${GROQ_API_KEY}
    max_tokens: 8192
    temperature: 0.7
```

### Mistral

```yaml
models:
  mistral-small:
    provider: mistral
    api_key: ${MISTRAL_API_KEY}
    max_tokens: 32000
    temperature: 0.7
```

### Ollama (Local)

```yaml
models:
  llama3:
    provider: ollama
    endpoint: http://localhost:11434
    max_tokens: 4096
    temperature: 0.7
```

## Adding a New Model

### Step 1: Get API Key

```bash
# For cloud providers, get API key from their dashboard
# For local models, ensure Ollama is running
ollama serve
ollama pull llama3
```

### Step 2: Add Environment Variable

```bash
# Add to /opt/aiw-infra/.env
echo "NEW_MODEL_API_KEY=sk-..." >> /opt/aiw-infra/.env
```

### Step 3: Configure Model

```bash
# Edit Hermes config
nano /root/.hermes/config.yaml

# Add under models section:
models:
  new-model:
    provider: provider-name
    api_key: ${NEW_MODEL_API_KEY}
    max_tokens: 32000
    temperature: 0.7
```

### Step 4: Set as Default (Optional)

```yaml
# To use as default for all requests
default_model: new-model
```

### Step 5: Restart Hermes

```bash
# Restart the agent
systemctl restart hermes-agent

# Check logs
tail -50 /var/log/hermes-agent.log | grep -i model
```

### Step 6: Test Model

```bash
# Send test request
curl -X POST http://localhost:8081/inference \
  -H "Content-Type: application/json" \
  -d '{
    "model": "new-model",
    "prompt": "Hello, world!",
    "max_tokens": 100
  }'
```

## Model Tiers

Organize models by capability:

```yaml
model_tiers:
  fast:
    - mistral-small
    - groq-llama-3.3-70b
  
  standard:
    - claude-3-haiku
    - gemini-pro
  
  premium:
    - claude-3-sonnet
    - gpt-4o
```

## Fallback Configuration

Set fallback for when primary model fails:

```yaml
models:
  primary-model:
    provider: mistral
    api_key: ${MISTRAL_API_KEY}
    fallback: groq-llama-3.3-70b
```

## Testing Model Performance

### Latency Test

```bash
#!/bin/bash
MODEL=${1:-mistral-small}

for i in {1..5}; do
  START=$(date +%s%N)
  curl -s -X POST http://localhost:8081/inference \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"Say 'test'\", \"max_tokens\": 10}" \
    > /dev/null
  END=$(date +%s%N)
  echo "Run $i: $(( (END - START) / 1000000 ))ms"
done
```

### Quality Test

```bash
# Run standard prompts through model
for prompt in "Summarize" "Translate" "Code"; do
  curl -s -X POST http://localhost:8081/inference \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$prompt test\"}"
done
```

## Troubleshooting

### Model Not Loading

```bash
# Check API key is set
env | grep API_KEY

# Test direct API access
curl -s https://api.provider.com/models \
  -H "Authorization: Bearer $API_KEY"
```

### Rate Limiting

```bash
# Check rate limit headers
curl -I https://api.provider.com/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

### Context Window Issues

```yaml
# Reduce max_tokens if hitting limits
models:
  large-model:
    max_tokens: 16000  # Half of actual context
```

## Removing a Model

```bash
# 1. Remove from config
nano /root/.hermes/config.yaml

# 2. Remove environment variable
sed -i '/MODEL_API_KEY/d' /opt/aiw-infra/.env

# 3. Restart Hermes
systemctl restart hermes-agent
```
