---
type: exemplar
artifact-type: prompt
demonstrates: analyze-complexity-metrics
domain: code-quality
quality-score: exceptional
version: 1.0.0
illustrates: code-quality.analyze-complexity-metrics
extracted-from: .cursor/prompts/code-quality/analyze-complexity-metrics.prompt.md
---

# Complexity Metrics Analysis Exemplar

## Examples (Few-Shot)

### Example 1: Export System Complexity Report

**Input**:
```
<complexity_report>
| Assembly | Class | Method | Crap Score | Cyclomatic Complexity |
|----------|-------|--------|------------|-----------------------|
| DataMigrator | ExportCommandFactory | ExecuteExportAsync | 8556 | 92 |
| DataMigrator | ExportCommandFactory | ExportEntityAsync | 812 | 28 |
| DataMigrator | ExportCommandFactory | ExportGroupedEntitiesAsync | 800 | 28 |
| DataMigrator | ValidationService | ValidateConfiguration | 245 | 18 |
| DataMigrator | DataCollector | CollectEntityData | 156 | 15 |
</complexity_report>
```

**Reasoning**:
Report shows 1 catastrophic method (ExecuteExportAsync: 92/8556), 2 very high methods (both ~28/800), and 2 moderate methods. All high-complexity methods are in `ExportCommandFactory` - suggests class has too many responsibilities. Pattern: Export methods share similar structure and format-handling logic. Strategy: Severity-First prioritization, but leverage module-level patterns to refactor efficiently.

**Output** (Abbreviated):
```markdown
# Complexity Metrics Analysis

## Executive Summary
- Total: 5 methods analyzed
- Critical: 1 (ExecuteExportAsync - CATASTROPHIC)
- High: 2 (ExportEntityAsync, ExportGroupedEntitiesAsync)
- Medium: 2 (ValidateConfiguration, CollectEntityData)
- **Recommended Strategy**: Severity-First with Module-Level Pattern Reuse
- **Total Effort**: 5-7 days

## Severity Breakdown

### Critical (Urgent Refactoring)
| Method | Class | Complexity | CRAP | Risk Level |
|--------|-------|------------|------|------------|
| ExecuteExportAsync | ExportCommandFactory | 92 | 8556 | ☠️ CATASTROPHIC |

**Assessment**: Method has 92 decision points and CRAP score of 8556 - highest risk in entire codebase. Estimated 1165 lines handling 5 distinct responsibilities (validation, config, data collection, execution, reporting). This is the linchpin of export system - must refactor carefully but urgently.

**Estimated Effort**: 3-4 days (5 phases)
**Pattern**: Extract Service (create 5 focused services)

### High Priority
| Method | Class | Complexity | CRAP | Risk Level |
|--------|-------|------------|------|------------|
| ExportEntityAsync | ExportCommandFactory | 28 | 812 | 💀 Very High |
| ExportGroupedEntitiesAsync | ExportCommandFactory | 28 | 800 | 💀 Very High |

**Assessment**: Both methods have similar complexity profiles (28/~800) and are in same class as Critical method. Likely share code patterns and format-handling logic. **Opportunity**: Can reuse services extracted from ExecuteExportAsync refactoring.

**Estimated Effort**: 2-3 days (both methods together)
**Pattern**: Strategy Pattern + reuse Tier 1 services

### Medium Priority
[ValidateConfiguration and CollectEntityData with lower urgency]

## Pattern Analysis

**Common Issues**:
1. **Class Overload** - `ExportCommandFactory` contains 3 of 5 high-complexity methods
   - Suggests: Class doing too much, violates SRP
   - Solution: Extract services from class, reduce to factory role only

2. **Format Handling Conditionals** - All export methods have format-based branching
   - Example: if (format == CSV) {...} else if (format == JSON) {...}
   - Solution: Strategy Pattern - `IExportFormatStrategy` with format-specific implementations

3. **Missing Abstraction** - High-complexity methods do everything inline
   - No service layer, no delegation
   - Solution: Extract focused service classes

**Root Causes**:
- Multiple responsibilities in single methods: 3/5 methods
- Format-handling conditionals: 3/5 methods
- Lack of service abstraction: All methods

**Class-Level Analysis**:
- `ExportCommandFactory`: 3 high-complexity methods (92, 28, 28) - **Primary target**
- Other classes: Lower complexity, monitor only

## Prioritization Recommendation

**Strategy**: **Severity-First with Module-Level Pattern Reuse**

**Rationale**:
1. **Start with worst offender**: ExecuteExportAsync (92/8556) is catastrophic risk
2. **Extract reusable patterns**: Services created for ExecuteExportAsync can be reused for ExportEntityAsync and ExportGroupedEntitiesAsync
3. **Efficiency gain**: Refactoring all 3 `ExportCommandFactory` methods together reduces total effort by ~30%
4. **Class improvement**: Entire `ExportCommandFactory` class will be improved, not just individual methods

**Why not Module-First?**: Would require refactoring medium-priority methods first to "complete" the class - inefficient use of time.

**Why not Risk-Based?**: All export methods are equally business-critical - no risk differentiation.

## Refactoring Approach

### Tier 1: Critical - ExecuteExportAsync (3-4 days)

**Method**: ExecuteExportAsync  
**Current**: Complexity 92, CRAP 8556, 1165 lines  
**Target**: Complexity <15, CRAP <100, <50 lines  

**5-Phase Plan**:
1. Extract Format Validation → `FormatValidationService` (~10 complexity reduction)
2. Extract Configuration Building → `ExportConfigurationBuilder` (~8 reduction)
3. Extract Data Collection → `DataCollectionService` (~15 reduction)
4. Extract Export Execution → `ExportExecutionService` (~20 reduction)
5. Extract Results Reporting → `ResultReportingService` (~10 reduction)

**Expected Outcome**: Main method becomes orchestration logic calling 5 services.

**Next Step**: Run `@create-refactoring-plan ExecuteExportAsync`

### Tier 2: High Priority - Export Methods (2-3 days)

**Methods**: ExportEntityAsync, ExportGroupedEntitiesAsync  
**Current**: Both ~28 complexity, ~800 CRAP  
**Target**: <8 complexity, <50 CRAP each  

**Reuse-First Approach**:
1. **Reuse** services from Tier 1 (FormatValidationService, ExportConfigurationBuilder, etc.)
2. **Add** format-specific Strategy Pattern for entity vs grouped handling
3. **Extract** remaining method-specific logic to focused helpers

**Expected Outcome**: Both methods reduced to <50 lines, reusing 80% of Tier 1 services.

**Efficiency**: By doing Tier 1 first, Tier 2 becomes 2-3 days instead of 4-5 days.

### Tier 3: Medium Priority - Validation & Data Collection (2 days)
[Lower priority, monitor for now]

## Success Criteria
[Full checklist as in template]

## Next Steps

1. **Immediate**: Create ticket "EPP-XXX: Refactor ExecuteExportAsync" 
2. **Generate detailed plan**: Run `@create-refactoring-plan ExecuteExportAsync [paste method]`
3. **Review plan**: Technical lead approval before starting
4. **Begin Phase 1**: Extract Format Validation (2 hours, low risk)
5. **Track progress**: Update complexity metrics after each phase

## Estimated Total Effort

**By Tier**:
- Tier 1: 3-4 days (ExecuteExportAsync)
- Tier 2: 2-3 days (ExportEntityAsync + ExportGroupedEntitiesAsync)
- Tier 3: 2 days (Medium priority methods)
- **Total**: 7-9 days

**By Week**:
- Week 1: Tier 1 (Critical - ExecuteExportAsync)
- Week 2: Tier 2 (High - Entity export methods)
- Week 3: Tier 3 (Medium - Validation/Data)

**Expected Complexity Reduction**:
- Before: 5 methods, total complexity 181, avg CRAP 2281
- After: 5 methods, total complexity ~40, avg CRAP ~60
- **Reduction**: 78% complexity reduction, 97% CRAP reduction
```

### Example 2: Payment System Analysis

**Input**:
```
<complexity_report>
| Assembly | Class | Method | Crap Score | Cyclomatic Complexity |
|----------|-------|--------|------------|-----------------------|
| Payment | PaymentProcessor | ProcessTransaction | 420 | 35 |
| Payment | PaymentProcessor | RefundTransaction | 380 | 32 |
| Payment | ValidationService | ValidatePaymentMethod | 156 | 18 |
| Payment | FraudDetection | CheckFraudRisk | 512 | 42 |
</complexity_report>

<business_context>
Critical path: All payment processing
Active development: Adding cryptocurrency support
Compliance requirement: PCI-DSS certification required
</business_context>
```

**Reasoning**:
Report shows high-complexity payment processing methods. Business context indicates this is critical production code requiring PCI-DSS compliance. `FraudDetection.CheckFraudRisk` has highest CRAP (512) - critical risk for payment security. Strategy: **Risk-Based prioritization** - start with fraud detection despite not being highest complexity, because business impact is highest. Then tackle payment processing methods.

**Output** (Abbreviated):
```markdown
# Complexity Metrics Analysis - Payment System

## Executive Summary
- Total: 4 methods analyzed
- Critical: 1 (CheckFraudRisk - 42/512) - **Security-critical**
- High: 2 (ProcessTransaction - 35/420, RefundTransaction - 32/380)
- Medium: 1 (ValidatePaymentMethod - 18/156)
- **Recommended Strategy**: Risk-Based (Security & Compliance First)
- **Total Effort**: 6-8 days

## Severity Breakdown

### Critical (Urgent Refactoring)
| Method | Class | Complexity | CRAP | Risk Level | Business Impact |
|--------|-------|------------|------|------------|-----------------|
| CheckFraudRisk | FraudDetection | 42 | 512 | ☠️ CRITICAL | 🔐 Security |

**Assessment**: **SECURITY-CRITICAL** - Fraud detection directly impacts payment security and PCI-DSS compliance. CRAP score of 512 indicates high risk of introducing bugs during changes. With cryptocurrency support being added, this method will need modification soon - **must refactor before that work begins**.

**Compliance Impact**: High complexity in fraud detection may fail PCI-DSS code review requirements.

**Business Risk**: Bugs in fraud detection could result in:
- Unauthorized transactions processed
- False positives blocking legitimate customers
- Compliance audit failures

**Estimated Effort**: 2-3 days
**Pattern**: Extract Decision Rules + Strategy Pattern for fraud detection methods

**PRIORITY**: Start here despite not highest complexity - business risk is highest.

[... rest of analysis ...]

## Prioritization Recommendation

**Strategy**: **Risk-Based (Security & Compliance First)**

**Rationale**:
1. **Security-critical code**: FraudDetection.CheckFraudRisk must be refactored first due to security/compliance implications
2. **Imminent changes**: Cryptocurrency support will require modifying fraud detection - refactor before adding features
3. **Compliance requirement**: PCI-DSS audit may flag high-complexity payment code - proactive refactoring reduces audit risk
4. **Business impact**: Payment processing bugs are high-cost (chargebacks, reputation, compliance fines)

**Order**: CheckFraudRisk → ProcessTransaction → RefundTransaction → ValidatePaymentMethod

**Why not Severity-First?**: CheckFraudRisk isn't worst offender by metrics, but highest business/security risk.
```
