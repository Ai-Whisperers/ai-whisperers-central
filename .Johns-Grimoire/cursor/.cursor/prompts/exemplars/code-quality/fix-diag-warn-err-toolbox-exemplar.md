---
type: exemplar
artifact-type: prompt
demonstrates: diagnostic-resolution-toolbox
domain: code-quality
quality-score: exceptional
version: 1.0.0
illustrates: code-quality.fix-diag-warn-err
extracted-from: .cursor/prompts/code-quality/fix-diag-warn-err.prompt.md
notes: "Repo-specific absolute paths were removed during extraction."
---

# Fix Diagnostics Toolbox Exemplar

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

Prefer the dedicated templar for this pattern: `.cursor/prompts/templars/code-quality/aggressive-auto-fix-first-templar.md`

**For IDE0008 and most analyzer issues (70-80% efficiency)**:
```bash
# 🚨 AGGRESSIVE AUTO-FIX FIRST (MANDATORY) - your most efficient approach
dotnet build
dotnet format analyzers
dotnet format --verify-no-changes
dotnet format analyzers --verify-no-changes
dotnet build
```

**For a specific IDE0008 failure in a specific repository**:
```bash
cd "<REPO_ROOT>"
dotnet build
dotnet format analyzers
dotnet build
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
