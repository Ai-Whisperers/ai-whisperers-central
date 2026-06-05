---
name: execute-plan
description: "Please execute pre-generated plan.md from ticket folder systematically with validation"
category: ticket
tags: ticket, execution, plan, implementation, deliverables, validation, workflow
argument-hint: "Ticket folder path (e.g., tickets/EPP-192/01-subtask/)"
rules:
  - .cursor/rules/ticket/ticket-workflow-rule.mdc
  - .cursor/rules/ticket/plan-rule.mdc
  - .cursor/rules/ticket/progress-rule.mdc
  - .cursor/rules/ticket/validation-before-completion-rule.mdc
---

# Execute Ticket Plan

Please execute a pre-generated plan.md from the referenced ticket folder, following all steps systematically and creating all specified deliverables.

**Pattern**: Plan Execution Pattern ⭐⭐⭐⭐⭐  
**Effectiveness**: Essential for executing pre-planned work systematically  
**Use When**: Working through tickets with pre-generated plans

---

## Purpose

This prompt enables systematic execution of pre-generated ticket plans by:
- Reading plan.md from the specified folder
- Understanding objectives and acceptance criteria
- Executing implementation steps in order
- Creating all specified deliverables
- Validating against success criteria
- Documenting progress as work proceeds

Use this when you have a detailed plan.md ready and need to execute it.

---

## Decision Tree

```
Do you have a pre-generated plan.md?
├─ YES → Use this prompt (execute-plan)
└─ NO → Use start-ticket.prompt.md to create plan first

Is plan.md detailed and actionable?
├─ YES → Continue with execution
└─ NO → Use activate-ticket.prompt.md to review/update plan

Are you resuming existing work?
├─ YES → Check progress.md first, then execute remaining steps
└─ NO → Start fresh from Step 1

Is plan blocked or needs changes?
├─ YES → Document blocker in progress.md, update plan if needed
└─ NO → Execute systematically
```

---

## Required Context

```xml
<ticket>
  <folder>[TICKET_FOLDER_PATH]</folder>
  <action>execute plan</action>
</ticket>
```

**Placeholder Conventions**:
- `[TICKET_FOLDER_PATH]` - Path to ticket folder containing plan.md (e.g., tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/)

**User will typically reference folder via @mention**

---

## Process

Follow these steps to execute the plan:

### Step 1: Read Plan Documentation
- Read `plan.md` from the referenced folder
- Understand objectives and acceptance criteria
- Review work breakdown and phases
- Note dependencies and constraints
- Check success criteria

### Step 2: Understand Context
- Read `context.md` if present
- Understand relevant components and architecture
- Note technical considerations
- Identify integration points

### Step 3: Execute Implementation Steps
- Follow steps in order as specified in plan
- Implement changes file-by-file
- Create all deliverables specified in plan
- Apply relevant coding standards and patterns
- Run tests and validations as specified

### Step 4: Validate Deliverables
- Check against success criteria in plan
- Verify all deliverables created
- Run specified tests/validations
- Measure metrics if required (complexity, coverage, etc.)
- Ensure quality standards met

### Step 5: Document Progress
- Update `progress.md` with session log entry
- Document what was accomplished
- Note any decisions made
- Record any deviations from plan
- Update next steps

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Read Plan Thoroughly**: Understand the full scope before starting
2. **Identify Dependencies**: Note what needs to be done first
3. **Follow Step Order**: Execute phases/steps in specified sequence
4. **Create All Deliverables**: Don't skip any specified outputs
5. **Validate Continuously**: Check work against criteria as you go
6. **Document as You Work**: Update progress.md throughout session
7. **Handle Issues**: If blocked, document in progress and explain
8. **Verify Completion**: Confirm all criteria met before claiming done

---

## Output Format

When executing a plan, AI must report progress with:

```markdown
## 🚀 Executing Plan: [TICKET-ID]

**Folder**: [TICKET_FOLDER_PATH]
**Plan**: [Brief plan summary]
**Phase**: [Current phase being executed]

---

### ✅ Steps Completed

#### [Phase/Step Name]
- ✅ [Specific action completed]
- ✅ [Specific action completed]
- ⚙️ [In progress action]

---

### 📁 Deliverables Created

- ✅ [File/artifact created] - [Purpose]
- ✅ [File/artifact created] - [Purpose]

---

### 🎯 Validation Status

- [✅/⚠️/❌] [Success criterion] - [Status/result]
- [✅/⚠️/❌] [Success criterion] - [Status/result]

---

### ⚠️ Issues / Deviations

[Any problems encountered, deviations from plan, or blockers]

---

### ⏭️ Next Steps

[What comes next - next phase, next sub-ticket, or validation]

---

**Progress Updated**: `progress.md` updated with session log
```

---

## Examples (Few-Shot)

See exemplar for complete worked examples:
- `.cursor/prompts/exemplars/ticket/ticket-execute-plan-exemplar.md`

---

## Quality Criteria

Before marking plan execution complete:

- [ ] Plan.md read and understood thoroughly
- [ ] All phases/steps executed in order
- [ ] All deliverables created as specified
- [ ] All success criteria validated
- [ ] All validation checks passed
- [ ] Progress.md updated with session log
- [ ] Any deviations documented with rationale
- [ ] Next steps identified and clear
- [ ] If multi-phase, ready for next phase
- [ ] If final phase, completion criteria met

---

## Anti-Patterns

### ❌ DON'T: Skip reading the plan
```markdown
[Starts implementing without reading plan.md]
```
**Why bad**: Miss critical requirements, dependencies, or validation criteria

✅ **DO: Read plan thoroughly first**
```markdown
Step 1: Reading plan.md...
- Objectives: [List]
- Phases: [List]
- Deliverables: [List]
- Success Criteria: [List]

Now executing Phase 1...
```

### ❌ DON'T: Cherry-pick easy steps
```markdown
✅ Created simple file
✅ Updated comment
⚠️ Skipping complex refactoring (too hard)
```
**Why bad**: Plan incomplete, success criteria not met

✅ **DO: Execute all steps systematically**
```markdown
Phase 1:
✅ Step 1 complete
✅ Step 2 complete
⚙️ Step 3 in progress (complex but working through it)
```

### ❌ DON'T: Skip validation
```markdown
✅ All steps complete
[No validation against success criteria]
Done!
```
**Why bad**: Work might not meet requirements, might have missed something

✅ **DO: Validate thoroughly**
```markdown
### Validation Status
- ✅ Criterion 1: Verified by [evidence]
- ✅ Criterion 2: Tested with [test]
- ✅ Criterion 3: Measured at [metric]

All criteria met ✅
```

---

## Troubleshooting

### Issue: Plan.md not found in folder

**Cause**: Incorrect folder path or plan not yet created  
**Solution**:
1. Verify folder path is correct
2. Check if plan.md exists in folder
3. If missing, use `/start-ticket` to create plan first

### Issue: Plan is too vague to execute

**Cause**: Plan lacks detail or specific steps  
**Solution**:
1. Use `/activate-ticket` to review and enhance plan
2. Add specific implementation steps
3. Define clear deliverables and success criteria
4. Then use `/execute-plan` again

### Issue: Execution blocked by dependency

**Cause**: External dependency not available  
**Solution**:
1. Document blocker in progress.md (see Example 3)
2. Note what's needed to unblock
3. Update next steps with resolution actions
4. Pause execution until blocker resolved

### Issue: Plan needs changes mid-execution

**Cause**: Discovered new requirements or constraints  
**Solution**:
1. Document discovery in progress.md
2. Note deviation from original plan
3. Update plan.md with new information
4. Continue with adjusted plan
5. Document rationale for changes

### Issue: Unclear what "done" means

**Cause**: Success criteria not specific enough  
**Solution**:
1. Review success criteria in plan.md
2. If unclear, interpret based on objectives
3. Document interpretation in progress.md
4. Validate against what criteria do exist
5. Note any ambiguity for future plan improvements

---

## Usage

**Execute plan in referenced folder**:
```
Execute @execute-plan on @tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/
```

**Or via slash command (if setup)**:
```
/execute-plan @tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/
```

**With explicit ticket reference**:
```xml
<ticket>
  <id>EPP-192-RISKREDUCTION5-01</id>
  <action>execute plan</action>
  <folder>tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/</folder>
</ticket>
```

---

## Related Prompts

- `ticket/start-ticket.prompt.md` - Create new ticket with plan
- `ticket/activate-ticket.prompt.md` - Resume existing ticket
- `ticket/update-progress.prompt.md` - Document progress
- `ticket/validate-completion.prompt.md` - Final validation before completion
- `ticket/check-status.prompt.md` - Review ticket status
- `templars/ticket/ticket-execute-plan-templar.md` - Reusable plan execution structure

---

## Related Rules

Follows workflow from:
- `.cursor/rules/ticket/ticket-workflow-rule.mdc` - Overall ticket workflow
- `.cursor/rules/ticket/plan-rule.mdc` - Plan documentation standards
- `.cursor/rules/ticket/progress-rule.mdc` - Progress tracking standards
- `.cursor/rules/ticket/validation-before-completion-rule.mdc` - Completion validation

---

## Extracted Patterns

- **Templar**: `.cursor/prompts/templars/ticket/ticket-execute-plan-templar.md`
- **Exemplar**: `.cursor/prompts/exemplars/ticket/ticket-execute-plan-exemplar.md`

**Pattern**: Plan Execution Pattern  
**Use When**: Executing tickets with pre-generated plans  
**Created**: 2026-01-13  
**Improved**: 2026-01-13 (Added decision tree, troubleshooting, more examples, rule references)  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
