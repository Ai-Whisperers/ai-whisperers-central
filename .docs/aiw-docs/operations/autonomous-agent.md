# AI Whisperers - Autonomous Agent Guide

## Overview

This guide enables autonomous operation for managing AI Whisperers infrastructure.

## Quick Start

### Access Tools

| Tool | Command | Purpose |
|------|---------|---------|
| GitHub CLI | `gh` | Manage repos, issues, PRs |
| SSH | `ssh vps-sunstein` | Access VPS |
| Docker | `docker` | Container management |

### Essential Commands

```bash
# List all repos
gh repo list Ai-Whisperers

# View repo details
gh repo view Ai-Whisperers/aiw-infra

# Create issue
gh issue create --title "Bug found" --body "Description"

# SSH to VPS
ssh vps-sunstein
```

## VPS Management

### Service Control
```bash
ssh vps-sunstein
docker stack ls                    # List services
docker ps                         # Running containers
make status                        # Service status
make restart SERVICE=n8n          # Restart service
```

### Health Checks
```bash
ssh vps-sunstein "docker stats --no-stream"
ssh vps-sunstein "curl localhost:4000/health"
ssh vps-sunstein "curl localhost:5678/healthz"
```

## GitHub Operations

### Repo Workflow
```bash
# Clone/create repo
gh repo clone Ai-Whisperers/aiw-docs
cd aiw-docs

# Make changes
git add . && git commit -m "feat: add feature"

# Push and create PR
git push
gh pr create --title "Feature" --body "Description"
```

### Issue Management
```bash
# List issues
gh issue list

# Close issue
gh issue close <number> --comment "Fixed"

# Add labels
gh issue edit <number> --add-label bug
```

## Deployment

### Standard Deploy
```bash
# 1. Make changes in repo
cd /opt/aiw-infra
git pull

# 2. Deploy
make deploy

# 3. Verify
make status
make logs
```

### Rollback
```bash
# Rollback to previous commit
git revert HEAD
make deploy
```

## Documentation

### Update Docs
```bash
cd ~/.aiw/repos/aiw-docs
# Edit markdown files
git add . && git commit -m "docs: update"
git push
```

### View Docs
- https://github.com/Ai-Whisperers/aiw-docs

## Common Tasks

### Fix GitHub Token Issue
```bash
ssh vps-sunstein
# Edit /opt/aiw-code-agent/.env
# Update GITHUB_TOKEN
docker stack deploy -c /opt/aiw-code-agent/docker-stack.aiw.yml aiw-code-agent
```

### Check WhatsApp Pipeline
```bash
ssh vps-sunstein
docker exec postgres_postgres.1.* psql -U n8n -d n8n -c "SELECT * FROM execution_entity ORDER BY startedAt DESC LIMIT 5;"
```

### LiteLLM Health
```bash
ssh vps-sunstein
curl -H "Authorization: Bearer sk-hermes-litellm-sunstein-2026" http://localhost:4000/health
```

## Tailscale Network

| Device | Tailscale IP | Purpose |
|--------|--------------|---------|
| agentzero | 100.91.243.120 | Primary VPS |
| PC-Ale | 100.110.9.12 | Ivan's PC |

Manage at: https://login.tailscale.com/admin/machines

## Security Notes

- GitHub PAT: Stored in memory, not written to disk
- VPS SSH: Key-based auth only
- Secrets: Use environment variables

## Emergency Contacts

| Name | Role |
|------|------|
| Ivan Weiss van der Pol | Lead |
| Jonatan Verdún | Developer |
