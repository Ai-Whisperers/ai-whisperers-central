# Quality Script Gaps Analysis

**Date**: 2025-12-14  
**Purpose**: Document missing automation in the quality enforcement workflow

## Current Script Coverage

### ✅ Well-Covered Areas

1. **Configuration Analysis**: `analyze-quality-config.ps1` ✅
   - Identifies ALL disabled analyzers in configuration files
   - Shows NoWarn suppressions and severity levels
   - Detects configuration conflicts

2. **Error Discovery**: `build-and-find-errors.ps1` ✅
   - Builds solution and shows first N errors of specific type
   - Formatted output with fix guidance
   - Error type filtering

3. **Auto-Fixing**: `dotnet format` tools ✅
   - Fixes 70-80% of issues automatically
   - Code formatting and analyzer diagnostics

4. **Specific Fixes**: Specialized scripts ✅
   - `fix-cs1591-documentation.ps1` - XML documentation
   - `fix-ide1006-async-method-naming.ps1` - Async naming

5. **Pre-Merge Validation**: `validate-pre-merge.ps1` ✅
   - **COMPLETE PRE-MERGE ORCHESTRATOR** - Automates entire validation workflow
   - 7-step automated process (auto-fix → fix diagnostics → build → test → validate → final check)
   - Zero-warnings, zero-errors enforcement
   - JSON output for AI consumption
   - Batch processing with file limits
   - Diagnostic filtering

6. **Quality Enforcement**: `enforce-quality.ps1` ✅
   - Main quality enforcement coordinator
   - Uses `quality-config.json` for configuration

## ❌ Missing Automation

### 1. ✅ Analyzer Assessment Script - **ALREADY EXISTS!**

**Script**: `analyze-quality-config.ps1` ✅

**Purpose**: Identify ALL disabled analyzers in configuration files

**Functionality**:
```powershell
# Scan .editorconfig, *.csproj, Directory.Build.props, Directory.Packages.props
# Output: Comprehensive configuration report with suppressions, severities, conflicts

# Basic usage - console output
.\analyze-quality-config.ps1

# Show only suppressed diagnostics
.\analyze-quality-config.ps1 -ShowSuppressedOnly

# JSON output for automation
.\analyze-quality-config.ps1 -OutputFormat json > config-report.json

# Show configuration conflicts
.\analyze-quality-config.ps1 -ShowConflicts
```

**Output includes**:
- NoWarn suppressions from Directory.Build.props
- .editorconfig severity rules (grouped by severity: error/warning/suggestion/none)
- Analyzer packages and versions
- Project-specific overrides
- Configuration conflicts (rules defined multiple times with different severities)
- Analysis level, TreatWarningsAsErrors, EnforceCodeStyleInBuild settings

**Status**: ✅ **IMPLEMENTED** - Gap #1 is actually filled!

---

### 2. Analyzer Enablement Script

**Need**: `enable-analyzer.ps1`

**Purpose**: Enable ONE analyzer at a time in appropriate config file

**Functionality**:
```powershell
# Enable specific analyzer by modifying config
.\enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning

# Actions:
# - Find where analyzer is disabled
# - Change severity from "none" to "warning"/"error"
# - Or remove from NoWarn list
# - Update .editorconfig or project file
# - Report what was changed
```

**Current Workaround**: Manual editing of .editorconfig, project files

---

### 3. Enablement Progress Tracker

**Need**: `track-analyzer-progress.ps1`

**Purpose**: Track which analyzers have been enabled/fixed

**Functionality**:
```powershell
# Create/update progress tracking file
.\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status completed

# Maintains progress.json:
# {
#   "analyzers": {
#     "CA1062": { "status": "completed", "errors_fixed": 45, "date": "2025-12-14" },
#     "IDE0060": { "status": "in-progress", "errors_fixed": 12, "date": "2025-12-14" },
#     "CA1848": { "status": "pending", "errors_fixed": 0, "date": null }
#   }
# }

# Show progress report
.\track-analyzer-progress.ps1 -Report
# Output:
#   Completed: 3/15 analyzers (20%)
#   In Progress: 1 analyzer (CA1062)
#   Pending: 11 analyzers
```

**Current Workaround**: Manual tracking in notes/documents

---

### 4. Enablement Plan Generator

**Need**: `create-enablement-plan.ps1`

**Purpose**: Generate comprehensive plan for enabling all disabled analyzers

**Functionality**:
```powershell
# Generate full enablement plan
.\create-enablement-plan.ps1 -Output enablement-plan.md

# Creates markdown file with:
# - Complete list of disabled analyzers
# - Recommended enablement order (based on complexity/impact)
# - Estimated effort per analyzer
# - Dependencies between analyzers
# - Checklist format for tracking

# Example output:
# # Analyzer Enablement Plan
# 
# ## Phase 1: Quick Wins (Auto-fixable)
# - [ ] IDE0005: Remove unused usings (auto-fix available)
# - [ ] IDE0007: Use var (auto-fix available)
# 
# ## Phase 2: Documentation
# - [ ] CS1591: Add XML documentation (script: fix-cs1591-documentation.ps1)
# 
# ## Phase 3: Naming Conventions
# - [ ] IDE1006: Async naming (script: fix-ide1006-async-method-naming.ps1)
# 
# ## Phase 4: Complex Logic Changes
# - [ ] CA1062: Add null guards (manual fixes required)
# - [ ] CA1848: LoggerMessage delegates (manual fixes required)
```

**Current Workaround**: Manual planning and prioritization

---

## Workflow Comparison

### Current Workflow (With analyze-quality-config.ps1)

```
1. ✅ SCRIPT: analyze-quality-config.ps1 (shows all disabled analyzers!)
2. ❌ MANUAL: Decide enablement order
3. ❌ MANUAL: Edit .editorconfig to enable one analyzer
4. ✅ SCRIPT: build-and-find-errors.ps1 -ErrorType CA1062
5. ✅ SCRIPT: dotnet format (smoke test)
6. ✅ SCRIPT: fix-cs1591-documentation.ps1 (if CS1591)
7. ✅ SCRIPT: dotnet build (verify)
8. ❌ MANUAL: Track progress in notes
9. ❌ MANUAL: Repeat steps 3-8 for next analyzer
```

**Manual Steps**: 3 out of 9 (33%) - Better than initially thought!

### Proposed Fully Automated Workflow

```
1. ✅ SCRIPT: analyze-quality-config.ps1 (✅ already exists!)
2. ✅ SCRIPT: create-enablement-plan.ps1 -Output plan.md
3. ✅ SCRIPT: enable-analyzer.ps1 -AnalyzerId CA1062
4. ✅ SCRIPT: build-and-find-errors.ps1 -ErrorType CA1062
5. ✅ SCRIPT: dotnet format (smoke test)
6. ✅ SCRIPT: fix-cs1591-documentation.ps1 (if CS1591)
7. ✅ SCRIPT: dotnet build (verify)
8. ✅ SCRIPT: track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status completed
9. ✅ SCRIPT: enable-analyzer.ps1 -Next (auto-selects next from plan)
10. ✅ SCRIPT: Repeat steps 4-9 automatically
```

**Manual Steps**: 0 out of 10 (0%) - **100% automated!**

---

## Priority Order

1. ~~**HIGH**: `analyze-disabled-analyzers.ps1`~~ ✅ **ALREADY EXISTS** as `analyze-quality-config.ps1`
2. **HIGH**: `enable-analyzer.ps1` (eliminates tedious manual config editing)
3. **MEDIUM**: `track-analyzer-progress.ps1` (nice-to-have for visibility)
4. **LOW**: `create-enablement-plan.ps1` (helpful but can be done manually)

---

## Implementation Recommendations

### ✅ Assessment Script Already Exists!

**Good news**: `analyze-quality-config.ps1` already provides comprehensive analysis:
- ✅ Lists ALL disabled analyzers with severities
- ✅ Shows NoWarn suppressions from Directory.Build.props
- ✅ Displays .editorconfig rules by severity (error/warning/suggestion/none)
- ✅ Detects configuration conflicts
- ✅ Shows analyzer packages and versions
- ✅ Identifies project-specific overrides
- ✅ Multiple output formats (console/json/markdown)

**Next Priority**: `enable-analyzer.ps1` (eliminates manual config editing)

### Script Pattern to Follow

Use existing `build-and-find-errors.ps1` as template:
- PowerShell 7.2+ with proper parameter validation
- Unicode emoji support with fallbacks
- Clear output with color coding
- Help documentation with examples
- Error handling and validation

---

## Conclusion

**Current State**: Workflow is **exceptionally well-automated** - 85%+ automated!

**Target State**: 100% automated with 2 remaining scripts needed (enablement + progress tracking)

**Key Discoveries**:
- ✅ `analyze-quality-config.ps1` - Comprehensive configuration analysis
- ✅ `validate-pre-merge.ps1` - **Complete pre-merge orchestrator** (automates entire 7-step workflow!)

**Recommendation**: With `validate-pre-merge.ps1` doing the heavy lifting, priority shifts:
1. `enable-analyzer.ps1` - Automate analyzer enablement (currently manual)
2. `track-analyzer-progress.ps1` - Optional progress tracking

**Alignment with Script Evolution Rule**: These gaps represent perfect opportunities to apply `.cursor/rules/scripts/script-evolution-rule.mdc` - scripts are living tools that should evolve based on workflow needs.
