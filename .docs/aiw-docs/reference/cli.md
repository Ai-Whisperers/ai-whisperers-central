# CLI Commands

Command-line tools for managing AI Whisperers infrastructure.

## Makefile Commands

All commands run from `/opt/aiw-infra`:

### Service Management

```bash
# Start all services
make start

# Stop all services
make stop

# Restart all services
make restart

# Deploy (pull + restart)
make deploy

# Full redeploy
make redeploy
```

### Individual Service Control

```bash
make restart SERVICE=n8n
make restart SERVICE=postgres
make restart SERVICE=redis
make restart SERVICE=traefik
make restart SERVICE=evolution-api
```

### Status & Logs

```bash
# Check service status
make status

# View all logs
make logs

# View specific service logs
make logs-n8n
make logs-postgres
make logs-redis

# Follow logs in real-time
make logs-follow

# Resource usage
make stats
```

### Database

```bash
# Connect to database
make db-connect

# Backup database
make backup-db

# Restore database
make restore-db FILE=backups/n8n-20240101.sql

# Run migrations
make db-migrate
```

### Development

```bash
# Run tests
make test

# Run linters
make lint

# Format code
make format

# Build images
make build
```

### Maintenance

```bash
# Clean up resources
make clean

# Prune Docker resources
make prune

# Update dependencies
make update

# Health check
make health
```

## Docker Compose Commands

### Direct Commands

```bash
# Start specific service
docker compose up -d n8n

# Stop specific service
docker compose stop n8n

# View service logs
docker compose logs -f n8n

# Rebuild service
docker compose up -d --build n8n

# Scale service
docker compose up -d --scale n8n=2
```

### Service Management

```bash
# List all containers
docker compose ps

# List all images
docker compose images

# View service config
docker compose config

# Pull latest images
docker compose pull
```

## System Commands

### Hermes Agent

```bash
# Check status
systemctl status hermes-agent

# Restart
systemctl restart hermes-agent

# View logs
journalctl -u hermes-agent -f

# Reload config
systemctl reload hermes-agent
```

### Cron Jobs

```bash
# List current crontab
crontab -l

# Edit crontab
crontab -e

# Common backup cron
0 */6 * * * /opt/aiw-infra/scripts/backup.sh
```

## Git Commands

```bash
cd /opt/aiw-infra

# Check status
git status

# View changes
git diff

# Pull updates
git pull origin main

# Create backup branch
git checkout -b backup/$(date +%Y%m%d)

# View history
git log --oneline -20
```

## n8n CLI

```bash
# Execute workflow manually
docker compose exec n8n n8n execute --id WORKFLOW_ID

# Export workflow
docker compose exec n8n n8n export:workflow --id WORKFLOW_ID

# Import workflow
docker compose exec n8n n8n import:workflow --input=workflow.json
```

## Health Checks

```bash
# Check all endpoints
curl -f http://localhost:5678/healthz
curl -f http://localhost:8080/instance/connectionState/hermes-whatsapp
curl -f http://localhost:6379/

# Full health check script
/opt/aiw-infra/scripts/health-check.sh
```

## Troubleshooting Commands

```bash
# Check port usage
sudo netstat -tlnp | grep -E ':(80|443|5678|8080)'

# Check DNS resolution
dig n8n.your-domain.com

# Test internal connectivity
docker compose exec n8n wget -qO- http://postgres:5432

# Check disk space
df -h

# Check memory
free -h

# Container resource usage
docker stats --no-stream
```

## Quick Reference

| Task | Command |
|------|---------|
| Restart n8n | `make restart SERVICE=n8n` |
| View logs | `make logs-n8n` |
| Check status | `make status` |
| Backup DB | `make backup-db` |
| SSH to container | `make shell SERVICE=n8n` |
| Update infrastructure | `git pull && make deploy` |
| Restart bot | `systemctl restart hermes-agent` |
