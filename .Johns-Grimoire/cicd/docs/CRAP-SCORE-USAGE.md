# CRAP Score Usage Guide

## Overview

The `enhanced-coverage-analysis.ps1` script now generates **CRAP (Change Risk Anti-Patterns) scores** for all methods in your codebase. These scores help you identify high-risk code that needs refactoring by combining:

- **Cyclomatic Complexity**: How complex the code is
- **Test Coverage**: How well the code is tested

**Formula**: `CRAP = Complexity² × (1 - Coverage)³ + Complexity`

## Quick Start

### Step 1: Generate Code Metrics

First, run the code metrics script to calculate cyclomatic complexity:

```powershell
.\cicd\scripts\calculate-code-metrics.ps1 -Configuration Release
```

**Output**: `local-reports/metrics/metrics-summary.json`

### Step 2: Run Coverage Analysis with CRAP Scores

```powershell
.\cicd\scripts\enhanced-coverage-analysis.ps1 -Configuration Release
```

**Outputs**:
- `local-reports/coverage/crap-scores.md` - Prompt-ready markdown table
- `local-reports/coverage/crap-scores.csv` - Full data for analysis
- `local-reports/coverage/enhanced-coverage-summary.json` - Updated with CRAP metrics

### Step 3: Use with AI Prompt

Open the generated `crap-scores.md` file and copy the table. Then use the `analyze-complexity-metrics` prompt:

```
@analyze-complexity-metrics

<complexity_report>
[Paste table from crap-scores.md here]
</complexity_report>
```

The AI will:
1. **Categorize methods** by severity (Critical, High, Medium, Low)
2. **Identify patterns** and root causes of complexity
3. **Recommend prioritization** strategy
4. **Create detailed refactoring** approach

## Understanding CRAP Scores

### What Does the Score Mean?

| CRAP Score | Risk Level | What It Means | Action |
|---|---|---|---|
| **1-30** | ✅ Low | Simple and/or well-tested | Keep up the good work! |
| **31-60** | ⚠️ Medium | Getting complex or under-tested | Monitor, consider improving |
| **61-100** | ⚠️ High | Complex and under-tested | Plan to refactor soon |
| **>100** | ❌ Critical | Very complex and poorly tested | **Refactor immediately** |

### How Does It Work?

The CRAP formula considers both complexity and coverage:

```
CRAP = Complexity² × (1 - Coverage)³ + Complexity
```

**Key Insights**:

1. **100% Coverage**: CRAP ≈ Complexity
   - Even complex code is acceptable if well-tested
   - Example: Complexity 15, Coverage 100% → CRAP 15 ✅

2. **0% Coverage**: CRAP = Complexity² + Complexity
   - Untested code gets severely penalized
   - Example: Complexity 15, Coverage 0% → CRAP 240 ❌

3. **Partial Coverage**: Exponential penalty
   - Even 50% coverage is much better than 0%
   - Example: Complexity 15, Coverage 50% → CRAP 43 ⚠️

### Real-World Examples

| Method | Complexity | Coverage | CRAP | Risk | Why? |
|---|---|---|---|---|---|
| `GetVersion()` | 1 | 100% | 1 | ✅ Low | Trivial method, perfect coverage |
| `ParseConfig()` | 8 | 95% | 8 | ✅ Low | Reasonable complexity, well-tested |
| `CalculateTotal()` | 5 | 0% | 30 | ⚠️ Medium | Simple but completely untested |
| `ValidateInput()` | 12 | 80% | 13 | ✅ Low | Complex but very well-tested |
| `ProcessOrder()` | 20 | 30% | 418 | ❌ Critical | Very complex and poorly tested |

## Using the Outputs

### 1. Markdown Table (`crap-scores.md`)

**Purpose**: Direct input to AI prompts

**Format**:
```markdown
| Assembly | Class | Method | Crap Score | Cyclomatic Complexity | Line Coverage (%) |
|----------|-------|--------|------------|-----------------------|-------------------|
| MyAssembly | OrderProcessor | ProcessOrder | 418.5 | 20 | 30.0 |
| MyAssembly | PaymentService | ValidatePayment | 156.2 | 15 | 40.0 |
```

**Usage**: Copy and paste into `@analyze-complexity-metrics` prompt

### 2. CSV Export (`crap-scores.csv`)

**Purpose**: Detailed analysis in Excel, Power BI, or custom tools

**Columns**:
- `Assembly`: Which assembly contains the method
- `Class`: Which class contains the method
- `Method`: Method name
- `CrapScore`: Calculated CRAP score
- `CyclomaticComplexity`: Method complexity (from code metrics)
- `LineCoverage`: Test coverage percentage (0-100)

**Usage Examples**:
- Sort by CRAP score to find worst methods
- Filter by assembly to focus on specific projects
- Pivot by class to find problem classes
- Track changes over time (compare multiple runs)

### 3. JSON Summary (`enhanced-coverage-summary.json`)

**Purpose**: Programmatic access, CI/CD integration

**New Fields**:
```json
{
  "CrapScores": {
    "TotalMethods": 1234,
    "AverageCrapScore": 25.5,
    "HighCrapMethods": 15
  },
  "HighCrapMethods": [
    {
      "Assembly": "MyAssembly",
      "Class": "OrderProcessor",
      "Method": "ProcessOrder",
      "CrapScore": 418.5,
      "CyclomaticComplexity": 20,
      "LineCoverage": 30.0
    }
  ]
}
```

**Usage**: CI/CD gates, dashboards, automated alerts

## Refactoring Workflow

### 1. Identify High-CRAP Methods

Run the script and review the console output:

```
[WARN] 15 methods exceed MinCrapScore threshold (100):
  - OrderProcessor.ProcessOrder (CRAP: 418, Complexity: 20, Coverage: 30%)
  - PaymentService.ValidatePayment (CRAP: 156, Complexity: 15, Coverage: 40%)
  ...
```

### 2. Prioritize Methods

**Factors to consider**:
- **CRAP Score**: Higher = more urgent
- **Business Impact**: Critical paths first
- **Change Frequency**: Often-changed code first
- **Team Capacity**: Start with manageable wins

**Typical Prioritization**:
1. Critical business logic with CRAP > 200
2. Frequently changed methods with CRAP > 100
3. Security-sensitive code with CRAP > 60
4. Other methods by descending CRAP score

### 3. Choose Refactoring Strategy

Use the `analyze-complexity-metrics` prompt to get AI-generated refactoring plans:

```
@analyze-complexity-metrics

<complexity_report>
[Paste table from crap-scores.md]
</complexity_report>
```

The AI will suggest:
- **Extract Method**: Break down complex methods
- **Simplify Conditionals**: Reduce branching
- **Add Tests**: Increase coverage first
- **Replace Complex Logic**: Simplify algorithms

### 4. Refactor and Verify

After refactoring:

```powershell
# Re-run metrics and coverage
.\cicd\scripts\calculate-code-metrics.ps1
.\cicd\scripts\enhanced-coverage-analysis.ps1

# Verify CRAP score improvement
# Check crap-scores.md for updated scores
```

**Target**: CRAP < 30 for all methods

### 5. Track Progress

Enable history tracking to monitor trends:

```powershell
.\cicd\scripts\enhanced-coverage-analysis.ps1 -EnableHistoryTracking
```

**Historical Data**: `.history/coverage-history.jsonl`

## Configuration Options

### Adjust CRAP Threshold

Default threshold is 100. Adjust based on your team's standards:

```powershell
# Stricter (warn at CRAP > 60)
.\enhanced-coverage-analysis.ps1 -MinCrapScore 60

# More lenient (warn at CRAP > 150)
.\enhanced-coverage-analysis.ps1 -MinCrapScore 150

# No warnings (informational only)
.\enhanced-coverage-analysis.ps1 -MinCrapScore 10000
```

### CI/CD Integration

**Azure Pipelines**:

```yaml
- task: PowerShell@2
  displayName: 'Analyze Coverage and CRAP Scores'
  inputs:
    filePath: 'cicd/scripts/enhanced-coverage-analysis.ps1'
    arguments: '-MinLineCoverage 70 -MinCrapScore 100'
    pwsh: true
```

**Warning Output**:
```
##vso[task.logissue type=warning]ProcessOrder has high CRAP score: 418
```

## Troubleshooting

### Problem: All CRAP scores are 0

**Cause**: Code metrics not available

**Solution**:
1. Run `calculate-code-metrics.ps1` first
2. Verify `local-reports/metrics/metrics-summary.json` exists
3. Check for errors in metrics script output

### Problem: CRAP scores seem incorrect

**Cause**: Method name mismatch between coverage and metrics

**Solution**:
- Verify method names match exactly (case-sensitive)
- Check for method overloads (may need disambiguation)
- Review `metrics-summary.json` for expected method entries

### Problem: Too many high-CRAP warnings

**Cause**: Threshold too low for current codebase state

**Solution**:
- Increase `-MinCrapScore` temporarily
- Focus on top 10-20 worst methods first
- Set realistic goals for gradual improvement

## Best Practices

### 1. Run Regularly

**Frequency**:
- **Daily**: During active development
- **Pre-commit**: Before merging feature branches
- **Release**: Before tagging releases

### 2. Set Realistic Thresholds

**Recommendation**:
- **New projects**: Start with MinCrapScore 60
- **Existing projects**: Start with MinCrapScore 150, gradually tighten
- **Legacy projects**: Start with MinCrapScore 300, focus on critical paths

### 3. Focus on High-Impact Methods

**Priority Order**:
1. Business-critical logic (orders, payments, security)
2. Frequently changed code (hot spots)
3. Public APIs (external contracts)
4. Complex algorithms (data processing, calculations)

### 4. Balance Refactoring with Tests

**Two Approaches**:

**A. Coverage First** (safer):
1. Add tests to increase coverage
2. Run analysis to verify CRAP improvement
3. Then refactor with safety net

**B. Refactoring First** (faster):
1. Simplify complex code
2. Add tests for refactored code
3. Verify CRAP improvement

**Recommended**: Coverage First for critical code, Refactoring First for non-critical

### 5. Track Trends

Enable history tracking to see improvement over time:

```powershell
.\enhanced-coverage-analysis.ps1 -EnableHistoryTracking
```

Review trends in `.history/coverage-history.jsonl`:
- Average CRAP score decreasing?
- Number of high-CRAP methods decreasing?
- Coverage improving?

## References

- **CRAP Metric Background**: [Google Testing Blog - This Code Is Crap](https://testing.googleblog.com/2011/02/this-code-is-crap.html)
- **Original Paper**: Artho et al., "Code Coverage for Continuous Integration" (2008)
- **Implementation Details**: See `CRAP-IMPLEMENTATION-SUMMARY.md`
- **AI Refactoring Prompt**: `.cursor/prompts/code-quality/analyze-complexity-metrics.prompt.md`

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review implementation summary: `CRAP-IMPLEMENTATION-SUMMARY.md`
3. Check script help: `Get-Help .\enhanced-coverage-analysis.ps1 -Full`
4. Review script source: `cicd/scripts/enhanced-coverage-analysis.ps1`

---

**Quick Reference**:
- **Run**: `.\cicd\scripts\enhanced-coverage-analysis.ps1`
- **Output**: `local-reports/coverage/crap-scores.md`
- **Prompt**: `@analyze-complexity-metrics`
- **Threshold**: Default 100, adjust with `-MinCrapScore`
- **Goal**: All methods CRAP < 30

**Remember**: CRAP scores are a guide, not an absolute rule. Use your judgment to balance refactoring effort with business value!
