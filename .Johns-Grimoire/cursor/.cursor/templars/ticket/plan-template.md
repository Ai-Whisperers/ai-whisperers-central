---
id: templar.plan.v1
kind: templar
version: 1.0.0
description: Structure template for plan.md files
implements: plan.update
globs: ""
governs: ""
requires: []
provenance: { owner: team-ticket, last_review: 2025-12-06 }
---

# {{ticket_id}} Plan

## Objective

{{objective_statement}}

## Background

{{background_context}}

## Requirements

{{detailed_requirements_list}}

## Acceptance Criteria

- [ ] {{criterion_1}}
- [ ] {{criterion_2}}
- [ ] {{criterion_n}}

## Implementation Strategy

{{implementation_approach}}

## Complexity Assessment

**Track**: {{complexity_track}}

**Rationale**: {{complexity_rationale}}

## Dependencies

{{dependencies}}

## Risks

{{risks}}

## Status

{{current_status}} (Planning, Ready, In Progress, Complete)

---
*Plan created: {{timestamp}}*

