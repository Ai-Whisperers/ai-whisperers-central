---
name: refactor-determinism-and-test-seams
description: "Please increase determinism and introduce test seams (time, randomness, IO, environment) to reduce refactoring risk and speed up tests"
category: refactoring
tags: refactoring, testability, determinism, seams, time, randomness, io, environment, dependency-injection
argument-hint: "Scope + sources of non-determinism + test pain points"
---

# Refactor: determinism & test seams

Use this when unit tests exist, but refactoring is still risky because logic depends on time, randomness, environment/process state, filesystem/network, static/global state, or concurrency side effects.

**Pattern**: Refactoring for Determinism & Seams ⭐⭐⭐⭐⭐  
**Effectiveness**: High (reduces flakiness, speeds up tests, unlocks safer refactors)  
**Use when**: You see flaky/slow tests or high-risk refactors due to hidden dependencies

---

## Required context (provide in the request)

- **Scope**: projects/folders/classes to target
- **Sources of non-determinism** (list the ones you suspect/know):
  - **Time**: `DateTime.UtcNow`, `DateTimeOffset.UtcNow`, `Stopwatch`, `TimeProvider`, timers, scheduling
  - **Randomness**: `Random`, GUIDs used as behavior drivers, non-seeded RNG
  - **Environment/process**: `Environment.*`, machine name, culture/timezone, current directory, process-wide settings
  - **IO**: filesystem, network, database, HTTP, message bus
  - **Static/global state**: singletons, caches, static mutable fields, `AsyncLocal`, ambient context
  - **Concurrency**: races, background tasks, thread scheduling assumptions
- **Test pain** (what you want to improve):
  - **Flaky tests** (intermittent failures)
  - **Slow tests** (runtime / heavy dependencies)
  - **Heavy setup/teardown** (mocks, containers, integration wiring)
  - **Hard-to-reproduce bugs** (timing-dependent)
- **Constraints**:
  - **Public API constraints** (cannot change / can add overloads)
  - **DI constraints** (existing container patterns, where composition happens)
  - **Incremental change preference** (touch few call sites per step)

---

## Output goals (success criteria)

- **Deterministic tests**: eliminate flakes by removing hidden time/random/IO dependencies from unit-level logic
- **Smaller tests**: less setup (fewer mocks, fewer global resets)
- **Faster tests**: shift unit tests away from real IO and slow resources
- **Clear seams**: explicit dependencies (ports/adapters) that make future refactors cheaper and safer

Non-goals (unless requested):

- Do not introduce abstraction everywhere; add seams only where they reduce risk/cost.

---

## Common seam patterns

- **Time**: prefer `TimeProvider` (modern .NET); otherwise introduce an `IClock` wrapper and inject it
- **Randomness**: inject an `IRandom` (or RNG wrapper) or provide seeded RNG at the boundary
- **Environment/process**: wrap environment access behind a small interface (only where used for behavior)
- **IO**: push external calls behind ports/adapters; keep core logic pure where possible
- **Global/static**: replace static/global access with injected dependencies incrementally (start at hotspots)
- **Concurrency**: centralize scheduling/clock/await patterns; avoid time-based sleeps in unit tests

---

## Instructions (agent workflow)

### Step 1: Inventory & diagnosis

- Find non-deterministic dependencies in scope (time/random/env/IO/global/static/concurrency).
- Classify each as:
  - **Behavior-driving** (changes outputs/branches) vs **incidental** (logging/telemetry)
  - **Unit-test relevant** vs **integration-test only**

### Step 2: Prioritize

Pick a small set to tackle first (highest ROI):

- Flaky tests
- Slowest tests
- Code with high churn or an upcoming refactor

### Step 3: Introduce seams incrementally (safe refactor loop)

For each target dependency:

- Add a seam at the edge of the logic (constructor/parameter injection).
- Provide a default production implementation (composition root / DI registration).
- Update call sites in small steps (avoid “big bang” rewrites).
- Keep behavior unchanged (use tests; add characterization tests if needed).

### Step 4: Make tests deterministic and fast

- Replace sleeps/time waits with controlled time (`TimeProvider`/fake clock).
- Replace randomness with seeded or controlled random source.
- Replace real IO with fakes/stubs at unit level; keep integration tests for real IO.

### Step 5: Validate

- Ensure flakes are eliminated (or tests are reclassified as deterministic integration tests).
- Ensure test runtime improves measurably where possible (before/after timing, or “removed external dependency X”).

---

## Expected output (deliverables)

### 1) Seam inventory + plan

- List of identified dependencies with:
  - **Location** (file/class/member)
  - **Type** (time/random/env/IO/global/static/concurrency)
  - **Impact** (flake/slow/setup/churn)
  - **Proposed seam** (what to inject, where)
  - **Order** (why this order)

### 2) Implementation changes

- New abstractions and where they live (module/namespace ownership).
- Production wiring (DI registrations / factories / composition root).
- Notes on any API constraints and how breaking changes were avoided.

### 3) Tests

- Tests added/updated with a brief mapping:
  - **Which seam enables which test**
  - **What flakiness/slowdowns were removed**

---

## Quality checklist (before claiming done)
- [ ] No unit test relies on wall-clock time or sleeps for correctness
- [ ] Randomness affecting behavior is controlled (seeded or injected)
- [ ] Unit tests do not hit real filesystem/network/DB
- [ ] Seams are introduced only where needed (no abstraction sprawl)
- [ ] Public API breakage avoided (or explicitly documented with rationale)

---

## Examples

### Example 1: Time-based logic seam
**Input context**:

- Scope: `Billing/InvoiceDueDateCalculator.cs`
- Non-determinism: `DateTime.UtcNow`
- Test pain: flaky tests around month boundaries

**Expected output characteristics**:

- Introduce `TimeProvider` (or `IClock`) injected into the calculator
- Add tests using a fake/frozen time provider covering boundary dates

### Example 2: IO-dependent logic seam
**Input context**:

- Scope: `Import/CustomerImportService.cs`
- Non-determinism: filesystem reads + environment-dependent base path
- Test pain: slow tests and heavy setup

**Expected output characteristics**:

- Move filesystem + env resolution behind a small interface
- Keep parsing/validation logic unit-testable with in-memory inputs

---

## Related prompts

- `prompt/improve-prompt.prompt.md` - Improve prompts to match standards
- `prompt/enhance-prompt.prompt.md` - Add examples, checklists, and advanced structure

---

**Created**: 2026-01-18
