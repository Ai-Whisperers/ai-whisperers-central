---
name: refactor-branchy-logic-into-models
description: "Please replace branch-heavy orchestration with explicit models (strategies/rules/state) so business logic becomes composable and testable"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, complexity, strategy, state-machine, rules, domain-model
argument-hint: "Entry point(s) + branch drivers + preferred model style (strategy/rules/state) + constraints (optional)"
---

# Refactor: branchy logic into explicit models

Please refactor branch-heavy orchestration (many if/switch paths, format/type routing, and nested decision trees) into explicit models so the orchestration becomes thin and the business logic becomes composable and testable.

**Pattern**: Replace Branches with Explicit Models ⭐⭐⭐⭐  
**Effectiveness**: High when branches cluster by decision driver (type/rules/state)  
**Use when**: Cyclomatic complexity may be acceptable, but maintainability suffers due to branching spread across methods and features

---

## Required context (provide in the request)

- **Entry point(s)**: method(s) where branching concentrates
- **Branch drivers**: what causes decision routing (type/format, scenario flags, state transitions, rules/thresholds, etc.)
- **Preferred modeling approach** (pick 1): strategy | rules | state
- **Constraints** (optional but recommended): e.g., "no breaking public API", "must preserve serialization", "performance-sensitive path"

Provide the above using robust delimiters:

```text
<entry_points>
[ENTRY_POINTS]
</entry_points>

<branch_drivers>
[BRANCH_DRIVERS]
</branch_drivers>

<preferred_model>
[PREFERRED_MODEL] # strategy | rules | state
</preferred_model>

<constraints>
[CONSTRAINTS] # optional
</constraints>
```

---

## Output goals

- Orchestration becomes thin: “select model → execute”
- Business decision logic becomes first-class objects
- Tests shift from “giant scenario tests” to “rule/strategy/state tests”

---

## Reasoning process (for the agent)

1. **Inventory branches**: identify the entry point(s) and map branch paths to their primary decision driver.
2. **Choose the best model**: pick strategy vs rules vs state based on the dominant driver.
3. **Design the seam**: define the smallest interface/contract that makes decisions explicit without dragging in unrelated dependencies.
4. **Extract incrementally**: migrate one “slice” at a time and keep behavior stable.
5. **Lock behavior with tests**: add small, deterministic tests for the new model objects plus a small regression set around the entry point.

---

## Process

1. Identify the branching hotspots and group branches by responsibility.
2. Choose one modeling pattern that fits the branch driver:
   - Many type/format routes → strategy lookup
   - Many independent checks → rule pipeline
   - Lifecycle transitions → state objects / state machine
3. Extract incrementally:
   - Introduce interface/abstraction
   - Add one implementation at a time
   - Replace branch slices with the model
4. Add tests per model object (small and deterministic), plus a small set of end-to-end regression tests.

---

## Output format (recommended)

```markdown
## Refactor plan — branchy logic into explicit models

### 1) Branch map (current)
- Entry point(s):
- Decision drivers:
- Branch groups (by responsibility):

### 2) Selected modeling pattern
- Pattern: strategy | rules | state
- Why this matches the branching:

### 3) Proposed model types
- Types to introduce:
  - [TypeName] — responsibility — location/ownership
- Wiring/selection mechanism:
  - e.g., dictionary lookup, pipeline ordering, transition table

### 4) Incremental extraction steps
1. ...
2. ...

### 5) Test plan
- New unit tests:
  - ...
- Regression tests (minimal set):
  - ...
```

---

## Expected output (deliverables)

- The selected modeling pattern and why it matches the branching
- New model types (strategies/rules/states) with ownership/module placement
- Test plan (new tests + what existing tests serve as regression)

---

## Examples (Few-Shot)

### Example 1: Type/format routing → strategies

**Input**:

```text
Entry points:
- TimeSerieService.Convert(...)

Branch drivers:
- Switch on IntervalType (10m/15m/60m)
- Switch on Unit (kW/kWh)
- A few flags (rounding, missing-values behavior)

Preferred model:
- strategy

Constraints:
- No breaking public API
- Keep conversions deterministic (no DateTime.Now)
```

**Output**:

```markdown
## Refactor plan — branchy logic into explicit models

### 2) Selected modeling pattern
- Pattern: strategy
- Why this matches the branching:
  - The dominant driver is type routing (IntervalType × Unit), which maps cleanly to a strategy lookup.

### 3) Proposed model types
- IConversionStrategy — convert input series to output series (pure/deterministic) — `src/.../Conversions`
- Interval10mTo15mStrategy — handles 10m→15m — `src/.../Conversions`
- Interval15mTo60mStrategy — handles 15m→60m — `src/.../Conversions`
- ConversionStrategySelector — selects strategy from (IntervalType, Unit, flags) — `src/.../Services`

### 4) Incremental extraction steps
1. Introduce `IConversionStrategy` and selector while keeping existing branching.
2. Move one branch (10m→15m) into `Interval10mTo15mStrategy` and replace that slice in the entry point.
3. Repeat per route; keep entry-point logic as “select → execute”.

### 5) Test plan
- Unit tests per strategy (AAA, deterministic fixtures)
- Regression: small set of “known input → expected output” tests at `TimeSerieService.Convert(...)`
```

---

## Troubleshooting

- **Branches don’t partition cleanly**
  - Prefer a “rules” model first to separate independent checks, then promote stable rule groups into strategies/state later.
- **Too many strategy combinations**
  - Split selection from execution: use a selector + composable strategy decorators (e.g., rounding/missing-values behavior).

---

## Validation checklist

Before claiming completion:

- [ ] Entry-point orchestration is “select model → execute” (no deep nested conditionals left there)
- [ ] Decision logic lives in explicit types (strategies/rules/states), each with a clear single responsibility
- [ ] New model objects have focused unit tests (small, deterministic)
- [ ] A minimal set of regression tests protects behavior at the entry point
- [ ] Constraints honored (e.g., public API preserved if required)

---

## Related prompts

- `refactoring/orchestrate-refactoring-sessions.prompt.md`
- `refactoring/refactor-determinism-and-test-seams.prompt.md`
- `refactoring/refactor-module-boundaries-and-ownership.prompt.md`
- `refactoring/refactor-public-api-surface.prompt.md`
- `refactoring/refactor-dependency-direction-and-cycles.prompt.md`
- `unit-testing/architecture-unit-tests.prompt.md`

---

## Related rules

- `.cursor/rules/prompts/prompt-creation-rule.mdc` - Prompt content quality standards

---

**Created**: 2026-01-18  
