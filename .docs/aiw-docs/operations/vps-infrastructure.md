# AI Whisperers Infrastructure Report

**Date:** April 13, 2026  
**VPS:** agentzero (72.61.44.159)  
**Tailscale:** 100.91.243.120

---

## Executive Summary

The AI Whisperers infrastructure is running on a single VPS with Docker Swarm. Key components include:
- **Hermes/Code Agent** - GitHub PR review automation (FIXED today - GitHub 401 resolved)
- **AI Services** - Context API, Vision, STT, TTS, LiteLLM
- **WhatsApp Integration** - Evolution API with active connection
- **Full monitoring stack** - Grafana, Prometheus, Loki, Uptime Kuma

---

## Tailscale Network

| Device | IP | OS | Status | Notes |
|--------|----|----|--------|-------|
| agentzero (VPS) | 100.91.243.120 | Linux | Current | Primary server |
| ai-whisperers-server | 100.69.193.50 | Linux | Online | Port 80/443 open, purpose unknown |
| iZt4n7wo7pg57a16w9x87aZ | 100.123.97.41 | Linux | Online | Purpose unknown |
| PC-Ale | 100.110.9.12 | Windows | Online (idle) | Likely Ivan's PC |
| srv1396188 | 100.124.222.54 | Linux | **OFFLINE** | Last seen 23 days ago |

---

## Docker Swarm Services

| Stack | Services | Status |
|-------|----------|--------|
| traefik | 1 | Running |
| portainer | 2 | Running |
| n8n | 1 | Running |
| postgres | 1 | Running |
| evolution | 2 | Running |
| aiw-code-agent | 2 | **Running (FIXED)** |
| vete | 1 | Running |
| gyro | 1 | Running |
| sunstein-website | 1 | Running |

---

## Active Containers (46 total)

### AI Core
| Service | Image | Status | Port |
|---------|-------|--------|------|
| **aiw-code-agent** | ai-whisperers/code-agent:aiw-dev | ✅ Running | 8080 |
| **aiw-context-api** | aiw-context-api:v6 | ✅ Running | - |
| **aiw-vision** | aiw-vision | ✅ Running | - |
| **aiw-stt** | aiw-stt | ✅ Running | - |
| **aiw-tts** | aiw-tts | ✅ Running | - |
| **litellm** | ghcr.io/berriai/litellm:main-v1.81.14-stable | ✅ Running | 4000 |
| **litellm-redis** | redis:7-alpine | ✅ Running | 6379 |
| **qdrant** | qdrant/qdrant | ✅ Running | 6333 |

### Communication
| Service | Image | Status | Port |
|---------|-------|--------|------|
| **n8n** | docker.n8n.io/n8nio/n8n | ✅ Running | 5678 |
| **evolution-api** | evoapicloud/evolution-api | ✅ Running | 8080 |

### Monitoring
| Service | Image | Status | Port |
|---------|-------|--------|------|
| **grafana** | grafana/grafana:11.5.0 | ✅ Running | 3030 |
| **prometheus** | prom/prometheus:v3.1.0 | ✅ Running | 9090 |
| **loki** | grafana/loki:3.7 | ✅ Running | 3100 |
| **cadvisor** | gcr.io/cadvisor/cadvisor | ✅ Running | 8080 |
| **node-exporter** | prom/node-exporter | ✅ Running | 9100 |
| **uptime-kuma** | louislam/uptime-kuma:1 | ✅ Running | 3001 |

### Productivity
| Service | Image | Status | Port |
|---------|-------|--------|------|
| **hoarder** | ghcr.io/hoarder-app/hoarder | ✅ Running | 3000 |
| **excalidraw** | excalidraw/excalidraw | ✅ Running | 80 |
| **gitea** | gitea/gitea | ✅ Running | - |
| **memos** | neosmemo/memos:stable | ✅ Running | 5230 |
| **langfuse** | langfuse/langfuse:2 | ✅ Running | - |

### Infrastructure
| Service | Image | Status | Port |
|---------|-------|--------|------|
| **traefik** | traefik:v3.5.3 | ✅ Running | 80, 443 |
| **portainer** | portainer/portainer-ce | ✅ Running | 8000, 9000, 9443 |
| **postgres** | postgres:14 | ✅ Running | 5432 |
| **vaultwarden** | vaultwarden/server | ✅ Running | 8889 |
| **minio** | minio/minio | ✅ Running | - |

---

## Recent Fixes

### ✅ GitHub 401 Error Fixed (April 13, 2026)
- **Issue:** Code agent was failing with `GitHub get PR failed (HTTP 401)`
- **Root Cause:** Invalid GitHub token in `/opt/aiw-code-agent/.env`
- **Fix:** Updated `GITHUB_TOKEN` to valid PAT
- **Result:** Now successfully syncing 30 PRs across 2 repos (solstein, Vete)

---

## Issues to Address

### Medium Priority
1. **ai-whisperers-server** - Unknown device, ports 80/443 open
2. **iZt4n7wo7pg57a16w9x87aZ** - Unknown device, no ports responding
3. **srv1396188** - Offline for 23 days, may need cleanup

### Low Priority
1. Hermes gateway URL not configured - WhatsApp notification disabled
2. Teams notification config invalid
3. n8n webhook SSRF protection blocking some URLs

---

## Resource Usage

| Resource | Total | Used | Available |
|----------|-------|------|-----------|
| RAM | 31 GB | 10 GB | 21 GB (67%) |
| Disk | 387 GB | 163 GB | 224 GB (43%) |
| Swap | 8 GB | 1.1 GB | 6.9 GB |

---

## GitHub Integration Status

### Repos with PR Cache
| Repo | Open PRs |
|------|----------|
| Ai-Whisperers/solstein | 16 |
| Ai-Whisperers/Vete | 14 |
| **Total** | **30** |

---

## Exposed Ports (Public)

| Port | Service | URL |
|------|---------|-----|
| 80 | Traefik | http://72.61.44.159 |
| 443 | Traefik | https://72.61.44.159 |

## Internal Ports (Tailscale/Docker)

| Port | Service |
|------|---------|
| 4000 | LiteLLM |
| 5678 | n8n |
| 6333 | Qdrant |
| 8080 | Code Agent, Evolution API |
| 9090 | Prometheus |
| 3030 | Grafana |

---

## Next Steps

1. [ ] Document purpose of ai-whisperers-server
2. [ ] Investigate iZt4n7wo7pg57a16w9x87aZ
3. [ ] Clean up srv1396188 or restore
4. [ ] Configure Hermes gateway URL for WhatsApp notifications
5. [ ] Fix Teams notification config

---

*Report generated by opencode*
