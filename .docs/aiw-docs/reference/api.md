# API Reference

API endpoints for AI Whisperers services.

## n8n REST API

Base URL: `http://localhost:5678`

### Authentication

Set `X-N8N-API-KEY` header with your API key.

### Workflows

#### List All Workflows

```http
GET /rest/workflows
```

Response:
```json
{
  "data": [
    {
      "id": "907ed14b-ec53-4b3b-aff6-6dda4da496bd",
      "name": "Hermes Pipeline",
      "active": true,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### Get Workflow

```http
GET /rest/workflows/{id}
```

#### Create Workflow

```http
POST /rest/workflows
Content-Type: application/json

{
  "name": "New Workflow",
  "nodes": [...],
  "connections": {...}
}
```

#### Update Workflow

```http
PUT /rest/workflows/{id}
Content-Type: application/json

{
  "name": "Updated Workflow",
  "nodes": [...],
  "active": true
}
```

#### Activate/Deactivate

```http
POST /rest/workflows/{id}/activate
POST /rest/workflows/{id}/deactivate
```

### Executions

#### List Executions

```http
GET /rest/executions?limit=20&workflowId={id}
```

#### Get Execution

```http
GET /rest/executions/{id}
```

#### Retry Execution

```http
POST /rest/executions/{id}/retry
```

### Webhooks

#### Manual Trigger

```http
POST /webhook/{webhookKey}
Content-Type: application/json

{
  "test": true
}
```

## Evolution API

Base URL: `http://localhost:8080`

### Instance Management

#### Get Connection State

```http
GET /instance/connectionState/{instanceName}
```

Response:
```json
{
  "instance": "hermes-whatsapp",
  "state": "open"
}
```

#### QR Code

```http
GET /instance/connect/{instanceName}
```

### Send Messages

#### Send Text

```http
POST /message/sendText/{instanceName}
Content-Type: application/json

{
  "number": "54911XXXXXXXX",
  "text": "Hello from Hermes!"
}
```

#### Send Image

```http
POST /message/sendImage/{instanceName}
Content-Type: application/json

{
  "number": "54911XXXXXXXX",
  "image": "https://example.com/image.jpg",
  "caption": "Image description"
}
```

#### Send Audio

```http
POST /message/sendPtt/{instanceName}
Content-Type: application/json

{
  "number": "54911XXXXXXXX",
  "audio": "https://example.com/audio.ogg"
}
```

### Group Management

#### Send Group Message

```http
POST /message/sendText/{instanceName}
Content-Type: application/json

{
  "number": "120363XXXXX@g.us",
  "text": "Group message"
}
```

#### Group Participants

```http
GET /group/participants/{groupId}
```

## Hermes Agent API

Base URL: `http://localhost:8081`

### Inference

#### Generate Response

```http
POST /inference
Content-Type: application/json

{
  "model": "mistral-small",
  "messages": [
    {"role": "system", "content": "You are Nyx..."},
    {"role": "user", "content": "Hello!"}
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

Response:
```json
{
  "model": "mistral-small",
  "content": "Hello! How can I help?",
  "usage": {
    "prompt_tokens": 100,
    "completion_tokens": 50
  }
}
```

### Models

#### List Available Models

```http
GET /models
```

Response:
```json
{
  "models": [
    {"name": "mistral-small", "status": "available"},
    {"name": "groq-llama-3.3-70b", "status": "available"}
  ]
}
```

#### Health Check

```http
GET /health
```

## PostgreSQL

Connection: `postgresql://n8n:n8n@localhost:5432/n8n`

### Key Tables

#### workflow_entity

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | VARCHAR | Workflow name |
| nodes | JSONB | Node definitions |
| connections | JSONB | Connection definitions |
| active | BOOLEAN | Is active |
| created_at | TIMESTAMP | Creation time |
| updated_at | TIMESTAMP | Last update |

#### workflow_history

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| workflow_id | UUID | FK to workflow_entity |
| nodes | JSONB | Published nodes (cache!) |
| version_id | VARCHAR | Version identifier |

#### execution_entity

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| workflow_id | UUID | FK to workflow |
| status | VARCHAR | finished/running/error |
| started_at | TIMESTAMP | Start time |
| finished_at | TIMESTAMP | End time |

## Redis

Connection: `redis://localhost:6379`

### Keys

| Pattern | Type | Description |
|---------|------|-------------|
| `n8n:cache:*` | String | n8n cache data |
| `workflow:*` | Hash | Workflow metadata |
| `session:*` | Hash | User session data |
| `rate:*` | String | Rate limit counters |

### Commands

```bash
# Check rate limits
redis-cli GET rate:54911XXXXXXXX

# Clear session cache
redis-cli DEL session:54911XXXXXXXX

# View cache stats
redis-cli INFO stats | grep -E "(keyspace_hits|keyspace_misses)"
```

## Docker

### Socket

`/var/run/docker.sock`

### CLI Examples

```bash
# List containers
curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json

# Container stats
curl -s --unix-socket /var/run/docker.sock http://localhost/containers/n8n/stats
```
