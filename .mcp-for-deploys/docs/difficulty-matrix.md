# DEPLOY DIFFICULTY MATRIX

Extended **deployment difficulty matrix** including **self-deploy** paths (Windows + Linux nuances, execution-focused):

```
Platform / Method                 | Initial setup | Ongoing ops | Infra control | Debug/prod | Scaling | Cost friction | Overall difficulty
Vercel                            | Very low      | Very low    | Very low      | Low        | Medium  | Low→Medium   | ★☆☆☆☆
Render                            | Low           | Low         | Low→Medium   | Medium     | Medium  | Medium       | ★★☆☆☆
GCP (Cloud Run)                   | Medium→High   | Medium      | High         | High       | Very high | Variable   | ★★★★☆
AWS (ECS/EKS/EC2)                 | High          | High        | Very high    | High       | Very high | Variable   | ★★★★★
Self-deploy: Docker + Linux       | Medium        | Medium      | Very high    | Medium     | High     | Low          | ★★★☆☆
Self-deploy: Docker + WSL2        | Medium→High   | Medium      | Very high    | Medium     | High     | Low          | ★★★★☆
Self-deploy: Bare metal (no Docker)| Medium        | Medium→High | Max          | Medium     | Medium   | Lowest       | ★★★☆☆
```

---

### 1) Dockerization (when, how, and **when to avoid Docker Desktop**)

**Linux (native Docker + docker-compose)**
Best self-deploy baseline.

* Install `docker`, `docker-compose-plugin`
* Run rootless if possible (security + stability)
* Lowest overhead, predictable networking, easy systemd integration

**Windows (WSL2 + Docker Engine inside WSL)**
Recommended over Docker Desktop.

* Install WSL2 (Ubuntu)
* Install Docker **inside WSL**, not Docker Desktop
* Use `docker compose` from WSL shell
  Why avoid Docker Desktop:
* Extra abstraction layer + GUI tax
* Licensing constraints
* Higher RAM/CPU overhead
* Networking edge cases with tunnels and ports

Use Docker Desktop **only if**:

* You need Windows containers
* Corporate environment forces it
* You rely on its GUI for team onboarding

Avoid Docker entirely when:

* Ultra-low latency / HPC / SIMD-heavy workloads
* You want maximal observability with zero abstraction
* You deploy a single binary/service (systemd + reverse proxy is simpler)

---

### 2) Tunnels (public exposure without cloud infra)

#### Cloudflare Tunnel (preferred)

**Why**: stable, free tier, DNS-native, production-grade.

**Core dependency**

* `cloudflared`

**Linux**

```
sudo apt install cloudflared
cloudflared tunnel login
cloudflared tunnel create myapp
cloudflared tunnel route dns myapp app.domain.com
```

* Run as systemd service
* Env vars via `/etc/environment` or service unit

**Windows**

* Install `cloudflared.exe`
* Add to PATH (System Environment Variables)
* Auth opens browser
* Run as scheduled task or service (NSSM recommended)
* Env vars:

  * System Properties → Environment Variables
  * Or PowerShell `$env:VAR="value"`

**Why Cloudflare wins**

* No per-session URLs
* No NAT pain
* TLS handled
* Works cleanly with Docker and bare metal

#### Ngrok

* Faster to demo
* Paid for stability/custom domains
* Session-oriented, less infra-like
  Use for: quick demos, not real prod

#### Tailscale

* Zero-trust private mesh
* Not public by default
  Use for: internal tools, admin panels, P2P clusters

---

### Practical heuristics (execution rules)

* **Fast MVP, public** → Vercel
* **Backend + jobs, low ops** → Render
* **Serverless containers, clean scaling** → GCP Cloud Run
* **Full control, low cost, sovereignty** → Linux + Docker + Cloudflare Tunnel
* **Windows dev, prod-like self-deploy** → WSL2 + Docker (no Desktop) + Cloudflare

