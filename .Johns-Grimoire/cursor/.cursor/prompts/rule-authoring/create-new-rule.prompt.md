---
name: create-new-rule
description: "Please create a new rule following the rule-authoring framework with proper structure and validation"
category: rule-authoring
tags: rules, creation, framework, validation
argument-hint: "[category] [rule-name]"
---

# Create New Rule

Please help me create a new rule for the rule framework:

**Rule Purpose**: `[REPLACE WITH WHAT THIS RULE GOVERNS]`
**Rule Category**: `[REPLACE WITH CATEGORY: agile/database/git/ticket/etc.]`
**Trigger Strategy**: `[REPLACE WITH: file-mask/agentic/always-apply]`

## Rule Creation Process

1. **Define Rule Scope**:
   - What does this rule govern?
   - When should it apply?
   - What files/contexts does it affect?
   - What outputs does it produce?

2. **Rule Front Matter**:
   ```yaml
   ---
   rule_id: [category]-[descriptive-name]-rule
   title: [Clear Rule Title]
   version: 1.0.0
   created: [YYYY-MM-DD]
   status: active
   tags: [tag1, tag2, tag3]
   ---
   ```

3. **Invocation Strategy**:
   - **File-mask**: If rule triggers on specific file patterns
     - Define glob patterns (governs field)
   - **Agentic**: If AI should decide when to apply
     - Write clear description for when to use
   - **Always-apply**: If rule always applies
     - Add to always-applied rules

4. **Rule Structure**:
   ```markdown
   # Rule Title
   
   ## Purpose
   [What this rule does and why it exists]
   
   ## Scope
   [What this rule covers and doesn't cover]
   
   ## When to Apply
   [Specific conditions for application]
   
   ## Rule Definition
   [The actual rules and requirements]
   
   ## Process
   [Step-by-step process if applicable]
   
   ## Quality Checklist
   [Validation criteria]
   
   ## Examples
   [Good and bad examples]
   
   ## References
   [Related rules, templars, exemplars]
   ```

5. **Rule Contracts**:
   - Define inputs the rule expects
   - Define outputs the rule produces
   - Specify preconditions
   - Specify postconditions

6. **Create Validation Checklist**:
   - Add checklist section
   - Make items specific and verifiable
   - Cover all critical aspects

7. **Add Examples**:
   - Provide good exemplars
   - Provide bad exemplars (anti-patterns)
   - Show before/after if applicable

8. **Cross-References**:
   - Link to related rules
   - Link to templars (output templates)
   - Link to exemplars (examples)

## Supporting Artifacts

Consider creating:
- **Templar**: Template for outputs this rule generates
- **Exemplar**: Example of good/bad outputs
- **Agent Application Rule**: Guide for when to apply the rule

## Rule Validation

Validate against:
- Rule file structure standards
- Front-matter completeness
- Clear invocation strategy
- Explicit contracts
- Quality checklist present
- Examples provided

## Deliverable

Provide:
1. Complete rule file content
2. Front-matter with metadata
3. Structured rule content
4. Validation checklist
5. Examples (good and bad)
6. Suggested file path: `.cursor/rules/[category]/[rule-name].mdc`
7. Agent application rule (if needed)
8. Templars/exemplars (if needed)

Follow standards from:
- `.cursor/rules/rule-authoring/rule-file-structure.mdc`
- `.cursor/rules/rule-authoring/rule-contracts-and-scope.mdc`
- `.cursor/rules/rule-authoring/rule-invocation-strategies.mdc`
- `.cursor/rules/rule-authoring/rule-validation-and-checklists.mdc`
- `.cursor/rules/rule-authoring/rule-naming-conventions.mdc`

