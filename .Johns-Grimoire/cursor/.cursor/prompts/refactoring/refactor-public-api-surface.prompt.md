---
name: refactor-public-api-surface
description: "Please stabilize and reduce accidental public API surface: define contracts, internalize implementation, and prevent leakage"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: refactoring
tags: refactoring, api, surface-area, contracts, compatibility, encapsulation
argument-hint: "Scope + consumer constraints (breaking changes allowed?) + target public contract"
---

# Refactor: public API surface control

Please use this when refactoring reveals that “public” doesn’t match “intended contract” (too many public types, leaking implementation details, hard-to-change APIs).

---

## Required context (provide in the request)

- **Scope**:
  <scope>
  [SCOPE] <!-- projects/namespaces/packages where API surface should be controlled -->
  </scope>
- **Consumer constraints**:
  <consumer_constraints>
  - Breaking changes allowed? [BREAKING_CHANGES_ALLOWED] <!-- yes|no -->
  - External consumers: [CONSUMERS] <!-- list repos/packages/apps; "none" if unknown -->
  </consumer_constraints>
- **Target public contract**:
  <target_public_contract>
  - Facades/services: [PUBLIC_FACADES] <!-- types or namespaces -->
  - Contracts/DTOs: [PUBLIC_CONTRACT_TYPES] <!-- types or namespaces -->
  - Exceptions/results: [PUBLIC_EXCEPTIONS_AND_RESULTS] <!-- types or namespaces -->
  </target_public_contract>

---

## Output goals

- Clear “public contract” vs “internal implementation” separation
- Fewer public types/members that are not part of the contract
- Safer refactors in the future (smaller blast radius)

---

## Typical actions

- Move consumer-facing types to `*.Contracts` (or equivalent) if that pattern exists
- Reduce visibility:
  - `public` → `internal` where possible
  - `public set` → `init`/private set (when compatible)
- Introduce an explicit facade/entrypoint and hide internal services behind it
- Add API compatibility checks if the repo already uses them (reuse existing tooling)

---

## Reasoning process (for the AI agent)

Before changing visibility or moving types, please:

1. **Identify the contract**: Determine which types/members are intentionally public (and who consumes them).
2. **Assess break risk**: Use `[BREAKING_CHANGES_ALLOWED]` to decide whether changes must be source/binary compatible.
3. **Prefer non-breaking containment**: Favor wrappers, facades, and type moves that keep existing call sites stable when breaking changes are not allowed.
4. **Apply changes incrementally**: Make small moves, keep the build and tests green, and avoid broad renames unless necessary for contract clarity.
5. **Add guardrails**: Ensure the “public surface” remains stable over time (architecture tests / analyzers / API checks).

---

## Process

1. **Inventory public surface** in `<scope>`:
   - List public types and their key public members (methods/properties/events) that matter to consumers.
2. **Classify each public item**:
   - **Intended contract**: belongs to `<target_public_contract>`
   - **Accidental exposure**: implementation detail or “helper” that leaked out
3. **Refactor toward the contract** (incrementally):
   - Internalize accidental exposure (`public` → `internal`) when safe
   - Introduce/strengthen a facade/entrypoint and route consumers through it
   - Move contract types into a dedicated contracts area (e.g., `*.Contracts`) if that exists (or create a consistent equivalent)
   - Minimize mutability on contract types when compatible (`public set` → `init`/private set)
4. **Protect against re-leakage**:
   - Add/extend architecture tests enforcing “only contracts are public” (when feasible)
   - Add/extend API compatibility checks if already used in the repo/tooling

---

## Examples (Few-Shot)

### Example 1: Accidental exposure (internalize + keep facade public)

**Input**:

<scope>
MyProduct.Domain; MyProduct.Infrastructure
</scope>
<consumer_constraints>
- Breaking changes allowed? no
- External consumers: MyProduct.Api, MyProduct.Worker
</consumer_constraints>
<target_public_contract>
- Facades/services: MyProduct.Domain.IPriceService, MyProduct.Domain.PriceService
- Contracts/DTOs: MyProduct.Domain.Contracts.*
- Exceptions/results: MyProduct.Domain.Contracts.PriceError, MyProduct.Domain.Contracts.PriceResult
</target_public_contract>

**Reasoning**:
- Keep `IPriceService` and contract types public because they are consumed externally.
- Internalize helper and persistence details, and keep them behind DI and the public facade.
- Add a guardrail so new public types in `MyProduct.Domain` must live under `*.Contracts` (except explicitly allowed facades).

**Output**:
- Internalize `MyProduct.Infrastructure.Sql.PriceRepository` (and related helpers) to `internal`.
- Ensure the only public entrypoint used by consumers is `IPriceService` / `PriceService` and contract types under `MyProduct.Domain.Contracts`.
- Add an architecture test: public types must be either:
  - In `MyProduct.Domain.Contracts.*`, or
  - In the allow-list: `IPriceService`, `PriceService` (and any other explicitly listed facades)

---

## Expected output

**Deliverables**:
1. **Contract definition**: What constitutes the intended public contract (explicit allow-list + contract namespaces).
2. **Change set summary**: What was internalized/moved and why (grouped by project/namespace).
3. **Compatibility notes**: Any breaking change risks and how they were avoided (or justified if allowed).
4. **Guardrails**: What prevents re-leakage (tests/analyzers/API checks) and how to maintain them.

---

## Quality criteria (validation checklist)

Before claiming completion, please verify:
- [ ] Public contract is explicitly defined (allow-list and/or contract namespaces)
- [ ] No accidental public types/members remain in `<scope>` (or each is justified as contract)
- [ ] Changes respect `[BREAKING_CHANGES_ALLOWED]`
- [ ] Build and tests are green after each incremental step
- [ ] Guardrails exist (architecture tests and/or API checks) to prevent re-leakage
- [ ] Output includes concrete locations (project/namespace/type) for key changes

---

## Usage

```text
@refactor-public-api-surface
<scope>
[SCOPE]
</scope>
<consumer_constraints>
- Breaking changes allowed? [BREAKING_CHANGES_ALLOWED]
- External consumers: [CONSUMERS]
</consumer_constraints>
<target_public_contract>
- Facades/services: [PUBLIC_FACADES]
- Contracts/DTOs: [PUBLIC_CONTRACT_TYPES]
- Exceptions/results: [PUBLIC_EXCEPTIONS_AND_RESULTS]
</target_public_contract>
```

---

## Related prompts

- `prompt/improve-prompt.prompt.md` - Improve a prompt for correctness/standards before enhancing
- `prompt/enhance-prompt.prompt.md` - Enhance a working prompt with examples, structure, and guardrails

---

**Created**: 2026-01-18
