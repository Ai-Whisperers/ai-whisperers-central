---
name: analyze-complexity-metrics
description: "Please analyze complexity metrics (Cyclomatic Complexity and CRAP scores) and plan refactoring approach"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: code-quality
tags: complexity, crap-score, cyclomatic, analysis, refactoring, planning
argument-hint: "Complexity report data or method names"
---

# Analyze Complexity Metrics

Please analyze complexity metrics (Cyclomatic Complexity and CRAP scores) to understand code health and plan systematic refactoring approach.

**Pattern**: Analysis and Planning Pattern ⭐⭐⭐⭐⭐  
**Effectiveness**: Critical for addressing technical debt systematically  
**Use When**: Dealing with high-complexity methods identified in code quality reports

---

## Purpose

This prompt helps you:
- Understand what complexity metrics mean (Cyclomatic Complexity, CRAP Score)
- Assess severity and risk levels
- Prioritize which code to refactor first
- Plan systematic approach to reducing complexity
- Prepare for detailed refactoring work

Use this when you receive complexity reports with high scores and need to plan how to address them.

---

## Required Context

Provide the complexity data using XML delimiters for robust parsing:

```markdown
<complexity_report>
| Assembly | Class | Method | Crap Score | Cyclomatic Complexity |
|----------|-------|--------|------------|-----------------------|
| [data rows here]
</complexity_report>
```

**Optional Context**:
- Source code file paths
- Existing test coverage information
- Business context (critical vs. non-critical code)

---

## Process

Follow these steps to analyze complexity metrics:

### Step 1: Interpret Metrics
Explain what the metrics mean for the specific methods:
- **Cyclomatic Complexity**: Number of decision points (if/else, loops, switches)
- **CRAP Score**: Change Risk Anti-Patterns (complexity × test coverage factor)

**Risk Levels**:
- Complexity 1-10: ✅ Low risk
- Complexity 11-20: ⚠️ Moderate risk
- Complexity 21-50: 🔴 High risk
- Complexity 50+: 💀 Very High risk

- CRAP 1-30: ✅ Manageable
- CRAP 31-100: ⚠️ Moderate risk
- CRAP 100-500: 🔴 High risk
- CRAP 500+: ☠️ Critical risk

### Step 2: Categorize Methods
Group methods by severity:
- **Critical** (CRAP > 500 or Complexity > 50): Urgent refactoring needed
- **High** (CRAP 100-500 or Complexity 30-50): High priority
- **Medium** (CRAP 30-100 or Complexity 15-30): Should address
- **Low** (CRAP < 30 and Complexity < 15): Monitor

### Step 3: Identify Patterns
Analyze the high-complexity methods for common issues:
- Are they all in one class? (suggests class doing too much)
- Similar method types? (validation, configuration, execution patterns)
- Shared root causes? (too many conditionals, no abstraction, long methods)

### Step 4: Prioritization Strategy
Recommend approach based on:
- **Severity-First**: Start with worst offenders (highest CRAP/complexity)
- **Module-First**: Group by class/module, refactor together
- **Risk-Based**: Start with most critical business logic
- **Quick-Wins**: Start with easiest to refactor (high impact, low effort)

### Step 5: Proposed Approach
For each prioritization tier, recommend:
- **Analysis needed**: What to understand before refactoring
- **Refactoring patterns**: Strategy, Extract Method, Service Extraction
- **Estimated effort**: Time/complexity estimate
- **Dependencies**: What blocks or enables this work

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Parse Report**: Extract method names, classes, complexity values, CRAP scores from XML-delimited data
2. **Calculate Risk**: Assess each method against risk thresholds
3. **Identify Patterns**: Look for commonalities (same class, similar types)
4. **Determine Root Causes**: Why are these methods complex? (conditionals, length, responsibility)
5. **Propose Strategy**: Recommend prioritization and approach
6. **Estimate Effort**: Provide realistic timeline/effort estimates
7. **Create Actionable Plan**: Specific next steps with measurable outcomes

---

## Prioritization Decision Tree

```
What's the business context?

├─ Critical Production Code (payments, security, data integrity)
│  └─ Use Risk-Based prioritization
│     - Start with highest-risk critical methods
│     - Even if complexity is moderate
│
├─ Stable Legacy Code (rarely changes)
│  └─ Use Severity-First prioritization
│     - Only tackle worst offenders (CRAP > 500)
│     - Don't fix what doesn't break
│
├─ Active Development Code (frequent changes)
│  └─ Use Module-First prioritization
│     - Refactor entire class/module together
│     - Prevents partial refactoring pain
│
└─ Technical Debt Cleanup (no urgent pressure)
   └─ Use Quick-Wins prioritization
      - Start with easiest high-impact fixes
      - Build momentum and patterns
```

---

## Instructions

1. **Read complexity report data** (from user input or attached file)
2. **Interpret each metric** with risk level assessment
3. **Categorize methods** into severity tiers (Critical/High/Medium/Low)
4. **Identify patterns** across high-complexity methods
5. **Select prioritization strategy** using decision tree
6. **Recommend prioritization strategy** (severity-first, module-first, etc.)
7. **Propose approach** for each tier with estimated effort
8. **Create action plan** with clear next steps

---

## Expected Output

Comprehensive analysis report with:

```markdown
# Complexity Metrics Analysis

## Executive Summary
- Total methods analyzed: [count]
- Critical issues: [count] (CRAP > 500 or Complexity > 50)
- High priority: [count] (CRAP 100-500 or Complexity 30-50)
- Medium priority: [count] (CRAP 30-100 or Complexity 15-30)
- Recommended approach: [strategy]
- Estimated total effort: [X] days

## Severity Breakdown

### Critical (Urgent Refactoring)
| Method | Class | Complexity | CRAP | Risk Level |
|--------|-------|------------|------|------------|
| ExecuteExportAsync | ExportCommandFactory | 92 | 8556 | ☠️ CATASTROPHIC |

**Assessment**: [Why this is critical, impact on codebase]
**Estimated Effort**: [X] days
**Recommended Pattern**: [Extract Service/Strategy/etc.]

### High Priority
| Method | Class | Complexity | CRAP | Risk Level |
|--------|-------|------------|------|------------|
| ExportEntityAsync | ExportCommandFactory | 28 | 812 | 💀 Very High |

**Assessment**: [Why this needs attention]
**Estimated Effort**: [X] days
**Recommended Pattern**: [Pattern name]

### Medium Priority
[Similar structure]

## Pattern Analysis

**Common Issues Identified**:
1. **[Pattern 1]** - Found in [count] methods
   - Example: [Method names]
   - Root cause: [Explanation]
   
2. **[Pattern 2]** - Found in [count] methods
   - Example: [Method names]
   - Root cause: [Explanation]

**Root Causes**:
- Too many conditionals (if/else, switch) - [X] methods
- Methods doing multiple responsibilities - [Y] methods
- Lack of abstraction/delegation - [Z] methods
- [Other specific causes]

**Class-Level Analysis**:
- `ExportCommandFactory`: 3 high-complexity methods - suggests class doing too much
- [Other classes]

## Prioritization Recommendation

**Recommended Strategy**: [Severity-First / Module-First / Risk-Based / Quick-Wins]

**Rationale**: [Why this approach makes sense for this codebase]
- [Specific reason 1]
- [Specific reason 2]
- [Business/technical context]

**Alternative Approaches Considered**:
- [Strategy 2]: [Why not chosen]
- [Strategy 3]: [Why not chosen]

## Refactoring Approach

### Tier 1: Critical Methods (Est: [X] days)

**Methods**:
1. **ExecuteExportAsync** (Complexity 92 → target <15, CRAP 8556 → <100)
   - Location: `ExportCommandFactory.cs`
   - Lines: 1165

**Root Cause**: Multiple responsibilities (validation + config + data + execution + reporting)

**Approach**:
1. Analyze method structure and responsibilities
2. Apply Extract Service pattern (5 phases)
3. Create service classes for each concern:
   - `FormatValidationService`
   - `ExportConfigurationBuilder`
   - `DataCollectionService`
   - `ExportExecutionService`
   - `ResultReportingService`
4. Test after each extraction

**Expected Outcome**:
- Complexity: 92 → 8 (91% reduction)
- CRAP: 8556 → 50 (99% reduction)
- Lines: 1165 → 50
- New classes: 5 focused services

**Estimated Effort**: 3-4 days
**Risk**: Medium - High test coverage (95%) provides safety net

---

### Tier 2: High Priority Methods (Est: [X] days)

**Methods**:
1. **ExportEntityAsync** (Complexity 28 → target <8, CRAP 812 → <50)
2. **ExportGroupedEntitiesAsync** (Complexity 28 → target <8, CRAP 800 → <50)

**Root Cause**: Format-handling conditionals, can reuse patterns from Tier 1

**Approach**:
1. Apply Strategy Pattern for format handling (reuse from Tier 1)
2. Extract file operations to service
3. Refactor both methods together (shared abstractions)

**Expected Outcome**:
- Complexity: 28 → 8 each (71% reduction)
- CRAP: ~800 → 50 each (94% reduction)
- Reuse services from Tier 1

**Estimated Effort**: 2-3 days
**Risk**: Low - Can leverage Tier 1 work, test coverage adequate

---

### Tier 3: Medium Priority Methods (Est: [X] days)
[Similar structure]

---

## Success Criteria

**Metrics Targets**:
- [ ] All Critical methods reduced to Complexity <15, CRAP <100
- [ ] All High Priority methods reduced to Complexity <8, CRAP <50
- [ ] Medium Priority methods reduced to Complexity <8, CRAP <30

**Quality Gates**:
- [ ] 100% test pass rate (no regressions)
- [ ] No performance degradation
- [ ] Code follows SOLID principles
- [ ] XML documentation complete for all new classes

**Process Success**:
- [ ] Each tier completed before starting next
- [ ] Metrics measured and validated after each phase
- [ ] Lessons learned documented for reuse

---

## Next Steps

**Immediate Actions**:
1. **Start with**: [Worst method from Tier 1]
2. **Run prompt**: `@create-refactoring-plan [method-name]`
3. **Review plan** with team/lead
4. **Set up tracking**: Complexity metrics dashboard

**Ticket Creation**:
- Create parent ticket: "[PROJECT] Reduce Code Complexity"
- Create sub-tickets:
  - "[PROJECT]-REFACTOR-1: Refactor ExecuteExportAsync"
  - "[PROJECT]-REFACTOR-2: Refactor ExportEntityAsync"
  - [... more sub-tickets ...]

**Monitoring**:
- Set up automated complexity reporting (weekly)
- Track progress: [current] methods → [target] methods in each tier
- Celebrate wins: Share complexity reductions with team

---

## Estimated Total Effort

**By Tier**:
- Tier 1 (Critical): [X] days
- Tier 2 (High): [Y] days
- Tier 3 (Medium): [Z] days
- **Total refactoring**: [X+Y+Z] days

**By Activity**:
- Analysis and planning: [A] days
- Refactoring implementation: [B] days
- Testing and validation: [C] days
- Documentation: [D] days
- **Total**: [A+B+C+D] days

**Timeline**:
- Week 1-2: Tier 1 (Critical methods)
- Week 3-4: Tier 2 (High priority methods)
- Week 5+: Tier 3 (Medium priority methods)

---

## Risk vs Impact Matrix

| Method | Complexity | CRAP | Refactor Effort | Business Risk | Refactor Priority |
|--------|------------|------|-----------------|---------------|-------------------|
| ExecuteExportAsync | 92 | 8556 | High | Medium | 🔥 Urgent |
| ExportEntityAsync | 28 | 812 | Medium | Medium | ⚠️ High |
| [Others] | ... | ... | ... | ... | ... |

**Legend**:
- **Refactor Effort**: Low (<1 day), Medium (1-3 days), High (3+ days)
- **Business Risk**: Low (rarely used), Medium (regular use), High (critical path)
- **Priority**: Urgent (do now), High (do soon), Medium (plan), Low (monitor)
```

---

## Usage Modes

### Quick Analysis (5-10 min)
For initial triage of complexity reports:
```
@analyze-complexity-metrics --quick

<complexity_report>
[Paste report data]
</complexity_report>
```

Provides: Executive summary, severity breakdown, recommended strategy only.

### Standard Analysis (15-30 min)
For detailed planning:
```
@analyze-complexity-metrics

<complexity_report>
[Paste report data]
</complexity_report>
```

Provides: Full analysis with pattern identification, detailed tier plans, effort estimates.

### Comprehensive Analysis (30-60 min)
For complex codebases or leadership presentation:
```
@analyze-complexity-metrics --comprehensive

<complexity_report>
[Paste report data]
</complexity_report>

<business_context>
Critical paths: Payment processing, user authentication
Active development: Export functionality
Legacy stable: Reporting module
</business_context>
```

Provides: Everything in Standard + risk/impact matrix, alternative strategies, leadership summary.

---

## Examples (Few-Shot)

Examples are extracted to keep this prompt compact. See: `../exemplars/code-quality/complexity-metrics-analysis-exemplar.md`


## Troubleshooting

### Issue: CRAP Score Seems Wrong
**Cause**: CRAP score depends on test coverage - may be calculated incorrectly
**Formula**: CRAP = Complexity² × (1 - Coverage)³ + Complexity
**Solution**:
1. Verify test coverage percentage is accurate
2. Re-run coverage analysis if needed
3. If coverage is <50%, CRAP score will be very high regardless of complexity
4. Focus on Cyclomatic Complexity if CRAP seems unreliable

### Issue: Can't Decide Between Severity-First vs Module-First
**Cause**: Multiple methods in same class with varying severity
**Decision Matrix**:
- **Use Severity-First** if: Methods are independent, different classes, or urgent pressure on worst method
- **Use Module-First** if: 3+ methods in same class, all need refactoring eventually, or class is under active development

**Hybrid Approach**: Start with worst method (Severity), then refactor rest of class (Module) to reuse patterns.

### Issue: Effort Estimates Seem Too Low/High
**Cause**: Complexity doesn't always correlate linearly with refactoring effort
**Factors**:
- **Test coverage**: High coverage = easier refactoring (safety net)
- **Business logic complexity**: Domain complexity may exceed cyclomatic complexity
- **Dependencies**: Tightly coupled code takes longer to extract
- **Team familiarity**: Known domain = faster refactoring

**Calibration**: Start with one method, measure actual time, adjust estimates for others.

### Issue: All Methods Show High Complexity
**Cause**: Either systemic issues OR tool misconfiguration
**Solution**:
1. **Verify tool settings**: Check if complexity includes test code (shouldn't)
2. **Sample review**: Manually review 2-3 methods - do they genuinely seem complex?
3. **Baseline**: Compare against industry standards (>10 is moderate, >20 is high, >50 is critical)
4. **If genuinely all high**: This is systemic architecture issue - recommend broader refactoring strategy document

### Issue: Business Wants Everything Fixed Immediately
**Cause**: Unclear prioritization or unrealistic expectations
**Solution**:
1. **Show risk levels**: Use ☠️ CATASTROPHIC, 💀 Very High symbols - makes severity visceral
2. **Effort estimates**: "All 10 methods = 4 weeks" - make cost clear
3. **Quick wins**: Propose 1-2 easy methods first to show progress
4. **ROI argument**: "Fixing worst method reduces 70% of technical debt for 20% of effort"
5. **Phased plan**: "Week 1: Critical, Week 2: High, Month 2: Medium" - shows systematic approach

---

## Quality Criteria

- [ ] All methods categorized by severity (Critical/High/Medium/Low)
- [ ] Risk levels clearly assessed with visual indicators
- [ ] Patterns and root causes identified with specific examples
- [ ] Clear prioritization strategy recommended with rationale
- [ ] Specific refactoring approach for each tier
- [ ] Realistic effort estimates provided (days/hours)
- [ ] Success criteria defined and measurable
- [ ] Next steps actionable and specific
- [ ] Business context considered in prioritization
- [ ] Alternative strategies evaluated and documented

---

## Related Prompts

- `code-quality/create-refactoring-plan.prompt.md` - Create detailed refactoring plan (use after this analysis)
- `code-quality/refactor-for-clean-code.prompt.md` - Execute refactoring work
- `code-quality/review-code-quality.prompt.md` - Review refactored code quality

---

## Related Rules

- `.cursor/rules/function-length-and-responsibility.mdc` - Single responsibility principle
- `.cursor/rules/dry-principle.mdc` - Don't repeat yourself
- `.cursor/rules/code-quality-and-best-practices.mdc` - Code quality standards
- `.cursor/rules/clean-code.mdc` - Clean code principles

---

**Created**: 2026-01-12  
**Improved**: 2026-01-12 (Added: agent/model fields, decision tree, complete Few-Shot examples, troubleshooting, usage modes, XML delimiters, risk/impact matrix)  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
