---
name: create-refactoring-plan
description: "Please create a detailed refactoring plan to reduce complexity and improve maintainability"
agent: cursor-agent
model: Claude-3.5-Sonnet
category: code-quality
tags: refactoring, complexity, planning, maintainability, technical-debt
argument-hint: "Method name and complexity metrics"
---

# Create Refactoring Plan

Please create a comprehensive, actionable refactoring plan to reduce code complexity and improve maintainability.

**Pattern**: Refactoring Planning Pattern ⭐⭐⭐⭐⭐  
**Effectiveness**: Essential for systematic complexity reduction  
**Use When**: After analyzing complexity metrics and identifying high-complexity methods requiring refactoring

---

## Purpose

This prompt helps you:
- Create detailed, phased refactoring plans for high-complexity code
- Identify specific refactoring patterns to apply
- Break down large refactoring into manageable phases
- Establish clear success criteria and validation steps
- Prepare executable implementation strategy

Use this after analyzing complexity metrics to create the detailed execution plan.

---

## Required Context

- **Target Method**: Name and location (class, file)
- **Complexity Metrics**: Current Cyclomatic Complexity and CRAP Score
- **Source Code**: The actual method to be refactored
- **Test Coverage**: Existing test coverage information
- **Optional**: Analysis from `analyze-complexity-metrics` prompt

---

## Process

Follow these steps to create a refactoring plan:

### Step 1: Understand Current State
Analyze the method to refactor:
- Read the full source code
- Identify responsibilities (what does it do?)
- Map decision trees (where are the branches?)
- Count lines of code
- Assess test coverage

### Step 2: Identify Root Causes
Determine why complexity is high:
- **Too many conditionals**: if/else chains, switch statements
- **Multiple responsibilities**: Validation + execution + reporting
- **Long method**: Violates single responsibility principle
- **Lack of abstraction**: No service classes, all inline
- **Deep nesting**: Nested if statements

### Step 3: Choose Refactoring Patterns
Select appropriate patterns for the situation:
- **Extract Method**: Pull out cohesive blocks into separate methods
- **Extract Class/Service**: Create focused service classes
- **Strategy Pattern**: Replace conditionals with polymorphism
- **Parameter Object**: Group related parameters into config objects
- **Guard Clauses**: Reduce nesting with early returns

### Step 4: Design Phased Approach
Break refactoring into safe, testable phases:
- Each phase extracts one cohesive unit
- Order phases by risk (easy/safe first)
- Ensure tests can run after each phase
- Plan for incremental commits

### Step 5: Define Target Metrics
Set specific, measurable goals:
- Target Cyclomatic Complexity (e.g., 92 → <15)
- Target CRAP Score (e.g., 8556 → <100)
- Target method length (e.g., 1165 lines → <50 lines)
- Expected complexity reduction per phase

### Step 6: Plan Validation
Define how to verify success:
- Test pass criteria (100% pass rate)
- Performance benchmarks (no degradation)
- Code quality checks (SOLID principles)
- Metrics measurement (actual vs. target)

---

## Reasoning Process (for AI Agent)

When this prompt is invoked, the AI should:

1. **Read Source Code**: Fully understand the method structure
2. **Identify Responsibilities**: What distinct jobs does it perform?
3. **Map Complexity Sources**: Where do the branches come from?
4. **Select Patterns**: Which refactoring patterns fit best?
5. **Design Phases**: Break into safe, testable increments
6. **Estimate Effort**: Realistic time/complexity per phase
7. **Define Validation**: How to confirm each phase succeeded

---

## Pattern Selection Decision Tree

```
What's the primary complexity source?

├─ Too Many Conditionals (if/else chains)
│  ├─ Format/Type decisions → Strategy Pattern
│  ├─ Nested validations → Guard Clauses + Extract Method
│  └─ Switch statements → Polymorphism/Dictionary lookup
│
├─ Multiple Responsibilities (validation + execution + reporting)
│  ├─ Distinct concerns → Extract Class/Service
│  ├─ Related logic → Extract Method
│  └─ Configuration heavy → Parameter Object
│
├─ Long Method (>100 lines)
│  ├─ Sequential steps → Extract Method for each step
│  ├─ Repeated patterns → Extract Method + DRY
│  └─ Complex algorithm → Extract Method Object
│
└─ Deep Nesting (3+ levels)
   ├─ Validation chains → Guard Clauses (early returns)
   ├─ Nested loops → Extract Inner Loop method
   └─ Nested conditions → Combine conditions or Extract Method
```

---

## Instructions

1. **Analyze the method** structure, responsibilities, and complexity sources
2. **Choose refactoring patterns** appropriate for the situation
3. **Design phased approach** with 3-7 phases, ordered by risk/dependency
4. **Define each phase** with:
   - Goal and scope
   - Specific extraction steps
   - New classes/methods to create
   - Expected complexity reduction
   - Testing approach
5. **Set target metrics** (complexity, CRAP, method length)
6. **Create validation plan** (tests, performance, quality checks)
7. **Estimate effort** per phase and total
8. **Document risks** and mitigation strategies

---

## Expected Output

Detailed refactoring plan document:

```markdown
# Refactoring Plan: [MethodName]

## Current State

**Location**: `[FilePath]::ClassName::MethodName`

**Metrics**:
- Cyclomatic Complexity: [current]
- CRAP Score: [current]
- Lines of Code: [current]
- Test Coverage: [percentage]%

**Assessment**: [Brief assessment of why this is problematic]

---

## Target State

**Metrics**:
- Cyclomatic Complexity: [current] → [target] ([percentage]% reduction)
- CRAP Score: [current] → [target] ([percentage]% reduction)
- Lines of Code: [current] → [target]
- Method Structure: [Clean orchestration with service delegation]

**Success Criteria**:
- [ ] Complexity reduced by ≥[X]%
- [ ] CRAP score reduced by ≥[Y]%
- [ ] All tests pass (100% pass rate)
- [ ] No performance degradation
- [ ] SOLID principles followed
- [ ] Complete XML documentation

---

## Root Cause Analysis

**Why is complexity high?**

1. **[Root Cause 1]** (Contributes ~[X] complexity points)
   - [Description]
   - [Impact]

2. **[Root Cause 2]** (Contributes ~[Y] complexity points)
   - [Description]
   - [Impact]

**Primary Issue**: [Main problem, e.g., "Method violates Single Responsibility Principle - handles 5 distinct concerns"]

---

## Refactoring Strategy

**Patterns to Apply**:
1. **Extract Method Objects** - Break giant method into cohesive service classes
2. **Strategy Pattern** - Replace format conditionals with strategy classes
3. **Service Extraction** - Create focused domain services
4. **Parameter Object** - Group configuration parameters

**Phased Approach**: [X] phases over [Y] days

---

## Phase-by-Phase Plan

### Phase 1: Extract [Responsibility Name] (~[X] complexity reduction)

**Goal**: Extract [responsibility] logic into dedicated service class

**Create**:
- `[ClassName]` class/service

**Extract**:
- [Specific logic block] → `[MethodName]()`
- [Specific conditional] → `[MethodName]()`
- Lines [X-Y] of original method

**Refactoring Steps**:
1. Create new class `[ClassName]`
2. Move validation logic to `ValidateX()` method
3. Replace original code with call to service
4. Update any dependencies

**Expected Result**:
- Original method: [current] → [new] lines
- Complexity: [current] → [new] (~[X] point reduction)
- New service: Complexity ~[Y]

**Testing**:
- Run full test suite after extraction
- Verify [specific behavior] still works
- Ensure [edge cases] handled

**Commit Message**:
```
Refactor [Ticket]: Phase 1 - Extract [Responsibility]

- Created [ClassName] for [purpose]
- Reduced complexity by ~[X] points
- All tests passing
```

**Estimated Effort**: [X] hours
**Risk**: [Low/Medium/High] - Mitigated by [strategy]

---

### Phase 2: Extract [Responsibility Name] (~[X] complexity reduction)

[Same structure as Phase 1]

---

### Phase 3: Extract [Responsibility Name] (~[X] complexity reduction)

[Same structure as Phase 1]

---

[Continue for all phases]

---

## Final Method Structure

After all phases, the method should look like:

```csharp
private static async Task [MethodName](...)
{
    // Phase 1: Validation
    var validator = new [ValidatorClass]();
    validator.ValidateX(...);
    
    // Phase 2: Configuration
    var config = new [ConfigBuilder]().Build(...);
    
    // Phase 3: Data Collection
    var data = await _dataCollector.CollectAsync(...);
    
    // Phase 4: Execution
    var results = await _executor.ExecuteAsync(data, config);
    
    // Phase 5: Reporting
    _reporter.Report(results);
}
```

**Final Metrics**:
- Lines: ~[X] (down from [Y])
- Complexity: ~[X] (down from [Y])
- CRAP: ~[X] (down from [Y])

**New Classes Created**: [Count] focused service classes

---

## New Classes/Services

### [ClassName1]
**Responsibility**: [Single responsibility description]
**Methods**:
- `[Method1]()` - [Purpose]
- `[Method2]()` - [Purpose]
**Complexity**: ~[X] per method
**Tests**: [Test class name]

### [ClassName2]
[Same structure]

---

## Testing Strategy

**Leverage Existing Tests**:
- [X] existing tests act as regression safety net
- Run after each phase
- No test modifications needed (tests are the spec)

**Continuous Validation**:
1. Run full test suite after each extraction
2. Verify 100% pass rate before proceeding
3. Commit only when tests pass
4. Incremental changes allow easy rollback

**Performance Validation**:
- Benchmark [representative scenario]
- Ensure no degradation from abstraction
- Compare before/after execution time

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|---------|------------|
| Breaking existing functionality | Medium | High | Run tests after each phase; commit incrementally |
| Performance degradation | Low | Medium | Benchmark critical paths; keep hot code efficient |
| Introducing new bugs | Medium | High | Small focused extractions; thorough testing |
| Scope creep | High | Medium | Strict scope: only this method; defer others |
| Over-abstraction | Medium | Medium | Follow YAGNI; extract only when justified |

---

## Dependencies & Constraints

**Requires**:
- Existing test suite functional
- Access to complexity measurement tools
- Understanding of [domain/business logic]

**Blocks**:
- [Any dependent work that can't proceed until this is done]

**Must Preserve**:
- All existing functionality (zero regressions)
- Current API contracts (no breaking changes)
- Output format (byte-for-byte identical)
- Performance characteristics

**Must Follow**:
- SOLID principles
- XML documentation standards
- Existing naming conventions
- Clean code practices from `.cursor/rules/`

---

## Timeline

**Total Estimated Effort**: [X] days

**Breakdown**:
- Phase 1: [X] hours
- Phase 2: [X] hours
- Phase 3: [X] hours
- [... more phases]
- Final validation: [X] hours

**Milestones**:
- Day 1: Complete phases 1-2
- Day 2: Complete phases 3-4
- Day 3: Complete phases 5-6, validate

---

## Validation Checklist

Before claiming refactoring complete:

### Metrics Validation
- [ ] Complexity reduced from [X] to [target] (≥[Y]% reduction)
- [ ] CRAP score reduced from [X] to [target] (≥[Y]% reduction)
- [ ] Method length reduced from [X] to [target] lines

### Functionality Validation
- [ ] All tests pass (100% pass rate)
- [ ] No new test failures
- [ ] Edge cases still handled correctly
- [ ] Error paths still work

### Quality Validation
- [ ] SOLID principles followed
- [ ] Clear separation of concerns
- [ ] No code duplication (DRY)
- [ ] Appropriate abstraction levels
- [ ] XML documentation complete

### Performance Validation
- [ ] Benchmarks run successfully
- [ ] Performance ≥100% of baseline (no degradation)
- [ ] No memory leaks introduced
- [ ] Resource usage reasonable

---

## Success Metrics

**Complexity Reduction**:
- Method complexity: [current] → [target] ([X]% reduction)
- CRAP score: [current] → [target] ([Y]% reduction)
- Lines of code: [current] → [target]

**Quality Improvements**:
- Number of classes: 1 → [X] (focused, single-responsibility)
- Average method length: <50 lines
- Cyclomatic complexity per method: <8

**Validation Results**:
- Test pass rate: 100%
- Performance: ≥100% baseline
- Code review score: [Rating]

---

## Follow-Up Actions

After refactoring:
- [ ] Update documentation
- [ ] Create lessons learned document
- [ ] Share patterns with team
- [ ] Apply to similar methods
- [ ] Monitor metrics over time

---

## References

- **Source File**: [File path]
- **Complexity Report**: [Report location/date]
- **Test Suite**: [Test file paths]
- **Related Tickets**: [Ticket IDs]
```

---

## Usage Modes

### Quick Mode (30-60 min)
For simpler methods (Complexity 15-30):
```
@create-refactoring-plan ExecuteExportAsync --quick
[Complexity: 28, CRAP: 150, Lines: 200]
```

Creates plan with 2-3 phases, less detail, faster execution.

### Standard Mode (2-4 hours)
For moderate complexity (Complexity 30-60):
```
@create-refactoring-plan ExecuteExportAsync
[Complexity: 45, CRAP: 500, Lines: 450]
```

Creates plan with 3-5 phases, balanced detail.

### Comprehensive Mode (4-8 hours)
For high complexity (Complexity 60+):
```
@create-refactoring-plan ExecuteExportAsync --comprehensive
[Complexity: 92, CRAP: 8556, Lines: 1165]
```

Creates plan with 5-7 phases, maximum detail, complete risk analysis.

---

## Examples (Few-Shot)

### Example 1: Large Method with Multiple Responsibilities

**Input**:
```
Method: ExecuteExportAsync
Location: ExportCommandFactory.cs
Complexity: 92
CRAP: 8556
Lines: 1165
Test Coverage: 95%

Responsibilities identified:
1. Format validation and selection
2. Configuration building
3. Data collection from database
4. Export execution with progress tracking
5. Results reporting and file management
```

**Reasoning**:
This method has catastrophic complexity (92) and CRAP score (8556). Primary issue is violation of Single Responsibility Principle - the method handles 5 distinct concerns. Strategy: Extract each responsibility into focused service class, reducing main method to orchestration logic. Expect ~90% complexity reduction across 5 phases.

**Output** (Abbreviated - full plan would be 400+ lines):
```markdown
# Refactoring Plan: ExecuteExportAsync

## Current State
**Location**: `Commands/ExportCommandFactory.cs::ExecuteExportAsync`
**Metrics**: Complexity 92, CRAP 8556, 1165 lines, 95% coverage
**Assessment**: CATASTROPHIC - Method violates SRP, handles 5 concerns

## Target State
**Metrics**: Complexity 92 → 8 (91% reduction), CRAP 8556 → 50 (99% reduction)
**Success Criteria**: All 5 phases complete, 100% tests pass, no performance loss

## Root Cause Analysis
1. **Multiple Responsibilities** (~80 complexity points)
   - Combines validation, config, data, execution, reporting
2. **Format Conditionals** (~12 complexity points)
   - Switch on format type throughout method

**Primary Issue**: Method does everything - needs decomposition

## Refactoring Strategy
**Patterns**: Extract Service (5x), Strategy Pattern (format handling), Parameter Object (config)
**Phased Approach**: 5 phases over 3-4 days

## Phase 1: Extract Format Validation (~10 complexity reduction)
**Goal**: Extract format validation/selection into `FormatValidationService`
**Create**: `FormatValidationService` with `ValidateAndSelectFormat()` method
**Extract**: Lines 50-120 (format validation logic)
**Expected**: Main method 1165 → 1100 lines, Complexity 92 → 82
**Testing**: Verify format validation still catches invalid formats
**Effort**: 2 hours | **Risk**: Low - isolated logic

## Phase 2: Extract Configuration Building (~8 complexity reduction)
**Goal**: Extract config building into `ExportConfigurationBuilder`
**Create**: `ExportConfigurationBuilder` with fluent API
**Extract**: Lines 121-200 (config assembly logic)
**Expected**: Main method 1100 → 1050 lines, Complexity 82 → 74
**Effort**: 2 hours | **Risk**: Low - pure data transformation

[... Phases 3-5 similar structure ...]

## Final Method Structure
```csharp
private static async Task ExecuteExportAsync(...)
{
    var format = _formatValidator.ValidateAndSelectFormat(...);
    var config = _configBuilder.Build(...);
    var data = await _dataCollector.CollectAsync(...);
    var results = await _exportExecutor.ExecuteAsync(data, config);
    _resultReporter.Report(results);
}
```

**Final Metrics**: 50 lines (from 1165), Complexity 8 (from 92), CRAP 50 (from 8556)
**New Classes**: 5 focused service classes

[... Complete testing, risk, timeline sections ...]
```

### Example 2: Conditional-Heavy Method

**Input**:
```
Method: ProcessTransaction
Complexity: 35
CRAP: 245
Lines: 280
Test Coverage: 85%

Issue: Nested if/else chains for payment type handling (Credit, Debit, PayPal, Bitcoin)
```

**Reasoning**:
High complexity driven by conditional branching on payment types. Current approach uses nested if/else. Better approach: Strategy Pattern - create payment type strategies. Expect ~70% complexity reduction in 3 phases.

**Output** (Abbreviated):
```markdown
# Refactoring Plan: ProcessTransaction

## Current State
**Complexity**: 35, **CRAP**: 245, **Lines**: 280

## Target State
**Complexity**: 35 → 10 (71% reduction)

## Root Cause Analysis
**Too Many Conditionals** (~25 complexity points)
- 4 payment types × nested validation/processing logic

## Refactoring Strategy
**Pattern**: Strategy Pattern for payment types

## Phase 1: Define Payment Strategy Interface
**Create**: `IPaymentStrategy` interface
**Extract**: Common payment processing contract
**Effort**: 1 hour

## Phase 2: Extract Payment Type Strategies
**Create**: `CreditCardStrategy`, `DebitCardStrategy`, `PayPalStrategy`, `BitcoinStrategy`
**Extract**: Type-specific logic into each strategy
**Effort**: 3 hours

## Phase 3: Replace Conditionals with Strategy Lookup
**Refactor**: Dictionary<PaymentType, IPaymentStrategy> lookup
**Expected**: Complexity 35 → 10
**Effort**: 2 hours

[... rest of plan ...]
```

---

## Troubleshooting

### Issue: Can't Identify Clear Responsibilities
**Cause**: Method logic is tightly coupled, no obvious boundaries
**Solution**:
1. Draw flowchart of method execution
2. Identify "sections" by comments or blank lines
3. Look for repeated variable prefixes (validation*, export*, report*)
4. Ask: "If I had to explain this to someone, what are the 3-5 main steps?"

### Issue: Phases Seem Too Small/Too Large
**Cause**: Incorrect granularity for phasing
**Solution**:
- **Too small**: Combine related extractions (all validation together)
- **Too large**: Split by sub-responsibility (validation → type validation + data validation)
- **Rule of thumb**: Each phase should be 1-3 hours of work

### Issue: Tests Break After Extraction
**Cause**: Extracted logic had hidden dependencies
**Solution**:
1. Rollback extraction
2. Identify dependencies (shared state, order dependencies)
3. Extract dependencies first, then logic
4. Consider dependency injection for testability

### Issue: Performance Degrades After Refactoring
**Cause**: Too much abstraction overhead or unnecessary object creation
**Solution**:
1. Profile before/after with realistic data
2. Identify hot paths (tight loops, repeated calls)
3. Keep hot paths inline or cache strategy objects
4. Use value types or object pooling if needed

### Issue: Can't Meet Target Metrics
**Cause**: Unrealistic targets or fundamental algorithm complexity
**Solution**:
- **Unrealistic targets**: Adjust targets to realistic values (algorithm determines minimum complexity)
- **Algorithm complexity**: Document as "irreducible complexity" and focus on other metrics
- **Example**: Binary search has minimum complexity of log(n) - can't reduce further

---

## Quality Criteria

- [ ] Current state fully documented (metrics, structure)
- [ ] Root causes identified and explained
- [ ] Refactoring patterns chosen and justified
- [ ] Phased approach with 3-7 clear phases
- [ ] Each phase has specific steps and deliverables
- [ ] Target metrics clearly defined
- [ ] Testing strategy for each phase
- [ ] Risk assessment with mitigation
- [ ] Realistic effort estimates
- [ ] Validation checklist comprehensive
- [ ] Success criteria measurable

---

## Related Prompts

- `code-quality/analyze-complexity-metrics.prompt.md` - Run first to understand complexity
- `code-quality/refactor-for-clean-code.prompt.md` - Execute the refactoring plan
- `code-quality/review-code-quality.prompt.md` - Validate refactored code
- `unit-testing/validate-test-quality.prompt.md` - Ensure test coverage adequate

---

## Related Rules

- `.cursor/rules/function-length-and-responsibility.mdc` - Single responsibility principle
- `.cursor/rules/dry-principle.mdc` - Don't repeat yourself
- `.cursor/rules/code-quality-and-best-practices.mdc` - Code quality standards
- `.cursor/rules/clean-code.mdc` - Clean code principles
- `.cursor/rules/general-code-style-and-readability.mdc` - Code style and readability

---

**Created**: 2026-01-12  
**Improved**: 2026-01-12 (Added: agent/model fields, decision tree, complete Few-Shot examples, troubleshooting, usage modes)  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
