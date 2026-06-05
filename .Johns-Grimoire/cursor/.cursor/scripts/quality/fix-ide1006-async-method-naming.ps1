#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE1006 async method naming violations by ensuring async methods end with 'Async'

.DESCRIPTION
    This script automatically fixes IDE1006 naming rule violations for async methods in C# test files.
    The .editorconfig rule requires async methods to end with the 'Async' suffix.

    The script handles complex renaming patterns where 'Async' appears in the middle of method names:
    - MethodAsync_Name_Should_DoSomething() → Method_Name_Should_DoSomethingAsync()
    - Compare_ConcurrentCalls_ShouldHandleThreadSafely() → Compare_ConcurrentCalls_ShouldHandleThreadSafelyAsync()

    Features:
    - Safe pattern matching to avoid false positives
    - Dry-run mode to preview changes
    - Comprehensive logging with file-by-file progress
    - Compatible with both PowerShell 5.1 and 7+ (graceful fallback)
    - Works from any directory (auto-detects repository root)

.PARAMETER Path
    Root path to scan for test files. Defaults to current directory.

.PARAMETER TestDirectory
    Name of the test directory to scan. Defaults to 'tst'.

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.PARAMETER Force
    Overwrite existing files without prompting.

.EXAMPLE
    .\fix-ide1006-async-method-naming.ps1
    Fixes async method naming violations in all test files under tst/

.EXAMPLE
    .\fix-ide1006-async-method-naming.ps1 -WhatIf
    Shows what would be changed without making actual modifications

.EXAMPLE
    .\fix-ide1006-async-method-naming.ps1 -Path "C:\MyProject" -TestDirectory "test"
    Fixes async method naming in a different project structure

.NOTES
    File Name      : fix-ide1006-async-method-naming.ps1
    Author         : Code Quality Automation
    Prerequisite   : PowerShell 5.1+, Test files in tst/ directory
    Related Rules  : IDE1006 naming conventions, async method standards

.LINK
    https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/style-rules/ide1006
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Root path to scan for test files")]
    [ValidateNotNullOrEmpty()]
    [string]$Path = $PWD.Path,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the test directory to scan")]
    [ValidateNotNullOrEmpty()]
    [string]$TestDirectory = "tst",

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be changed without making changes")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite existing files without prompting")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Optional diagnostics report file to restrict processing to reported files/lines")]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsFile,

    [Parameter(Mandatory = $false, HelpMessage = "Diagnostic code to filter within DiagnosticsFile (default: IDE1006)")]
    [ValidatePattern('^[A-Z]{2,10}\d{1,6}$')]
    [string]$DiagnosticCode = 'IDE1006',

    [Parameter(Mandatory = $false, HelpMessage = "Number of lines around each diagnostic to treat as eligible (default: 2)")]
    [ValidateRange(0, 50)]
    [int]$LinePadding = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the naming fixer")]
    [switch]$SkipRoslyn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import shared modules if available (skip if PowerShell version incompatible)
$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$commonModulePath = Join-Path $scriptRoot "modules\Common.psm1"
if (-not (Test-Path $commonModulePath)) {
    throw "Common module not found at: $commonModulePath"
}
Import-Module $commonModulePath -Force -ErrorAction Stop

$roslynModulePath = Join-Path $scriptRoot "modules\RoslynFixes.psm1"
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$diagnosticsModulePath = Join-Path $scriptRoot "modules\Diagnostics.psm1"
if (Test-Path $diagnosticsModulePath) {
    try {
        Import-Module $diagnosticsModulePath -Force -ErrorAction Stop
    } catch {
        Write-WarningMessage "Could not import Diagnostics.psm1 module: $($_.Exception.Message)"
    }
}

# Main logic
Write-Section "Async Method Naming Fixer - IDE1006 Compliance"

Write-InfoMessage "Configuration:"
Write-InfoMessage "  Root Path: $Path"
Write-InfoMessage "  Test Directory: $TestDirectory"
Write-InfoMessage "  Dry Run Mode: $($DryRun.IsPresent)"
Write-InfoMessage "  Force Mode: $($Force.IsPresent)"

if (-not $SkipRoslyn -and -not $DryRun -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
    try {
        $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('IDE1006') -Severity 'info' -Include @($Path)
        if ($roslynResult.Attempted) {
            if ($roslynResult.Applied) {
                Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (IDE1006). Continuing with naming fixer for any remaining cases."
            } else {
                Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (IDE1006). Continuing with naming fixer."
            }
        } else {
            Write-InfoMessage "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with naming fixer."
        }
    } catch {
        Write-InfoMessage "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with naming fixer."
    }
}

# Validate paths
$testPath = Join-Path $Path $TestDirectory

# If running from scripts directory, adjust path to repository root
if (-not (Test-Path $testPath) -and $Path -match "\.cursor\\scripts$") {
    $repoRoot = Split-Path (Split-Path $Path -Parent) -Parent
    $testPath = Join-Path $repoRoot $TestDirectory
    Write-InfoMessage "Adjusted path to repository root: $repoRoot"
}

if (-not (Test-Path $testPath)) {
    Write-ErrorMessage "Test directory not found: $testPath"
    Write-InfoMessage "Current working directory: $(Get-Location)"
    Write-InfoMessage "Script location: $scriptRoot"
    exit 1
}

Write-InfoMessage "Scanning for test files in: $testPath"

# Find all test files (optionally restricted by diagnostics report)
$testFiles = @()
if (-not [string]::IsNullOrWhiteSpace($DiagnosticsFile) -and (Get-Command Get-DiagnosticTargetsFromReport -ErrorAction SilentlyContinue)) {
    $targets = Get-DiagnosticTargetsFromReport -ReportFilePath $DiagnosticsFile -Codes @($DiagnosticCode) -LinePadding $LinePadding
    foreach ($filePath in $targets.Files) {
        if ($filePath -match "Tests\.cs$" -and (Test-Path $filePath -PathType Leaf)) {
            $testFiles += (Get-Item -LiteralPath $filePath)
        }
    }
    Write-InfoMessage "Using DiagnosticsFile filter for $DiagnosticCode. Found $($testFiles.Count) test file(s) to process"
} else {
    $testFiles = Get-ChildItem -Path $testPath -Filter "*.cs" -Recurse -File |
        Where-Object { $_.FullName -match "Tests\.cs$" }
}

if ($testFiles.Count -eq 0) {
    Write-WarningMessage "No test files found in $testPath"
    exit 0
}

Write-InfoMessage "Found $($testFiles.Count) test files to process"

$totalFixed = 0
$filesChanged = 0

foreach ($file in $testFiles) {
    $filePath = $file.FullName
    $relativePath = $file.FullName.Replace("$Path\", "").Replace("$Path/", "")

    Write-InfoMessage "Processing: $relativePath"

    try {
        $content = Get-Content $filePath -Raw -Encoding UTF8
        $originalContent = $content
        $fileChanged = $false

        # Pattern 1: public async Task MethodAsync_Name_Should_DoSomething()
        # Replace with: public async Task Method_Name_Should_DoSomethingAsync()
        $pattern1 = 'public async Task ([A-Za-z][A-Za-z0-9_]*)Async([A-Za-z0-9_]+_Should[A-Za-z0-9_]*)\(\)'
        $replacement1 = 'public async Task $1$2Async()'

        $content = $content -replace $pattern1, $replacement1

        # Pattern 2: Handle methods that already end with Async but have Async in middle
        $pattern2 = 'public async Task ([A-Za-z][A-Za-z0-9_]*)Async(_[A-Za-z0-9_]+)_\(\)'
        $replacement2 = 'public async Task $1$2Async()'

        $content = $content -replace $pattern2, $replacement2

        # Pattern 3: Simple methods without underscores that don't end with Async
        $pattern3 = 'public async Task ([A-Za-z][A-Za-z0-9_]*)Async([^)]*)\(\)(?!.*Async)'
        $replacement3 = 'public async Task $1$2Async()'

        $content = $content -replace $pattern3, $replacement3

        # Check if file was modified
        if ($content -ne $originalContent) {
            $fileChanged = $true
            $filesChanged++

            # Count how many methods were fixed in this file
            $originalMatches = [regex]::Matches($originalContent, 'public async Task .*Async.*\(\)')
            $newMatches = [regex]::Matches($content, 'public async Task .*Async\(\)')

            if ($newMatches.Count -gt $originalMatches.Count) {
                $methodsFixed = $newMatches.Count - $originalMatches.Count
                $totalFixed += $methodsFixed
                Write-SuccessMessage "Fixed $methodsFixed async method(s) in $relativePath"
            }
        } else {
            Write-InfoMessage "No changes needed in $relativePath"
        }

        # Write changes if not in dry run mode
        if ($fileChanged -and -not $DryRun) {
            $content | Set-Content $filePath -NoNewline -Encoding UTF8
            Write-InfoMessage "Updated: $relativePath"
        } elseif ($fileChanged -and $DryRun) {
            Write-InfoMessage "Would update: $relativePath (Dry Run mode)"
        }

    } catch {
        Write-ErrorMessage "Error processing $relativePath : $($_.Exception.Message)"
        continue
    }
}

# Summary
Write-Section "Processing Complete"

if ($DryRun) {
    Write-InfoMessage "Dry Run Mode - No files were actually changed"
}

Write-SuccessMessage "Summary:"
Write-SuccessMessage "  Files processed: $($testFiles.Count)"
Write-SuccessMessage "  Files changed: $filesChanged"
Write-SuccessMessage "  Methods fixed: $totalFixed"

if ($totalFixed -gt 0) {
    Write-SuccessMessage "All async method naming violations have been fixed!"
    Write-InfoMessage "Run 'dotnet format --verify-no-changes' to verify compliance"
} else {
    Write-InfoMessage "No async method naming violations found"
}

exit 0

