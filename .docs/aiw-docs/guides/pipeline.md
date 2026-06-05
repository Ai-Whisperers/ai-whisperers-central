# Pipeline

Technical documentation of the Hermes messaging pipeline.

## Overview

The Hermes pipeline processes incoming WhatsApp messages through n8n workflows:

```
WhatsApp → Evolution API → n8n Webhook → Hermes Agent → Response → WhatsApp
```

## Workflow Structure

**Workflow ID**: `907ed14b-ec53-4b3b-aff6-6dda4da496bd`
**Version**: 23
**Nodes**: 21

### Pipeline Stages

| Stage | Node | Purpose |
|-------|------|---------|
| 1 | Webhook Trigger | Receive incoming messages |
| 2 | Extract & Classify | Parse message, detect intent |
| 3 | Check Mentions | Verify bot is mentioned |
| 4 | Prepare Context | Build conversation context |
| 5 | Hermes Inference | Generate AI response |
| 6 | Format Response | Prepare WhatsApp message |
| 7 | Send Response | Deliver via Evolution API |

## Node Details

### 1. Webhook Trigger

```javascript
// Receives POST from Evolution API
{
  "instance": "hermes-whatsapp",
  "data": {
    "key": {
      "remoteJid": "54911XXXXXXXX@c.us",
      "fromMe": false
    },
    "message": {
      "conversation": "Message text"
    }
  }
}
```

### 2. Extract & Classify

Extracts:
- Sender phone number
- Message content
- Timestamp
- Group or DM context

Classifies intent:
- Direct question
- Command request
- General chat
- Media message

### 3. Check Mentions

Validates bot is addressed:
- `@595991501444` (bot number)
- `@154288881946676` (bot LID)
- `nyx` or `erebus` keyword
- DM (no mention needed)

### 4. Prepare Context

Builds prompt with:
- Conversation history (last 5 messages)
- Team member context
- Language preference
- Intent classification

### 5. Hermes Inference

Sends to Hermes agent:
```javascript
{
  "model": "mistral-small",
  "messages": [
    {"role": "system", "content": systemPrompt},
    {"role": "user", "content": userMessage}
  ]
}
```

### 6. Format Response

Prepares WhatsApp-compatible message:
- Strips markdown for plain text
- Handles mentions
- Formats code blocks
- Truncates if too long

### 7. Send Response

Posts to Evolution API:
```
POST http://evolution_evolution_api:8080/message/sendText/hermes-whatsapp
```

## Database Schema

### workflow_entity

Stores active workflow definitions.

### workflow_history

**Critical**: Caches published nodes. Both `workflow_entity.nodes` AND `workflow_history.nodes` must be updated for changes to take effect.

### execution_entity

Stores workflow execution history.

## Updating the Pipeline

### Via n8n UI

1. Open workflow in n8n
2. Make changes
3. Click **Save** then **Activate**
4. Verify both tables updated:

```sql
-- Check workflow_entity
SELECT updated_at FROM workflow_entity 
WHERE id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';

-- Check workflow_history (must match!)
SELECT updated_at FROM workflow_history 
WHERE workflow_id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';
```

### Via Database (Emergency)

```bash
docker compose exec postgres psql -U n8n -d n8n

-- Update both tables
UPDATE workflow_entity SET nodes = '[...]' WHERE id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';
UPDATE workflow_history SET nodes = '[...]' WHERE workflow_id = '907ed14b-ec53-4b3b-aff6-6dda4da496bd';
```

## Performance Tuning

### Timeout Settings

```yaml
# In n8n environment
N8N_EXECUTIONS_TIMEOUT=120
N8N_EXECUTIONS_TIMEOUT_MAX=300
```

### Concurrent Executions

```yaml
N8N_EXECUTIONS_MODE=regular
N8N_CONCURRENT_WORKFLOWS=5
```

### Caching

```yaml
# Redis cache for repeated queries
REDIS_CACHE_TTL=300
```

## Monitoring

### Key Metrics

| Metric | Target | Alert |
|--------|--------|-------|
| Avg response time | < 10s | > 30s |
| Error rate | < 1% | > 5% |
| Queue depth | < 10 | > 50 |
| Active executions | < 20 | > 50 |

### View Metrics

```bash
# n8n metrics endpoint
curl http://localhost:5678/metrics

# Prometheus format
curl http://localhost:5678/metrics | grep n8n_
```

## Troubleshooting

### Messages Not Processing

1. Check workflow is active
2. Verify webhook URL in Evolution API
3. Check n8n logs for errors

### Slow Responses

1. Check AI model latency
2. Review workflow for bottlenecks
3. Check n8n resource usage

### Double Responses

1. Check for duplicate webhooks
2. Verify workflow isn't triggering twice
3. Check Evolution API settings

## API Reference

### Webhook Payload

```json
{
  "instance": "string",
  "data": {
    "key": {
      "remoteJid": "string",
      "fromMe": boolean
    },
    "message": {},
    "messageTimestamp": "string"
  }
}
```

### Response Format

```json
{
  "number": "54911XXXXXXXX",
  "text": "Response message",
  "options": {
    "delay": 1000
  }
}
```
