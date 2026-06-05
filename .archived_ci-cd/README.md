# ci-cd — Ai-Whisperers Centralized CI/CD

**Single source of truth for all client site deployments.**  
Update a workflow here once → auto-synced to all client repos.

## Structure

```
.github/workflows/
  ci-nextjs.yml          — Reusable: lint + typecheck + test + build (Next.js)
  ci-python.yml          — Reusable: ruff + pytest + typecheck (Python)
  deploy-vps.yml         — Reusable: build on runner + SCP Docker to VPS
  deploy-vps-git-pull.yml — Reusable: git pull on VPS + build
  security-scan.yml      — Reusable: trufflehog + npm audit
  governance.yml         — Reusable: org policy checks (verify-information, no-inventions, validation-before-completion, no-unnecessary-updates)
  sync-workflows.yml     — Push latest workflows to all client repos on push

scripts/
  deploy.sh              — VPS-side: clone → docker build → service update
  deploy-git-pull.sh     — VPS-side: git pull → npm build → stack deploy
  setup-vps.sh           — Run once on VPS to install deploy scripts
  sync-workflows.js      — GH API: push workflows to all client repos

templates/
  Dockerfile.nextjs      — Standard Next.js multi-stage Dockerfile
  docker-compose.yml     — Standard Docker Compose with healthcheck

clients.json             — Registry of all client sites and their configs
```

## How It Works

1. **Each client repo** adds ONE file: `.github/workflows/deploy.yml`
2. That file calls the reusable workflows in this repo
3. When you update a workflow here, push to main → `sync-workflows` propagates it
4. No more copy-pasting deploy scripts across 24 repos

## Required Org Secrets

Set these in `Ai-Whisperers` org settings → Secrets and variables → Actions:

| Secret | Purpose |
|--------|---------|
| `VPS_HOST` | VPS IP (72.61.44.159) |
| `VPS_USER` | SSH user (root) |
| `VPS_KEY` | SSH private key |
| `SUPABASE_URL` | Shared Supabase URL |
| `SUPABASE_ANON_KEY` | Shared Supabase anon key |

## Client Registration

Every client site must be added to `clients.json` with:
- `site` — Docker service/image name
- `repo` — GitHub repo path
- `url` — Live site URL
- `type` — `nextjs` or `python`
- `pm` — `npm` or `pnpm`
- `node` — Node.js version
- `docker_image` — Docker image tag
- `docker_service` — Docker Swarm service name
- `deploy_strategy` — `build-and-scp` or `git-pull`
