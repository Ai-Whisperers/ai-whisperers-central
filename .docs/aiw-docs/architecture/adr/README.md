# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the AI Whisperers platform.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-n8n-pipeline-updates.md) | n8n Pipeline Updates via PostgreSQL | Accepted | 2026-04-13 |
| [0002](0002-free-models-strategy.md) | 100% Free AI Models Strategy | Accepted | 2026-04-13 |
| [0003](0003-docker-swarm-over-k8s.md) | Docker Swarm over Kubernetes | Accepted | 2026-04-07 |

## What is an ADR?

An ADR is a document describing a significant architectural decision: what changed, why, and what the consequences are.

## Format

Each ADR includes:
- **Date**: When the decision was made
- **Status**: Proposed, Accepted, Deprecated, or Superseded
- **Context**: The problem or situation that motivated the decision
- **Decision**: The actual change or approach chosen
- **Consequences**: What became easier or more difficult

## Creating a New ADR

1. Copy `template.md` to `00XX-title-lowercase.md`
2. Fill in Context, Decision, Consequences
3. Set Status to "Proposed" and open a PR

## Example

```markdown
# 0004. Use PostgreSQL for Workflow Storage

Date: 2026-04-15

## Status

Proposed

## Context

We need to store workflow definitions in a way that allows:
- Version control
- Easy programmatic updates
- Rollback capability

## Decision

Store workflow definitions in PostgreSQL alongside n8n's existing data.

## Consequences

### Positive
- Single database to manage
- Transactional updates

### Negative
- Schema coupling to n8n version
```
