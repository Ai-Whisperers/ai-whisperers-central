---
name: manage-code-quality-enforcement
description: "Comprehensive code quality enforcement management - check, repair, and gradually tighten warnings-as-errors policies"
category: code-quality
tags: code-quality, warnings, errors, enforcement, gradual-tightening, ci-cd
argument-hint: "Target project path (e.g., src/MyProject/ or . for root)"
---

# Manage Code Quality Enforcement

## Purpose

Comprehensive management of code quality enforcement settings across .NET projects, including warnings-as-errors configuration, gradual tightening policies, and CI/CD integration. Handles the complete lifecycle from "warnings as errors" enforcement to temporary suppressions to systematic issue resolution.

## Preferred “Golden Path” (Script-First)

Use the quality scripts as the primary mechanism (avoid ad-hoc manual commands):

1. **Assess config**: `.\.cursor\scripts\quality\analyze-quality-config.ps1`
2. **Auto-fix first**: `.\.cursor\scripts\quality\validate-pre-merge.ps1` (runs `dotnet format` + `dotnet format analyzers`)
3. **Targeted fix scripts**: `validate-pre-merge.ps1` step 2 runs available `fix-*.ps1` scripts (CS1591, IDE1006, CS1570 comments/format, IDE0028, CA1825)
4. **Validate**: build + tests + format verification via `validate-pre-merge.ps1`
5. **Gradual tightening**:
   - Enable one analyzer at a time with: `validate-pre-merge.ps1 -EnableAnalyzer <CODE> -AnalyzerSeverity warning -TrackProgress`
   - Update `.editorconfig` severity baselines from `quality-config.json` using: `.\.cursor\scripts\quality\enforce-quality.ps1 -Action update-editorconfig`

## Required Context

- `[TARGET_PATH]`: Target project/directory path (e.g., `src/MyProject/` or `.` for root)
- `[CURRENT_PHASE]`: Current enforcement phase (optional):
  - `baseline` - Initial assessment
  - `auto-fix` - Run automated fix scripts first
  - `enforce` - Enable warnings-as-errors
  - `suppress` - Add temporary suppressions
  - `gradual` - Gradually remove suppressions
  - `strict` - Full enforcement

## Optional Parameters

- `[TOLERANCE_LEVEL]`: Warning tolerance (0-100, default 0 for zero-tolerance)
- `[SUPPRESSION_DAYS]`: Days suppressions are valid before review (default 30)
- `[CI_CD_INTEGRATION]`: Enable CI/CD step generation (`true`/`false`, default `false`)
- `[FIX_SCRIPTS]`: JSON array of available fix scripts with error codes:
  ```json
  [
    {"errorCode": "IDE1006", "scriptPath": ".cursor/scripts/quality/fix-async-method-naming.ps1", "description": "Fix async method naming violations"},
    {"errorCode": "CA1304", "scriptPath": ".cursor/scripts/quality/fix-culture-info.ps1", "description": "Fix string comparison culture issues"}
  ]
  ```
- `[STORE_SUCCESSFUL_SCRIPTS]`: Store successful fix scripts for reuse (`true`/`false`, default `true`)

## Reasoning Process

1. **Assess Current State**: Analyze project configurations, editorconfigs, and existing suppressions
2. **Check Available Fix Scripts**: Identify which automated fix scripts are available for detected errors
3. **Prioritize Fixes**: Run automated fix scripts first (fast, reliable), then manual fixes
4. **Identify Gaps**: Compare current settings against enforcement standards
5. **Plan Progression**: Determine appropriate phase based on current quality level
6. **Generate Actions**: Create specific commands and configuration changes
7. **Store Successful Scripts**: Save working fix scripts for future reuse
8. **Validate Safety**: Ensure changes won't break builds or introduce regressions

## Process

### Phase 1: Assessment & Analysis

#### Check Project Configurations

Prefer the repository scripts for configuration inventory:

```powershell
.\.cursor\scripts\quality\analyze-quality-config.ps1
```

#### Analyze EditorConfig Settings

```powershell
# Find .editorconfig files and show explicit severities
Get-ChildItem -Path "[TARGET_PATH]" -Recurse -Filter ".editorconfig" -File |
  ForEach-Object {
    $_.FullName
    Select-String -Path $_.FullName -Pattern "dotnet_diagnostic\\..*\\.severity\\s*="
  }
```

#### Inventory Existing Suppressions

```powershell
# Common suppression files
Get-ChildItem -Path "[TARGET_PATH]" -Recurse -File |
  Where-Object { $_.Name -eq "GlobalSuppressions.cs" -or $_.Name -like "*.suppress" } |
  Select-Object -ExpandProperty FullName

# Inline suppressions (rough count)
(Get-ChildItem -Path "[TARGET_PATH]" -Recurse -Filter "*.cs" -File |
  Select-String -Pattern "#pragma warning disable").Count
```

#### Analyze Current Build Status

Prefer the orchestrator (supports DryRun and JSON output):

```powershell
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "[TARGET_PATH]" -SkipAutoFix
```

### Phase 2: Automated Fix Scripts (Run First)

Prefer the repository orchestrator: it already runs `dotnet format`, `dotnet format analyzers`, and any supported `fix-*.ps1` scripts before you do manual work.

```powershell
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "[TARGET_PATH]"
```

See exemplar (expanded “fix scripts” pattern): `../exemplars/code-quality/manage-code-quality-enforcement-fix-scripts-exemplar.md`

If you need to tighten gradually (one analyzer at a time, with tracking):

```powershell
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "[TARGET_PATH]" -EnableAnalyzer <CODE> -AnalyzerSeverity warning -TrackProgress
```

### Phase 3: Configuration Repair

#### Enable Warnings-as-Errors in Projects

```xml
<!-- Add to each .csproj file -->
<PropertyGroup>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <WarningsAsErrors />
  <AnalysisLevel>latest</AnalysisLevel>
  <EnableNETAnalyzers>true</EnableNETAnalyzers>
</PropertyGroup>
```

#### Configure EditorConfig for Strict Enforcement

```ini
# Add to .editorconfig
[*.cs]
dotnet_diagnostic.CA1304.severity = error
dotnet_diagnostic.CA1305.severity = error
dotnet_diagnostic.CA1062.severity = error
dotnet_diagnostic.CA1307.severity = error
dotnet_diagnostic.IDE1006.severity = error
# NOTE: CA1860 is intentionally NOT included (counter good working practice)

# Culture/string issues
dotnet_diagnostic.CA1304.severity = error    # ToLower without culture
dotnet_diagnostic.CA1305.severity = error    # ToString without culture

# Null validation
dotnet_diagnostic.CA1062.severity = error    # null validation

# String comparison
dotnet_diagnostic.CA1307.severity = error    # StringComparison

# Naming conventions
dotnet_diagnostic.IDE1006.severity = error   # Missing underscore prefix

# CA1860 deliberately omitted (counter good working practice)
# dotnet_diagnostic.CA1860.severity = none   # Not needed - analyzer already skipped
```

### CA1860 Skip/Deactivate Policy

#### 🚫 CA1860 SKIP/DEACTIVATE: Counter Good Working Practice

**CRITICAL DECISION**: CA1860 warnings are **DEACTIVATED/SKIPPED** as they represent counter good working practices.

**Reasoning**:
- CA1860 blindly recommends `Count > 0` over `Any()` for "performance"
- This ignores context: `Count()` enumerates entire collection on `IEnumerable<T>`, while `Any()` short-circuits
- For LINQ queries and database scenarios, `Any()` is actually more efficient
- CA1860's blanket recommendation fails for lazy evaluation and infinite sequences
- The analyzer's "performance" claim is context-dependent and often incorrect

**Action Required**:
- **SKIP ALL CA1860 warnings** - do not apply any transformations
- **Document CA1860 violations** but leave code unchanged
- **Accept CA1860 as false positive** - the current `Any()` usage is intentional and correct

**Exception**: Only apply CA1860 transformations if `IsEmpty` property is actually available on the collection type (rare in .NET).

**Do NOT add to EditorConfig**:
```ini
# ❌ DO NOT ADD: This would enforce the counter good practice
# dotnet_diagnostic.CA1860.severity = error
```

### Phase 3: Suppression Management

#### Create Global Suppressions File

```csharp
// GlobalSuppressions.cs (temporary, max [SUPPRESSION_DAYS] days)
using System.Diagnostics.CodeAnalysis;

[assembly: SuppressMessage("Naming", "IDE1006:Missing prefix: '_'", Justification = "Temporary suppression during gradual enforcement. Remove by [DATE]", Scope = "member", Target = "~M:MyClass.method")]
```

#### Inline Suppressions (Last Resort)

```csharp
#pragma warning disable CA1304 // ToLower without culture - TODO: Add CultureInfo.InvariantCulture
var lower = input.ToLower();
#pragma warning restore CA1304
```

### Phase 4: Gradual Tightening Strategy

#### Level 1: Culture/String Issues Only

- Enable: CA1304, CA1305
- Suppress: IDE1006, CA1062, CA1307
- Duration: 7 days

#### Level 2: Add Null Validation

- Keep: CA1304, CA1305
- Enable: CA1062
- Suppress: IDE1006, CA1307
- Duration: 14 days

#### Level 3: Add String Comparison

- Keep: CA1304, CA1305, CA1062
- Enable: CA1307
- Suppress: IDE1006
- Duration: 21 days

#### Level 4: Add Naming Conventions

- Enable: All (CA1304, CA1305, CA1062, CA1307, IDE1006)
- No suppressions
- Duration: Permanent

### Phase 5: CI/CD Integration

#### Generate CI/CD Validation Script

```powershell
# Prefer the repository orchestrator in CI so local and CI behavior stays aligned.
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "[TARGET_PATH]" -SkipAutoFix
```

See templar (expanded CI/CD script example): `../templars/code-quality/manage-code-quality-enforcement-cicd-validation-templar.md`

#### CI/CD Pipeline Integration

```yaml
# Add to azure-pipelines.yml
- task: PowerShell@2
  displayName: 'Validate code quality (no auto-fix)'
  inputs:
    targetType: 'inline'
    script: |
      .\\.cursor\\scripts\\quality\\validate-pre-merge.ps1 -TargetPath \"$(Build.SourcesDirectory)\" -SkipAutoFix
```

## Examples

### Example 1: Baseline assessment (script-first)

```text
@manage-code-quality-enforcement src/MyProject/

Recommended commands:
.\.cursor\scripts\quality\analyze-quality-config.ps1
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "src/MyProject/" -SkipAutoFix
```

### Example 2: Gradual tightening (single analyzer)

```text
@manage-code-quality-enforcement src/MyProject/ gradual

Next action:
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "src/MyProject/" -EnableAnalyzer CA1304 -AnalyzerSeverity warning -TrackProgress
```

## Output Format

### Assessment Report

```markdown
## Code Quality Enforcement Assessment

**Target**: [TARGET_PATH]
**Date**: [TIMESTAMP]
**Phase**: [CURRENT_PHASE]

### Current State
- **Projects**: [count] .csproj files found
- **Build Status**: [PASS/FAIL] with [X] warnings, [Y] errors
- **Suppressions**: [Z] active suppressions found

### Issues by Category
| Category | Count | Severity | Action |
|----------|-------|----------|--------|
| CA1304 (Culture) | 3 | High | Fix immediately |
| IDE1006 (Naming) | 8 | Medium | Gradual fix |
| CA1062 (Null) | 4 | High | Fix in batches |

### Recommendations
1. **Immediate**: Enable warnings-as-errors in all projects
2. **Short-term**: Add temporary suppressions for existing issues
3. **Medium-term**: Gradual removal of suppressions over 30 days
4. **Long-term**: Strict zero-tolerance policy

**Next Phase**: [RECOMMENDED_PHASE]
```

### Action Report

```markdown
## Code Quality Enforcement Actions

**Target**: [TARGET_PATH]
**Phase**: [EXECUTED_PHASE]
**Date**: [TIMESTAMP]

### Files Modified
- ✅ `MyProject.csproj`: Added `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`
- ✅ `.editorconfig`: Updated severity settings
- ✅ `GlobalSuppressions.cs`: Added temporary suppressions

### Build Validation
- **Before**: 15 warnings, 0 errors
- **After**: 0 warnings, 15 errors (expected with enforcement)
- **With Suppressions**: 0 warnings, 0 errors (temporary)

### Next Steps
1. **Fix Issues**: Address suppressed warnings systematically
2. **Schedule Review**: Reassess suppressions in 30 days
3. **Advance Phase**: Move to 'gradual' phase when ready

**CI/CD Updated**: Added validation step to pipeline
```

## Validation Checklist

Before claiming code quality enforcement is properly configured:

- [ ] CA1860 warnings are properly skipped/deactivated (counter good working practice)
- [ ] Repo orchestrator (`validate-pre-merge.ps1`) was run (with/without auto-fix as appropriate)
- [ ] `.csproj` + `.editorconfig` match the intended enforcement phase (excluding CA1860)
- [ ] Temporary suppressions (if any) are minimal, justified, and time-boxed
- [ ] CI (if configured) runs the same orchestrator steps as local

## Usage Modes

### Basic Mode (Quick Assessment)

For simple projects or when you just want to enable warnings-as-errors:

```text
@manage-code-quality-enforcement src/MyProject/
```

Runs baseline assessment and recommends next steps.

### Enforcement Mode (Enable Strict Checking)

For projects ready to enforce quality standards:

```text
@manage-code-quality-enforcement src/MyProject/ enforce
```

Enables warnings-as-errors and validates the change.

### Suppression Mode (Add Temporary Fixes)

When build fails after enforcement and you need temporary suppressions:

```text
@manage-code-quality-enforcement src/MyProject/ suppress
```

Adds temporary suppressions with automatic expiration.

### Gradual Mode (Progressive Improvement)

For systematic quality improvement over time:

```text
@manage-code-quality-enforcement src/MyProject/ gradual
```

Removes suppressions gradually based on the tightening schedule.

### Strict Mode (Zero Tolerance)

For production-ready code with no warnings or errors:

```text
@manage-code-quality-enforcement src/MyProject/ strict
```

Enforces absolute zero-tolerance policy.

## Troubleshooting

### Issue: Build Fails After Enforcement

**Symptoms**: `dotnet build` fails with many errors after enabling warnings-as-errors
**Cause**: Existing code has warnings that are now treated as errors
**Solutions**:

1. **Quick Fix**: Run suppression mode to add temporary suppressions
2. **Long-term Fix**: Run gradual mode to fix issues systematically
3. **Check Specific Errors**: Review error messages to identify patterns

### Issue: Suppressions Not Working

**Symptoms**: Build still fails even after adding suppressions
**Cause**: Suppressions may not match exact error codes or locations
**Solutions**:

1. **Verify Error Codes**: Check that suppression codes match actual warnings
2. **Check File Paths**: Ensure suppressions target correct files
3. **Use GlobalSuppressions.cs**: Add suppressions to global file instead of inline

### Issue: Too Many Suppressions

**Symptoms**: Hundreds of suppressions added, feels overwhelming
**Cause**: Trying to fix too much at once
**Solutions**:

1. **Use Gradual Mode**: Fix issues in phases over time
2. **Prioritize by Impact**: Focus on high-impact warnings first
3. **Set Tolerance Level**: Use `--tolerance-level 10` to allow some warnings

## Advanced Features

### Custom Phases

You can create custom enforcement phases by modifying the PowerShell script:

```powershell
# Add custom phase logic
switch ($Phase) {
    'custom' {
        # Your custom enforcement logic
        Write-Host "Applying custom quality rules..." -ForegroundColor Yellow
    }
}
```

### Quality Metrics Tracking

Generate comprehensive quality reports:

```powershell
# Quality metrics report
$metrics = @{
    TotalFiles = (Get-ChildItem -Recurse -Filter "*.cs").Count
    TotalWarnings = $currentWarnings
    SuppressionsActive = $activeSuppressions.Count
    BuildPassRate = if ($buildSuccess) { 100 } else { 0 }
    AverageFixTime = "2.5 days"
}

Write-Host "=== Quality Enforcement Metrics ===" -ForegroundColor Cyan
$metrics.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)" -ForegroundColor White
}
```

## Related Prompts

- `check-naming-conventions` - Specific naming convention validation
- `refactor-for-clean-code` - Code quality improvement
- `iterative-refinement` - Gradual improvement approach
- `report-errors` - Error analysis and reporting
- `fix-diag-warn-err.prompt.md` - Fix all analyzer diagnostics with zero tolerance

## Related Rules

- `rule.quality.zero-warnings-zero-errors.v1` - Zero tolerance policy
- `rule.quality.diagnostic-messages.v1` - Quality error reporting
- `rule.quality.code-quality-enforcement-rule.mdc` - Systematic enforcement patterns
- `rule.scripts.core-principles.v1` - Script portability and reusability standards
- `rule.scripts.powershell-standards.v1` - PowerShell script quality requirements
- `rule.cicd.pre-build-validation.v1` - CI/CD integration patterns
- `rule.cicd.tag-based-versioning-rule.mdc` - Version control integration
- `rule.ticket.workflow.v1` - Ticket-based gradual enforcement
- `rule.ticket.complexity-assessment-rule.mdc` - Implementation strategy selection
- `rule.development.commit-message.mdc` - Quality commit standards

## Fix Script Registry

### Script Storage Format

Successful fix scripts are stored in `.cursor/scripts/quality/script-registry.json`:

```json
{
  "scripts": [
    {
      "errorCode": "IDE1006",
      "scriptPath": ".cursor/scripts/quality/fix-async-method-naming.ps1",
      "description": "Fix async method naming violations",
      "successCount": 15,
      "lastSuccess": "2025-12-13"
    }
  ],
  "lastUpdated": "2025-12-13"
}
```

### Script Discovery

The prompt automatically discovers available fix scripts from:
1. **Explicit parameter**: `[FIX_SCRIPTS]` JSON array
2. **Registry file**: Previously successful scripts
3. **Standard locations**: `.cursor/scripts/quality/*.ps1` files with error code prefixes

### Best Practice: Proven Scripts First

**Always prefer proven scripts over creating new ones:**
- ✅ **Reuse existing**: Scripts that have worked multiple times
- ✅ **Test before trust**: New scripts should be validated before wide use
- ✅ **Collect successes**: Store working scripts in registry for team reuse
- ❌ **Avoid recreation**: Don't rewrite working scripts unless significantly improved
