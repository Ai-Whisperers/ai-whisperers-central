---
name: refactor-module-boundaries-and-ownership
description: "Please make module boundaries explicit: define ownership, move responsibilities, and reduce cross-module leakage"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, modules, boundaries, ownership, architecture, cohesion, coupling
argument-hint: "Scope + suspected boundary problems + target module map"
---

# Refactor: module boundaries & ownership

Use this when the code is now readable/tested, but the **module layout doesn’t match responsibilities** (types live in the wrong place, cross-cutting helpers grow, and “misc” namespaces expand).

**Pattern**: Refactoring Workflow Pattern ⭐⭐⭐⭐  
**Effectiveness**: High for reducing coupling and clarifying ownership  
**Use When**: You need a clear module map, ownership rules, and enforcement via architecture tests

---

## Required context (provide in the request)

- **Scope**: what area you want to modularize (folders/namespaces/projects)
- **Candidate modules** (even if rough): 3–10 module names with 1–2 sentence responsibilities each
- **Hot boundary pain** (examples):
  - “Types from X are used everywhere”
  - “Services combine multiple concerns”
  - “Domain rules are mixed with persistence/integration”
  - “Infrastructure details leak into application/domain”
- **Current dependency constraints** (if any): e.g. “Domain must not reference Infrastructure”
- **Constraints**: timeline (1–2 sessions vs ongoing), “no breaking public API”, performance sensitivities, etc.
- **Test/build commands**: how to run unit tests and architecture tests in this repo
- **Preferred module style** (optional): layer-based (Domain/Application/Infrastructure) vs feature-based slices

---

## Output goals

- Higher cohesion inside modules, lower coupling across modules
- Clear ownership of concepts (nouns) and behaviors (verbs)
- Stable dependency direction and fewer cross-module references

---

## Process

### Step 1: Establish the module map (target state)

- Propose (or refine) a module map for the scope: **module name → responsibility → owned concepts**
- State the **dependency rules** between modules (allowed/forbidden)
- Define “ownership” rules:
  - **Owns types**: where the canonical type lives
  - **Owns behavior**: where business logic must live
  - **Consumes**: how other modules can depend on it (interfaces, DTOs, events, etc.)

### Step 2: Find boundary violations (current state)

Identify and list concrete violations, grouped by impact:

- **Misplaced types** (type belongs in module A but lives in B)
- **Utility buckets** hiding ownership (“Helpers”, “Common”, “Shared”, “Misc”)
- **Dependency direction reversals** (lower-level module referencing higher-level)
- **Cycles** (direct or indirect module cycles)
- **Leaky abstractions** (domain logic depending on persistence/integration concerns)

### Step 3: Plan incremental refactoring batches

Create a prioritized plan of small batches (each should be testable independently):

- Batch size: “1–5 files” or “single concept move” per batch
- For each batch: what moves, what changes, expected ripple effects, rollback plan
- Explicitly call out **public API** or **serialization** risks when moving types

### Step 4: Execute refactoring batches

For each batch:

- Move types to their owning module
- Rename/re-home “helpers” into the owning concept/module (or delete if obsolete)
- Introduce boundary abstractions only when needed (interfaces, ports, adapters)
- Keep tests green after each batch (run the repo’s test commands)

### Step 5: Lock the boundaries with architecture tests

- Add/extend architecture tests that enforce:
  - Allowed module dependencies
  - Forbidden references (e.g., Domain → Infrastructure)
  - Cycle prevention (if you track cycles)

---

## Instructions to the agent

1. Establish the target module map and dependency rules.
2. Identify and prioritize boundary violations with concrete examples.
3. Produce an incremental batch plan with minimal blast radius per step.
4. Apply batches while preserving behavior and keeping tests green.
5. Add/extend architecture tests to enforce the new boundaries.

---

## Validation

- Unit tests pass
- Architecture tests enforce:
  - Allowed dependencies between modules
  - Forbidden references (e.g., Domain → Infrastructure)
- Optional: reduce cycle count / coupling metrics if you track them

---

## Validation checklist (definition of done)

- [ ] Module map exists and is understandable by a new team member
- [ ] Each key concept has a single owning module (no “floating” ownership)
- [ ] Public API surface changes are intentional and documented (or avoided)
- [ ] No new cross-module cycles introduced (and ideally reduced)
- [ ] Architecture tests fail when forbidden dependencies are introduced
- [ ] Unit tests pass after each refactoring batch

---

## Expected output

- Module map (short)
- A prioritized list of moves/extractions
- What architecture tests were added/updated to lock boundaries

---

## Examples

### Example 1: Stop domain leaking into infrastructure

**Input**:

- Scope: `src/Orders/*`
- Candidate modules:
  - `Orders.Domain`: order rules, invariants, value objects
  - `Orders.Application`: use cases and orchestration
  - `Orders.Infrastructure`: EF/Dapper/HTTP integrations
- Pain: “Domain uses repository implementations and SQL helpers”

**Expected output**:

- Module map + dependency rules:
  - `Orders.Domain` → depends on nothing in `Orders.Infrastructure`
  - `Orders.Application` → can depend on `Orders.Domain` and abstractions
  - `Orders.Infrastructure` → implements ports for `Orders.Application`
- Prioritized moves:
  - Move `OrderStatus` enum and `OrderId` value object into `Orders.Domain`
  - Replace `SqlOrderRepository` usage in Domain with an interface/port in Application
- Architecture tests:
  - Fail if `Orders.Domain` references `Orders.Infrastructure`

### Example 2: Collapse “Common/Helpers” into real owners

**Input**:

- Scope: `src/*/Common/*`
- Pain: “Everything depends on Common; it’s a dumping ground”

**Expected output**:

- Categorize helpers by owner (domain concepts, application utilities, infra utils)
- Move each helper to its owning module and rename by intent (avoid `*Helper`)
- Update architecture rules to prevent “Common” from reappearing as a catch-all

---

## Usage

```text
@refactor-module-boundaries-and-ownership "Scope: src/Orders; Pain: Domain references Infrastructure; Candidate modules: Orders.Domain, Orders.Application, Orders.Infrastructure"
```

---

## Related prompts

- `refactoring/refactor-dependency-direction-and-cycles.prompt.md`
- `refactoring/refactor-public-api-surface.prompt.md`
- `refactoring/refactor-determinism-and-test-seams.prompt.md`
- `refactoring/refactor-branchy-logic-into-models.prompt.md`
- `refactoring/orchestrate-refactoring-sessions.prompt.md`
- `refactoring/refactoring-next-steps-sets.prompt.md`

---

**Created**: 2026-01-18
