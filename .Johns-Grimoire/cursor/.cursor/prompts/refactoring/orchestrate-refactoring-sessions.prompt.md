---
name: orchestrate-refactoring-sessions
description: "Please orchestrate the next refactoring sessions by selecting the right refactoring actions and ordering them into a safe, test-first roadmap"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, orchestration, roadmap, architecture, coupling, dependency-rules, sessions
argument-hint: "Scope + goals + constraints (e.g., \"no breaking changes\") + hotspots"
---

# Orchestrate refactoring sessions

Please use this prompt as the **entrypoint** after you’ve already improved CC/CRAP and have strong unit test coverage.

**Pattern**: Orchestration / Roadmap Planning Pattern ⭐⭐⭐⭐  
**Use when**: You need to decide what to refactor next, in what order, without big-bang rewrites.

The output must be a **session plan** that calls into the more specific refactoring prompts (usually **one action prompt per session**).

---

## Purpose

Help the agent:
- Choose which refactoring actions matter most **next**
- Sequence work so each session is safe and compounding
- Define entry/exit criteria per session (tests + metrics + architecture rules)

---

## Required context (provide in the request)

- **Scope**: which projects/folders/features are in scope
- **Primary goals** (pick 1–3):
  - Reduce coupling / break cycles
  - Clarify module boundaries / ownership
  - Stabilize and shrink public API surface
  - Make business rules explicit (replace branchy logic)
  - Improve determinism/test seams
  - Improve diagrams/docs at the right level
- **Constraints**:
  - Breaking changes allowed? (yes/no)
  - Performance constraints
  - Timeline (e.g., “3 sessions”)
- **Hotspots**:
  - Top 3–10 areas by pain/complexity/churn (if known)

---

## Available action prompts (the orchestrator must reference these)

- `refactoring/refactor-dependency-direction-and-cycles.prompt.md`
- `refactoring/refactor-module-boundaries-and-ownership.prompt.md`
- `refactoring/refactor-public-api-surface.prompt.md`
- `refactoring/refactor-branchy-logic-into-models.prompt.md`
- `refactoring/refactor-determinism-and-test-seams.prompt.md`
- `unit-testing/architecture-unit-tests.prompt.md`
- `documentation/documentation-levels-and-mermaid-diagrams.prompt.md`

---

## Instructions to the agent

### 1) Establish assumptions (only if needed)
If the request lacks details, make **explicit assumptions** (kept minimal) and proceed. Do not ask follow-up questions; instead, produce a plan with assumptions and “validation-first” entry criteria.

### 2) Choose the number of sessions
Propose **3–8 sessions**, constrained by the provided timeline. If the user requests “N sessions”, propose exactly **N** unless there is a safety reason to split a session (in that case: keep the same total by merging low-risk work).

### 3) Select actions and sequence them safely
- Prefer steps that **unlock** later steps (test seams, dependency direction) before steps that **reshape** the system (API surface, boundaries).
- Default ordering when unsure:
  1) Dependency direction/cycles → 2) Architecture tests → 3) Boundaries → 4) API surface → 5) Models → 6) Seams → 7) Diagrams/docs
- Avoid big-bang rewrites; prefer incremental “strangler” migrations.

### 4) Define per-session contracts
Each session must include:
- **Name**
- **Goal** (1 sentence)
- **Why now** (1–3 bullets; risk reduction / unlocking / dependency)
- **Run**: exactly which action prompt(s) to run (usually **one**); include scope hints
- **Entry criteria** (what must be true before starting)
- **Exit criteria** (what “done” means)
- **Validation**: tests, architecture tests, and metrics checks (only those relevant and available)

### 5) Guardrails
- Don’t propose “refactor everything” sessions.
- Keep each session small enough to complete and validate.
- Prefer changes that reduce coupling and increase testability **without** changing externally-visible behavior (unless breaking changes are allowed).

---

## Expected output

```markdown
## Refactoring session roadmap (next sessions)

### Assumptions (only if needed)
- ...

### Session 1 — <name>
- Goal: <one sentence>
- Why now:
  - <bullet>
- Run:
  - @refactor-dependency-direction-and-cycles (scope: ...)
- Entry criteria:
- Exit criteria:
- Validation:
  - Tests:
  - Architecture tests:
  - Metrics:

### Session 2 — <name>
...
```

---

## Usage examples

### Example 1: 3 sessions, no breaking changes

```
@orchestrate-refactoring-sessions
Scope: src/ + tst/ in eneve.domain
Primary goals: Reduce coupling / break cycles; Clarify module boundaries / ownership
Constraints: Breaking changes allowed? no; Timeline: 3 sessions
Hotspots: services, repositories, complex orchestration classes
```

### Example 2: 6 sessions, focus on public API surface + branchy logic

```
@orchestrate-refactoring-sessions
Scope: src/Services/ + src/Extensions/
Primary goals: Stabilize and shrink public API surface; Make business rules explicit (replace branchy logic)
Constraints: Breaking changes allowed? yes (minor); Timeline: 6 sessions
Hotspots: “god service” classes; complex switch/if chains; shared static helpers
```

---

## Validation checklist (for the orchestrator output)
- [ ] Sessions count matches the requested timeline (or is justified by safety)
- [ ] Each session references at least one action prompt from the list above
- [ ] Each session has clear entry criteria, exit criteria, and validation steps
- [ ] Ordering is safety-first (unlocking steps precede reshaping steps)
- [ ] No big-bang rewrite sessions; each session is scoped and testable

---

## Related rules
- `.cursor/rules/prompts/prompt-creation-rule.mdc`

---

**Created**: 2026-01-18
