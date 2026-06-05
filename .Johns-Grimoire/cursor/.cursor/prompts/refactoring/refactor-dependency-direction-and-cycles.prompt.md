---
name: refactor-dependency-direction-and-cycles
description: "Please reduce hidden coupling by detecting and breaking dependency cycles and enforcing dependency direction (projects/namespaces)"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, dependencies, cycles, layering, coupling, architecture
argument-hint: "Scope (projects/namespaces) + known issues (cycles/forbidden refs) + desired dependency direction rules"
---

# Refactor: dependency direction & cycle removal

Use this when CC/CRAP refactors have exposed deeper structural coupling: unexpected references, cycles, and “everything depends on everything” patterns.

---

## Purpose

Break dependency cycles and make the intended dependency direction explicit and enforceable, with minimal, low-risk changes that preserve runtime behavior.

---

## Required context (provide in the request)

- **Scope**: projects/folders/namespaces to analyze
- **Known issues** (if any):
  - “We have a cycle between A and B”
  - “Domain references Infrastructure”
  - “Tests rely on internal modules in unsafe ways”
- **Desired dependency direction** (examples):
  - Application → Domain → (abstractions) ← Infrastructure
  - `*.Contracts` can be referenced by others; implementation projects should not be referenced externally

---

## Output goals

- Break cycles with minimal changes
- Make dependency direction explicit and enforceable
- Keep behavior unchanged (tests stay green)

---

## Common tactics (pick the smallest that works)

- **Move types** to the owning layer/module
- **Introduce an abstraction** (interface) in the higher-level module
- **Extract Contracts** project/namespace for boundary types
- **Invert dependency** (higher layer depends on interface; lower provides implementation)
- **Split module** if it contains mixed responsibilities

---

## Instructions to the agent

### Step 1: Identify the dependency problems

- Detect **project reference** cycles (A → B → A) and (where applicable) **namespace-level** cycles.
- Identify **forbidden dependency directions** (e.g., Domain → Infrastructure when the rule is Domain is pure).

### Step 2: Propose a minimal break for each cycle

For each cycle:
- Describe the cycle path (A → B → C → A)
- Propose 1–3 candidate breaks, ordered by smallest/lowest risk
- Choose the smallest change that resolves the cycle without broad churn

Preference order (typical):
1. Move a small type to its owning layer
2. Extract a boundary type into a `*.Contracts` (or similar) project/namespace
3. Introduce an interface/abstraction “upwards” and implement “downwards”
4. Split a mixed-responsibility module (only when unavoidable)

### Step 3: Implement the chosen break

- Make the minimal code and project-reference changes required to remove the cycle.
- Avoid unrelated refactors.

### Step 4: Add enforcement (architecture tests)

- Add/extend architecture unit tests to prevent regressions.
- Use `unit-testing/architecture-unit-tests.prompt.md` as the enforcement step.

### Step 5: Validate

- Build + run tests for impacted projects
- Ensure **no new warnings**

---

## Expected output

- **Findings**
  - Cycles found (project refs and/or namespaces) with locations
  - Forbidden dependency directions found (rule violated + where)
- **Plan**
  - Chosen break strategy per cycle (why it’s minimal)
  - Notes on trade-offs (if any)
- **Changes**
  - Code + project reference changes
  - Updated/added architecture tests (how they enforce the rule)
- **Validation**
  - Build/test commands run (or equivalent) and results
  - Confirmation that no new warnings were introduced

---

## Examples

### Example 1: Simple project reference cycle

**Input (request context)**:
- Scope: `MyApp.Domain`, `MyApp.Infrastructure`
- Known issue: “We have a cycle between Domain and Infrastructure”
- Desired direction: Infrastructure may depend on Domain, Domain must not depend on Infrastructure

**Expected output (shape)**:
- Findings: `MyApp.Domain` → `MyApp.Infrastructure` (illegal), `MyApp.Infrastructure` → `MyApp.Domain` (legal) → cycle
- Plan: extract/move the boundary abstraction so Domain no longer needs Infrastructure
- Changes: remove Domain → Infrastructure reference, keep Infrastructure → Domain, update wiring
- Enforcement: architecture test “Domain does not reference Infrastructure”
- Validation: impacted projects build + tests pass

### Example 2: Namespace-level cycle inside a single project

**Input (request context)**:
- Scope: `MyApp.Domain` namespaces `Domain.Services` and `Domain.Models`
- Known issue: “Services and Models reference each other in confusing ways”
- Desired direction: Models should not depend on Services

**Expected output (shape)**:
- Findings: `Domain.Models` depends on `Domain.Services` via helper/static calls → cycle-ish coupling
- Plan: move model-owned logic into Models, or introduce a small interface in Models implemented by Services
- Enforcement: architecture test “Models namespace does not depend on Services namespace” (if tooling supports namespace rules)
- Validation: build + tests pass

---

## Validation checklist

- [ ] All identified dependency cycles are removed
- [ ] Dependency direction rules are explicit and enforced in tests
- [ ] No unrelated refactors were introduced
- [ ] Impacted projects build and tests pass with **zero new warnings**

**Created**: 2026-01-18
