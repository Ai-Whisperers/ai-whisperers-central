---
type: templar
artifact-type: prompt
pattern-name: ticket-start
version: 1.0.0
applies-to: ticket prompts
implements: ticket.start-ticket
consumed-by:
  - .cursor/prompts/ticket/start-ticket.prompt.md
---

# Ticket Start / Initialization Templar

## Pattern Purpose
Initialize a ticket safely and consistently: create the required documentation structure, assess complexity, and produce a clear, actionable plan for immediate execution.

## When to Use
- Starting any new ticket
- Bootstrapping a new sub-ticket under an existing ticket umbrella
- Standardizing ticket documentation for handoff/continuity

## Deterministic Steps
1) Parse ticket ID, summary, and optional requirements  
2) Create/update `tickets/[TICKET_ID]/` folder structure  
3) Create baseline docs (`plan.md`, `context.md`, `progress.md`) and optional files (`references.md`, `tracker.md` when Complex)  
4) Classify complexity (Simple Fix vs Complex Implementation) with rationale  
5) Populate work breakdown with concrete phases/tasks  
6) Set `tickets/current.md` to this ticket  
7) Provide “next 3 steps” so execution can begin immediately  

## Expected Output
- A short “Ticket Initialized” confirmation with:
  - folder structure created
  - complexity assessment (classification + rationale)
  - plan summary + first tasks
  - dependencies/risks/questions
  - next steps (immediate)

## Quality Criteria
- [ ] Ticket folder + required files created
- [ ] Complexity classification includes rationale and effort estimate
- [ ] Plan includes actionable tasks (not vague)
- [ ] Context includes key files/components and immediate next steps
- [ ] `tickets/current.md` updated
- [ ] OPSEC-clean (no secrets/PII/absolute machine paths)

