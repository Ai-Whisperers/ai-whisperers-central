---
name: fix-diag-warn-err
description: "AGGRESSIVE AUTO-FIX FIRST: Apply dotnet format + dotnet format analyzers immediately after compilation to fix 70-80% of issues automatically (including IDE0008 var→explicit type conversions). Then identify ALL disabled analyzers, enable them iteratively one-by-one, compile and fix remaining errors - achieve ultimate standard with zero diagnostics except allowed test suppressions"
category: code-quality
tags: diagnostics, analyzers, errors, warnings, suggestions, zero-tolerance, iterative-enablement, ultimate-standard, cs1591, ide1006, ide0008, xml-documentation, async-naming, dotnet-format, code-formatting, auto-fix, aggressive-auto-fix, var-to-explicit, quick-fix
argument-hint: "File or folder paths containing the diagnostics"
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
  - .cursor/rules/diagnostic-messages-agent-application-rule.mdc
  - .cursor/rules/scripts/script-evolution-rule.mdc
---

# Ultimate Standard - Complete Analyzer Enablement & Diagnostic Resolution

**CRITICAL**: Identify ALL disabled analyzers, enable them iteratively ONE BY ONE, compile after each enablement, fix ALL resulting errors before proceeding to next analyzer. Only specific test method suppressions allowed. End result: ALL analyzers enabled, zero diagnostics except documented test suppressions - ultimate code quality standard achieved.

---

## Purpose

- Resolve ALL analyzer diagnostics (errors, warnings, suggestions) in provided files.
- **CRITICAL**: Use iterative staged approach - enable disabled analyzers ONE BY ONE, compile, fix errors, then enable next analyzer.
- **AGGRESSIVE AUTO-FIX FIRST**: Immediately after compilation, apply `dotnet format` + `dotnet format analyzers` to auto-fix 70-80% of issues (including IDE0008 var→explicit type conversions) before any manual work.
- End result: zero diagnostics, all analyzers enabled, no suppressions except explicitly allowed test validations.
- Keep behavior unchanged and produce minimal, targeted diffs.

## Tooling Philosophy - Scripts Are Living Tools

**ALWAYS use scripts, extend them when needed, create new ones for missing functionality** (see `.cursor/rules/scripts/script-evolution-rule.mdc`):

- ✅ **Use existing scripts FIRST** - `.\.cursor\scripts\quality\*.ps1` for all quality enforcement
- ✅ **Extend scripts** when missing functionality - don't bypass with manual commands
- ✅ **Create new scripts** when functionality doesn't exist - propose for standardization
- ✅ **Scripts are living tools** - they evolve with feedback, not fossil relics
- ❌ Do NOT bypass scripts with ad-hoc manual commands
- ❌ Do NOT create undocumented one-off workarounds

**Key Quality Scripts Available**:
- `validate-pre-merge.ps1` - **🎯 PRE-MERGE ORCHESTRATOR** (complete 7-step automated validation)
- `analyze-quality-config.ps1` - Analyze all quality configuration (disabled analyzers, suppressions, conflicts)
- `build-and-find-errors.ps1` - Build and identify diagnostics
- `fix-cs1591-documentation.ps1` - Fix missing XML documentation
- `fix-ide1006-async-method-naming.ps1` - Fix async method naming
- `enforce-quality.ps1` - Quality enforcement coordinator

**If functionality is missing**: Propose enhancing existing scripts OR create new standardized scripts for the team.

## CRITICAL: Ultimate Standard - Enable ALL Disabled Analyzers Iteratively

**GOAL**: Lift code to ultimate standard by fixing ALL analyzer diagnostics (errors, warnings, suggestions) through systematic iterative enablement of ALL disabled analyzers.

**DO NOT enable all at once**. Systematically identify and enable EVERY disabled analyzer one by one, compiling and fixing all errors after each enablement until ALL analyzers are enabled and ALL diagnostics are resolved.

**Process for Each Analyzer** (Smoke Test Approach):
```
Identify disabled analyzer → Enable analyzer → dotnet build → QUICK FIX: dotnet format + dotnet format analyzers (smoke test) → Manual fixes only for remaining → dotnet build (verify clean) → Next analyzer
```

**🚀 Efficiency Gains with Smoke Test Approach**:
- **70-80% of issues** resolved automatically by `dotnet format` commands
- **Quick feedback** - know immediately what can be auto-fixed vs needs manual work
- **Reduced manual effort** - focus only on complex logic changes, not formatting
- **Faster iterations** - enable analyzer → smoke test → manual fixes → verify (minutes instead of hours)
- **Consistent results** - automated fixes ensure uniform code style across team

**Only Suppressions Allowed**: Specific test method suppressions (documented below). ALL other diagnostics from ALL analyzers must be fixed to achieve ultimate standard.

## Required Context

- Paths to files that contain the diagnostics.
- Current diagnostic messages for all errors, warnings, and suggestions.
- Applicable logging/event ID conventions for the target code (reuse existing IDs).

## Reasoning Process (for AI Agent)

Before applying fixes, the AI should:
1. **Understand Scope**: Identify all diagnostics (errors/warnings/suggestions) in provided files
2. **CRITICAL - Ultimate Standard Iterative Approach**:
   - **Phase 1**: Assess current state - identify ALL disabled analyzers in configuration
   - **Phase 2**: Create complete enablement plan for ALL disabled analyzers (may include CA1303, CA1848, CA2007, IDE0060, IDE0005, and others)
   - **Phase 3**: Enable ONE disabled analyzer at a time (any order, but systematically)
   - **Phase 4**: Compile and AGGRESSIVELY AUTO-FIX ALL resulting errors for that analyzer using `dotnet format` + `dotnet format analyzers` first (fixes 70-80% automatically including IDE0008 var issues)
   - **Phase 4b**: SYSTEMATIC ERROR CATALOGING - If errors remain after auto-fix, catalog ALL remaining errors using tracking tools (error by error, project by project, file by file)
   - **Phase 4c**: SYSTEMATIC ERROR FIXING - Fix remaining errors systematically using the catalog (error type → project → file approach)
   - **Phase 5**: Repeat Phases 3-4c for each disabled analyzer until ALL are enabled
   - **Phase 6**: Achieve ultimate standard - zero diagnostics except explicitly allowed test suppressions
3. **Prioritize Fixes**: Errors first, then warnings, then suggestions; safety/performance over style
4. **Preserve Behavior**: Ensure all fixes maintain existing functionality and don't introduce new issues
5. **Zero Tolerance**: End result must have zero diagnostics, all analyzers enabled, no suppressions except explicitly allowed test validations
6. **Validate Results**: Confirm fixes resolve all diagnostics and build succeeds
7. **CA1860 Globally Suppressed**: CA1860 (Any() → Count() > 0) is globally disabled in Directory.Build.props - you will not encounter these warnings

## Target Diagnostics

**All analyzer diagnostics from the iterative enablement process** - these examples show types of issues that will appear when enabling each disabled analyzer one-by-one:
- **Errors**: Build-breaking issues that appear when enabling each analyzer (fix ALL before proceeding)
- **Warnings**: Code quality issues surfaced during enablement (fix ALL before proceeding)
- **Suggestions**: Style/best practice recommendations (fix ALL before proceeding)

**IMPORTANT**: These are examples of issues you'll encounter. The process is NOT to fix random diagnostics, but to systematically enable each disabled analyzer from the list and fix every diagnostic that appears.

Specific examples of issues that will appear:
- **IDE0008**: Use explicit type instead of 'var' → **AUTO-FIXED** by `dotnet format analyzers` (your issue!)
- **CS1591**: Missing XML documentation for publicly visible type or member → **USE** `fix-cs1591-documentation.ps1`
- **IDE1006**: Async methods should end with 'Async' → **USE** `fix-ide1006-async-method-naming.ps1`
- **CA1062**: Add argument null checks for externally visible methods
- **CA1307**: Use string comparison overloads with `StringComparison`
- **CA1848**: Replace direct logger calls with cached `LoggerMessage` delegates
- **IDE0060**: Remove unused parameters or rename to discards

## Examples (Few-Shot)

### Example 1: CA1062 Null Guard Addition

**Before**:
```csharp
public void ProcessData(string input)
{
    var result = input.ToUpper(); // CA1062: input could be null
}
```

**After**:
```csharp
public void ProcessData(string input)
{
    ArgumentNullException.ThrowIfNull(input);
    var result = input.ToUpper();
}
```

### Example 2: CA1307 String Comparison Fix

**Before**:
```csharp
if (fileName.EndsWith(".json")) // CA1307: Missing StringComparison
{
    // process JSON file
}
```

**After**:
```csharp
if (fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
{
    // process JSON file
}
```

### Example 3: CA1848 LoggerMessage Delegate

**Before**:
```csharp
_logger.LogInformation("Processing file {FileName}", fileName); // CA1848: Direct logger call
```

**After**:
```csharp
private static readonly Action<ILogger, string, Exception?> ProcessFileStart =
    LoggerMessage.Define<string>(LogLevel.Information, new EventId(1001, "ProcessFileStart"),
        "Processing file {FileName}");

ProcessFileStart(_logger, fileName, null);
```

### Example 4: IDE0060 Unused Parameter

**Before**:
```csharp
public void OnTimerElapsed(object sender, EventArgs e) // IDE0060: e is unused
{
    // timer logic here
}
```

**After**:
```csharp
public void OnTimerElapsed(object sender, EventArgs _) // Renamed to discard
{
    // timer logic here
}
```

### Example 5: IDE0008 Var to Explicit Type (Your Issue!)

**Before** (IDE0008 error):
```csharp
public class FoundationDomainExportFactory
{
    public void ProcessExport()
    {
        var result = CalculateValue(); // IDE0008: Use explicit type instead of 'var'
        // process result...
    }

    private double CalculateValue() => 42.0;
}
```

**After** (Auto-fixed by `dotnet format analyzers`):
```csharp
public class FoundationDomainExportFactory
{
    public void ProcessExport()
    {
        double result = CalculateValue(); // Fixed: explicit type used
        // process result...
    }

    private double CalculateValue() => 42.0;
}
```

**Note**: This exact transformation is automatically applied by `dotnet format analyzers` - no manual work needed!

## Fix Patterns
- **CA1062**: Guard reference parameters at method entry before any dereference.
  ```csharp
  ArgumentNullException.ThrowIfNull(options);
  ArgumentException.ThrowIfNullOrWhiteSpace(filePath);
  ```
- **CA1307**: Add explicit `StringComparison`.
  - `name.EndsWith("Id")` → `name.EndsWith("Id", StringComparison.OrdinalIgnoreCase)`
  - `string.Equals(a, b)` → `string.Equals(a, b, StringComparison.Ordinal)`
- **CA1848**: Define cached `LoggerMessage` delegates and use them.
  ```csharp
  private static readonly Action<ILogger, string, Exception?> ImportStart =
      LoggerMessage.Define<string>(LogLevel.Information, new EventId(1001, "ImportStart"),
          "Starting JSON import from {FilePath}");

  // usage
  Log.ImportStart(_logger, filePath, null);
  ```
  - Place the static `Log` class near the top of the file.
  - Reuse stable event IDs grouped by feature.
- **IDE0060**: If a parameter is unused, rename it to `_` (or `_1`, `_2`). If it should be used, wire it into the logic instead of discarding.

## CA1860 Suppression - Globally Disabled

### 🚫 CA1860: Globally Suppressed in Directory.Build.props

**CURRENT STATUS**: CA1860 is **GLOBALLY SUPPRESSED** via `<NoWarn>$(NoWarn);CA1860</NoWarn>` in Directory.Build.props.

**Reasoning**:
- CA1860 blindly recommends `Count > 0` over `Any()` for "performance"
- This ignores context: `Count()` enumerates entire collection on `IEnumerable<T>`, while `Any()` short-circuits
- For LINQ queries and database scenarios, `Any()` is actually more efficient
- CA1860's blanket recommendation fails for lazy evaluation and infinite sequences
- The analyzer's "performance" claim is context-dependent and often incorrect

**Configuration**:
```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <!-- CA1860: Prefer Any() over Count() for readability and LINQ efficiency -->
  <NoWarn>$(NoWarn);CA1860</NoWarn>
</PropertyGroup>
```

**Action Required**:
- **NO ACTION NEEDED** - CA1860 is globally suppressed at build level
- You will NOT see CA1860 warnings in builds or IDE
- `Any()` usage is preferred and encouraged for LINQ/IEnumerable scenarios

**When Count() > 0 IS Appropriate** (Manual Review):
- Concrete collections with O(1) Count property (List<T>, Array, HashSet<T>)
- When collection is already materialized in memory
- When you need the actual count value for other logic

**Note**: CA1860 represents an oversimplified view of collection performance. Since we cannot reliably distinguish between concrete collections and LINQ queries automatically, we globally suppress this analyzer to avoid incorrect transformations.

## Process

### CRITICAL: Ultimate Standard - Identify & Enable ALL Disabled Analyzers

**ULTIMATE STANDARD GOAL**: Zero diagnostics across ALL analyzers - achieve perfect code quality.

**DO NOT enable all analyzers at once**. Use this exact iterative approach to reach ultimate standard:

1. **Assess Current State**: Identify ALL disabled analyzers in configuration files (.editorconfig, project files)
2. **Create Enablement Plan**: List all disabled analyzers that need to be enabled (may include CA1303, CA1848, CA2007, IDE0060, IDE0005, and any others currently disabled)
3. **Enable One Analyzer**: Choose ONE disabled analyzer from the complete list
4. **Compile & Fix**: Run build, fix ALL errors that appear from enabling this analyzer
5. **Verify Clean**: Ensure build succeeds with zero new errors for this analyzer
6. **Repeat**: Enable next analyzer, compile, fix errors, repeat until ALL analyzers are enabled
7. **Ultimate Validation**: Confirm zero diagnostics remain except explicitly allowed test suppressions

**Iteration Pattern for Ultimate Standard**:
```
For each disabled analyzer in complete list:
  1. Enable analyzer in configuration (change severity from "none" to "warning"/"error")
  2. dotnet build
  3. Fix ALL compilation errors from this analyzer (no suppressions except test methods)
  4. dotnet build (verify clean for this analyzer)
  5. Move to next disabled analyzer
  6. Repeat until ALL analyzers enabled and ALL diagnostics resolved
```

### Step 1: Scope Analysis
- Identify all files containing any diagnostics (errors/warnings/suggestions)
- Confirm files are within provided scope boundaries
- Count total diagnostics by severity to track progress
- **Note**: CA1860 diagnostics will not appear (globally suppressed in Directory.Build.props)

### Step 2: Current State Assessment

**Use the analysis script to discover ALL configuration**:
```powershell
# Get comprehensive configuration analysis
.\.cursor\scripts\quality\analyze-quality-config.ps1

# Show only suppressed diagnostics (NoWarn entries)
.\.cursor\scripts\quality\analyze-quality-config.ps1 -ShowSuppressedOnly

# Export to JSON for automation
.\.cursor\scripts\quality\analyze-quality-config.ps1 -OutputFormat json > config-report.json

# Check for configuration conflicts
.\.cursor\scripts\quality\analyze-quality-config.ps1 -ShowConflicts
```

**This script shows**:
- Which analyzers are currently enabled vs disabled (.editorconfig severities)
- NoWarn suppressions in Directory.Build.props and project files
- Analyzer packages and versions
- Configuration conflicts between files
- Analysis level and quality settings

**Action**: Use this output to create enablement plan (which analyzers to enable one-by-one)

### Step 3: Iterative Analyzer Enablement
For each disabled analyzer in the list above:
- **Enable**: Use the enablement script to activate the analyzer:
  ```powershell
  # Enable specific analyzer (dry-run first)
  .\.cursor\scripts\quality\enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning -WhatIf
  
  # Apply the change
  .\.cursor\scripts\quality\enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning
  
  # Track progress as in-progress
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status in-progress
  ```
- **Identify Errors**: Run build and find script to see new diagnostics:
  ```powershell
  # Find specific error type (e.g., CS1591)
  .\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591 -MaxErrors 10
  
  # Or build with dotnet directly
  dotnet build
  ```
- **AGGRESSIVE AUTO-FIX FIRST (MANDATORY)**: Immediately apply automated fixes using dotnet format tools - this is NOT optional and fixes 70-80% of issues automatically:
  ```bash
  # 🚀 AGGRESSIVE AUTO-FIX - Apply immediately after compilation (MANDATORY)
  dotnet format                    # Auto-fix code formatting/style issues (indentation, spacing, braces)
  dotnet format analyzers          # Auto-fix analyzer diagnostics (IDE0008 var→explicit, IDE0005 usings, CAxxxx, etc.)

  # Verify fixes applied (should show no changes needed)
  dotnet format --verify-no-changes
  dotnet format analyzers --verify-no-changes
  ```
  **🚨 CRITICAL**: These commands are MANDATORY and fix the vast majority of issues automatically (including IDE0008 var→explicit type conversions). Only proceed to manual fixes for the remaining 20-30% of complex issues. This aggressive approach saves massive amounts of time compared to manual fixes.

- **📊 SYSTEMATIC ERROR CATALOGING & TRACKING (MANDATORY IF ERRORS REMAIN)**: After aggressive auto-fix, catalog ALL remaining errors using error tracking tools:
  ```powershell
  # 📋 CATALOG ALL REMAINING ERRORS - Error by error, project by project, file by file
  .\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"

  # Create systematic fix tracker
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -CreateFixTracker -OutputPath "systematic-fixes-tracker.json"

  # Get detailed error breakdown by project
  dotnet build --no-restore 2>&1 | Group-Object { $_.Split(':')[0] } | Sort-Object Count -Descending
  ```

- **🔧 SYSTEMATIC ERROR-BY-ERROR FIXING (MANDATORY IF ERRORS REMAIN)**: Fix errors systematically using the catalog:
  ```powershell
  # PHASE 1: Fix by error type (group similar errors)
  .\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591 | ForEach-Object {
    # Fix all CS1591 errors across solution
    .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $_.File
    .\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CS1591 -Status in-progress
  }

  # PHASE 2: Fix by project (isolate project-specific issues)
  $projects = dotnet sln list | Where-Object { $_ -like "*.csproj" }
  foreach ($project in $projects) {
    Write-Host "🔍 Checking project: $project" -ForegroundColor Cyan
    dotnet build $project --no-restore
    if ($LASTEXITCODE -ne 0) {
      # Fix errors in this specific project
      .\.cursor\scripts\quality\build-and-find-errors.ps1 -Project $project | Out-File "project-errors-$([System.IO.Path]::GetFileNameWithoutExtension($project)).txt"
      # Apply fixes specific to this project's errors
    }
  }

  # PHASE 3: Fix by file (handle stubborn individual files)
  $errorFiles = .\.cursor\scripts\quality\build-and-find-errors.ps1 -FilesOnly
  foreach ($file in $errorFiles) {
    Write-Host "🔧 Fixing file: $file" -ForegroundColor Yellow
    # Apply file-specific fixes
    .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $file
    .\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path $file
    # Manual fixes for complex issues
    dotnet build --no-restore
  }

  # PHASE 4: Validation after each fix cycle
  .\.cursor\scripts\quality\build-and-find-errors.ps1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ All errors resolved!" -ForegroundColor Green
    .\.cursor\scripts\quality\track-analyzer-progress.ps1 -Status completed
  }
  ```

- **Fix Remaining Issues**: Resolve any remaining diagnostics using appropriate tools:
  - **For CS1591 (missing XML documentation)**: Use `fix-cs1591-documentation.ps1`
  - **For IDE1006 (async method naming)**: Use `fix-ide1006-async-method-naming.ps1`
  - **For other diagnostics**: Apply manual fixes following examples and patterns above
- **Verify**: Build succeeds with zero new errors (use script again to confirm)
- **Track Completion**: Record successful analyzer enablement:
  ```powershell
  # Mark as completed with error count
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status completed -ErrorsFixed 23 -Notes "Added null guards to public methods"
  
  # View progress report
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -Report
  ```

### Step 4: Allowed Suppressions (Test Methods Only)
Only these specific suppressions are allowed:
- **Test Method Parameter Suppressions**: `[SuppressMessage("IDE0060", "Remove unused parameter", Justification = "Required for test method signature consistency")]`
- **Test Setup/Teardown Suppressions**: `[SuppressMessage("CA1303", "Do not pass literals as localized parameters", Justification = "Test strings don't need localization")]`
- **Reason**: Test methods often have required signatures or use literal strings for testing

**NO OTHER SUPPRESSIONS ALLOWED**. Fix all other diagnostics.

### Step 5: Validation
- Run `dotnet build` to verify no compilation errors
- Run comprehensive format checks:
  ```bash
  # Verify code formatting is correct
  dotnet format --verify-no-changes

  # Verify analyzer fixes are applied
  dotnet format analyzers --verify-no-changes
  ```
- Confirm zero diagnostics at all levels (except explicitly allowed test suppressions)
- Validate that functionality remains unchanged

### Build and Find Errors Script

Use the automated script to build and find specific error types:

```powershell
# Find first 10 CS1591 errors (missing XML documentation)
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591

# Find first 5 errors of any type
.\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 5

# Find specific error type in Debug configuration
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS0246 -Configuration Debug -MaxErrors 3
```

**Output includes**:
- ✅ Progress reporting with timestamps
- ✅ Parsed errors with file locations (file:line:column)
- ✅ Error messages with context
- ✅ Fix guidance specific to each error type
- ✅ Formatted for easy navigation and fixing

**Manual Alternative (Use Only for Reference - Create/Extend Script Instead)**:

Example manual PowerShell command for reference, but **scripts are living tools** - extend them or create new ones:

```powershell
# Manual approach (REFERENCE ONLY) - shows raw build output with pattern matching
cd "e:\WPG\Git\E21\GitRepos\eneve.ebase.datamigrator" && dotnet build --no-restore 2>&1 | Select-String -Pattern "(error|warning|CS\d+|CA\d+|IDE\d+)" | Select-Object -First 20
```

**Why scripts win over manual commands?**
- ✅ Parsed file locations (clickable in IDE)
- ✅ Error-specific fix guidance
- ✅ Better formatting and readability
- ✅ Progress reporting with timestamps
- ✅ Configuration options (Debug/Release)
- ✅ Error type filtering
- ✅ Team benefits from improvements

**Scripts are living tools, not fossil relics**:
- 🚀 **If script missing functionality**: Extend `build-and-find-errors.ps1` with new parameters/features
- 🚀 **If no script exists**: Create new script and propose for team standardization
- ✅ **Scripts evolve**: They improve through use, feedback, and enhancement
- ❌ **Don't bypass**: Manual commands create technical debt and knowledge silos

See `.cursor/rules/scripts/script-evolution-rule.mdc` for full philosophy.

### Enforce Quality Script (Main Orchestrator)

**`enforce-quality.ps1`** - The main quality enforcement orchestrator that uses `quality-config.json` for severity mappings.

**Purpose**: Comprehensive quality enforcement across entire solution with configurable severity levels.

**Usage**:
```powershell
# Run quality enforcement with default settings
.\.cursor\scripts\quality\enforce-quality.ps1

# Dry run mode (show what would be changed without modifying files)
.\.cursor\scripts\quality\enforce-quality.ps1 -DryRun

# Auto-fix mode (automatically apply fixes where possible)
.\.cursor\scripts\quality\enforce-quality.ps1 -AutoFix

# Target specific configuration
.\.cursor\scripts\quality\enforce-quality.ps1 -Configuration Release
```

**How It Works**:
1. Reads `quality-config.json` for diagnostic severity mappings (error/warning/suggestion/none)
2. Applies severity levels to .editorconfig or project files
3. Builds solution and reports diagnostics
4. Optionally auto-fixes issues using dotnet format + specialized scripts
5. Validates final state and reports results

**Configuration File - `quality-config.json`**:
```json
{
  "version": "1.0.0",
  "defaultSeverity": "error",
  "rules": {
    "CS1591": "error",      // Missing XML documentation
    "CA1062": "warning",    // Validate arguments
    "CA1307": "error",      // StringComparison
    "CA1860": "IGNORE",     // Globally suppressed (Any vs Count)
    "IDE1006": "error",     // Naming conventions
    "IDE0060": "warning"    // Unused parameters
  }
}
```

**Severity Levels**:
- **error**: Critical issues (blocks build with TreatWarningsAsErrors=true)
- **warning**: Quality issues (must fix, but code compiles)
- **suggestion**: Style preferences (informational)
- **none**: Disabled (analyzer not active)
- **IGNORE**: Special marker (don't modify severity - leave as-is)

**Integration with Other Scripts**:
- Calls `build-and-find-errors.ps1` to identify issues
- Calls `fix-cs1591-documentation.ps1` for XML doc fixes
- Calls `fix-ide1006-async-method-naming.ps1` for async naming
- Uses `dotnet format` for auto-fixable issues

**When to Use**:
- Full solution quality enforcement
- Before merging to main branch
- Setting up new quality standards
- Batch fixing across multiple projects

**When NOT to Use**:
- Quick fixes for single files (use specific scripts instead)
- Incremental single-analyzer enablement (use manual workflow)
- CI/CD pipeline (use direct dotnet build + format commands)

**Progressive Enforcement Workflow (Detect, Relax, Fix, Tighten)**:

This is the recommended strategy for gradually achieving zero warnings/errors:

```powershell
# Step 1: Detect ALL issues
.\.cursor\scripts\quality\enforce-quality.ps1 -Action update-editorconfig

# Step 2: Build and see what fails
dotnet build  # This will show ALL diagnostics

# Step 3: Identify problematic rules and temporarily relax them
# Edit quality-config.json - set problematic rules to "IGNORE"
# Example: "CA1062": "IGNORE" (temporarily skip null validation)

# Step 4: Regenerate .editorconfig without IGNORED rules
.\.cursor\scripts\quality\enforce-quality.ps1 -Action update-editorconfig

# Step 5: Build succeeds - now you can compile!
dotnet build  # Should succeed

# Step 6: Fix issues incrementally
# Use auto-fix tools first:
dotnet format
dotnet format analyzers
.\.cursor\scripts\quality\fix-cs1591-documentation.ps1
.\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1

# Step 7: Gradually tighten rules
# Edit quality-config.json - change IGNORE back to "warning" one rule at a time
# Repeat steps 4-6 for each rule until all are "error" or "warning"

# Step 8: Achieve zero warnings/errors
dotnet build  # Final validation
dotnet test   # Ensure tests still pass
```

**Key Principle**: **Progressive tightening** - Don't enable all rules at once. Use IGNORE for temporary relaxation, fix issues incrementally, then tighten rules gradually until achieving ultimate quality standard.

### 🚀 AGGRESSIVE AUTO-FIX CAPABILITIES (dotnet format Tools)

**🚨 CRITICAL**: These tools automatically fix 70-80% of all analyzer issues including the IDE0008 error you mentioned.

**`dotnet format`** automatically fixes:
- Code indentation and spacing
- Brace placement and newlines
- Trailing whitespace
- Basic code style issues

**`dotnet format analyzers`** automatically fixes (including your IDE0008 issue):
- **IDE0008** (your issue): `var` → explicit types (e.g., `var x = 1.0` → `double x = 1.0`)
- **IDE0007**: explicit types → `var` (opposite of IDE0008)
- **IDE0005**: Using statement ordering and removal of unused usings
- **CS8019/CS8020**: Invalid or unnecessary using directives
- **IDE0055**: Fix formatting and whitespace issues
- **Many CAxxxx and IDExxxx analyzers** that have auto-fix capability

**Manual fixes still needed for**:
- CS1591 (XML documentation) - use `fix-cs1591-documentation.ps1`
- IDE1006 (async naming) - use `fix-ide1006-async-method-naming.ps1`
- Complex CA1062, CA1307, CA1848 issues requiring logic changes

**Build and find errors script**: `.\.cursor\scripts\quality\build-and-find-errors.ps1` - Builds solution and shows first N errors of specific type with formatted output and fix guidance

### Step 6: Report Results
- Summarize analyzers enabled and fixes applied for each
- Confirm zero diagnostics remain (with only allowed test suppressions)
- Provide confidence level in complete resolution

## Expected Output

**Code Changes**:
- Modified source files with all diagnostics resolved through iterative analyzer enablement
- Each disabled analyzer enabled one-by-one, compiled, and all errors fixed before proceeding
- Only allowed suppressions are specific test method suppressions (see Process section)
- No behavioral changes to existing functionality
- Preserved code formatting and style

**Validation Report**:
```markdown
## Ultimate Standard - ALL Analyzers Enabled

### All Disabled Analyzers Identified & Enabled (One By One)
[List will vary based on actual disabled analyzers found]

1. **[Analyzer ID]** ([Analyzer Description])
   - Files modified: [count]
   - Fixes applied: [specific changes]

2. **[Analyzer ID]** ([Analyzer Description])
   - Files modified: [count]
   - Fixes applied: [specific changes]

[... continues for ALL disabled analyzers that were enabled ...]

### Allowed Suppressions Applied (Test Methods Only)
- Test parameter suppressions: [count] `[SuppressMessage("IDE0060", ...)]`
- Test string suppressions: [count] `[SuppressMessage("CA1303", ...)]`
- Justification: Required for test method signatures and test data

### Validation Results
✅ **Aggressive Auto-Fix Applied**: `dotnet format` + `dotnet format analyzers` applied immediately after compilation (MANDATORY)
✅ `dotnet build` succeeds after each analyzer enablement
✅ `dotnet format --verify-no-changes` passes (formatting correct)
✅ `dotnet format analyzers --verify-no-changes` passes (analyzer auto-fixes applied, including IDE0008 var→explicit)
✅ All analyzers now enabled (previously disabled ones activated)
✅ Zero diagnostics except explicitly allowed test suppressions
✅ No functional changes introduced
✅ **Massive Efficiency Achieved**: 70-80% of issues resolved by aggressive automated fixes (including IDE0008)
✅ **Systematic Tracking Applied**: All remaining errors cataloged and tracked (error by error, project by project, file by file)
✅ Iterative process completed: enable → compile → AGGRESSIVE AUTO-FIX → systematic error cataloging → error-by-error fixing (by type → by project → by file) → repeat

### Final State
- All previously disabled analyzers now enabled and clean
- Zero errors, zero warnings, zero suggestions (except allowed test suppressions)
- Code compiles cleanly with all analyzers active
- Only suppressions are documented test method exceptions
```

**Change Details**:
- Specific line numbers and changes made
- Rationale for each fix applied
- Any edge cases handled

## Quality Checklist
- [ ] ALL disabled analyzers identified in configuration files (.editorconfig, project files)
- [ ] Iterative process followed: each disabled analyzer enabled one-by-one
- [ ] After each analyzer enablement: compiled successfully, aggressive auto-fix applied, remaining errors systematically cataloged and fixed (error by error, project by project, file by file)
- [ ] After each analyzer enablement: compiled successfully and all errors fixed
- [ ] ALL previously disabled analyzers now enabled and clean (verified individually)
- [ ] Only allowed suppressions applied (test methods only):
  - [ ] Test parameter suppressions: `[SuppressMessage("IDE0060", ...)]`
  - [ ] Test string suppressions: `[SuppressMessage("CA1303", ...)]`
- [ ] Zero diagnostics remain at all severity levels (except explicitly allowed test suppressions)
- [ ] All analyzers enabled, no other suppressions in final state
- [ ] `dotnet build` passes with all analyzers active
- [ ] Forbidden transformations (Any() → Count() > 0) properly documented and not applied

## Troubleshooting

### Issue: CA1062 diagnostics persist after adding guards
**Cause**: Guards added in wrong location or insufficient coverage
**Solution**: Ensure `ArgumentNullException.ThrowIfNull()` is called immediately after method entry, before any dereference of the parameter

### Issue: CA1848 LoggerMessage not recognized
**Cause**: Missing `using Microsoft.Extensions.Logging;` or incorrect delegate definition
**Solution**: Add using statement and verify delegate signature matches the log call

### Issue: StringComparison overload not available
**Cause**: Using older .NET version that doesn't support StringComparison
**Solution**: Use explicit `string.Equals(a, b, StringComparison.Ordinal)` instead of method chaining

### Issue: CA1860 diagnostics expected but not appearing
**Cause**: CA1860 is globally suppressed in Directory.Build.props
**Solution**: This is intentional. CA1860 (prefer Count > 0 over Any) is disabled project-wide because Any() is preferred for LINQ/database queries.

### Issue: dotnet format analyzers command fails
**Cause**: dotnet-format tool not installed or wrong syntax
**Solution**: Install with `dotnet tool install -g dotnet-format` and use correct syntax

### Issue: dotnet format commands not found
**Cause**: Tool not in PATH or not installed globally
**Solution**:
```bash
# Check if installed
dotnet tool list -g

# Reinstall if missing
dotnet tool install -g dotnet-format

# Use full path if PATH issues
%USERPROFILE%\.dotnet\tools\dotnet-format.exe
```

### Issue: dotnet format doesn't fix expected issues
**Cause**: Some analyzers require manual fixes or different severity levels
**Solution**:
- Ensure analyzers are enabled (not "none" severity)
- Some fixes require "warning" or "error" severity to trigger
- Complex issues need manual intervention

## Usage Modes

### Quick Fix Mode
For single files with specific diagnostics:
```
@fix-info-lines src/Services/PaymentService.cs
```

### Batch Fix Mode
For entire directories or multiple files:
```
@fix-info-lines src/ --batch
```

### Targeted Fix Mode
For specific diagnostic types:
```
@fix-info-lines src/ --only CA1062,CA1848
```

## Quality Enforcement Scripts Toolbox

### Main Scripts

1. **`validate-pre-merge.ps1`** - 🎯 **PRE-MERGE ORCHESTRATOR** (Use This First!)
   - **Complete 7-step automated pre-merge validation workflow**
   - Enforces zero-warnings, zero-errors discipline
   - Auto-fixes → Build → Test → Validate → Report
   - JSON output for AI consumption, batch processing support
   - Location: `.\.cursor\scripts\quality\validate-pre-merge.ps1`
   - Example: `.\.cursor\scripts\quality\validate-pre-merge.ps1`
   - **This is your primary tool for pre-merge validation**

2. **`analyze-quality-config.ps1`** - 🔍 **CONFIGURATION ANALYSIS**
   - Analyzes ALL quality configuration (disabled analyzers, suppressions, conflicts)
   - Scans .editorconfig, Directory.Build.props, project files
   - Shows which analyzers are disabled/enabled with severity levels
   - Detects configuration conflicts
   - Location: `.\.cursor\scripts\quality\analyze-quality-config.ps1`
   - Example: `.\.cursor\scripts\quality\analyze-quality-config.ps1 -ShowSuppressedOnly`

3. **`enable-analyzer.ps1`** - 🔧 **ANALYZER ENABLEMENT**
   - Enable a specific disabled analyzer by modifying configuration files
   - Changes severity from "none" to "warning"/"error"
   - Removes from NoWarn lists
   - Supports dry-run mode with `-WhatIf`
   - Location: `.\.cursor\scripts\quality\enable-analyzer.ps1`
   - Example: `.\.cursor\scripts\quality\enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning`
   - Use Case: Iterative analyzer enablement (one-by-one approach)

4. **`track-analyzer-progress.ps1`** - 📊 **PROGRESS TRACKING**
   - Track progress of analyzer enablement across solution
   - Maintains `analyzer-progress.json` with status tracking
   - Supports statuses: pending, in-progress, completed, skipped
   - Generate progress reports in console/json/markdown formats
   - Location: `.\.cursor\scripts\quality\track-analyzer-progress.ps1`
   - Examples:
     - Update: `.\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status completed -ErrorsFixed 45`
     - Report: `.\.cursor\scripts\quality\track-analyzer-progress.ps1 -Report`

5. **`enforce-quality.ps1`** - 🎯 **QUALITY ENFORCEMENT**
   - Comprehensive quality enforcement across entire solution
   - Uses `quality-config.json` for severity mappings
   - Coordinates all other quality scripts
   - Location: `.\.cursor\scripts\quality\enforce-quality.ps1`
   - See "Enforce Quality Script" section above for usage

6. **`build-and-find-errors.ps1`** - 🔍 **ERROR DISCOVERY**
   - Build solution and show first N errors of specific type
   - Quick identification of compilation issues
   - Location: `.\.cursor\scripts\quality\build-and-find-errors.ps1`
   - Example: `.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591`

7. **`fix-cs1591-documentation.ps1`** - 📝 **PRIMARY TOOL for XML Documentation**
   - Fixes CS1591 (missing XML documentation) diagnostics
   - Auto-generates XML comments for public APIs
   - Location: `.\.cursor\scripts\quality\fix-cs1591-documentation.ps1`
   - Example: `.\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/`

8. **`fix-ide1006-async-method-naming.ps1`** - ⚡ **PRIMARY TOOL for Async Naming**
   - Fixes IDE1006 (async method naming) violations
   - Renames methods to end with "Async"
   - Location: `.\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1`
   - Example: `.\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path src/`

### Configuration Files

- **`quality-config.json`** - Severity mappings for all analyzers
  - Location: `.\.cursor\scripts\quality\quality-config.json`
  - Defines which diagnostics are errors/warnings/suggestions
  - Used by `enforce-quality.ps1`

### 🚀 AGGRESSIVE AUTO-FIX WORKFLOW (Your Primary Tool for IDE0008)

**For IDE0008 and Most Analyzer Issues (70-80% efficiency)**:
```bash
# 🚨 AGGRESSIVE AUTO-FIX FIRST (MANDATORY) - Your most efficient approach
dotnet build                                    # Show diagnostics (including IDE0008)
dotnet format analyzers                         # Auto-fix IDE0008 var→explicit + many others
dotnet format --verify-no-changes              # Verify formatting fixes applied
dotnet format analyzers --verify-no-changes    # Verify analyzer fixes applied
dotnet build                                    # Verify zero errors remain
```

**For Your Specific IDE0008 Error**:
```bash
# This exact sequence fixes your FoundationDomainExportFactory.cs issue
cd "e:\WPG\Git\E21\GitRepos\eneve.ebase.datamigrator"
dotnet build
dotnet format analyzers  # This fixes IDE0008 automatically!
dotnet build            # Should now pass with no IDE0008 errors
```

### 🔧 SYSTEMATIC ERROR-BY-ERROR FIXING WORKFLOW (If Errors Remain)

**When aggressive auto-fix doesn't resolve everything (remaining 20-30%)**:
```powershell
# 📋 PHASE 1: CATALOG ALL REMAINING ERRORS
.\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -CreateFixTracker -OutputPath "systematic-fixes-tracker.json"

# 🔍 PHASE 2: FIX BY ERROR TYPE (group similar errors together)
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591 | ForEach-Object {
  Write-Host "Fixing CS1591 in $($_.File)" -ForegroundColor Yellow
  .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $_.File
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CS1591 -Status in-progress
}

# 📁 PHASE 3: FIX BY PROJECT (isolate project-specific issues)
$projects = dotnet sln list | Where-Object { $_ -like "*.csproj" }
foreach ($project in $projects) {
  Write-Host "🔍 Checking project: $project" -ForegroundColor Cyan
  dotnet build $project --no-restore
  if ($LASTEXITCODE -ne 0) {
    Write-Host "📋 Cataloging errors in $project" -ForegroundColor Red
    .\.cursor\scripts\quality\build-and-find-errors.ps1 -Project $project | Out-File "project-errors-$([System.IO.Path]::GetFileNameWithoutExtension($project)).txt"
    # Apply project-specific fixes here
  }
}

# 📄 PHASE 4: FIX BY FILE (handle stubborn individual files)
$errorFiles = .\.cursor\scripts\quality\build-and-find-errors.ps1 -FilesOnly
foreach ($file in $errorFiles) {
  Write-Host "🔧 Fixing file: $file" -ForegroundColor Yellow
  # Apply file-specific automated fixes first
  .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $file
  .\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path $file
  # Then manual fixes for complex issues in this file
  dotnet build --no-restore  # Check if file is now clean
}

# ✅ PHASE 5: VALIDATION AFTER EACH FIX CYCLE
.\.cursor\scripts\quality\build-and-find-errors.ps1
if ($LASTEXITCODE -eq 0) {
  Write-Host "✅ All errors resolved!" -ForegroundColor Green
  .\.cursor\scripts\quality\track-analyzer-progress.ps1 -Status completed
}
```

**Benefits of Systematic Approach**:
- 📊 **Complete visibility**: Every error is cataloged and tracked
- 🎯 **Organized fixing**: Group similar errors, then tackle by scope (project → file)
- 📈 **Progress tracking**: Know exactly what's been fixed and what remains
- 🔄 **Iterative validation**: Build and verify after each fix cycle
- 📝 **Audit trail**: Complete record of all fixes applied

### Workflow Recommendations

**Quick Single-File Fix**:
```powershell
# Just fix documentation issues in one file
.\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/MyService.cs
```

**Full Solution Enforcement**:
```powershell
# Enforce all quality standards across solution
.\.cursor\scripts\quality\enforce-quality.ps1 -AutoFix
```

**Iterative Analyzer Enablement** (Recommended):
```powershell
# 1. Enable one analyzer
.\.cursor\scripts\quality\enable-analyzer.ps1 -AnalyzerId CS1591 -Severity warning
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CS1591 -Status in-progress

# 2. Find errors
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591

# 3. Fix with appropriate tool
.\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/

# 4. Verify clean
dotnet build

# 5. Track completion
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -AnalyzerId CS1591 -Status completed -ErrorsFixed 42
```

**Complete Test-and-Validate Workflow** (Before Merge):

**Option 1: Automated (Recommended) - Single Command**:
```powershell
# Run complete 7-step pre-merge validation workflow
.\.cursor\scripts\quality\validate-pre-merge.ps1

# What it does:
# 1. Auto-fix formatting and analyzer issues (70-80% resolution)
# 2. Systematically catalog remaining errors (error by error, project by project, file by file)
# 3. Fix remaining errors systematically using error catalog
# 4. Fix specific diagnostic types (CS1591, IDE1006)
# 5. Build solution with warnings-as-errors
# 6. Run all tests to ensure no functionality broke
# 7. Validate formatting is clean
# 8. Final quality check with tracking
# 9. Display summary (ready to merge? yes/no)

# Additional options:
.\.cursor\scripts\quality\validate-pre-merge.ps1 -SkipAutoFix    # Dry-run mode
.\.cursor\scripts\quality\validate-pre-merge.ps1 -DiagnosticFilter "CS1591,IDE1006"  # Focus on specific diagnostics
.\.cursor\scripts\quality\validate-pre-merge.ps1 -MaxFiles 10     # Batch processing (fix 10 files at a time)
.\.cursor\scripts\quality\validate-pre-merge.ps1 -JsonOutput      # JSON output for AI consumption

# Exit codes:
# 0 = Success - ready to merge
# 1 = Build failed or errors found
# 2 = Tests failed
# 3 = Format validation failed
```

**Option 2: Manual (Step-by-Step)**:
```powershell
# Step 1: Auto-fix what can be fixed (70-80% of issues)
dotnet format                    # Fix formatting
dotnet format analyzers          # Fix analyzer issues

# Step 2: Systematically catalog and track remaining errors
.\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -CreateFixTracker -OutputPath "systematic-fixes-tracker.json"

# Step 3: Fix remaining errors systematically (error by error, project by project, file by file)
# PHASE 1: Fix by error type (group similar errors)
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591 | ForEach-Object {
  .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $_.File
}

# PHASE 2: Fix by project (isolate project-specific issues)
$projects = dotnet sln list | Where-Object { $_ -like "*.csproj" }
foreach ($project in $projects) {
  dotnet build $project --no-restore
  if ($LASTEXITCODE -ne 0) {
    .\.cursor\scripts\quality\build-and-find-errors.ps1 -Project $project | Out-File "project-errors-$([System.IO.Path]::GetFileNameWithoutExtension($project)).txt"
    # Apply project-specific fixes
  }
}

# PHASE 3: Fix by file (handle stubborn individual files)
$errorFiles = .\.cursor\scripts\quality\build-and-find-errors.ps1 -FilesOnly
foreach ($file in $errorFiles) {
  .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path $file
  .\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path $file
  # Manual fixes for complex issues
}

# Step 4: Fix specific diagnostic types
.\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/
.\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path src/

# Step 3: Build and verify zero warnings
dotnet build
# With TreatWarningsAsErrors=true, any warning will fail the build

# Step 4: Run tests to ensure nothing broke
dotnet test --verbosity normal
# All tests must pass - no functionality should be broken by fixes

# Step 5: Validate formatting is clean
dotnet format --verify-no-changes
dotnet format analyzers --verify-no-changes

# Step 6: Final quality check
.\.cursor\scripts\quality\build-and-find-errors.ps1
# Should show: "✅ Build succeeded with 0 errors"

# Step 7: Commit with confidence
git add .
git commit -m "chore: enforce code quality standards"
```

**Result**: Zero warnings, zero errors, all errors systematically cataloged and fixed (error by error, project by project, file by file), all tests passing, ready to merge.

**💡 Recommendation**: Use `validate-pre-merge.ps1` for complete automation. Use manual steps only if you need fine-grained control over each step.

## Related Prompts

- `code-quality/validate-code-quality.prompt.md` - Comprehensive code quality validation
- `code-quality/fix-warnings.prompt.md` - Fix warning-level diagnostics
- `code-quality/add-xml-documentation.prompt.md` - Add missing XML documentation
- `logging/standardize-logging.prompt.md` - Standardize logging patterns

## Related Rules

- `.cursor/rules/quality/zero-warnings-zero-errors-rule.mdc` - Zero tolerance for warnings/errors
- `.cursor/rules/quality/code-quality-enforcement-rule.mdc` - Code quality enforcement standards
- `.cursor/rules/documentation/documentation-standards-rule.mdc` - Documentation requirements
- `.cursor/rules/diagnostic-messages-agent-application-rule.mdc` - Diagnostic message quality

## Usage

### Prerequisites: Install dotnet-format Tool
```bash
# Install the dotnet-format global tool
dotnet tool install -g dotnet-format

# Verify installation
dotnet format --version
```

### 🚨 AGGRESSIVE AUTO-FIX FIRST (MANDATORY) - Your Primary Tool for IDE0008 and All Analyzer Issues
```bash
# Enable one analyzer in .editorconfig or project file
# Then run build to see diagnostics (including IDE0008 var→explicit type errors)
dotnet build

# 🚀 AGGRESSIVE AUTO-FIX (MANDATORY) - Fixes 70-80% of issues automatically including IDE0008
dotnet format                    # Auto-fix formatting (indentation, spacing, braces)
dotnet format analyzers          # Auto-fix analyzer issues (IDE0008 var→explicit, IDE0005 usings, CAxxxx, etc.)

# Verify the auto-fix worked (should show no changes needed)
dotnet format --verify-no-changes
dotnet format analyzers --verify-no-changes
dotnet build  # Final verification - should have zero errors now
```

**🚨 CRITICAL**: This 4-command sequence is MANDATORY and your most efficient tool for fixing IDE0008 errors and 70-80% of all analyzer issues automatically! Apply immediately after any compilation that shows diagnostics.**

### Advanced Usage Examples
```bash
# Fix specific project
dotnet format MyProject.csproj
dotnet format analyzers MyProject.csproj

# Fix entire solution
dotnet format MySolution.sln
dotnet format analyzers MySolution.sln

# Fix with verbose output
dotnet format analyzers --verbosity diagnostic

# Fix specific files only
dotnet format "**/Services/*.cs"
dotnet format analyzers "**/Services/*.cs"
```

### CI/CD Pipeline Integration
```yaml
# Azure DevOps example
- task: DotNetCoreCLI@2
  displayName: 'Install dotnet-format'
  inputs:
    command: 'custom'
    custom: 'tool install dotnet-format --global'

- task: DotNetCoreCLI@2
  displayName: 'Auto-fix formatting'
  inputs:
    command: 'custom'
    custom: 'format'

- task: DotNetCoreCLI@2
  displayName: 'Auto-fix analyzers'
  inputs:
    command: 'custom'
    custom: 'format analyzers'

- task: DotNetCoreCLI@2
  displayName: 'Verify fixes'
  inputs:
    command: 'custom'
    custom: 'format --verify-no-changes'

- task: DotNetCoreCLI@2
  displayName: 'Verify analyzer fixes'
  inputs:
    command: 'custom'
    custom: 'format analyzers --verify-no-changes'
```

---

**Created**: 2025-12-13  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0  
**Enhanced**: 2025-12-13 (Prompt optimization workflow)
