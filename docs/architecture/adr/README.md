# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the AI Whisperers infrastructure.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | n8n Pipeline Updates via PostgreSQL | Accepted |
| 0002 | 100% Free AI Models Strategy | Accepted |
| 0003 | Docker Swarm over Kubernetes | Accepted |

## What is an ADR?

An ADR is a document describing a significant architectural decision: what changed, why, and what the consequences are. See [ADR template](template.md).

## Creating a New ADR

1. Copy `template.md` to `00XX-title.md`
2. Fill in Context, Decision, Consequences
3. Set Status to "Proposed" and open a PR

## Format

ADRs are numbered sequentially. When an ADR is superseded or deprecated, update its Status field.
