# Hermes Code Agent

## Overview

Hermes is a Java-based code agent that can write, debug, and explain code. It has access to:
- Code graph analysis
- Knowledge base
- Semantic search
- Customer context
- Conversation history

## Access Methods

### 1. WhatsApp
Send `/hermes <your question>` to Nyx.

Example:
```
/hermes write a Python function to calculate fibonacci
/hermes explain this code: const x = () => {}
/hermes fix this bug: for(i=0;i<10;i++) {
```

### 2. Terminal
SSH to VPS and type `hermes`:

```bash
ssh root@vps.sunstein.cloud
hermes
```

This opens an interactive TUI where you can:
- Multi-line editing
- Command history (up/down arrows)
- Interrupt and redirect mid-conversation
- Stream tool output

### 3. API
Direct HTTP access:

```bash
curl -X POST https://code-agent.sunstein.cloud/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "write hello world in python"}'
```

For streaming:
```bash
curl -N -X POST https://code-agent.sunstein.cloud/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "write hello world"}'
```

## Configuration

| Setting | Value |
|---------|-------|
| Model | `mistral-small` (primary), `groq-llama-3.3-70b` (fallback) |
| Provider | LiteLLM (free models) |
| Thinking | Disabled (free model compatibility) |
| Max turns | 50 |
| Tool use | Auto |

Config file: `/root/.hermes/config.yaml`

## Tools Available

Hermes can:
- Read/write files
- Execute shell commands
- Search the web
- Analyze code structure
- Run tests
- Git operations
- Deploy applications

## Troubleshooting

### "Failed to call a function" error
Usually a Groq-side issue. Hermes automatically retries with fallback models.

### Agent not responding
Check if Hermes is running:
```bash
ps aux | grep hermes
```

Restart if needed:
```bash
kill <pid>
cd /root/.hermes
nohup ./hermes-agent/venv/bin/hermes > /var/log/hermes-agent.log 2>&1 &
```
