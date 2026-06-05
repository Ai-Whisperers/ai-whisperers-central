---
type: exemplar
artifact-type: prompt
demonstrates: comprehensive-diagnostic-resolution-workflow, exceptional-contract-definition, outstanding-validation-checklists
domain: code-quality
quality-score: exceptional
version: 1.0.0
illustrates: code-quality.fix-diag-warn-err
extracted-from: .cursor/prompts/code-quality/fix-diag-warn-err.prompt.md
---

# Diagnostic Resolution Workflow Exemplar

## Artifact Type

**Type**: Prompt
**Domain**: Code Quality
**Purpose**: Comprehensive analyzer diagnostic resolution through systematic iterative enablement

## Why This is Exemplary

This exemplar demonstrates exceptional quality across multiple dimensions:

1. **Outstanding Contract Definition**: Extremely detailed inputs, outputs, preconditions, and postconditions with clear boundaries and expectations
2. **Exceptional Validation Checklists**: Multi-level validation (Critical/Standard/Quality/Best Practices) with specific, actionable criteria
3. **Comprehensive Examples**: Extensive before/after examples covering good/bad/edge cases with concrete code samples
4. **Excellent Error Handling**: Detailed troubleshooting section with specific error types, causes, and solutions
5. **Perfect Cross-Referencing**: Extensive links to related prompts/rules/scripts with proper categorization
6. **Superior Clarity**: Zero ambiguity with crystal-clear requirements, processes, and expectations
7. **Best Practices Demonstration**: Shows automation integration, tooling philosophy, and iterative improvement

## Key Quality Elements

### 1. Comprehensive Contract Definition
**Why Exceptional**: The prompt defines inputs, outputs, preconditions, and postconditions with exceptional detail and clarity.

**Example of Excellence**:
```
argument-hint: "File or folder paths containing the diagnostics"
```

This single line provides immediate clarity about expected inputs, making the prompt immediately usable.

### 2. Multi-Level Validation Framework
**Why Exceptional**: Implements a sophisticated 4-level validation hierarchy with weighted scoring and clear severity levels.

**Example of Excellence**:
```
### Level 1: Format Compliance (REQUIRED - 40% weight)
### Level 2: Naming Conventions (20% weight)
### Level 3: Quality Standards (30% weight)
### Level 4: Best Practices (10% weight)
```

Each level has specific, measurable criteria with clear pass/fail conditions.

### 3. Systematic Process Orchestration
**Why Exceptional**: Provides multiple coordinated workflow options (automated, manual, iterative) with clear decision trees.

**Example of Excellence**:
```
**Option 1: Automated (Recommended) - Single Command**:
```powershell
.\.cursor\scripts\quality\validate-pre-merge.ps1
```

**Option 2: Manual (Step-by-Step)**:
[Comprehensive manual steps with specific commands]
```

### 4. Exceptional Error Handling and Troubleshooting
**Why Exceptional**: Comprehensive troubleshooting section with specific error patterns, causes, and solutions.

**Example of Excellence**:
```
### Issue: dotnet format analyzers command fails
**Cause**: dotnet-format tool not installed or wrong syntax
**Solution**:
```bash
# Check if installed
dotnet tool list -g

# Reinstall if missing
dotnet tool install -g dotnet-format
```
```

### 5. Outstanding Cross-Referencing
**Why Exceptional**: Extensive, well-categorized references to related artifacts with clear relationships.

**Example of Excellence**:
```
## Related Prompts
- `code-quality/validate-code-quality.prompt.md` - Comprehensive code quality validation
- `code-quality/fix-warnings.prompt.md` - Fix warning-level diagnostics
- `code-quality/add-xml-documentation.prompt.md` - Add missing XML documentation

## Related Rules
- `.cursor/rules/quality/zero-warnings-zero-errors-rule.mdc` - Zero tolerance for warnings/errors
- `.cursor/rules/quality/code-quality-enforcement-rule.mdc` - Code quality enforcement standards
```

## Pattern Demonstrated

This exemplar demonstrates the **"Comprehensive Diagnostic Resolution Workflow"** pattern, which combines:

1. **Aggressive Auto-Fix First**: Mandatory automated fixing before manual work
2. **Iterative Analyzer Enablement**: Systematic one-by-one analyzer activation
3. **Systematic Error Cataloging**: Error-by-error, project-by-project, file-by-file tracking
4. **Multi-Level Validation**: Critical → Standard → Quality → Best Practices hierarchy
5. **Tool Integration Philosophy**: Scripts as living tools with evolution rules

## Full Exemplar Content

### Exceptional Contract Definition

**Purpose**:
- Resolve ALL analyzer diagnostics (errors, warnings, suggestions) in provided files.
- **CRITICAL**: Use iterative staged approach - enable disabled analyzers ONE BY ONE, compile, fix errors, then enable next analyzer.
- **AGGRESSIVE AUTO-FIX FIRST**: Immediately after compilation, apply `dotnet format` + `dotnet format analyzers` to auto-fix 70-80% of issues (including IDE0008 var→explicit) before any manual work.

**Required Context**:
- Paths to files that contain the diagnostics.
- Current diagnostic messages for all errors, warnings, and suggestions.
- Applicable logging/event ID conventions for the target code (reuse existing IDs).

### Outstanding Validation Checklists

**Quality Checklist**:
- [ ] ALL disabled analyzers identified in configuration files (.editorconfig, project files)
- [ ] Iterative process followed: each disabled analyzer enabled one-by-one
- [ ] After each analyzer enablement: compiled successfully, aggressive auto-fix applied, remaining errors systematically cataloged and fixed (error by error, project by project, file by file)
- [ ] After each analyzer enablement: compiled successfully and all errors fixed
- [ ] ALL previously disabled analyzers now enabled and clean (verified individually)
- [ ] Only allowed suppressions applied (test methods only)
- [ ] Zero diagnostics remain at all severity levels (except explicitly allowed test suppressions)

### Comprehensive Examples with Before/After

**Example 1: CA1062 Null Guard Addition**
```csharp
// Before:
public void ProcessData(string input)
{
    var result = input.ToUpper(); // CA1062: input could be null
}

// After:
public void ProcessData(string input)
{
    ArgumentNullException.ThrowIfNull(input);
    var result = input.ToUpper();
}
```

**Example 2: IDE0008 Var to Explicit Type (Auto-fixed)**
```csharp
// Before (IDE0008 error):
public class FoundationDomainExportFactory
{
    public void ProcessExport()
    {
        var result = CalculateValue(); // IDE0008: Use explicit type instead of 'var'
    }
}

// After (Auto-fixed by dotnet format analyzers):
public class FoundationDomainExportFactory
{
    public void ProcessExport()
    {
        double result = CalculateValue(); // Fixed: explicit type used
    }
}
```

### Superior Troubleshooting Documentation

**Issue: CA1860 diagnostics expected but not appearing**
**Cause**: CA1860 is globally suppressed in Directory.Build.props
**Solution**: This is intentional. CA1860 (prefer Any() over Count() > 0) is disabled project-wide.

**Issue: dotnet format commands not found**
**Cause**: Tool not in PATH or not installed globally
**Solution**:
```bash
# Check if installed
dotnet tool list -g

# Reinstall if missing
dotnet tool install -g dotnet-format
```

## Learning Points

### 1. Contract Definition Excellence
**Lesson**: Always provide crystal-clear inputs, outputs, and expectations. Use `argument-hint` for immediate usability.

**Impact**: Users can immediately understand what the prompt needs and produces, reducing confusion and support requests.

### 2. Multi-Level Validation Power
**Lesson**: Structure validation as hierarchical levels with weighted scoring provides objective quality assessment.

**Impact**: Teams can make data-driven decisions about artifact quality and prioritize improvements effectively.

### 3. Aggressive Automation First
**Lesson**: Always attempt automated fixes before manual work - they resolve 70-80% of issues with zero human effort.

**Impact**: Dramatically improves efficiency and consistency across large codebases.

### 4. Comprehensive Error Handling
**Lesson**: Include specific troubleshooting for common failure modes with exact commands and error patterns.

**Impact**: Reduces debugging time and frustration when issues occur.

### 5. Tool Integration Philosophy
**Lesson**: Treat scripts as "living tools" that evolve with feedback, not fossil relics.

**Impact**: Creates sustainable automation that improves over time rather than becoming technical debt.

### 6. Critical Workflow Sequence
**Lesson**: Always follow build → auto-fix → catalog → scripts → AI intervention sequence for maximum efficiency.

**Impact**: Ensures systematic resolution where 70-80% is auto-fixed, then error-code specific scripts handle known patterns, leaving only complex logic changes for manual/AI intervention.

## When to Reference

Use this exemplar when creating:

- **Code quality enforcement prompts**: For comprehensive diagnostic resolution workflows
- **Iterative process automation**: For systematic enablement and fixing patterns
- **Multi-level validation systems**: For hierarchical quality assessment frameworks
- **Tool integration documentation**: For living tool philosophies and script evolution
- **Troubleshooting documentation**: For comprehensive error handling and recovery

## Learning Points Summary

1. **Contract clarity eliminates ambiguity** - Clear inputs/outputs reduce support overhead
2. **Weighted validation enables objectivity** - Hierarchical scoring provides data-driven quality assessment
3. **Aggressive automation maximizes efficiency** - Auto-fix 70-80% of issues before manual work
4. **Comprehensive troubleshooting minimizes frustration** - Specific solutions for common failure modes
5. **Living tools evolve sustainably** - Scripts improve with use rather than becoming debt
6. **Exceptional cross-referencing enables discovery** - Well-categorized references help users find related artifacts
7. **Multiple workflow options serve different users** - Automated, manual, and hybrid approaches meet diverse needs
8. **Critical workflow sequence maximizes efficiency** - Build → auto-fix → catalog → scripts → AI intervention

## Critical Workflow Sequence Demonstration

This exemplar demonstrates the **exact sequence** for maximum diagnostic resolution efficiency:

### 🚀 Phase 1: Build + Auto-Fix (70-80% Automatic Resolution)
```bash
# STEP 1: Build first to identify ALL diagnostics
cd "<REPO_ROOT>"
dotnet build                                    # Shows ALL current diagnostics

# STEP 2: AGGRESSIVE AUTO-FIX IMMEDIATELY (MANDATORY)
dotnet format analyzers                         # Fixes IDE0008 var→explicit + 70-80% of other issues
dotnet format                                   # Fixes formatting/style issues

# STEP 3: Verify auto-fix results
dotnet format analyzers --verify-no-changes     # Should pass if auto-fix worked
dotnet format --verify-no-changes              # Should pass if auto-fix worked
dotnet build                                    # Verify build still succeeds
```

### 📊 Phase 2: Catalog What Is Left Over (Systematic Inventory)
```powershell
# STEP 4: CATALOG ALL REMAINING ERRORS after auto-fix
.\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"

# STEP 5: Create systematic fix tracker for leftovers
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -CreateFixTracker -OutputPath "systematic-fixes-tracker.json"
```

### 🔧 Phase 3: Target Leftovers with Error-Code Specific Scripts (Script-First)
```powershell
# STEP 6: TARGET LEFTOVERS WITH ERROR-CODE SPECIFIC SCRIPTS FIRST
# (Located in @eneve.domain/.cursor/scripts/quality)

# For CS1591 (missing XML documentation)
.\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/

# For IDE1006 (async method naming)
.\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path src/

# [Add other available error-code specific scripts]
# Scripts handle known patterns automatically before manual work
```

### 🤖 Phase 4: AI Intervention Only After Scripts (Manual Complex Fixes)
```powershell
# STEP 7: AFTER SCRIPTS - Check what remains for AI/manual intervention
.\.cursor\scripts\quality\build-and-find-errors.ps1

# STEP 8: AI examines only the complex leftovers requiring:
# - Logic changes (CA1062 null guards, CA1307 string comparisons)
# - Architecture decisions (CA1848 logger patterns)
# - Complex refactoring (IDE0060 parameter removal)
```

### 📊 Phase 5: Validation and Completion
```powershell
# STEP 9: Final validation
dotnet build                                    # Must succeed
dotnet format --verify-no-changes              # Formatting clean
dotnet format analyzers --verify-no-changes    # Analyzer fixes applied

# STEP 10: Track completion
.\.cursor\scripts\quality\track-analyzer-progress.ps1 -Status completed -ErrorsFixed 45
```

**Why This Sequence Matters**:
- **Build First**: Identifies the complete scope before any fixes
- **Auto-Fix Immediately**: Resolves 70-80% of issues with zero human effort
- **Catalog Systematically**: Creates complete inventory of what remains
- **Scripts Target Known Patterns**: Error-code specific scripts handle predictable issues
- **AI Only for Complex Cases**: Manual/AI intervention reserved for logic changes requiring judgment

This sequence maximizes efficiency by automating the easy parts and focusing human/AI effort on complex issues requiring analysis and decision-making.

## Related Exemplars

- `prompts/rule-authoring/comprehensive-extraction-exemplar.md` - For comprehensive documentation patterns
- `prompts/code-quality/validation-workflow-exemplar.md` - For validation and quality enforcement patterns
- `scripts/automation/tool-integration-exemplar.md` - For tool integration and automation patterns

---

**Preserved From**: `.cursor/prompts/code-quality/fix-diag-warn-err.prompt.md`  
**Why Preserved**: This prompt demonstrates exceptional quality across contract definition, validation frameworks, error handling, cross-referencing, and automation integration - serving as a gold standard for comprehensive diagnostic resolution workflows.  
**Reference When**: Creating prompts that require comprehensive workflows, multi-level validation, extensive examples, or sophisticated error handling.

---

**Version**: 1.0.0  
**Created**: 2025-12-15  
**Follows**: `.cursor/rules/rule-authoring/rule-templars-and-exemplars.mdc`