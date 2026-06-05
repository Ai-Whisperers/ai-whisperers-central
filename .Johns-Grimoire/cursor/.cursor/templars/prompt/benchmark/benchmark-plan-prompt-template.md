---
id: templar.benchmark-plan-prompt.v1
kind: templar
version: 1.0.0
description: Structure template for benchmark ticket plan prompts
globs: ""
governs: ""
implements: prompt.benchmark-plan.create
requires: []
model_hints: { temp: 0.2, top_p: 0.9 }
provenance: { owner: team-prompts, last_review: 2026-01-23 }
alwaysApply: false
---

# Benchmark Plan Prompt Templar

## Purpose & Scope

Defines the reusable structure for prompts that generate BENCHMARK ticket plans with deterministic datasets and reproducible runs.

**Applies to**: `.cursor/prompts/benchmark/*.prompt.md` files that produce benchmark plan drafts.  
**Does not apply to**: Benchmark project implementation or code changes.

## Inputs (Contract)

- Prompt name and description for YAML frontmatter.
- Ticket plan requirements, constraints, and expected output structure.
- Required context placeholders (ticket path, scope/config, preferred location).
- Repository conventions that must be referenced.

## Outputs (Contract)

- A `.prompt.md` file that follows prompt registry standards.
- Required sections: Purpose, Required Context, Reasoning Process, Process, Constraints, Expected Output, Output Format, Examples, Validation, Quality Criteria.

## Deterministic Steps

1. Populate YAML frontmatter fields with prompt metadata.
2. Fill required context placeholders and XML-delimited scope block.
3. Provide numbered process steps aligned to benchmark planning needs.
4. Include constraints and expected output format.
5. Reference a separate exemplar for full examples.

## Formatting Requirements

Use this template structure:

```markdown
---
name: {{prompt_name}}
description: "{{prompt_description}}"
category: benchmark
tags: benchmark, performance, planning, ticket, benchmarkdotnet
argument-hint: "{{argument_hint}}"
---

# {{prompt_title}}

{{short_description}}

**Pattern**: Constrained Generation
**Effectiveness**: {{effectiveness_statement}}
**Use When**: {{use_when_statement}}

---

## Purpose

{{purpose_statement}}

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
{{step_1_instructions}}

### Step 2: Specify Tooling and Determinism
{{step_2_instructions}}

### Step 3: Create Plan Structure
{{step_3_instructions}}

### Step 4: Align with Repo Conventions
{{step_4_instructions}}

---

## Constraints

- {{constraint_1}}
- {{constraint_2}}
- {{constraint_3}}

---

## Expected Output

{{expected_output_description}}

```markdown
{{expected_output_template}}
```

---

## Output Format

{{output_format_instructions}}

---

## Examples

See exemplar: `exemplar.setup-benchmark-project.good.v1`

---

## Validation Checklist

- [ ] {{validation_check_1}}
- [ ] {{validation_check_2}}
- [ ] {{validation_check_3}}

---

## Quality Criteria

- [ ] {{quality_criterion_1}}
- [ ] {{quality_criterion_2}}
- [ ] {{quality_criterion_3}}
```

## OPSEC and Leak Control

- Do not include secrets, tokens, or internal URLs in prompt examples.
- Keep examples generic and avoid repo-specific confidential data.

## Integration Points

- Aligns with `rule.prompts.creation.v1` for content quality.
- Aligns with `rule.prompts.registry-integration.v1` for `.prompt.md` format.
- References `rule.authoring.templars-and-exemplars.v1` for extraction boundaries.

## Failure Modes and Recovery

- **Missing placeholders**: Add required placeholders using standard `[PLACEHOLDER]` format.
- **Overly long examples**: Move full examples into exemplar and link instead.
- **Unclear constraints**: Rewrite constraints as explicit bullet items.

## Provenance Footer Specification

No provenance footer required for prompt files.

## Final Must-Pass Checklist

- [ ] Frontmatter contains `name` and `description`.
- [ ] Required context placeholders are present and clear.
- [ ] Steps are numbered and actionable.
- [ ] Examples are referenced via exemplar, not embedded.
- [ ] Output format is explicit and deterministic.
