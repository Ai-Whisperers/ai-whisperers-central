---
name: architecture-unit-tests
description: "Please add or tighten architecture unit tests (dependency rules, layering, boundaries) and make them enforceable"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: unit-testing
tags: architecture, unit-tests, boundaries, dependencies, layering, cycles, maintainability
argument-hint: "Repo area + desired constraints (e.g., \"Domain must not reference Infrastructure\")"
---

# Architecture Unit Tests (requirements + implementation prompt)

Use this prompt when the codebase has become test-covered and more modular, and you want to **prevent regressions** by enforcing architecture constraints automatically.

**Pattern**: Enforcement via Architecture Tests ⭐⭐⭐⭐  
**Effectiveness**: High when rules are minimal + stable  
**Use when**: You need CI-enforced layering/boundary constraints (projects/namespaces/modules)

---

## Purpose

Help the agent:

- Identify **existing architectural seams** (namespaces/projects/modules) and **current architecture test style** already used in this repo
- Define **explicit dependency rules** (allowed/forbidden references) with clear intent
- Add/extend **architecture unit tests** so that violations fail fast in CI
- Keep rules **minimal, enforceable, and evolvable** (avoid overfitting the current code)

---

## Required context (provide in the request)

- **Scope**: repo/module you want to cover (e.g., “Domain layer”, “All `src/` projects”, or “Feature X”)
- **Current reality**: naming patterns for layers/modules (projects + namespaces)
- **Rules you want** (start small):
  - Example: “Domain must not depend on Infrastructure”
  - Example: “No cycles between projects”
  - Example: “Only `*.Contracts` may be referenced by external assemblies”
- **Where tests live**: existing architecture test project/file(s) to follow (if any)

If you don’t know the exact module boundaries yet, say so — the agent should infer boundaries from project structure and namespace conventions.

---

## Constraints (what “good” looks like)

- Prefer **few strong rules** over many weak rules.
- Rules must be phrased as **contracts**:
  - What is forbidden / allowed
  - Why it matters
  - What to do instead
- Tests should be:
  - Deterministic and fast
  - Stable against harmless refactors (avoid brittle name matching)
  - Actionable on failure (failure messages should point to the rule + fix)
- Do not introduce new architecture-test dependencies unless necessary; **reuse the repo’s existing approach**.

---

## Suggested “starter set” of architecture rules

Pick 2–5 that fit the repo:

1. **No layer violations**
   - Domain does not reference Infrastructure/EF/IO/HTTP/etc.
2. **No cyclic dependencies**
   - Between projects and/or namespaces.
3. **API surface control**
   - Only designated projects are publicly consumable; others should be internal-only (as possible).
4. **Dependency direction**
   - App/UseCases → Domain → (abstractions) ← Infrastructure
5. **Forbidden technology bleed**
   - e.g. no JSON/ORM types inside Domain.

---

## Instructions to the agent

1. **Locate existing architecture tests** (or create a new dedicated test class in the existing test project).
2. **Document the rules** (short comment or test name string): what/why/how.
3. **Implement tests** following the repo conventions:
   - Project/namespace selection logic
   - Assertion style
   - Failure messages
4. **Run tests** for the affected test project (or as close as possible).
5. If violations exist, either:
   - Fix the violations (preferred if small and clearly correct), or
   - Add a small “known violations” list with explicit TODO + ticket reference (only if necessary).

---

## Reasoning process (for the agent)

1. **Confirm the boundary model**: are “layers” defined by projects, namespaces, folders, or a mix?
2. **Prefer compile-time boundaries** (project references) over heuristic boundaries (string namespace matching) when possible.
3. **Turn each rule into a contract**:
   - Forbidden/allowed
   - Why it matters (risk prevented)
   - How to fix (preferred dependency direction)
4. **Make failure output actionable**: print violated types/projects and the exact contract name.
5. **Keep exceptions explicit**: a small allow-list with TODO + ticket, never a silent skip.

---

## Expected output

- One or more architecture test(s) added/updated that enforce the requested rules.
- A short list of:
  - Rules implemented
  - What projects/namespaces they apply to
  - Any intentional exceptions (with justification)

---

## Output format (recommended)

```markdown
## Architecture rules enforced

### Rules implemented
1. [Rule name] — [short what/why/how]
2. ...

### Scope
- Projects:
  - ...
- Namespaces (if used):
  - ...

### Exceptions (if any)
- [Exception reason] — [ticket] — [temporary? yes/no]

### Test execution
- Command: `dotnet test ...`
- Result: pass/fail
```

---

## Example invocation

```text
@architecture-unit-tests

Scope: All src/ projects
Rules:
1) Domain must not reference Infrastructure
2) No cycles between projects
3) Only *.Contracts projects may be referenced by external repos
Notes:
- Follow existing architecture tests in tst/*Architecture*.Tests
```

---

## Troubleshooting

- **No existing architecture-test framework found**
  - Prefer adding tests using whatever the repo already uses for dependency assertions (avoid introducing new packages unless the repo has none).
- **Rules feel brittle**
  - Replace string-matching with project-reference checks where possible; otherwise centralize namespace patterns and keep them narrow.
- **Many violations found**
  - Start by enforcing the highest-value boundary (e.g., Domain → Infrastructure), then iterate; use a small, temporary allow-list only when necessary.

---

## Validation checklist

Before claiming completion:

- [ ] Each rule is stated as a contract (forbidden/allowed + why + how to fix)
- [ ] Tests are deterministic and fast
- [ ] Failures are actionable (identify violating projects/types and the rule name)
- [ ] No new dependencies added unless necessary and justified
- [ ] Tests run for the affected test project (or closest equivalent)

---

## Related prompts

- `code-quality/analyze-complexity-metrics.prompt.md`
- `code-quality/create-refactoring-plan.prompt.md`
- `documentation/validate-documentation-quality.prompt.md`

---

**Created**: 2026-01-18
