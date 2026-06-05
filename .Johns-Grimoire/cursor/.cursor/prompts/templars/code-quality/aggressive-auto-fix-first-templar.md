---
type: templar
artifact-type: prompt
applies-to: code-quality, diagnostic-resolution, automated-fixing
pattern-name: aggressive-auto-fix-first-pattern
version: 1.0.0
implements: code-quality.aggressive-auto-fix-first
consumed-by:
  - .cursor/prompts/code-quality/fix-diag-warn-err.prompt.md
---

# Aggressive Auto-Fix First Pattern Templar

## Pattern Purpose

This template provides a reusable pattern for resolving the majority of code quality issues automatically before manual intervention, dramatically improving efficiency by fixing 70-80% of issues with minimal human effort.

## Artifact Type

**For**: Prompts, Scripts, Rules, Documentation

## When to Use

- ✅ Code quality enforcement workflows
- ✅ Diagnostic resolution processes
- ✅ Automated fixing before manual work
- ✅ Build/CI pipeline optimization
- ✅ Pre-commit validation hooks

## Template Structure

### Section 1: Aggressive Auto-Fix Declaration

**CRITICAL**: [AGGRESSIVE_AUTO_FIX_DECLARATION]

**Pattern**: [TOOL_COMMAND_1] + [TOOL_COMMAND_2] automatically fixes [PERCENTAGE]% of issues ([SPECIFIC_ISSUES]) before any manual work.

### Section 2: Auto-Fix Commands

**🚀 AGGRESSIVE AUTO-FIX (MANDATORY)**: Apply immediately after [TRIGGER_CONDITION] - this is NOT optional and fixes [PERCENTAGE]% of issues automatically:

```bash
# 🚨 AGGRESSIVE AUTO-FIX FIRST (MANDATORY) - Your most efficient approach
[PRIMARY_AUTO_FIX_COMMAND]                    # Auto-fix [PRIMARY_FIX_TYPE]
[SECONDARY_AUTO_FIX_COMMAND]                  # Auto-fix [SECONDARY_FIX_TYPE]

# Verify fixes applied (should show no changes needed)
[VERIFY_COMMAND_1]                            # Verify [PRIMARY_FIX_TYPE] fixes applied
[VERIFY_COMMAND_2]                            # Verify [SECONDARY_FIX_TYPE] fixes applied
[FINAL_VALIDATION_COMMAND]                    # Final validation - should have zero [TARGET_ISSUE_TYPE] errors
```

### Section 3: Efficiency Benefits

**🚀 Efficiency Gains with [PATTERN_NAME] Approach**:
- **[PERCENTAGE_1]% of issues** resolved automatically by [TOOL_NAME] commands
- **[EFFICIENCY_BENEFIT_1]**
- **[EFFICIENCY_BENEFIT_2]**
- **[EFFICIENCY_BENEFIT_3]**
- **[EFFICIENCY_BENEFIT_4]**

### Section 4: Systematic Leftover Resolution (CRITICAL SEQUENCE)

**CRITICAL WORKFLOW SEQUENCE**: Auto-fix first, then catalog leftovers, then target with scripts, then AI intervention.

1. **🚀 PHASE 1: Build + Auto-Fix** (70-80% automatic resolution)
   ```bash
   # First: Build to identify all diagnostics
   dotnet build

   # Then: AGGRESSIVE AUTO-FIX (MANDATORY - fixes 70-80% automatically)
   dotnet format analyzers          # Auto-fix analyzer issues (IDE0008 var→explicit, CAxxxx, etc.)
   dotnet format                    # Auto-fix formatting/style issues
   ```

2. **📊 PHASE 2: Catalog What Remains** (Systematic inventory of leftovers)
   ```powershell
   # Catalog ALL remaining errors after auto-fix
   .\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
   ```

3. **🔧 PHASE 3: Target with Error-Code Specific Scripts** (Script-first approach)
   ```powershell
   # TARGET LEFTOVERS WITH ERROR-CODE SPECIFIC SCRIPTS FIRST
   .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/    # XML documentation
   .\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path src/  # Async naming
   # [Add other error-code specific scripts as available]
   ```

4. **🤖 PHASE 4: AI Intervention Only After Scripts** (Manual fixes for complex issues)
   - Only after error-code specific scripts have been applied
   - AI examines remaining complex issues requiring logic changes
   - Manual fixes for CA1062, CA1307, CA1848, etc. requiring code logic changes

**Manual fixes still needed for**:
- [MANUAL_FIX_CATEGORY_1] - [REASON_1]
- [MANUAL_FIX_CATEGORY_2] - [REASON_2]
- [MANUAL_FIX_CATEGORY_3] - [REASON_3]

**[ADDITIONAL_PROCESS_DESCRIPTION]**

### Section 5: Validation Commands

```bash
# Verify code formatting is correct
[FORMATTING_VERIFY_COMMAND]

# Verify analyzer fixes are applied
[ANALYZER_VERIFY_COMMAND]
```

## Customization Points

### [AGGRESSIVE_AUTO_FIX_DECLARATION]
**Purpose**: Clearly declare that aggressive auto-fix is mandatory and highly effective
**Guidance**: Emphasize that this step is NOT optional and provides significant efficiency gains
**Example**: "AGGRESSIVE AUTO-FIX FIRST: Apply dotnet format analyzers immediately after compilation"

### [TOOL_COMMAND_1] / [TOOL_COMMAND_2]
**Purpose**: Primary auto-fix commands that resolve majority of issues
**Guidance**: Choose commands that work together and cover complementary fix types
**Example**: "dotnet format" (formatting) + "dotnet format analyzers" (diagnostic fixes)

### [PERCENTAGE]
**Purpose**: Quantify the effectiveness of auto-fix approach
**Guidance**: Based on experience, typically 70-80% for comprehensive tool suites
**Example**: "70-80%"

### [SPECIFIC_ISSUES]
**Purpose**: Name the types of issues that get auto-fixed
**Guidance**: Be specific about what gets resolved automatically
**Example**: "including IDE0008 var→explicit type conversions"

### [TRIGGER_CONDITION]
**Purpose**: When to apply the aggressive auto-fix
**Guidance**: Typically after compilation or diagnostic identification
**Example**: "compilation that shows diagnostics"

### [EFFICIENCY_BENEFIT_X]
**Purpose**: Highlight the practical benefits of this approach
**Guidance**: Focus on time savings, quality improvements, consistency
**Examples**:
- "Quick feedback - know immediately what can be auto-fixed vs needs manual work"
- "Reduced manual effort - focus only on complex logic changes, not formatting"
- "Consistent results - automated fixes ensure uniform code style across team"

### [MANUAL_FIX_CATEGORY_X]
**Purpose**: Clearly define what still requires manual intervention
**Guidance**: Be specific about complexity levels that need human judgment
**Examples**:
- "Complex CA1062, CA1307, CA1848 issues requiring logic changes"
- "CS1591 (XML documentation) - use specific scripts"

### [ADDITIONAL_PROCESS_DESCRIPTION]
**Purpose**: Describe any additional workflow after auto-fix
**Guidance**: Include systematic approaches for remaining issues
**Example**: "Only proceed to manual fixes for the remaining 20-30% of complex issues"

## Example Usage

**For .NET Analyzer Resolution Prompt**:

```markdown
## Process

### CRITICAL WORKFLOW SEQUENCE: Build → Auto-Fix → Catalog → Scripts → AI

1. **🚀 Build + Auto-Fix** (70-80% automatic resolution):
   ```bash
   dotnet build                                    # Identify ALL diagnostics first
   dotnet format analyzers                         # Auto-fix 70-80% of issues
   dotnet format                                   # Fix formatting issues
   ```

2. **📊 Catalog Leftovers** (Systematic inventory):
   ```powershell
   .\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 50 | Out-File "error-catalog-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
   ```

3. **🔧 Target with Error-Code Specific Scripts** (Script-first approach):
   ```powershell
   .\.cursor\scripts\quality\fix-cs1591-documentation.ps1 -Path src/    # XML documentation
   .\.cursor\scripts\quality\fix-ide1006-async-method-naming.ps1 -Path src/  # Async naming
   ```

4. **🤖 AI Intervention Only After Scripts** (Complex manual fixes):
   - AI examines remaining complex issues requiring logic changes
   - Manual fixes for CA1062, CA1307, CA1848, etc.

## Tooling Philosophy

**ALWAYS use scripts, extend them when needed, create new ones for missing functionality** (see `.cursor/rules/scripts/script-evolution-rule.mdc`):

## CRITICAL: Iterative Analyzer Enablement

For each disabled analyzer in the list above:
- **Enable**: Use the enablement script to activate the analyzer
- **Apply CRITICAL SEQUENCE**: Build → auto-fix → catalog → scripts → AI intervention
```

## Related Templars

- `code-quality/iterative-analyzer-enablement-templar.md` - For enabling analyzers one-by-one
- `code-quality/systematic-error-cataloging-templar.md` - For systematic error tracking
- `code-quality/multi-level-validation-templar.md` - For comprehensive validation workflows

---

**Extracted From**: `.cursor/prompts/code-quality/fix-diag-warn-err.prompt.md`  
**Why Extracted**: Demonstrates exceptional efficiency gains through mandatory aggressive auto-fix approach, fixing 70-80% of issues automatically before manual work. This pattern is highly reusable across code quality enforcement, diagnostic resolution, and automated fixing workflows.  
**Use When**: Creating prompts/scripts/rules that involve automated fixing, code quality enforcement, or diagnostic resolution processes.

---

**Version**: 1.0.0  
**Created**: 2025-12-15  
**Follows**: `.cursor/rules/rule-authoring/rule-templars-and-exemplars.mdc`