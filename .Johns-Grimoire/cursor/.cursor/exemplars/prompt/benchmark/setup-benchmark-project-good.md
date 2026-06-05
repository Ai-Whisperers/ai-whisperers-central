---
id: exemplar.setup-benchmark-project.good.v1
kind: exemplar
version: 1.0.0
description: High-quality benchmark plan prompt example
globs: ""
governs: ""
implements: prompt.benchmark-plan.create
illustrates: prompt.benchmark-plan.create
use: critic-only
notes: "Pattern extraction only. NEVER copy content to production."
requires: []
model_hints: { temp: 0.2, top_p: 0.9 }
provenance: { owner: team-prompts, last_review: 2026-01-23 }
alwaysApply: false
---

# Setup Benchmark Project Prompt Exemplar

## Purpose & Scope

Preserves a complete, high-quality benchmark plan prompt for pattern learning and critique.

**Applies to**: Prompt authoring reviews and prompt pattern extraction.  
**Does not apply to**: Direct generation of new prompt files without templar guidance.

## Inputs (Contract)

- The full prompt content to preserve as an exemplar.
- The prompt's intended structure and constraints.

## Outputs (Contract)

- A complete prompt example retained verbatim for reference.
- Clear warning about non-production usage.

## Deterministic Steps

1. Preserve the full prompt content without modification.
2. Keep exemplar content in a single code block for easy reference.
3. Provide usage warnings to prevent content leakage.

## Formatting Requirements

Full exemplar content:

```markdown
---
name: setup-benchmark-project
description: "Please create a BENCHMARK ticket plan to set up a BenchmarkDotNet project for this repo with deterministic datasets and reproducible runs."
category: benchmark
tags: benchmark, performance, planning, ticket, benchmarkdotnet
argument-hint: "Ticket path, benchmark scope/config, preferred location (src/tst)"
---

# Setup Benchmark Project

Please create a BENCHMARK ticket plan to set up a BenchmarkDotNet project for this repo with deterministic datasets and reproducible runs.

**Pattern**: Constrained Generation  
**Effectiveness**: Ensures repeatable benchmark setup plans  
**Use When**: You need a standard plan for creating benchmark projects in this repository

---

## Purpose

Create a clear, repository-aligned BENCHMARK plan that defines scope, tooling, deterministic datasets, and repeatable execution steps for a BenchmarkDotNet benchmark project.

---

## Required Context

- **Ticket Path**: `[TICKET_PATH]` (e.g., `tickets/BENCHMARK`)
- **Benchmark Scope/Config**:
  <benchmark_scope>
  [BENCHMARK_SCOPE]
  </benchmark_scope>
  - Include/exclude targets, default selection, and configuration notes
- **Preferred Location**: `[BENCHMARK_LOCATION]` (`src` or `tst`)
- **Repo Conventions**: Ticket plan format and naming requirements used in this repository

---

## Reasoning Process (for AI Agent)

1. **Validate Inputs**: Ensure ticket path and preferred location align with repo conventions.
2. **Define Scope**: Convert scope/config into clear benchmark targets and configuration rules.
3. **Structure Plan**: Produce a plan.md using repository ticket standards.
4. **Check Reproducibility**: Ensure deterministic dataset requirements and execution steps are explicit.

---

## Process

### Step 1: Identify Benchmark Targets
Use the provided scope/config to list concrete benchmark targets and selection rules.

### Step 2: Specify Tooling and Determinism
State BenchmarkDotNet usage, deterministic dataset requirements, and baseline output format.

### Step 3: Create Plan Structure
Write a ticket plan with:
- Objective
- Requirements
- Acceptance Criteria
- Implementation Strategy
- Complexity Assessment
- Testing Strategy
- Notes (including OpenMetrics as separate ticket)

### Step 4: Align with Repo Conventions
Honor the requested location (`src` or `tst`) and match existing ticket plan style.

---

## Constraints

- Do not propose OpenMetrics integration in this plan (track separately).
- Keep dataset generation deterministic and explicitly documented.
- Avoid introducing tool choices beyond BenchmarkDotNet unless required by repo standards.

---

## Expected Output

A complete `plan.md` draft for `[TICKET_PATH]` that includes:

```markdown
# BENCHMARK Plan

## Objective
[Objective statement]

## Requirements
- [Requirement 1]
- [Requirement 2]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Implementation Strategy
1. [Step 1]
2. [Step 2]

## Complexity Assessment
[Complex or Simple track with rationale]

## Testing Strategy
- [Testing notes]

## Notes
- OpenMetrics in separate ticket
```

---

## Output Format

Provide a single `plan.md` draft in Markdown that follows the ticket plan structure shown above, with placeholders replaced by concrete, repo-aligned content.

---

## Pattern Used

- `templar.benchmark-plan-prompt.v1`

---

## Reference Example

- `exemplar.setup-benchmark-project.good.v1`

---

## Examples

See exemplar: `exemplar.setup-benchmark-project.good.v1`

---

## Validation Checklist

Before finalizing the plan:
- [ ] Ticket path and preferred location validated against repo conventions
- [ ] Benchmark targets explicitly listed with include/exclude rules
- [ ] Deterministic dataset strategy documented with reproducibility steps
- [ ] OpenMetrics explicitly deferred to a separate ticket

---

## Quality Criteria

- [ ] Scope/config translated into explicit benchmark targets
- [ ] BenchmarkDotNet called out as tooling
- [ ] Deterministic dataset requirements documented
- [ ] Preferred location (`src`/`tst`) respected
- [ ] Plan follows repo ticket conventions
- [ ] OpenMetrics explicitly separated

---

## Usage

```
@setup-benchmark-project tickets/BENCHMARK all-domain-objects; include/exclude rules; deterministic datasets tst
```

---

## Related Prompts

- `create-ticket` - Create a new ticket folder if needed
- `validate-plan` - Validate the plan structure and completeness

---

## Related Rules

- `rule.prompts.creation.v1` - Prompt content standards
- `rule.prompts.registry-integration.v1` - Prompt Registry format
- `rule.ticket.plan.v1` - Ticket plan requirements
- `rule.ticket.complexity-assessment.v1` - Complexity criteria
```

## OPSEC and Leak Control

- WARNING: This is an exemplar. Do not copy content into production prompts.
- Remove any repo-specific references if reusing patterns in other contexts.

## Integration Points

- Aligns with `rule.prompts.creation.v1` for content quality.
- Aligns with `rule.prompts.registry-integration.v1` for prompt format.
- Uses `templar.benchmark-plan-prompt.v1` for structure.

## Failure Modes and Recovery

- **Exemplar leaks into output**: Use templar-only during write phase.
- **Outdated example**: Replace with a newer prompt and bump version.

## Provenance Footer Specification

No provenance footer required for exemplar files.

## Final Must-Pass Checklist

- [ ] Exemplar includes `use: critic-only` and warning note.
- [ ] Full prompt content preserved verbatim.
- [ ] References use stable IDs where possible.
- [ ] No exemplar content copied into production outputs.
