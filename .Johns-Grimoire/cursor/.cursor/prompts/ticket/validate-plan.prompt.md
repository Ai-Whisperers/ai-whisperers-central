---
name: validate-plan
description: "Please validate that a ticket's plan is complete, clear, and ready for execution"
category: ticket
tags: ticket, plan, validation, quality-check, planning, pre-execution, quality-gate
argument-hint: "Ticket ID or path to plan.md (e.g., @tickets/AI-002/plan.md or AI-002)"
rules:
  - .cursor/rules/ticket/plan-rule.mdc
  - .cursor/rules/ticket/complexity-assessment-rule.mdc
  - .cursor/rules/ticket/validation-before-completion-rule.mdc
---

# Validate Ticket Plan

Validate a ticket’s `plan.md` as a **quality gate** before execution.

## Inputs

Use either:

```xml
<ticket>
  <id>[TICKET_ID]</id>
  <action>validate plan</action>
</ticket>
```

Or a direct file reference:

```text
@tickets/[TICKET_ID]/plan.md please validate this plan
```

## Process

1. **Locate plan**: Use the provided ticket ID/path; otherwise use `tickets/current.md`.
2. **Read plan**: Load `tickets/[TICKET_ID]/plan.md` completely.
3. **Validate all 8 categories**: Use the criteria below (don’t skip).
4. **Scan OPSEC**: Ensure no credentials, PII, internal hostnames, or absolute/internal paths.
5. **Produce report**: Follow the Output Format exactly and include evidence.

## Validation Categories (8)

### 1) Structure Completeness ✅❌

- **Required sections**: Objective, Requirements, Acceptance Criteria, Implementation Strategy, Complexity Assessment, Status.
- **Pass**: All required sections exist and contain meaningful content (no placeholders like TBD/TODO).
- **Evidence**: List sections found; call out missing/placeholder sections.

### 2) Objective Clarity ✅❌

- **Checks**: outcome-focused, explains why, in/out of scope, unambiguous.
- **Pass**: 2–5 sentences; a new developer can explain “what/why” without asking questions.
- **Evidence**: Quote the objective; point to scope boundaries.

### 3) Requirements Quality ✅❌

- **Checks**: enumerated list, actionable items, no contradictions, includes non-functional requirements when relevant.
- **Pass**: 3+ specific, implementable requirements.
- **Evidence**: Count requirements; cite any vague items.

### 4) Acceptance Criteria Quality ✅❌

- **Checks**: checkbox format (`- [ ]`), testable/verifiable, covers requirements, includes key edge cases.
- **Pass**: 3+ objective criteria with clear pass/fail.
- **Evidence**: Count criteria; identify any subjective criteria.

### 5) Implementation Strategy Clarity ✅❌

- **Checks**: approach/pattern defined, major steps/phases, key files/components touched, risks/mitigations where relevant.
- **Pass**: actionable sequence a developer can start from.
- **Evidence**: Cite the first concrete implementation step and where it happens.

### 6) Complexity Assessment ✅❌

- **Required**: Track (Simple Fix | Complex Implementation), rationale, criteria considered (files/lines/risk/pattern familiarity).
- **Pass**: Track + rationale + concrete criteria evidence.
- **Evidence**: Quote track/rationale; list the criteria used.

### 7) OPSEC and Security ✅❌

- **Must NOT include**: credentials/tokens, PII, customer identifiers, internal hostnames, absolute/internal paths, production secrets.
- **Pass**: No violations found.
- **Evidence**: State what you scanned for; if violation, quote and point to location.

### 8) Executability ✅❌

- **Checks**: no missing info that blocks start; dependencies noted; “done” is verifiable; scope is realistic.
- **Pass**: Honest answer to “Could I start implementing now?” is **YES**.
- **Evidence**: Identify the first file/action and how success will be verified.

## Severity Levels (for issues)

- **🔴 BLOCKER**: Prevents safe start/finish (missing required sections, OPSEC violation, non-testable criteria, placeholder strategy).
- **🟡 MUST-FIX**: Likely causes rework (vague requirements, weak strategy detail, missing scope boundaries).
- **🟢 NICE-TO-HAVE**: Improves quality but doesn’t block execution (extra tests, stronger notes).

## Output Format (required)

```markdown
## [✅ | ❌] Plan Validation Report: [TICKET-ID]

**Ticket**: [TICKET-ID] - [Title from Objective]  
**Plan Path**: `tickets/[TICKET-ID]/plan.md`  
**Status**: [✅ PLAN READY TO EXECUTE | ⚠️ PLAN READY WITH CAUTIONS | ❌ PLAN NOT READY]  
**Validation Date**: [YYYY-MM-DD]

---

### Validation Summary
**Overall**: [✅ PASS | ⚠️ PASS WITH WARNINGS | ❌ FAIL] ([X]/8 passing)

---

### Category Results
1. Structure Completeness: [✅ PASS | ❌ FAIL] — [evidence]
2. Objective Clarity: [✅ PASS | ❌ FAIL] — [evidence]
3. Requirements Quality: [✅ PASS | ❌ FAIL] — [evidence]
4. Acceptance Criteria Quality: [✅ PASS | ❌ FAIL] — [evidence]
5. Implementation Strategy Clarity: [✅ PASS | ❌ FAIL] — [evidence]
6. Complexity Assessment: [✅ PASS | ❌ FAIL] — [evidence]
7. OPSEC and Security: [✅ PASS | ❌ FAIL] — [evidence]
8. Executability: [✅ PASS | ❌ FAIL] — [evidence]

---

### Issues Found
#### 🔴 BLOCKERS
1. **[Issue]** — [impact] — [fix] — [location]

#### 🟡 MUST-FIX
1. **[Issue]** — [impact] — [fix] — [location]

#### 🟢 NICE-TO-HAVE
1. **[Issue]** — [impact] — [fix] — [location]

---

### [✅ | ⚠️ | ❌] RECOMMENDATION
**[READY TO EXECUTE | READY WITH CAUTIONS | NOT READY - FIX ISSUES FIRST]**

**Next Steps**:
1. [highest priority fix]
2. [next fix]
3. [re-validate: @validate-plan [TICKET-ID]]
```

## Critical Rules

- Do **not** recommend execution if **any** 🔴 blockers exist.
- Treat **OPSEC violations** as 🔴 blockers.
- Cite evidence for every pass/fail (quotes, counts, or specific locations).
- If uncertain, fail conservatively and explain exactly what’s missing and how to fix it.
