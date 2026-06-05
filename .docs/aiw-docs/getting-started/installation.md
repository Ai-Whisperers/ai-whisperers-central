# Installation & Setup

This guide covers setting up the AI Whisperers infrastructure from scratch.

## Prerequisites

- Ubuntu 22.04+ or Debian 12+ server
- Docker Engine 24+ with Docker Compose v2
- At least 4GB RAM (8GB recommended)
- 20GB disk space
- Domain name with DNS access
- Open ports: 80, 443, 3000, 5678, 8080

## Quick Setup

### 1. Clone the Infrastructure Repository

```bash
git clone https://github.com/Ai-Whisperers/aiw-infra.git /opt/aiw-infra
cd /opt/aiw-infra
```

### 2. Environment Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```bash
# Domain Configuration
DOMAIN=your-domain.com
N8N_HOST=n8n.your-domain.com
NYX_HOST=nyx.your-domain.com

# Evolution API
EVOLUTION_API_URL=https://evolution.your-domain.com
EVOLUTION_API_KEY=your-api-key

# Database
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=strong-password-here

# Authentication
WEBHOOK_TOKEN=random-secret-token
NYX_BOT_NUMBER=1234567890
```

### 3. Deploy Core Services

```bash
# Start the complete stack
docker compose up -d

# Or use the Makefile
make deploy
```

### 4. Configure DNS

Add DNS A records pointing to your server:

| Record | Type | Value |
|--------|------|-------|
| n8n | A | YOUR_SERVER_IP |
| nyx | A | YOUR_SERVER_IP |
| evolution | A | YOUR_SERVER_IP |

### 5. Setup SSL (Let's Encrypt)

```bash
# Using the setup script
./scripts/setup-ssl.sh your-email@domain.com

# Or manually with Traefik
docker compose exec traefik certs add --domains n8n.your-domain.com,nyx.your-domain.com
```

## Service Verification

Check that all services are running:

```bash
make status
# or
docker compose ps
```

Expected services:
- **n8n** - Automation platform (port 5678)
- **traefik** - Reverse proxy (ports 80, 443)
- **postgres** - Database (port 5432)
- **redis** - Cache (port 6379)
- **evolution-api** - WhatsApp API (port 8080)

## First Login

### n8n Dashboard

1. Navigate to `https://n8n.your-domain.com`
2. Create admin account on first访问
3. Import workflows from `/opt/aiw-infra/workflows/`

### Evolution API

1. Navigate to `https://evolution.your-domain.com`
2. Login with admin credentials
3. Configure WhatsApp business account

## Troubleshooting

### Port Already in Use

```bash
# Check what's using port 80/443
sudo netstat -tlnp | grep -E ':(80|443)'
# or
sudo lsof -i :80
```

### Database Connection Failed

```bash
# Check postgres logs
docker compose logs postgres

# Verify credentials in .env match
docker compose exec postgres psql -U n8n -d n8n -c "SELECT 1"
```

### Docker Network Issues

```bash
# Recreate networks
docker compose down --remove-orphans
docker network prune -f
docker compose up -d
```

## Next Steps

- [Quick Start Guide](/getting-started/quick-start.md) - Get up and running
- [First Steps](/getting-started/first-steps.md) - Configure your first workflow
