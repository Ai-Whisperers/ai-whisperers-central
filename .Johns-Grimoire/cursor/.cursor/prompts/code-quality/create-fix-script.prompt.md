---
name: create-fix-script
description: "Create automated PowerShell fix scripts for specific diagnostic codes (CS/IDE/CA rules). Analyzes diagnostic patterns and generates standardized fix scripts following eneve.domain script standards."
category: code-quality
tags: script-generation, diagnostic-fixes, automation, code-analysis, powershell, quality-scripts
argument-hint: "Diagnostic code (e.g., CA1861, IDE0300, CS1570) and example diagnostic message"
rules:
  - .cursor/rules/scripts/core-principles-rule.mdc
  - .cursor/rules/scripts/powershell-standards-rule.mdc
  - .cursor/rules/scripts/script-quality-levels-rule.mdc
  - .cursor/rules/quality/zero-warnings-zero-errors-rule.mdc
  - .cursor/rules/quality/diagnostic-messages-agent-application-rule.mdc
---

# Create Diagnostic Fix Script

## Purpose

Generate standardized PowerShell scripts to automatically fix specific diagnostic codes (CS compiler errors, IDE suggestions, CA analyzer warnings). The script should follow eneve.domain script standards and be placed in `.cursor/scripts/quality/` with the diagnostic code in the filename.

## Required Input

Provide:
1. **Diagnostic Code**: The specific code (e.g., `CA1861`, `IDE0300`, `CS1570`, `IDE1006`)
2. **Diagnostic Message**: The full diagnostic message text
3. **Example Code**: At least one example of code that triggers the diagnostic
4. **Fixed Code**: The expected fixed version (or pattern)
5. **Pattern Type**: 
   - `regex-replace` - Simple regex pattern matching and replacement
   - `format-only` - Can be fixed with `dotnet format` (create wrapper script)
   - `structural` - Requires code structure analysis (more complex)
   - `extraction` - Extract values to fields/constants (like CA1861)

## Script Naming Convention

**CRITICAL**: Script filename MUST include the diagnostic code:
- Format: `fix-{DIAGNOSTIC-CODE}-{descriptive-name}.ps1`
- Examples:
  - `fix-ca1861-static-readonly-arrays.ps1`
  - `fix-ide0300-collection-initialization.ps1`
  - `fix-cs1570-xml-comments.ps1`
  - `fix-ide1006-naming-violations.ps1`

## Script Structure Template

Every fix script MUST follow this structure (see existing scripts in `.cursor/scripts/quality/`):

```powershell
#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes {DIAGNOSTIC-CODE} {brief description}.

.DESCRIPTION
    Automatically fixes {DIAGNOSTIC-CODE} diagnostic: "{diagnostic message}"
    
    Specifically addresses:
    - {Issue pattern 1}
    - {Issue pattern 2}
    - {Issue pattern 3}
    
    This script targets {DIAGNOSTIC-CODE}: "{diagnostic message}"

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory and subdirectories will be processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER WhatIf
    Show what would be changed without actually making changes.

.PARAMETER Verbose
    Enable verbose output showing detailed processing information.

.PARAMETER Stabilize
    Enable stabilization points - prompts for commit after successful fixes.
    Allows incremental commits at safe points in the workflow.

.PARAMETER RefreshFromGit
    Refresh files from git and start over. Restores all files to last commit state
    before applying fixes. Use this if fixes introduced issues.

.EXAMPLE
    .\fix-{DIAGNOSTIC-CODE}-{name}.ps1 -Path "src/MyClass.cs"
    Fix {issue} in a specific file

.EXAMPLE
    .\fix-{DIAGNOSTIC-CODE}-{name}.ps1 -Path "src/" -Recurse
    Fix {issue} in all C# files under src/ directory

.EXAMPLE
    .\fix-{DIAGNOSTIC-CODE}-{name}.ps1 -Path "MyClass.cs" -WhatIf -Verbose
    Show what changes would be made without applying them

.NOTES
    File Name      : fix-{DIAGNOSTIC-CODE}-{name}.ps1
    Author         : AI Assistant
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes {DIAGNOSTIC-CODE} ({diagnostic description})
    Related Rules  : rule.quality.zero-warnings-zero-errors.v1, {relevant rules}
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to C# file or directory to process")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Recurse into subdirectories when Path is a directory")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "Enable stabilization points for commits")]
    [switch]$Stabilize,

    [Parameter(Mandatory = $false, HelpMessage = "Refresh from git and start over (restores files to last commit)")]
    [switch]$RefreshFromGit
)

$ErrorActionPreference = 'Stop'

# Emoji helpers for output
function Get-StatusEmoji {
    param([string]$Status)
    if ($env:CI -eq 'true') {
        return @{
            'success' = '[SUCCESS]'
            'error'   = '[ERROR]'
            'warning' = '[WARN]'
            'info'    = '[INFO]'
        }[$Status]
    }
    @{
        'success' = '✅'
        'error'   = '❌'
        'warning' = '⚠️'
        'info'    = 'ℹ️'
    }[$Status]
}

function Write-Step {
    param([string]$Message)
    $step = Get-StatusEmoji 'info'
    Write-Host "`n$step $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'success'
    Write-Host "$emoji $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'error'
    Write-Host "$emoji $Message" -ForegroundColor Red
}

function Write-InfoMessage {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'info'
    Write-Host "$emoji $Message" -ForegroundColor Gray
}

# Get all C# files to process
function Get-CSharpFiles {
    param([string]$TargetPath, [bool]$RecurseDirectories)

    if (Test-Path $TargetPath -PathType Leaf) {
        if ($TargetPath -like "*.cs") {
            return @($TargetPath)
        } else {
            Write-Failure "Specified file is not a C# file: $TargetPath"
            return @()
        }
    }

    if (Test-Path $TargetPath -PathType Container) {
        $searchOptions = @{
            Path    = $TargetPath
            Filter  = "*.cs"
            File    = $true
        }
        if ($RecurseDirectories) {
            $searchOptions.Recurse = $true
        }

        return Get-ChildItem @searchOptions | Select-Object -ExpandProperty FullName
    }

    Write-Failure "Path does not exist: $TargetPath"
    return @()
}

# Fix {DIAGNOSTIC-CODE} issues
function Fix-{DiagnosticIssue} {
    param([string]$FilePath)

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $originalContent = $content
        $changesMade = 0

        # Pattern 1: {Describe pattern}
        # Matches: {Example of problematic code}
        $pattern1 = '{regex-pattern}'
        $replacement1 = '{replacement-pattern}'
        
        $newContent = $content -replace $pattern1, $replacement1
        if ($newContent -ne $content) {
            $changesMade++
            if ($Verbose) {
                Write-InfoMessage "  Fixed pattern 1 in $FilePath"
            }
        }
        $content = $newContent

        # Add more patterns as needed...

        # Only write file if changes were made
        if ($changesMade -gt 0) {
            if ($WhatIf) {
                Write-InfoMessage "Would fix $changesMade {DIAGNOSTIC-CODE} issue(s) in $FilePath"
                return $true
            } else {
                $content | Set-Content $FilePath -NoNewline -ErrorAction Stop
                Write-Success "Fixed $changesMade {DIAGNOSTIC-CODE} issue(s) in $FilePath"
                return $true
            }
        } else {
            if ($Verbose) {
                Write-InfoMessage "No {DIAGNOSTIC-CODE} issues found in $FilePath"
            }
            return $false
        }

    } catch {
        Write-Failure "Error processing $FilePath : $_"
        return $false
    }
}

# Catalog diagnostics before fixes
function Get-Diagnostics {
    param([string]$SolutionFile)
    
    if (-not $SolutionFile -or -not (Test-Path $SolutionFile)) {
        return @{
            TargetDiagnostic = 0
            TotalErrors = 0
            TotalWarnings = 0
            Diagnostics = @()
        }
    }
    
    # Build and capture diagnostics
    $buildOutput = dotnet build "$SolutionFile" --no-restore 2>&1 | Out-String
    
    # Count target diagnostic
    $targetPattern = "{DIAGNOSTIC-CODE}"
    $targetCount = ([regex]::Matches($buildOutput, $targetPattern)).Count
    
    # Count all errors
    $errorMatches = [regex]::Matches($buildOutput, 'error\s+(CS|IDE|CA)\d+')
    $errorCount = $errorMatches.Count
    
    # Count all warnings
    $warningMatches = [regex]::Matches($buildOutput, 'warning\s+(CS|IDE|CA)\d+')
    $warningCount = $warningMatches.Count
    
    # Extract diagnostic details
    $diagnostics = @()
    $allMatches = [regex]::Matches($buildOutput, '(error|warning|info|suggestion)\s+((?:CS|IDE|CA)\d+):\s*(.+?)(?:\r?\n|$)')
    foreach ($match in $allMatches) {
        $diagnostics += @{
            Severity = $match.Groups[1].Value
            Code = $match.Groups[2].Value
            Message = $match.Groups[3].Value.Trim()
        }
    }
    
    return @{
        TargetDiagnostic = $targetCount
        TotalErrors = $errorCount
        TotalWarnings = $warningCount
        Diagnostics = $diagnostics
    }
}

# Refresh from git if requested
function Refresh-FromGit {
    param([string[]]$FilePaths)
    
    Write-Step "Git Refresh: Restoring files to last commit"
    Write-Warning "This will discard all uncommitted changes in the specified files"
    
    $response = Read-Host "Continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-InfoMessage "Git refresh cancelled by user"
        return $false
    }
    
    foreach ($file in $FilePaths) {
        if (Test-Path $file) {
            git checkout -- $file 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Restored: $file"
            } else {
                Write-Failure "Failed to restore: $file"
            }
        }
    }
    
    Write-Success "Git refresh completed - files restored to last commit"
    return $true
}

# Stabilization point - commit changes
function Invoke-StabilizationPoint {
    param([string[]]$ChangedFiles, [int]$TargetFixed, [int]$ErrorsIntroduced)
    
    if (-not $Stabilize) {
        return
    }
    
    Write-Step "Stabilization Point: Ready for commit"
    Write-InfoMessage "Fixed $TargetFixed {DIAGNOSTIC-CODE} diagnostic(s)"
    Write-InfoMessage "Changed $($ChangedFiles.Count) file(s)"
    
    if ($ErrorsIntroduced -gt 0) {
        Write-Failure "Cannot commit - $ErrorsIntroduced error(s) introduced"
        return
    }
    
    Write-InfoMessage "Files ready for commit:"
    $ChangedFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
    
    $response = Read-Host "Commit these changes? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        $commitMessage = Read-Host "Commit message (or press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($commitMessage)) {
            $commitMessage = "Fix {DIAGNOSTIC-CODE}: {brief description}"
        }
        
        git add $ChangedFiles 2>&1 | Out-Null
        git commit -m $commitMessage 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Committed changes: $commitMessage"
        } else {
            Write-Failure "Commit failed - check git status"
        }
    } else {
        Write-InfoMessage "Commit skipped - changes remain uncommitted"
    }
}

# Main execution
try {
    Write-Step "{DIAGNOSTIC-CODE} {Issue Name} Fixer"
    Write-InfoMessage "Fixes {DIAGNOSTIC-CODE} diagnostic: {diagnostic message}"

    # Refresh from git if requested
    if ($RefreshFromGit) {
        $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories $Recurse
        if ($files.Count -gt 0) {
            if (Refresh-FromGit -FilePaths $files) {
                Write-InfoMessage "Files refreshed - ready to start over"
            } else {
                Write-InfoMessage "Refresh cancelled - continuing with current files"
            }
        }
    }

    $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories $Recurse

    if ($files.Count -eq 0) {
        Write-Failure "No C# files found to process"
        exit 1
    }

    Write-InfoMessage "Found $($files.Count) C# file(s) to process"

    # Step 1: Catalog diagnostics BEFORE fixes
    Write-Step "Catalog: Analyzing current diagnostics"
    $solutionFile = $null
    $currentPath = if (Test-Path $Path -PathType Leaf) { Split-Path $Path -Parent } else { $Path }
    
    # Find solution file
    $solutionFiles = Get-ChildItem -Path $currentPath -Filter "*.sln" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $solutionFiles) {
        $parentPath = Split-Path $currentPath -Parent
        $solutionFiles = Get-ChildItem -Path $parentPath -Filter "*.sln" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($solutionFiles) {
        $solutionFile = $solutionFiles.FullName
    }
    
    $beforeDiagnostics = @{
        TargetDiagnostic = 0
        TotalErrors = 0
        TotalWarnings = 0
    }
    
    if ($solutionFile) {
        Write-InfoMessage "Cataloging diagnostics before fixes..."
        $beforeDiagnostics = Get-Diagnostics -SolutionFile $solutionFile
        Write-InfoMessage "Before: {DIAGNOSTIC-CODE} count = $($beforeDiagnostics.TargetDiagnostic)"
        Write-InfoMessage "Before: Total errors = $($beforeDiagnostics.TotalErrors), warnings = $($beforeDiagnostics.TotalWarnings)"
    } else {
        Write-InfoMessage "No solution file found - skipping diagnostic catalog"
    }

    # Step 2: Apply fixes
    Write-Step "Fixing: Applying {DIAGNOSTIC-CODE} fixes"
    $filesProcessed = 0
    $filesChanged = 0

    foreach ($file in $files) {
        $filesProcessed++
        if ($Verbose) {
            Write-InfoMessage "Processing: $file"
        }

        $changed = Fix-{DiagnosticIssue} -FilePath $file
        if ($changed) {
            $filesChanged++
        }
    }

    Write-Step "Summary"
    Write-InfoMessage "Processed: $filesProcessed file(s)"
    Write-InfoMessage "Changed: $filesChanged file(s)"

    if ($WhatIf) {
        Write-InfoMessage "Run without -WhatIf to apply changes"
        exit 0
    }

    # Step 3: Validation at the end - verify fixes worked and didn't introduce issues
    if ($filesChanged -gt 0 -and $solutionFile) {
        Write-Step "Validation: Verifying fixes and checking for regressions"
        
        Write-InfoMessage "Building solution to verify fixes: $solutionFile"
        
        # Catalog diagnostics AFTER fixes
        $afterDiagnostics = Get-Diagnostics -SolutionFile $solutionFile
        
        Write-InfoMessage "After: {DIAGNOSTIC-CODE} count = $($afterDiagnostics.TargetDiagnostic)"
        Write-InfoMessage "After: Total errors = $($afterDiagnostics.TotalErrors), warnings = $($afterDiagnostics.TotalWarnings)"
        
        # Compare before/after
        $targetFixed = $beforeDiagnostics.TargetDiagnostic - $afterDiagnostics.TargetDiagnostic
        $errorsIntroduced = $afterDiagnostics.TotalErrors - $beforeDiagnostics.TotalErrors
        $warningsIntroduced = $afterDiagnostics.TotalWarnings - $beforeDiagnostics.TotalWarnings
        
        # Verify target diagnostic was fixed
        if ($targetFixed -gt 0) {
            Write-Success "Fixed $targetFixed {DIAGNOSTIC-CODE} diagnostic(s)"
        } elseif ($beforeDiagnostics.TargetDiagnostic -eq 0) {
            Write-InfoMessage "No {DIAGNOSTIC-CODE} diagnostics found before fixes"
        } else {
            Write-Warning "No {DIAGNOSTIC-CODE} diagnostics were fixed (before: $($beforeDiagnostics.TargetDiagnostic), after: $($afterDiagnostics.TargetDiagnostic))"
        }
        
        # Verify no new errors introduced
        if ($errorsIntroduced -gt 0) {
            Write-Failure "ERROR: Introduced $errorsIntroduced new error(s) - fixes made it worse!"
            Write-InfoMessage "New errors detected:"
            $newErrors = $afterDiagnostics.Diagnostics | Where-Object { 
                $_.Severity -eq 'error' -and 
                -not ($beforeDiagnostics.Diagnostics | Where-Object { 
                    $_.Code -eq $_.Code -and $_.Message -eq $_.Message 
                })
            }
            $newErrors | ForEach-Object {
                Write-Host "  $($_.Code): $($_.Message)" -ForegroundColor Red
            }
            Write-InfoMessage "Review errors above and fix manually, or restore files with: git checkout -- $($files -join ', ')"
            exit 1
        } elseif ($errorsIntroduced -lt 0) {
            Write-Success "Bonus: Fixed $([Math]::Abs($errorsIntroduced)) additional error(s)"
        } else {
            Write-Success "No new errors introduced (0 errors added)"
        }
        
        # Verify no new warnings introduced (or at least report)
        if ($warningsIntroduced -gt 0) {
            Write-Warning "Introduced $warningsIntroduced new warning(s)"
            if ($Verbose) {
                $newWarnings = $afterDiagnostics.Diagnostics | Where-Object { 
                    $_.Severity -eq 'warning' -and 
                    -not ($beforeDiagnostics.Diagnostics | Where-Object { 
                        $_.Code -eq $_.Code -and $_.Message -eq $_.Message 
                    })
                }
                $newWarnings | ForEach-Object {
                    Write-Host "  $($_.Code): $($_.Message)" -ForegroundColor Yellow
                }
            }
        } elseif ($warningsIntroduced -lt 0) {
            Write-Success "Bonus: Fixed $([Math]::Abs($warningsIntroduced)) additional warning(s)"
        } else {
            Write-Success "No new warnings introduced (0 warnings added)"
        }
        
        # Final verification
        if ($afterDiagnostics.TotalErrors -eq 0 -and $targetFixed -gt 0) {
            Write-Success "{DIAGNOSTIC-CODE} fixes completed successfully - target fixed, no errors introduced"
            
            # Stabilization point: Offer to commit
            if ($Stabilize) {
                $changedFilesList = $files | Where-Object { 
                    $filePath = $_
                    git status --porcelain $filePath 2>&1 | Out-String | Select-String -Pattern '^\s*[AM]' -Quiet
                }
                if ($changedFilesList.Count -gt 0) {
                    Invoke-StabilizationPoint -ChangedFiles $changedFilesList -TargetFixed $targetFixed -ErrorsIntroduced $errorsIntroduced
                }
            }
            
            exit 0
        } elseif ($afterDiagnostics.TotalErrors -eq 0) {
            Write-Success "{DIAGNOSTIC-CODE} fixes completed - no errors, but verify target was fixed"
            
            # Stabilization point: Offer to commit
            if ($Stabilize -and $targetFixed -gt 0) {
                $changedFilesList = $files | Where-Object { 
                    $filePath = $_
                    git status --porcelain $filePath 2>&1 | Out-String | Select-String -Pattern '^\s*[AM]' -Quiet
                }
                if ($changedFilesList.Count -gt 0) {
                    Invoke-StabilizationPoint -ChangedFiles $changedFilesList -TargetFixed $targetFixed -ErrorsIntroduced $errorsIntroduced
                }
            }
            
            exit 0
        } else {
            Write-Failure "Build has errors - verify fixes didn't introduce issues"
            
            # Offer git refresh if errors introduced
            if ($errorsIntroduced -gt 0) {
                Write-Warning "Errors were introduced - consider refreshing from git"
                $response = Read-Host "Refresh files from git to start over? (y/N)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    Refresh-FromGit -FilePaths $files
                    Write-InfoMessage "Files refreshed - you can now run the script again"
                }
            }
            
            exit 1
        }
    } elseif ($filesChanged -gt 0) {
        Write-Warning "No solution file found - cannot verify fixes"
        Write-InfoMessage "Recommend running 'dotnet build' manually to verify fixes"
        Write-Success "{DIAGNOSTIC-CODE} fixes applied (validation skipped)"
        exit 0
    } else {
        Write-InfoMessage "No {DIAGNOSTIC-CODE} issues found - files are already fixed"
        exit 0
    }

} catch {
    Write-Failure "Script execution failed: $_"
    exit 1
}
```

## Pattern Analysis Guidelines

### 1. Regex-Replace Pattern (Most Common)

**When to use**: Simple text transformations that can be expressed as regex patterns.

**Example**: IDE0300 - Collection initialization simplification
- **Before**: `new List<string> { "a", "b" }`
- **After**: `new() { "a", "b" }`
- **Pattern**: `(\w+<[^>]+>)\s+(\w+)\s*=\s*new\s+\1\s*\{` → `$1 $2 = new() {`

**Implementation**:
```powershell
$pattern = '(\w+<[^>]+>)\s+(\w+)\s*=\s*new\s+\1\s*\{'
$replacement = '$1 $2 = new() {'
$content = $content -replace $pattern, $replacement
```

### 2. Format-Only Pattern

**When to use**: Issues that can be fixed by `dotnet format` or `dotnet format analyzers`.

**Example**: IDE0008 - Use explicit type instead of 'var'

**Implementation**:
```powershell
function Fix-FormatIssue {
    param([string]$FilePath)
    
    # Run dotnet format analyzers to auto-fix
    $result = dotnet format analyzers $FilePath --verbosity quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Fixed formatting issues in $FilePath"
        return $true
    }
    return $false
}
```

### 3. Extraction Pattern

**When to use**: Extract repeated values to constants/fields.

**Example**: CA1861 - Constant arrays should be static readonly fields
- **Before**: `Method(new[] { "value1", "value2" })`
- **After**: 
  ```csharp
  private static readonly string[] _methodArray = new[] { "value1", "value2" };
  Method(_methodArray);
  ```

**Implementation**:
```powershell
# Track field declarations and replacements
$fieldDeclarations = @()
$fieldReplacements = @{}

# Find patterns and extract to fields
# Generate unique field names
# Insert field declarations in class
# Replace usages with field references
```

### 4. Structural Pattern

**When to use**: Requires understanding code structure (classes, methods, etc.).

**Example**: CS1591 - Missing XML documentation
- Requires: Finding public members, checking for XML comments, generating documentation

**Implementation**:
```powershell
# Parse code structure
$methodPattern = '(?m)^\s*public\s+(?:async\s+)?(?:Task|void)\s+(\w+)\s*\('
$matches = [regex]::Matches($content, $methodPattern)

# Check each match for documentation
# Insert XML comments before methods
```

## Quality Standards Checklist

Before finalizing the script, ensure:

- [ ] **Filename includes diagnostic code**: `fix-{CODE}-{name}.ps1`
- [ ] **Comment-based help complete**: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`
- [ ] **Parameters validated**: `[ValidateNotNullOrEmpty()]`, proper types
- [ ] **Error handling**: `$ErrorActionPreference = 'Stop'`, try/catch blocks
- [ ] **WhatIf support**: `[CmdletBinding(SupportsShouldProcess = $true)]`
- [ ] **Status emoji helpers**: Unicode support with CI fallback
- [ ] **Exit codes**: 0 = success, 1 = failure
- [ ] **Verbose logging**: Detailed output when `-Verbose` is used
- [ ] **File processing**: Handles single files and directories with `-Recurse`
- [ ] **Pattern matching**: Uses appropriate regex patterns with proper escaping
- [ ] **Change tracking**: Only writes files if changes were made
- [ ] **Summary output**: Reports files processed and changed
- [ ] **Build validation**: Verifies code still compiles after fixes
- [ ] **Error detection**: Checks for new errors introduced by fixes
- [ ] **Auto-recovery**: Attempts to fix errors caused by the script

## Pattern Identification Process

1. **Analyze Diagnostic Message**:
   - What is the issue?
   - What should the code look like instead?
   - Is there a clear transformation pattern?

2. **Identify Pattern Type**:
   - Can it be fixed with regex? → Use regex-replace pattern
   - Can `dotnet format` fix it? → Use format-only pattern
   - Does it require extraction? → Use extraction pattern
   - Does it need structure analysis? → Use structural pattern

3. **Create Test Cases**:
   - Before/after examples
   - Edge cases to handle
   - What should NOT be changed

4. **Implement Pattern Matching**:
   - Write regex patterns (test thoroughly)
   - Handle edge cases
   - Ensure no false positives
   - **Use conservative patterns** - better to miss a fix than break code

5. **Test Script**:
   - Run on example files
   - Verify changes are correct
   - Check for unintended side effects
   - **Verify build succeeds** after fixes

6. **Add Validation**:
   - Build solution after fixes
   - Detect any introduced errors
   - Provide recovery guidance if errors found

## Examples

### Example 1: Simple Regex Pattern (IDE0300)

**Diagnostic**: `IDE0300: Collection initialization can be simplified`

**Pattern**: `List<string> list = new List<string> { ... }` → `List<string> list = new() { ... }`

**Script**: `fix-ide0300-collection-initialization.ps1`

**Key Pattern**:
```powershell
$pattern = '(\w+<[^>]+>)\s+(\w+)\s*=\s*new\s+\1\s*\{'
$replacement = '$1 $2 = new() {'
```

### Example 2: Extraction Pattern (CA1861)

**Diagnostic**: `CA1861: Constant arrays passed as arguments are not reused when called repeatedly`

**Pattern**: Extract `new[] { ... }` to `private static readonly` field

**Script**: `fix-ca1861-static-readonly-arrays.ps1`

**Key Pattern**:
```powershell
# Find: MethodName(new[] { "value1", "value2" })
# Replace: MethodName(_fieldName)
# Insert: private static readonly string[] _fieldName = new[] { "value1", "value2" };
```

### Example 3: Format-Only Pattern (IDE0008)

**Diagnostic**: `IDE0008: Use explicit type instead of 'var'`

**Pattern**: Can be auto-fixed by `dotnet format analyzers`

**Script**: `fix-ide0008-explicit-types.ps1`

**Key Pattern**:
```powershell
dotnet format analyzers $FilePath --verbosity quiet
```

## Output Requirements

1. **Create the script file** in `.cursor/scripts/quality/fix-{DIAGNOSTIC-CODE}-{descriptive-name}.ps1`
2. **Follow the template structure** exactly
3. **Include comprehensive comment-based help**
4. **Include build validation** - verify code compiles after fixes
5. **Include error detection** - check for introduced errors
6. **Test the script** on provided examples
7. **Verify build succeeds** after running script
8. **Document any limitations** or edge cases in the script comments

## Safety Guidelines

**CRITICAL**: Scripts must be safe and not break code:

1. **Conservative Patterns**:
   - Only match exact diagnostic patterns
   - Avoid overly broad regex patterns
   - Test on edge cases before finalizing

2. **Validation Always**:
   - Always run build validation after fixes
   - Exit with error if build fails
   - Provide clear error messages

3. **Recovery Options**:
   - If errors introduced, suggest fixes
   - Or provide git revert command
   - Document what went wrong

4. **WhatIf First**:
   - Always test with `-WhatIf` first
   - Review changes before applying
   - Verify pattern matches correctly

## Safety and Validation Requirements

**CRITICAL**: Scripts MUST include validation to ensure they don't break code:

1. **Git Refresh Option** (OPTIONAL):
   - If `-RefreshFromGit` is specified, restore files from git before starting
   - Ask user permission before discarding changes
   - Useful for starting fresh if previous run had issues

2. **Catalog BEFORE Fixes** (MANDATORY):
   - Build solution and catalog all diagnostics BEFORE applying fixes
   - Count target diagnostic occurrences
   - Count total errors and warnings
   - Store baseline for comparison

3. **Apply Fixes**:
   - Process files and apply fixes
   - Track which files were changed

4. **Verify AFTER Fixes** (MANDATORY - at the end):
   - Build solution again and catalog diagnostics AFTER fixes
   - Compare before/after counts:
     - **Target diagnostic**: Should decrease (verify it was actually fixed)
     - **Total errors**: Should be 0 or same (verify 0 new errors introduced)
     - **Total warnings**: Should be same or less (report if increased)
   - Exit with error if:
     - Target diagnostic wasn't fixed
     - New errors were introduced (made it worse)
   - Exit with success if:
     - Target diagnostic was fixed
     - No new errors introduced (0 -> 0, or reduced)

5. **Stabilization Points** (OPTIONAL):
   - If `-Stabilize` is specified, offer commit opportunities after successful fixes
   - Prompt user to commit changes at safe points
   - Allows incremental commits for large fix operations
   - Only commits if no errors were introduced

4. **Error Detection**:
   - Parse build output for errors
   - Compare before/after diagnostic lists
   - Identify new diagnostics introduced by fixes
   - Report errors clearly with file locations

5. **Auto-Recovery** (when possible):
   - If script introduces errors, attempt to fix them
   - Or provide clear guidance on how to fix
   - Or suggest reverting changes with git command

6. **Safe Patterns**:
   - Use conservative regex patterns (avoid false positives)
   - Test patterns on edge cases
   - Only modify code that matches the exact diagnostic pattern
   - Preserve code structure and formatting

## Validation

After creating the script:
- [ ] Script follows naming convention (`fix-{CODE}-{name}.ps1`)
- [ ] Script follows template structure
- [ ] Comment-based help is complete
- [ ] Script handles `-WhatIf` correctly
- [ ] Script handles `-Verbose` correctly
- [ ] Script processes files correctly
- [ ] Script generates correct fixes
- [ ] Script reports progress accurately
- [ ] Script uses proper exit codes
- [ ] **Script catalogs diagnostics BEFORE fixes** (baseline for comparison)
- [ ] **Script catalogs diagnostics AFTER fixes** (verify results)
- [ ] **Script compares before/after** (verify target fixed, no new errors)
- [ ] **Script verifies target diagnostic was fixed** (count decreased)
- [ ] **Script verifies no new errors introduced** (0 -> 0, or reduced)
- [ ] **Script exits with error if made worse** (new errors introduced)
- [ ] **Script provides error recovery guidance** (suggests fixes or revert)

## Related Scripts

Reference existing scripts for patterns:
- `fix-cs1570-xml-comments.ps1` - Regex pattern matching
- `fix-ide1006-naming-violations.ps1` - Field name transformations
- `fix-ca1825-static-readonly-arrays.ps1` - Extraction pattern
- `fix-ide0028-collection-initialization.ps1` - Collection simplification

## Workflow with Stabilization Points

**Standard Workflow**:
```powershell
# 1. Catalog and fix
.\fix-{CODE}-{name}.ps1 -Path "src/" -Recurse

# 2. If issues, refresh and retry
.\fix-{CODE}-{name}.ps1 -Path "src/" -Recurse -RefreshFromGit
```

**Workflow with Stabilization Points**:
```powershell
# 1. Fix with commit points enabled
.\fix-{CODE}-{name}.ps1 -Path "src/" -Recurse -Stabilize

# Script will:
# - Catalog diagnostics (baseline)
# - Apply fixes
# - Verify fixes worked
# - Prompt: "Commit these changes? (y/N)"
# - If yes: Commit with message
# - Continue to next batch or complete
```

**Recovery Workflow**:
```powershell
# If fixes introduced errors, refresh and start over
.\fix-{CODE}-{name}.ps1 -Path "src/" -Recurse -RefreshFromGit

# Or manually restore:
git checkout -- path/to/file.cs
```

## Notes

- **Scripts are living tools**: They should be enhanced when patterns are discovered
- **Follow DRY principle**: Reuse helper functions from existing scripts
- **Test thoroughly**: Use `-WhatIf` first, then test on real files
- **Document limitations**: If pattern can't handle all cases, document in script comments
- **Iterate**: Scripts can be improved based on real-world usage
- **Stabilization points**: Enable incremental commits for large fix operations
- **Git refresh**: Always ask permission before discarding uncommitted changes

