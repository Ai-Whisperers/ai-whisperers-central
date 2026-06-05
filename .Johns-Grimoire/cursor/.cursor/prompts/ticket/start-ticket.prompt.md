---
name: start-ticket
description: "Please initialize a new ticket with complete documentation structure and implementation plan"
category: ticket
tags: ticket, workflow, initialization, documentation, setup, planning
argument-hint: "Ticket ID and summary (e.g., EPP-192)"
---

# Start Working on Ticket

Please initialize complete ticket documentation and create an implementation plan for starting work.

**Pattern**: Ticket Initialization Pattern ⭐⭐⭐⭐⭐  
**Effectiveness**: Essential foundation for all ticket work  
**Use When**: Starting any new ticket, ensuring proper documentation and planning

---

## Purpose

This prompt establishes proper ticket foundation by:
- Creating structured ticket documentation folder
- Assessing complexity and determining implementation strategy
- Gathering relevant context and dependencies
- Planning work breakdown with milestones
- Setting up tracking mechanisms
- Enabling smooth handoff and continuity

Use this when beginning work on any new ticket.

---

## Required Context

```xml
<ticket>
  <id>[TICKET_ID]</id>
  <summary>[TICKET_SUMMARY]</summary>
  <requirements>[DETAILED_REQUIREMENTS]</requirements> <!-- optional -->
</ticket>
```

**Placeholder Conventions**:
- `[TICKET_ID]` - Full ticket identifier (e.g., EPP-192, EBASE-12345)
- `[TICKET_SUMMARY]` - Brief description of ticket objective (1-2 sentences)
- `[DETAILED_REQUIREMENTS]` - Optional detailed requirements or link to specification

**Canonical XML Schema**:
```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>start ticket</action>
  <context>[TICKET_SUMMARY]</context>
  <requirements>[DETAILED_REQUIREMENTS]</requirements>
</ticket>
```

---

## Process

Follow these steps to initialize a ticket:

### Step 1: Gather Ticket Information
Collect ticket ID, summary, and any available detailed requirements or specifications.

### Step 2: Formulate Start Request
Use pattern with XML delimiters:
```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>start ticket</action>
  <context>[TICKET_SUMMARY]</context>
</ticket>
```

### Step 3: AI Creates Documentation Structure
AI generates complete ticket folder with plan.md, context.md, progress.md, and assesses complexity.

### Step 4: Review Generated Documentation
Check plan, complexity assessment, work breakdown, and implementation strategy.

### Step 5: Begin Implementation
Use activate-ticket or proceed with first task from plan.

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Understand Objective**: What problem does this ticket solve? What's the desired outcome?
2. **Assess Complexity**: Simple fix or complex implementation? How many components involved?
3. **Identify Dependencies**: What existing code/systems does this touch? What could break?
4. **Plan Approach**: What's the logical sequence of work? What are the milestones?
5. **Surface Unknowns**: What questions need answers? What research is needed?
6. **Estimate Effort**: Based on complexity, how much work is this?
7. **Create Documentation**: Generate plan.md, context.md, progress.md following templates
8. **Update Tracking**: Set current.md to this ticket

---

## Complexity Assessment Criteria

### Simple Fix (1-2 days, <3 files, straightforward)
- Single responsibility change
- Clear requirements
- Minimal risk
- Few dependencies
- Focused scope

### Complex Implementation (>2 days, >3 files, uncertainty)
- Multiple components affected
- Architectural impact
- Unclear or evolving requirements
- Significant risk
- Many dependencies
- Multi-phase work

Document assessment in `plan.md` with rationale.

---

## Ticket Folder Structure

Initialize folder at `tickets/[TICKET_ID]/` with these files:

```
tickets/
  [TICKET_ID]/
    plan.md          # Objectives, approach, acceptance criteria
    context.md       # Technical state, dependencies, next steps
    progress.md      # Session-by-session work log
    references.md    # Static file and conversation references (optional)
```

---

## Ticket Documentation Templates

Use the ticket templars/templates instead of duplicating full blocks inline:

- **plan.md**: `.cursor/templars/ticket/plan-template.md` (or `.cursor/templars/ticket/plan-templar.md`)
- **context.md**: `.cursor/templars/ticket/context-template.md` (or `.cursor/templars/ticket/context-templar.md`)
- **progress.md**: `.cursor/templars/ticket/progress-template.md` (or `.cursor/templars/ticket/progress-templar.md`)
- **references.md**: `.cursor/templars/ticket/references-template.md`
- **Index**: `.cursor/templars/ticket/templar-index.md`

---

## Examples (Few-Shot)

See exemplar for complete worked examples:
- `.cursor/prompts/exemplars/ticket/ticket-start-exemplar.md`

## Output Format

When starting a ticket, AI must respond with:

```markdown
## ✅ Ticket Initialized: [TICKET-ID]

**Ticket**: [TICKET-ID]
**Summary**: [Brief summary]
**Complexity**: [Simple Fix | Complex Implementation]

---

### 📁 Folder Structure Created

```
tickets/[TICKET-ID]/
  ├── plan.md          ✅ Created
  ├── context.md       ✅ Created
  ├── progress.md      ✅ Created
  └── [tracker.md]     ✅ Created (if Complex Implementation)
```

---

### 📊 Complexity Assessment

**Classification**: [Simple Fix | Complex Implementation]

**Rationale**: [Detailed reasoning based on criteria]

**Estimated Effort**: [X days/hours]
**Risk Level**: [Low | Medium | High]
**Components Affected**: [N components]

---

### 📋 Implementation Plan

**Strategy**: [High-level approach]

**Work Breakdown**:

**Phase 1**: [Phase name]
- Task 1
- Task 2

[More phases...]

**Total Tasks**: [N tasks across M phases]

---

### 🔗 Dependencies Identified

**Internal**: [List]
**External**: [List]

---

### ⚠️ Risks & Questions

**Risks**: [List with mitigations]
**Questions Needing Resolution**: [List]

---

### 🌿 Git Branch Suggestion

```bash
git checkout -b [type]/[TICKET-ID]-[description] [base-branch]
```

---

### ⏭️ Ready to Start

**Next Steps**: [List first 3 actions]

**Start with**: [Command to begin work]

---

**Files Created**: [List of generated files]
```

---

## Quality Criteria

Before marking ticket initialization complete:

- [ ] Ticket folder created with all required files
- [ ] Plan.md includes objectives, acceptance criteria, work breakdown
- [ ] Complexity assessment done with rationale
- [ ] Context.md documents relevant components and dependencies
- [ ] Progress.md initialized with first entry
- [ ] Current.md updated to reflect active ticket
- [ ] Implementation strategy defined and clear
- [ ] Risks identified with mitigation plans
- [ ] Questions surfaced for resolution
- [ ] Git branch naming follows conventions (if applicable)
- [ ] Estimated effort is reasonable based on complexity
- [ ] Tracker.md created if Complex Implementation with many tasks

---

## Anti-Patterns

### ❌ DON'T: Skip complexity assessment
```markdown
# Plan
Let's implement this feature.
[No complexity assessment]
```
**Why bad**: Can't determine appropriate implementation strategy, effort estimation, or risk level

✅ **DO: Assess and document complexity**
```markdown
## Complexity Assessment
**Classification**: Complex Implementation
**Rationale**: Affects 14 entities across 5 domains, requires UnitOfWork pattern integration, estimated 5-7 days work
```

### ❌ DON'T: Vague work breakdown
```markdown
## Tasks
- Implement feature
- Test it
- Done
```
**Why bad**: No actionable tasks, no milestones, no way to track progress

✅ **DO: Specific, phased breakdown**
```markdown
## Work Breakdown

### Phase 1: Core Infrastructure (Day 1-2)
- [ ] Create repository base classes
- [ ] Implement UnitOfWork pattern
- [ ] Create entity mappers

### Phase 2: Domain Repositories (Day 3-5)
- [ ] Markets domain (5 repositories)
- [ ] Products domain (3 repositories)
...
```

### ❌ DON'T: Generic context
```markdown
## Context
This ticket is about adding repositories.
[No technical detail]
```
**Why bad**: Future developers have no context, can't resume work effectively

✅ **DO: Detailed technical context**
```markdown
## Current Technical State

### Relevant Components
- **Data Access Layer** (`src/DataAccess/`): Currently uses ADO.NET directly
- **Domain Entities** (`src/Domain/Configuration/`): 14 entities need repositories
- **Connection Management** (`src/Infrastructure/Database/`): Existing connection pooling

### Architecture Context
Currently using direct ADO.NET calls scattered across service layer. Implementing repository pattern to centralize data access, enable unit testing with mocks, and prepare for future ORM migration.
```

---

## Usage

**Start new ticket**:
```xml
<ticket>
  <id>EPP-192</id>
  <action>start ticket</action>
  <context>Implement unit test coverage for Calendar domain</context>
</ticket>
```

**Start with detailed requirements**:
```xml
<ticket>
  <id>EBASE-12345</id>
  <action>start ticket</action>
  <context>Implement repository pattern for configuration tables</context>
  <requirements>
    14 entities across 5 domains need repositories:
    - Markets: Country, Market, GridPointType, MarketParty, MarketRole
    - Products: MeterProduct, MeterPictogram, PhysicalProduct
    - Profiles: Profile, ProfileClass
    - Calendars: Calendar, CalendarEntry, CalendarDate
    - Units: MeasurementUnit
  </requirements>
</ticket>
```

---

## Related Prompts

- `ticket/activate-ticket.prompt.md` - Resume work on existing ticket
- `ticket/update-progress.prompt.md` - Document session progress
- `ticket/check-status.prompt.md` - Review ticket status
- `ticket/close-ticket.prompt.md` - Complete and close ticket
- `ticket/catchup-on-ticket.prompt.md` - Catch up on ticket history
- `templars/ticket/ticket-start-templar.md` - Reusable initialization structure

---

## Related Rules

Follows workflow from:
- `.cursor/rules/ticket/ticket-workflow-rule.mdc` - Overall ticket workflow
- `.cursor/rules/ticket/complexity-assessment-rule.mdc` - Complexity classification criteria
- `.cursor/rules/ticket/plan-rule.mdc` - Plan documentation standards
- `.cursor/rules/ticket/context-rule.mdc` - Context documentation standards
- `.cursor/rules/git/branch-naming-rule.mdc` - Branch naming conventions

---

## Extracted Patterns

- **Templar**: `.cursor/prompts/templars/ticket/ticket-start-templar.md`
- **Exemplar**: `.cursor/prompts/exemplars/ticket/ticket-start-exemplar.md`

**Pattern**: Ticket Initialization Pattern  
**Use When**: Starting any new ticket  
**Created**: 2025-12-06  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0  
**Improved**: 2025-12-08 (PROMPTS-OPTIMIZE ticket)
