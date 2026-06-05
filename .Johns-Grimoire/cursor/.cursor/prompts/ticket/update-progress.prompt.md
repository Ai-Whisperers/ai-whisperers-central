---
name: update-progress
description: "Please update ticket progress documentation with session accomplishments"
category: ticket
tags: ticket, progress, documentation, update, tracking
argument-hint: "Ticket ID or 'current ticket'"
---

# Update Ticket Progress

Please update the progress documentation for the current ticket with the work completed in this session.

**Pattern**: Session Documentation Pattern ⭐⭐⭐⭐  
**Effectiveness**: Essential for maintaining work history and context  
**Use When**: End of work session, after significant milestones, before context switches

---

## Purpose

This prompt ensures systematic progress documentation by:
- Recording what was accomplished this session
- Documenting key decisions and rationale
- Tracking file changes and technical state
- Updating next steps based on current reality
- Maintaining append-only progress discipline

Use this at the end of work sessions or after completing significant milestones.

---

## Required Context

```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>update progress</action>
  <context>[BRIEF_SUMMARY]</context> <!-- optional -->
  <session_summary>[SESSION_SUMMARY]</session_summary>
</ticket>
```

**Placeholder Conventions**:
- `[TICKET_ID]` - Ticket identifier (e.g., EPP-192, EBASE-12345, or "current")
- `[SESSION_SUMMARY]` - Brief description of what was accomplished (1-2 sentences)

---

## Process

Follow these steps to update ticket progress:

### Step 1: Gather Session Information
Review what was accomplished:
- Files changed (git status, recent commits)
- Decisions made (from conversation, code comments)
- Issues encountered and resolved
- Time spent (from verifiable sources: git commits, file timestamps)

### Step 2: Formulate Update Request
Use canonical XML schema:
```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>update progress</action>
  <context>[BRIEF_SUMMARY]</context>
</ticket>
```

Or for current ticket:
```xml
<ticket>
  <action>update progress</action>
  <context>[BRIEF_SUMMARY]</context>
</ticket>
```

### Step 3: Review Generated Progress Entry
Check that AI created entry with accomplishments, decisions, changes, and next steps.

### Step 4: Verify Context Updates
Ensure context.md reflects new current state (not aspirational).

### Step 5: Proceed with Next Steps
Use updated next steps to continue work or close session.

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Review Session Work**: What was actually accomplished (not what was intended)?
2. **Identify Decisions**: What technical/design choices were made and why?
3. **Assess Impact**: How does this change the current state (technically and workflow-wise)?
4. **Determine Next Steps**: What logically comes next based on new state?
5. **Capture Timeline**: When did this work happen (from verifiable sources: git, file stats)?
6. **Append to Progress**: Add new entry to progress.md (NEVER edit previous entries)
7. **Update Context**: Adjust context.md to reflect current technical state

---

## Progress Entry Template

Append to `tickets/[TICKET_ID]/progress.md`:

```markdown
### [TIMESTAMP] - [Brief Session Title]

#### Session Summary
[1-2 sentence overview of what this session accomplished]

#### Accomplished
- [Specific accomplishment 1 with outcome]
- [Specific accomplishment 2 with outcome]
- [Specific accomplishment 3 with outcome]

#### Decisions
- **[Decision 1]**: [Rationale and context - WHY this choice]
- **[Decision 2]**: [Rationale and context - WHY this choice]

#### Changes
- `path/to/file1.cs` - [What changed and why]
- `path/to/file2.cs` - [What changed and why]

#### Issues/Blockers
- [Issue 1 and how resolved/mitigated]
- [Issue 2 and current status]

#### Metrics (if applicable)
- [Quantifiable progress: tests added, coverage %, files completed]

#### Next Steps
- [Immediate next action based on current state]
- [Follow-up task]
- [Dependency or blocker to address]
```

---

## Examples (Few-Shot)
Examples are extracted to keep this prompt compact. See: `../exemplars/ticket/ticket-update-progress-exemplar.md`

---

## Output Format

When updating progress, AI must respond with:

```markdown
## Progress Update Complete

**Ticket**: [TICKET-ID]
**Session**: [Timestamp]

### ✅ Progress Entry Added

New entry appended to `tickets/[TICKET-ID]/progress.md`:

[Full progress entry markdown as generated]

### 📝 Context Updated

Updated `tickets/[TICKET-ID]/context.md`:

**Current Technical State**: [Summary of changes]
**Focus Areas**: [Updated priorities]
**Immediate Next Steps**: [Updated actions]

### 📊 Status Assessment

- Completion: [X]% ([rationale])
- Remaining work: [estimate]
- On track: [Yes/No - with reason]

### ⏭️ Next Steps

1. [Most logical next action]
2. [Follow-up task]
3. [Dependency to address]

**Files Updated**:
- `tickets/[TICKET-ID]/progress.md` - New entry appended
- `tickets/[TICKET-ID]/context.md` - Current state updated
```

---

## Quality Criteria

Before marking progress update complete:

- [ ] Progress entry follows append-only discipline (no edits to previous entries)
- [ ] Accomplishments are specific and verifiable (not vague)
- [ ] Decisions include rationale (not just what, but WHY)
- [ ] File changes list specific files with descriptions
- [ ] Issues/blockers documented with resolution status
- [ ] Metrics quantify progress where applicable (percentages, counts)
- [ ] Next steps are logical based on current state (not original plan)
- [ ] Context.md reflects actual current technical state (not aspirational)
- [ ] Timestamps from verifiable sources (git, file stats, not estimated)

---

## Guidelines

### APPEND-ONLY Discipline

- **Never edit previous progress entries** (historical record must remain intact)
- Add new entry below existing entries
- If correction needed, add new entry clarifying/correcting previous entry

### Be Specific

❌ Vague:
- "Fixed bug"
- "Updated code"
- "Made changes"

✅ Specific:
- "Fixed memory leak in CacheManager.Dispose() by adding explicit WeakReference cleanup"
- "Refactored MarketRepository to use async/await throughout"
- "Added XML documentation to 10 domain entity classes (Market, MarketParty, ...)"

### Capture Context

- Document **WHY** decisions were made (not just what)
- Note discoveries that changed understanding
- Record blockers and how resolved
- Include alternatives considered

### Update Reality

- Context.md reflects **current state**, not aspirational state
- Next steps based on what's **actually done**, not original plan
- Adjust estimates based on actual progress rate

---

## Anti-Patterns

### ❌ DON'T: Vague progress entry
```markdown
#### Accomplished
- Worked on the feature
- Made some changes
- Fixed issues
```
**Why bad**: No specificity, can't understand what was done or verify completion

✅ **DO: Specific progress entry**
```markdown
#### Accomplished
- Implemented MarketRepository with full CRUD operations (Create, Read, Update, Delete, GetAll)
- Added async/await support to all repository methods (no blocking I/O)
- Created MarketEntityMapper for bidirectional domain/data conversions
```

### ❌ DON'T: Missing rationale
```markdown
#### Decisions
- Used Dapper
- Made mapper class
```
**Why bad**: No context for why decisions were made, can't evaluate if still appropriate

✅ **DO: Decisions with rationale**
```markdown
#### Decisions
- **Used Dapper for data access**: Chosen for performance and explicit SQL control vs EF Core's abstraction overhead. Need fine-grained query optimization for complex joins.
- **Separate mapper class**: Improves maintainability and testability vs inline conversion logic. Keeps repository focused on data access.
```

### ❌ DON'T: Edit previous entries
```markdown
### 2025-12-07 - Feature Work
~~Implemented feature~~ Actually found bug, fixed it instead
```
**Why bad**: Destroys historical record, makes it unclear what actually happened when

✅ **DO: Add new entry to clarify**
```markdown
### 2025-12-08 - Correction
Previous entry indicated feature implementation. Discovered critical bug during implementation that blocked feature work. Pivoted to fix bug first (see RCA in tickets/[ID]/rca.md). Will resume feature implementation after bug fix merged.
```

---

## Usage

**Update current ticket progress**:
```xml
<action>update progress for current ticket</action>
<session_summary>Implemented Market repository with CRUD operations</session_summary>
```

**Update specific ticket progress**:
```xml
<ticket>
  <id>EBASE-12345</id>
  <action>update progress</action>
  <context>Fixed memory leak by adding explicit cleanup</context>
  <session_summary>Fixed memory leak by adding explicit cleanup</session_summary>
</ticket>
```

---

## Related Prompts

- `ticket/activate-ticket.prompt.md` - Start/resume ticket work
- `ticket/check-status.prompt.md` - Review overall ticket status
- `ticket/close-ticket.prompt.md` - Final progress update when completing
- `ticket/catchup-on-ticket.prompt.md` - Understand ticket history

---

## Related Rules

Follows standards from:
- `.cursor/rules/ticket/progress-rule.mdc` - Progress documentation discipline
- `.cursor/rules/ticket/context-rule.mdc` - Context maintenance standards
- `.cursor/rules/ticket/timeline-tracking-rule.mdc` - Timeline tracking with verifiable sources

---

**Pattern**: Session Documentation Pattern  
**Use When**: End of work session, after significant milestones, before context switches  
**Created**: 2025-12-06  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0  
**Improved**: 2025-12-08 (PROMPTS-OPTIMIZE ticket)
