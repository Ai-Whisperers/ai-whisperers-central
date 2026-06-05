---
name: refactoring-next-steps-sets
description: "Turn metric wins (CC/CRAP + tests) into a prioritized set-based refactoring roadmap (boundaries, coupling, APIs, flows)"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, roadmap, architecture, coupling, dependency-rules, boundaries, api-surface, flow-diagrams
argument-hint: "Repo area + goals (e.g., \"reduce coupling\", \"clarify modules\", \"stabilize APIs\")"
---

# Refactoring Next Steps (Set-based roadmap)

Use this after you’ve already:
- Reduced CC/CRAP via incremental refactors
- Increased unit test coverage to protect behavior
- Added/cleaned docs enough to navigate

Now the goal shifts to **structural refactoring**: make boundaries explicit, reduce coupling, and prevent re-growth.

---

## Purpose

Help the agent produce a **small number of refactoring “sets”** you can tackle in separate sessions, where each set is:
- Goal-driven (clear outcome)
- Incremental (can be done in steps)
- Protected (tests/architecture tests)
- Measurable (coupling/cycles, surface area, ownership, build times, etc.)

---

## Required context (provide in the request)

- **Target scope**: repo + projects/modules (e.g. `src/Domain/*`, “Export pipeline”, “TimeSeries conversions”)
- **Current state signals**:
  - Most painful areas (hotspots)
  - Any known dependency tangles/cycles
  - Any API/contract stability requirements
- **Constraints**:
  - “No breaking changes” vs “internal refactor OK”
  - Performance constraints / throughput requirements
  - Migration constraints (if any)

---

## Candidate refactoring sets (pick the best 3–6)

### Set A — Dependency direction + cycle removal
- Identify and break project/namespace cycles
- Define allowed reference directions
- Add architecture tests to lock it in

### Set B — Module boundaries + ownership
- Define modules/bounded contexts
- Move types so that responsibilities align to the module
- Introduce explicit abstractions at boundaries (ports/adapters where needed)

### Set C — Public API surface control
- Identify “consumer-facing” vs “internal” APIs
- Reduce accidental public surface area
- Add API compatibility checks if appropriate

### Set D — Replace branchy orchestration with explicit models
- Replace complex conditional routing with strategies/rules/state models
- Make business rules first-class and testable

### Set E — Determinism & seams for testability
- Wrap time/random/env/fs/network behind interfaces
- Reduce static/global state usage
- Stabilize tests and enable faster refactors

### Set F — Critical flow documentation + diagrams (Mermaid)
- Pick top 3–5 flows
- Produce flow/sequence diagrams and link to modules and persistence/integration points
- Ensure diagrams stay high-level and stable (not every class)

---

## Instructions to the agent

1. Propose **3–6 sets** (only), each with:
   - **Goal**
   - **Why now**
   - **Entry criteria** (what must already be true)
   - **Execution steps** (small increments)
   - **Validation** (tests, architecture rules, metrics)
   - **Exit criteria**
2. Order sets by:
   - Unblocking value (removes friction for later work)
   - Risk (do safer structural changes first)
3. Avoid proposing “boil the ocean” rewrites.

---

## Expected output

```markdown
## Refactoring sets (next sessions)

### Set 1: <name>
- Goal:
- Why now:
- Steps:
- Validation:
- Exit criteria:

### Set 2: <name>
...
```

---

## Related prompts

- `code-quality/create-refactoring-plan.prompt.md`
- `unit-testing/architecture-unit-tests.prompt.md`
- `documentation/documentation-levels-and-mermaid-diagrams.prompt.md`

---

**Created**: 2026-01-18
