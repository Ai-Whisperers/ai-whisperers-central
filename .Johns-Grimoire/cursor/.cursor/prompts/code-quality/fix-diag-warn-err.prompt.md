---
name: fix-diag-warn-err
description: "AGGRESSIVE AUTO-FIX FIRST: Apply dotnet format analyzers immediately after compilation to auto-fix 70-80% of analyzer issues (including IDE0008 var→explicit). Then systematically catalog and fix remaining errors using quality scripts."
category: code-quality
tags:
  - diagnostics
  - analyzers
  - ide0008
  - aggressive-auto-fix
  - systematic-fixing
  - dotnet-format
  - error-tracking
  - zero-warnings
  - zero-errors
argument-hint: "File or folder paths containing the diagnostics"
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
  - .cursor/rules/diagnostic-messages-agent-application-rule.mdc
  - .cursor/rules/scripts/script-evolution-rule.mdc
  - .cursor/rules/quality/zero-warnings-zero-errors-rule.mdc
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
- `fix-cs1570-xml-comments.ps1` - Fix badly-formed XML docs (CS1570)
- `fix-cs1570-xml-format.ps1` - Restore XML comment formatting (CS1570)
- `fix-ide0028-collection-initialization.ps1` - Fix simplify collection initialization (IDE0028)
- `fix-ca1825-static-readonly-arrays.ps1` - Fix static readonly array suggestions (CA1825)
- `enforce-quality.ps1` - Quality enforcement coordinator

**If functionality is missing**: Propose enhancing existing scripts OR create new standardized scripts for the team.

**See exemplar**: `.cursor/prompts/exemplars/code-quality/diagnostic-resolution-workflow-exemplar.md` for comprehensive examples, detailed workflows, and the complete build→auto-fix→catalog→scripts→AI sequence.

**See toolbox exemplar**: `.cursor/prompts/exemplars/code-quality/fix-diag-warn-err-toolbox-exemplar.md` for the expanded script/toolbox reference (kept out of the main prompt).

## CRITICAL: Ultimate Standard - Enable ALL Disabled Analyzers Iteratively

**GOAL**: Lift code to ultimate standard by fixing ALL analyzer diagnostics (errors, warnings, suggestions) through systematic iterative enablement of ALL disabled analyzers.

**DO NOT enable all at once**. Systematically identify and enable EVERY disabled analyzer one by one, compiling and fixing all errors after each enablement until ALL analyzers are enabled and ALL diagnostics are resolved.

**See templar**: `.cursor/prompts/templars/code-quality/aggressive-auto-fix-first-templar.md` for the aggressive auto-fix first pattern that resolves 70-80% of issues automatically.

**CRITICAL SEQUENCE**: Build → auto-fix → catalog leftovers → target with error-code specific scripts → AI intervention only for complex logic changes.

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

## Examples

**See exemplar**: `.cursor/prompts/exemplars/code-quality/diagnostic-resolution-workflow-exemplar.md` for comprehensive before/after examples including CA1062 null guards, CA1307 string comparisons, CA1848 logger delegates, IDE0060 unused parameters, and IDE0008 var-to-explicit type conversions (auto-fixed by `dotnet format analyzers`).

## Fix Patterns

**See exemplar**: `.cursor/prompts/exemplars/code-quality/diagnostic-resolution-workflow-exemplar.md` for detailed fix patterns for CA1062, CA1307, CA1848, IDE0060, and other common analyzer diagnostics.

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

**See templar**: `.cursor/prompts/templars/code-quality/aggressive-auto-fix-first-templar.md` for the complete iterative enablement process with aggressive auto-fix workflows, systematic error cataloging, and error-by-error fixing patterns.

- **Fix Remaining Issues**: Resolve any remaining diagnostics using appropriate tools:
  - **Preferred orchestration**: Use `validate-pre-merge.ps1` to run the standard sequence (enable analyzer → auto-fix → targeted fix scripts → build → tests → format verification).
    - Enable one analyzer at a time:
      - `.\.cursor\scripts\quality\validate-pre-merge.ps1 -EnableAnalyzer CA1062 -AnalyzerSeverity warning -TrackProgress`
    - For automation/AI parsing use:
      - `.\.cursor\scripts\quality\validate-pre-merge.ps1 -JsonOutput` (JSON-only output)
  - **For CS1591 (missing XML documentation)**: Use `fix-cs1591-documentation.ps1`
  - **For IDE1006 (async method naming)**: Use `fix-ide1006-async-method-naming.ps1`
  - **For CS1570 (badly formed XML docs)**: Use `fix-cs1570-xml-comments.ps1`
- **For CS1570 (format regressions)**: Use `fix-cs1570-xml-format.ps1`
  - **For IDE0028 (collection initialization)**: Use `fix-ide0028-collection-initialization.ps1`
  - **For CA1825 (static readonly arrays)**: Use `fix-ca1825-static-readonly-arrays.ps1`
  - **For other diagnostics**: Apply manual fixes following examples and patterns in the exemplar
- **Verify**: Build succeeds with zero new errors (use script again to confirm)
- **Track Completion**: Record successful analyzer enablement using the tracking scripts

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

**Manual alternative**: Avoid embedding repo-specific paths or one-off commands. If the scripts don’t expose what you need, extend them or add a new reusable script.

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
- [ ] After each analyzer enablement: compiled successfully, aggressive auto-fix applied (see templar), remaining errors systematically cataloged and fixed (see exemplar)
- [ ] After each analyzer enablement: compiled successfully and all errors fixed
- [ ] ALL previously disabled analyzers now enabled and clean (verified individually)
- [ ] Only allowed suppressions applied (test methods only):
  - [ ] Test parameter suppressions: `[SuppressMessage("IDE0060", ...)]`
  - [ ] Test string suppressions: `[SuppressMessage("CA1303", ...)]`
- [ ] Zero diagnostics remain at all severity levels (except explicitly allowed test suppressions)
- [ ] All analyzers enabled, no other suppressions in final state
- [ ] `dotnet build` passes with all analyzers active
- [ ] Forbidden transformations (Any() → Count() > 0) properly documented and not applied

## Extracted Patterns

This prompt demonstrates exceptional quality and has been extracted into reusable patterns:

**Templar**:
- `.cursor/prompts/templars/code-quality/aggressive-auto-fix-first-templar.md` - Aggressive auto-fix first pattern that resolves 70-80% of issues automatically

**Exemplar**:
- `.cursor/prompts/exemplars/code-quality/diagnostic-resolution-workflow-exemplar.md` - Comprehensive diagnostic resolution workflow with exceptional contract definition, validation checklists, and troubleshooting

**Why Extracted**: This prompt shows outstanding patterns for automated fixing workflows and comprehensive diagnostic resolution that benefit multiple quality enforcement scenarios. The aggressive auto-fix approach is highly reusable, and the implementation demonstrates best practices in tooling integration, systematic error handling, and iterative improvement.

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

### Usage Modes (Condensed)

If you only need to fix a small set of diagnostics in a couple of files, prefer the most specific prompt/script available. This prompt is optimized for repository-wide **iterative analyzer enablement** + **aggressive auto-fix first**.

### Toolbox (High-signal only)

- **Orchestrator**: `.\.cursor\scripts\quality\validate-pre-merge.ps1` (run first)
- **Configuration inventory**: `.\.cursor\scripts\quality\analyze-quality-config.ps1`
- **Error surfacing**: `.\.cursor\scripts\quality\build-and-find-errors.ps1`
- **Targeted fix scripts (examples)**:
  - `fix-cs1591-documentation.ps1`
  - `fix-ide1006-async-method-naming.ps1`
  - `fix-cs1570-xml-comments.ps1`
  - `fix-cs1570-xml-format.ps1`
  - `fix-ide0028-collection-initialization.ps1`
  - `fix-ca1825-static-readonly-arrays.ps1`
  - `enforce-quality.ps1` (severity coordination)

**Recommended**: keep detailed workflows/examples in the referenced exemplar/templar; keep this prompt focused on the contract + minimal commands.

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

Prefer the repository orchestrator to keep the workflow consistent and script-first:

```powershell
.\.cursor\scripts\quality\validate-pre-merge.ps1 -TargetPath "[TARGET_PATH]"
```

Manual verification (only if needed):

```bash
dotnet format --verify-no-changes
dotnet format analyzers --verify-no-changes
```

---

**Created**: 2025-12-13  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0  
**Enhanced**: 2025-12-13 (Prompt optimization workflow)
