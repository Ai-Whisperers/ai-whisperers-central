---
name: fix-plan
description: "Fix a ticket's plan based on validation issues - automatically address blockers, must-fix items, and improve plan quality"
category: ticket
tags: ticket, plan, fix, validation, quality-improvement, planning, auto-fix
argument-hint: "Ticket ID or path to plan.md (e.g., @tickets/AI-002/plan.md or AI-002), optionally include validation report"
rules:
  - .cursor/rules/ticket/plan-rule.mdc
  - .cursor/rules/ticket/complexity-assessment-rule.mdc
  - .cursor/rules/ticket/validation-before-completion-rule.mdc
---

# Fix Ticket Plan

Automatically fix a ticket's plan.md based on validation issues identified by plan validation. This prompt takes validation feedback and applies systematic fixes to improve plan quality.

**Pattern**: Plan Fix Pattern ⭐⭐⭐⭐⭐  
**Effectiveness**: Rapidly improves plan quality based on validation feedback  
**Use When**: After validation identifies issues, to quickly address blockers and must-fix items

---

## Purpose

This prompt automates the plan improvement process by:
- Reading validation report to understand issues found
- Systematically addressing each blocker and must-fix item
- Improving plan sections that failed validation categories
- Ensuring OPSEC compliance by redacting sensitive information
- Making acceptance criteria testable and specific
- Clarifying vague objectives and requirements
- Adding missing required sections
- Re-validating to confirm all issues resolved

**Fix Philosophy**: Address validation issues systematically, following priority order (blockers first, then must-fix items), ensuring plan becomes clear, complete, and executable.

Use this after validation to quickly improve plan quality before execution.

---

## Required Context

```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>fix plan</action>
</ticket>
```

**Or directly reference plan file**:
```
@tickets/[TICKET_ID]/plan.md please fix this plan based on validation issues
```

**With validation report**:
```
@tickets/[TICKET_ID]/plan.md 
@validation-report.md (or paste validation output)
please fix the plan
```

**Placeholder Conventions**:
- `[TICKET_ID]` - Ticket identifier (e.g., AI-002, EPP-192, EBASE-12345)

---

## Process

Follow these steps to fix a plan:

### Step 1: Identify Plan and Validation Issues

Determine which ticket's plan needs fixing:
- From explicit ticket ID in request
- From @-mentioned plan.md file
- From current ticket context

Load validation feedback:
- From @-mentioned validation report
- From pasted validation output in request
- If no validation provided, run validation first: `@validate-plan [TICKET_ID]`

### Step 2: Load Plan Content

Read the complete `tickets/[TICKET_ID]/plan.md` file to understand current state.

### Step 3: Analyze Validation Issues

Review validation report to identify:
- Blockers (🔴) - must fix before execution
- Must-Fix items (🟡) - should fix before execution
- Nice-to-Have items (🟢) - optional improvements
- Failed validation categories
- Specific evidence and recommended fixes

### Step 4: Apply Fixes in Priority Order

Fix issues systematically:

1. **OPSEC Violations** (highest priority if present)
   - Redact credentials, internal paths, PII
   - Replace with generic references or vault references
   
2. **Missing Required Sections**
   - Add Complexity Assessment if missing
   - Add any other required sections
   
3. **Vague Objective**
   - Clarify what's being built and why
   - Add scope boundaries
   - Make specific and unambiguous
   
4. **Non-Actionable Requirements**
   - Make requirements specific and detailed
   - Replace vague items with concrete specifications
   - Ensure each requirement is implementable
   
5. **Non-Testable Acceptance Criteria**
   - Convert subjective criteria to objective/measurable
   - Add checkboxes `- [ ]` format
   - Ensure each criterion maps to requirements
   - Include edge cases
   
6. **Unclear Implementation Strategy**
   - Define clear approach with 3-5 phases/steps
   - Specify files/components affected
   - Name technologies/patterns to use
   - Make actionable for developer
   
7. **Incomplete Complexity Assessment**
   - Add Track (Simple Fix or Complex Implementation)
   - Provide rationale with justification
   - List criteria met with specific values
   
8. **Other Issues**
   - Address remaining must-fix items
   - Optionally improve nice-to-have items

### Step 5: Update Plan File

Write the improved plan back to `tickets/[TICKET_ID]/plan.md`.

### Step 6: Re-Validate

Run validation on the updated plan to confirm all issues resolved:
```xml
<ticket><id>[TICKET_ID]</id><action>validate plan</action></ticket>
```

### Step 7: Report Results

Show summary of:
- What was fixed (issues addressed)
- Validation results after fixes
- Whether plan is now ready for execution
- Any remaining items requiring human input

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Load Context**: Read plan.md and validation report
2. **Identify Issues**: Extract blockers and must-fix items from validation
3. **Prioritize**: Order fixes by severity (OPSEC → structure → content quality)
4. **Apply Fixes Systematically**: 
   - For OPSEC: Redact and replace with generic/vault references
   - For structure: Add missing sections with appropriate content
   - For vague content: Make specific, concrete, actionable
   - For testability: Convert subjective to objective/measurable
5. **Preserve Intent**: Keep the original goal/intent, just make it clearer
6. **Don't Over-Fix**: Address validation issues, don't rewrite unnecessarily
7. **Re-Validate**: Confirm fixes resolved the issues
8. **Be Honest**: If can't fix without more context, explain what's needed

**Critical Mindset**: Fix what validation flagged, preserve developer's intent, make plan executable.

---

## Fix Modes

Choose fix depth based on context:

### Quick Fix (1-2 minutes)
- Address only blockers
- Minimal changes to pass validation
- Use when: Time-sensitive, simple fixes needed

### Standard Fix (3-5 minutes) ⭐ Default
- Address all blockers and must-fix items
- Improve failed validation categories
- Use when: Most situations, want solid plan quality

### Comprehensive Fix (5-10 minutes)
- Address blockers, must-fix, and nice-to-have
- Enhance all sections for optimal quality
- Add optional sections (Testing Strategy, Notes)
- Use when: Important ticket, want exceptional plan quality

---

## Fix Patterns by Issue Type

Use these quick patterns (keep changes minimal; fix only what validation flagged):

- **Vague Objective**: add scope boundaries + a clear success statement.
- **Non-actionable Requirements**: convert to concrete, implementable bullets.
- **Non-testable Acceptance Criteria**: convert to checkboxes with measurable pass/fail conditions.
- **Placeholder Strategy**: add 3–5 steps + affected files/components + validation steps.
- **Missing/weak Complexity Assessment**: add Track + Rationale + criteria.
- **OPSEC**: redact secrets/PII/internal paths/hostnames; replace with generic/vault references; never echo credentials.

Prefer keeping detailed examples in exemplars (avoid embedding sensitive paths/hosts in prompt text).

See: `../exemplars/ticket/ticket-fix-plan-patterns-exemplar.md`

## Output Format

```markdown
## 🔧 Plan Fix Report: [TICKET-ID]

**Ticket**: [TICKET-ID] - [Title]  
**Plan Path**: `tickets/[TICKET-ID]/plan.md`  
**Fix Date**: [YYYY-MM-DD]  
**Fix Mode**: [Quick | Standard | Comprehensive]

---

### Fix Summary

**Issues Addressed**:
- **Blockers Fixed**: [N] 🔴
- **Must-Fix Items Fixed**: [N] 🟡
- **Nice-to-Have Improved**: [N] 🟢

**Validation Status**:
- **Before Fixes**: [X]/8 categories passing ([XX]%)
- **After Fixes**: [Y]/8 categories passing ([YY]%)
- **Improvement**: +[Y-X] categories

---

### Changes Made

#### 1. [Issue Title] - 🔴 BLOCKER
**Problem**: [What was wrong]  
**Section**: [Which section in plan.md]  
**Fix Applied**: [What was changed]

**Before**:
```markdown
[Original content snippet]
```

**After**:
```markdown
[Fixed content snippet]
```

**Result**: [Category now passes validation / Issue resolved]

[Repeat for each fix applied]

---

### Re-Validation Results

[Output from re-validation - either full validation report or summary]

#### Validation Summary After Fixes

**Overall**: [✅ PASS | ⚠️ PASS WITH WARNINGS | ❌ STILL HAS ISSUES] ([Y]/8 categories)  
**Status**: [✅ PLAN READY | ⚠️ PLAN READY WITH CAUTIONS | ❌ PLAN STILL NOT READY]

**Remaining Issues** (if any):
- [Any issues that couldn't be auto-fixed]

---

### 📋 Recommendation

[If plan now ready:]
**✅ PLAN IS READY FOR EXECUTION**

All validation issues have been addressed. Plan is clear, complete, and executable.

**Next Steps**:
```xml
<ticket><id>[TICKET_ID]</id><action>please start</action></ticket>
```

[If plan has improvements but needs human input:]
**⚠️ PLAN IMPROVED BUT NEEDS HUMAN INPUT**

Addressed [N] automated fixes, but [M] items require human input:
- [Issue requiring human input with explanation]

**Next Steps**:
1. Review items requiring human input
2. Update plan manually for these items
3. Re-validate: `@validate-plan [TICKET_ID]`
4. When validation passes, proceed to execution

[If plan still has issues:]
**❌ PLAN STILL HAS ISSUES**

Fixed [N] items but [M] blockers remain:
- [Remaining blocker with explanation]

**Next Steps**:
1. Address remaining blockers manually
2. Re-validate: `@validate-plan [TICKET_ID]`
3. May need additional context or clarification
```

---

## Items Requiring Human Input

Sometimes fixes require context that only the developer has:

### Scenario 1: Unclear Technical Details
**Issue**: Don't know specific files/components affected  
**Auto-Fix Limitation**: Can't invent technical details  
**Human Input Needed**: Developer must specify affected files, APIs, or components

### Scenario 2: Ambiguous Requirements
**Issue**: Requirement is vague but can't determine correct specificity without domain knowledge  
**Auto-Fix Limitation**: Risk of guessing wrong requirements  
**Human Input Needed**: Developer must clarify exact requirements based on business context

### Scenario 3: Missing Business Context
**Issue**: Acceptance criteria need specific thresholds (e.g., "How fast is fast enough?")  
**Auto-Fix Limitation**: Can't determine appropriate performance/quality thresholds  
**Human Input Needed**: Developer must specify measurable targets based on requirements

### Scenario 4: Complex Architectural Decisions
**Issue**: Implementation strategy requires choosing between multiple valid approaches  
**Auto-Fix Limitation**: Can't make architectural decisions without trade-off evaluation  
**Human Input Needed**: Developer must evaluate options and document chosen approach

**In these cases**: Fix what can be automated, clearly document what needs human input, provide guidance on what information is needed.

---

## Anti-Patterns

### ❌ DON'T: Over-fix beyond validation issues

**Bad**:
```
Validation flagged missing complexity assessment.
Fix: Rewrote entire plan from scratch.
```

**Why bad**: Loses developer's original intent, creates unnecessary churn

**Good**:
```
Validation flagged missing complexity assessment.
Fix: Added Complexity Assessment section with Track, Rationale, Criteria Met. Preserved all other sections as-is.
```

---

### ❌ DON'T: Guess technical details

**Bad**:
```
Requirement was vague "improve performance".
Fix: Changed to "Reduce API response time from 2s to 500ms by adding Redis cache"
```

**Why bad**: Invented specific numbers and solution without evidence

**Good**:
```
Requirement was vague "improve performance".
Fix: Changed to "Optimize calendar event query performance - measure current response time and reduce by 50% (target: <500ms for typical user query with 100 events)". 
Note: Requires developer to measure baseline and confirm target is achievable.
```

---

### ❌ DON'T: Skip re-validation

**Bad**:
```
Applied fixes. Plan is probably good now.
```

**Why bad**: Don't know if fixes actually resolved the issues

**Good**:
```
Applied 5 fixes addressing all blockers.
Re-validating...
✅ Validation now passes: 8/8 categories. Plan ready for execution.
```

---

### ❌ DON'T: Fix OPSEC violations partially

**Bad**:
```
Removed password but left internal server hostname.
```

**Why bad**: Still exposes internal infrastructure

**Good**:
```
Removed all sensitive data: credentials, internal paths, server names, production identifiers. Replaced with vault references and generic descriptions.
```

---

## Critical Rules

### ✅ DO when fixing plans:
- **Address blockers first**: OPSEC violations and missing required sections have highest priority
- **Preserve intent**: Keep the original goal/purpose, just make it clearer
- **Make specific**: Convert vague to concrete, subjective to objective
- **Add evidence**: Show before/after for each fix
- **Re-validate**: Always confirm fixes resolved the issues
- **Document limitations**: Clearly state what requires human input

### 🚫 DO NOT when fixing plans:
- **Guess technical details**: Don't invent file names, APIs, performance numbers without evidence
- **Make architectural decisions**: Don't choose between multiple valid approaches without context
- **Over-fix**: Don't rewrite sections that passed validation
- **Skip OPSEC**: Don't leave any credentials, internal paths, or PII
- **Assume success**: Don't claim plan is fixed without re-validation

### ⚠️ When human input needed:
- **Be explicit**: State exactly what information is needed and why
- **Provide guidance**: Suggest what developer should consider or measure
- **Don't block**: Fix what can be automated, document what can't

---

## Usage

### Fix plan for specific ticket:
```xml
<ticket>
  <id>AI-002</id>
  <action>fix plan</action>
</ticket>
```

### Fix plan using file reference:
```
@tickets/AI-002/plan.md please fix this plan based on validation issues
```

### Fix with validation report included:
```
@tickets/AI-002/plan.md 
@validation-report.md
please fix the plan
```

### Fix in comprehensive mode:
```
@fix-plan AI-002 --mode comprehensive
```

### Recommended workflow (validate → fix → re-validate):
```xml
<!-- Step 1: Validate plan -->
<ticket><id>AI-002</id><action>validate plan</action></ticket>

<!-- Step 2: If issues found, fix automatically -->
<ticket><id>AI-002</id><action>fix plan</action></ticket>

<!-- Step 3: Review fix report and address any items needing human input -->

<!-- Step 4: Once plan ready, proceed to execution -->
<ticket><id>AI-002</id><action>please start</action></ticket>
```

---

## Related Prompts

- `ticket/validate-plan.prompt.md` - Validate plan quality before fixing
- `ticket/start-ticket.prompt.md` - Start ticket execution after plan fixed
- `ticket/update-progress.prompt.md` - Update progress during execution
- `ticket/validate-completion.prompt.md` - Validate work is complete
- `ticket/create-ticket.prompt.md` - Create new ticket with quality plan

---

## Related Rules

Apply planning standards from:
- `.cursor/rules/ticket/plan-rule.mdc` - Plan structure and content requirements
- `.cursor/rules/ticket/complexity-assessment-rule.mdc` - Complexity assessment standards
- `.cursor/rules/ticket/validation-before-completion-rule.mdc` - Validation principles
- `.cursor/rules/quality/zero-warnings-zero-errors-rule.mdc` - Quality gate standards

---

## Extracted Patterns

**Pattern**: Plan Fix Pattern  
**Use When**: After validation identifies issues in ticket plan  
**Critical Success Factor**: Systematic fixes addressing validation feedback in priority order  
**Effectiveness**: ⭐⭐⭐⭐⭐ Rapidly improves plan quality with minimal manual effort

---

**Created**: 2026-01-15  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.1.0  
**Companion to**: `ticket/validate-plan.prompt.md`
