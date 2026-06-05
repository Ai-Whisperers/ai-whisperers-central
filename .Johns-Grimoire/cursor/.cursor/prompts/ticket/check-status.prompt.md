---
name: check-status
description: "Request a comprehensive status review of a project, epic, or ticket"
category: ticket
tags: ticket, status, progress, reporting, assessment
argument-hint: "Project or Ticket ID (e.g., @EPP-192 please review status)"
---

# Check Status (Pattern-Based)

This prompt requests a comprehensive status review of a project, epic, or ticket.

**Pattern**: Status Check Pattern ⭐⭐⭐⭐  
**Effectiveness**: Essential for informed decision-making  
**Use When**: Understanding progress, deciding next actions, coordinating cross-repo work

---

## Required Context

- **Project/Ticket ID**: What to check status for (e.g., EPP-192, EBASE-12345, @roadmap.md)
- **Aspect** (Optional): Specific area to focus on (overall, implementation, testing, completion readiness)
- **Documentation Files**: Roadmap, plan, progress, context files (loaded automatically by AI)

---

## Process

Follow these steps to request a status check:

### Step 1: Identify What to Check
Determine scope:
- **Project-wide**: Entire project or epic
- **Ticket-specific**: Single ticket progress
- **Focused aspect**: Specific area (implementation, testing, dependencies)
- **Cross-repo**: Multiple related tickets

### Step 2: Formulate Status Request
Use canonical XML schema:
```xml
<ticket>
  <id>@[PROJECT_OR_TICKET_ID]</id>
  <action>check status</action>
  <context>[ASPECT]</context>
</ticket>
```

Or simplified for overall status:
```xml
<ticket>
  <id>@[PROJECT_OR_TICKET_ID]</id>
  <action>check status</action>
</ticket>
```

### Step 3: Add Context (if helpful)
Explain why you're checking:
```
<ticket><id>@[PROJECT_OR_TICKET_ID]</id><action>check status</action></ticket>

<context>We completed initial export testing. Need to orient before continuing with import.</context>
```

### Step 4: Review Status Report
Read AI's synthesized status covering completed/in-progress/remaining/blockers.

### Step 5: Act on Information
Proceed with next logical action based on status (see Follow-up Patterns).

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Load Documentation**: Read roadmap, plan, progress, context files for specified ticket/project
2. **Parse Current State**: Identify what's done, in progress, pending, blocked
3. **Analyze Progress**: Calculate completion percentages, assess dependencies
4. **Identify Blockers**: Surface any issues preventing progress with impact assessment
5. **Cross-Reference**: Check related tickets if multi-repo context
6. **Synthesize Report**: Present comprehensive status summary with evidence
7. **Recommend Next Steps**: Suggest logical next actions based on current state

---

## Basic Usage

```
<ticket><id>@[PROJECT_OR_TICKET_ID]</id><action>check [ASPECT] status</action></ticket>
```

**Placeholder Conventions**:
- `[PROJECT_OR_TICKET_ID]` - Epic (EPP-192), Project folder, or Ticket ID (EBASE-12345)
- `[ASPECT]` - Specific focus area (optional: "implementation", "testing", "completion readiness", "progress")

---

## Status Check Types

### 1. Overview Check (Big Picture)
```
<ticket><id>@EPP-192</id><action>check current status</action></ticket>
```
**AI delivers**: Comprehensive view of all aspects, overall progress, all work streams

### 2. Focused Check (Specific Aspect)
```
<ticket><id>@EPP-192</id><action>check <aspect>export implementation</aspect> status</action></ticket>
```
**AI delivers**: Deep dive into specific feature/aspect, detailed progress on that area

### 3. Completion Check (Validation)
```
<ticket><id>@EBASE-12345</id><action>are we ready to mark this complete?</action></ticket>
```
**AI delivers**: Readiness assessment, acceptance criteria validation, blockers to completion

### 4. Dependency Check (Coordination)
```
Is <ticket><id>@TICKET-A</id></ticket> done? I need it for <ticket><id>@TICKET-B</id></ticket>
```
**AI delivers**: Status of dependency, impact on dependent work, recommendations

### 5. Cross-Repo Sync (Multi-Repo Coordination)
```
<ticket><id>@foundation-ticket</id><action>check progress</action></ticket>, then continue on <ticket><id>@datamigrator-ticket</id><action>check progress</action></ticket>
```
**AI delivers**: Status of both tickets, coordination guidance, conditional next steps

### 6. Milestone Progress (Goal Assessment)
```
<ticket><id>@roadmap.md</id><action>what's left before we can release?</action></ticket>
```
**AI delivers**: Remaining work for milestone, blockers to release, timeline estimate

---

## Examples (Few-Shot)

See exemplar for complete worked examples:
- `.cursor/prompts/exemplars/ticket/ticket-status-diagnostic-exemplar.md`

## Output Format

When providing status check, AI must structure response as:

```markdown
## Current Status Summary: [TICKET/PROJECT-ID]

**[Item]**: [Name]  
**Overall Progress**: [X]% complete  
**Started**: [Date]  
**Last Activity**: [Date]

---

### Completed ✅

[List of completed items with completion dates and evidence]

- ✅ [Item 1]: [Brief description] ([Date])
- ✅ [Item 2]: [Brief description] ([Date])

---

### In Progress 🔄

[Current work items with status and progress]

- 🔄 [Item]: [What's being done] ([X]% complete)

---

### Remaining ⏳

[Pending work not yet started]

- [ ] [Item 1]: [Description]
- [ ] [Item 2]: [Description]

---

### Blockers/Dependencies 🚫

[Issues preventing progress, dependencies on other work]

- ⚠️ [Blocker]: [Description and impact]
- 🔗 [Dependency]: [What's needed and status]

---

### Next Recommended Steps →

1. [Most logical immediate action]
2. [Follow-up action]
3. [Alternative if blocked]

**Estimated Time to Completion**: [Time estimate]

---

**Files Reviewed**: [List of documentation files checked]
```

---

## Common Status Checks

### Project-Wide Status
```
<ticket><id>@EPP-192</id><action>review current project status</action></ticket>
```

### Ticket-Specific Progress
```
<ticket><id>@EBASE-12345</id><action>what's the current status?</action></ticket>
```

### Cross-Repo Coordination
```
<ticket><id>@foundation-ticket</id><action>check progress</action></ticket>, then continue on <ticket><id>@datamigrator-ticket</id><action>check progress</action></ticket>
```

### Completion Readiness
```
<ticket><id>@EBASE-12345</id><action>are we ready to mark this complete?</action></ticket>
```

### Milestone Progress
```
<ticket><id>@roadmap.md</id><action>what's left before we can release?</action></ticket>
```

---

## Status Check vs Catchup

### Use **Status Check** When:
- ✅ You're actively working on the ticket
- ✅ You need to know what's left to do
- ✅ You want structured progress report (not narrative)
- ✅ Preparing for next action or decision
- ✅ Need completion percentages
- ✅ Coordinating cross-repo work

### Use **Catchup** When:
- ✅ You've been away from the ticket
- ✅ You need to understand what happened (the story)
- ✅ You want narrative context with decisions and why
- ✅ Joining someone else's work
- ✅ Need to understand rationale behind current state

**Key Difference**: 
- **Status** = reporting (where we are, what's left)
- **Catchup** = storytelling (what happened, why decisions made)

---

## Quality Criteria

A good status report should have:

- [ ] All relevant documentation files reviewed (roadmap, plan, progress, context)
- [ ] Progress percentages calculated accurately with evidence
- [ ] Completed items listed with completion dates
- [ ] In-progress items clearly stated with current status
- [ ] Remaining items identified and estimated
- [ ] Blockers identified with impact assessment
- [ ] Dependencies noted (cross-ticket, cross-repo)
- [ ] Next steps are logical and actionable
- [ ] Completion estimate provided (if applicable)
- [ ] Files reviewed explicitly listed

---

## Follow-up Patterns

After status check, typically:

### 1. Ticket Activation (Start/Resume Work)
```
<ticket><id>@NEXT-TICKET</id><action>please start</action></ticket>
```

### 2. Validation-Before-Action (Complex Next Steps)
```
<spec>@spec.md</spec> <action>validate and execute</action>
```

### 3. Tracker Continuation (Resume Systematic Work)
```
<tracker>@tracker.md</tracker> <action>continue with remaining tasks</action>
```

### 4. Completion Validation (Ready to Close)
```
<ticket><id>@TICKET</id><action>validate completion</action></ticket>
```

---

## Tips

- Be specific about what aspect matters (overall vs focused)
- Provide context for why you're checking (helps AI prioritize info)
- Act on the information received (don't just collect status)
- Don't ask too broad - narrow to relevant area for actionable results
- Great before major decisions or work shifts
- Essential for cross-repo coordination
- Use before marking tickets complete

---

## Anti-Pattern (Don't Do This)

❌ **Too vague**:
```
What's happening with the project?
```
→ AI doesn't know what you care about or what level of detail you need

✅ **Specific and actionable**:
```
<ticket><id>@EPP-192</id><action>check export feature status - did Phase 2 complete?</action></ticket>
```
→ AI knows exactly what to report and at what level

---

## Related Prompts

- `ticket/catchup-on-ticket.prompt.md` - Narrative summary of what happened (storytelling focus)
- `ticket/activate-ticket.prompt.md` - After status check, start/resume work (action focus)
- `ticket/validate-before-action.prompt.md` - Before complex next steps (validation focus)
- `ticket/resume-tracker-work.prompt.md` - Resume systematic work (tracker focus)
- `ticket/validate-completion.prompt.md` - Final completion validation (readiness focus)
- `templars/ticket/ticket-status-diagnostic-templar.md` - Reusable status pattern
- `exemplars/ticket/ticket-status-diagnostic-exemplar.md` - Reference status output

---

## Extracted Patterns

- **Templar**: `.cursor/prompts/templars/ticket/ticket-status-diagnostic-templar.md`
- **Exemplar**: `.cursor/prompts/exemplars/ticket/ticket-status-diagnostic-exemplar.md`

---

**Source**: Pattern Discovery Analysis (48 conversations, Nov 22 - Dec 01, 2025)  
**Pattern ID**: #6 Status Check Pattern  
**Evidence**: conversations/JP/extracted/pattern-discovery-report.md  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0  
**Improved**: 2025-12-08 (PROMPTS-OPTIMIZE ticket)

