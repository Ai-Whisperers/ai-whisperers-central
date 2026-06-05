# 0003. Docker Swarm over Kubernetes

Date: 2026-04-07

## Status

Accepted

## Context

We need to run 40+ containers on a single VPS (32GB RAM). We evaluated Docker Swarm, Kubernetes (k3s/minikube), and standalone Docker Compose.

## Decision

Use **Docker Swarm** for container orchestration on the VPS.

### Why Docker Swarm

1. **Single-node simplicity** — Built into Docker, no extra installation
2. **Sufficient for our scale** — 40 containers on one VPS doesn't need k8s scheduling complexity
3. **Traefik native** — Swarm + Traefik works out of the box with labels
4. **No control plane overhead** — k3s lightweight but still adds complexity
5. **Team familiarity** — We know Docker, Swarm adds minimal new concepts

### Why NOT Kubernetes

- k8s is overkill for a single-node VPS
- k3s reduces overhead but adds another moving part
- Ingress controllers, RBAC, Helm charts = more maintenance
- Auto-scaling is irrelevant (single node)

### Why NOT Docker Compose

- Compose doesn't handle service discovery across multiple compose files well
- No rolling updates without额外 tooling
- No built-in load balancing

## Consequences

### Positive
- Native Docker, no extra installation
- Simple `docker stack deploy` for updates
- Built-in service discovery via DNS
- Rolling updates with `docker service update`

### Negative
- No auto-scaling (not needed on single node)
- Less ecosystem tooling than k8s
- Some advanced features (network policies) are Swarm-specific

### Risks
- Single node = single point of failure for container orchestration
- Mitigation: Use PostgreSQL for state, services restart automatically
