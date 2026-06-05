---
type: templar
artifact-type: prompt
pattern-name: ticket-execute-plan
version: 1.0.0
applies-to: ticket prompts
implements: ticket.execute-plan
consumed-by:
  - .cursor/prompts/ticket/execute-plan.prompt.md
---

# Execute Plan Templar

## Pattern Purpose
Execute a pre-written `plan.md` from a ticket folder systematically: follow steps in order, create the required deliverables, validate success criteria, and record progress.

## When to Use
- A ticket already has a detailed `plan.md` and work should proceed against it
- You want consistent plan execution + validation + progress logging

## Deterministic Steps
1) Read `plan.md` thoroughly (objective, acceptance criteria, work breakdown, constraints)  
2) Read `context.md` if present (components, dependencies, constraints, next steps)  
3) Execute phases/steps in order; create all deliverables referenced by the plan  
4) Validate against acceptance criteria and any required checks/scripts  
5) Update `progress.md` with a session entry (accomplished/decisions/issues/next steps)  

## Expected Output
- Current phase and what was completed
- Deliverables created (file list)
- Validation status against success criteria
- Issues/deviations (or explicit blockers)
- Next steps

