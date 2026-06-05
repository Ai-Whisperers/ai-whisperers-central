#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE0028 code analysis suggestions to simplify collection initialization syntax.

.DESCRIPTION
    Automatically fixes IDE0028 code analysis suggestions to simplify collection initialization.
    This script follows the Roslyn-first, conservative TSV-driven approach for mass auto-fixing.

    Specifically addresses:
    - Empty collection constructors: new List<T>() → []
    - Collection initializers: new List<T> { ... } → [ ... ]
    - Dictionary initializers: { { "key", value } } → { ["key"] = value }
    - Target-typed new: new List<T>() when type can be inferred → new()

    This script targets IDE0028: "Collection initialization can be simplified"

.PARAMETER DiagnosticsTsvPath
    Path to the TSV export file containing IDE0028 diagnostics.

.PARAMETER RepoRoot
    Root directory of the repository (used for relative path resolution).

.PARAMETER Include
    Optional array of file/folder path patterns to include (e.g., "src/", "tst/").

.PARAMETER OutputDirectory
    Directory where TSV and JSON reports will be written (default: .cursor/scripts/quality/out).

.PARAMETER MaxFiles
    Maximum number of files to process (for testing/debugging).

.PARAMETER MaxLines
    Maximum number of lines per file to process (for testing/debugging).

.PARAMETER NoApplyChanges
    Report-only mode: analyze and report changes without applying them.

.PARAMETER SkipRoslyn
    Skip Roslyn pre-pass and run only the heuristic TSV-driven fixer.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for entries marked as skipped/partial/error, so another AI can
    apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0028-collection-initialization.ps1 -DiagnosticsTsvPath "tickets/EPP-192/data/diagnostics.tsv" -RepoRoot "E:\repos\myproject"
    Process all IDE0028 diagnostics from the TSV file

.EXAMPLE
    .\fix-ide0028-collection-initialization.ps1 -DiagnosticsTsvPath "data.tsv" -Include "src/", "tst/" -NoApplyChanges
    Report-only mode for source and test directories

.NOTES
    File Name      : fix-ide0028-collection-initialization.ps1
    Author         : Enhanced AI Assistant (Roslyn-first, TSV-driven)
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes IDE0028 (collection initialization can be simplified)
    Related Rules  : rule.quality.zero-warnings-zero-errors.v1, C# collection initialization best practices
    Version        : 2.0.0 - Enhanced with TSV parsing and Roslyn-first approach
#>

[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Legacy')]
param(
    # -----------------------------------------------------------------------------------------
    # Legacy/orchestrator compatibility
    # -----------------------------------------------------------------------------------------
    # `validate-pre-merge.ps1` invokes fix scripts with `-Path <root> -Recurse`.
    # Provide a compatible parameter set that runs a Roslyn-first fix pass without requiring TSV input.
    [Parameter(ParameterSetName = 'Legacy', Mandatory = $false, HelpMessage = "Root path to run the IDE0028 fixer from (orchestrator compatibility)")]
    [ValidateNotNullOrEmpty()]
    [string]$Path = $PWD.Path,

    [Parameter(ParameterSetName = 'Legacy', Mandatory = $false, HelpMessage = "Recurse subdirectories (orchestrator compatibility; currently informational)")]
    [switch]$Recurse,

    # -----------------------------------------------------------------------------------------
    # TSV-driven mode (explicit runs)
    # -----------------------------------------------------------------------------------------
    [Parameter(ParameterSetName = 'Tsv', Mandatory = $true, HelpMessage = "Path to TSV file containing IDE0028 diagnostics")]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsTsvPath,

    [Parameter(ParameterSetName = 'Tsv', Mandatory = $true, HelpMessage = "Root directory of the repository")]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false, HelpMessage = "File/folder patterns to include")]
    [string[]]$Include,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for reports")]
    [string]$OutputDirectory = ".cursor/scripts/quality/out",

    [Parameter(Mandatory = $false, HelpMessage = "Maximum files to process")]
    [int]$MaxFiles = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum lines per file to process")]
    [int]$MaxLines = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Report-only mode (no changes applied)")]
    [switch]$NoApplyChanges,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn pre-pass")]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for skipped/partial/error entries")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

$ErrorActionPreference = 'Stop'

$commonModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (-not (Test-Path $commonModulePath)) {
    throw "Common module not found at: $commonModulePath"
}
Import-Module $commonModulePath -Force -ErrorAction Stop

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

# Parse TSV diagnostics
function Get-DiagnosticsFromTsv {
    param([string]$TsvPath)

    if (-not (Test-Path $TsvPath)) {
        throw "Diagnostics TSV file not found: $TsvPath"
    }

    try {
        $diagnostics = Import-Csv -Path $TsvPath -Delimiter "`t"

        # Validate required columns
        $requiredColumns = @('Code', 'File', 'Line')
        foreach ($col in $requiredColumns) {
            if (-not $diagnostics[0].PSObject.Properties.Name.Contains($col)) {
                throw "Required column '$col' not found in TSV. Found columns: $($diagnostics[0].PSObject.Properties.Name -join ', ')"
            }
        }

        # Filter to IDE0028 diagnostics only
        $ide0028Diagnostics = $diagnostics | Where-Object { $_.Code -eq 'IDE0028' }

        Write-InfoMessage "Loaded $($ide0028Diagnostics.Count) IDE0028 diagnostics from TSV"

        return $ide0028Diagnostics
    }
    catch {
        throw "Failed to parse diagnostics TSV: $_"
    }
}

# Group diagnostics by file and line
function Group-Diagnostics {
    param([array]$Diagnostics)

    $grouped = @{}

    foreach ($diag in $Diagnostics) {
        $filePath = $diag.File
        $line = [int]$diag.Line

        if (-not $grouped.ContainsKey($filePath)) {
            $grouped[$filePath] = @{}
        }

        if (-not $grouped[$filePath].ContainsKey($line)) {
            $grouped[$filePath][$line] = @()
        }

        $grouped[$filePath][$line] += $diag
    }

    return $grouped
}

# Filter files based on include patterns
function Test-IncludePattern {
    param([string]$FilePath, [string[]]$IncludePatterns)

    if (-not $IncludePatterns -or $IncludePatterns.Count -eq 0) {
        return $true
    }

    foreach ($pattern in $IncludePatterns) {
        # Normalize patterns to use forward slashes and check relative path
        $normalizedPattern = $pattern -replace '\\', '/'
        $relativePath = $FilePath -replace '^.*[/\\](src|tst)[/\\]', '$1/'

        if ($relativePath -like "$normalizedPattern*" -or $FilePath -like "*$pattern*") {
            return $true
        }
    }

    return $false
}

# Process diagnostics for a single file
function Process-FileDiagnostics {
    param(
        [string]$FilePath,
        [hashtable]$LineDiagnostics,
        [int]$MaxLines
    )

    $results = @()
    $totalProcessed = 0

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $lines = $content -split "`n"

        foreach ($lineNumber in $lineDiagnostics.Keys | Sort-Object) {
            if ($MaxLines -gt 0 -and $totalProcessed -ge $MaxLines) {
                break
            }

            $diagnostics = $lineDiagnostics[$lineNumber]
            $expectedCount = $diagnostics.Count

            # Get the line content (adjust for 0-based vs 1-based indexing)
            if ($lineNumber -le $lines.Count) {
                $originalLine = $lines[$lineNumber - 1].Trim()
            } else {
                $results += [pscustomobject]@{
                    File = $FilePath
                    Line = $lineNumber
                    ExpectedCount = $expectedCount
                    AppliedCount = 0
                    Status = 'line-out-of-range'
                    Applied = ''
                    OriginalLine = ''
                    UpdatedLine = ''
                }
                continue
            }

            # Apply conservative fixes based on pattern matching
            $updatedLine = $originalLine
            $appliedPatterns = @()
            $appliedCount = 0

            # Pattern 1: Empty constructors (most safe)
            if ($originalLine -match 'new\s+(List|Dictionary|HashSet)<[^>]+>\s*\(\s*\)') {
                $updatedLine = $originalLine -replace 'new\s+(List|Dictionary|HashSet)<[^>]+>\s*\(\s*\)', '[]'
                $appliedPatterns += 'empty-constructor'
                $appliedCount++
            }
            # Pattern 2: Dictionary { { key, value } } → { [key] = value }
            elseif ($originalLine -match 'new\s+Dictionary<[^>]+>\s*\{\s*\{\s*([^,]+),\s*([^}]+)\s*\}\s*\}') {
                $updatedLine = $originalLine -replace '\{\s*\{\s*([^,]+),\s*([^}]+)\s*\}\s*\}', '{ [$1] = $2 }'
                $appliedPatterns += 'dictionary-initializer'
                $appliedCount++
            }
            # Pattern 3: Target-typed new() for collections when type matches exactly
            elseif ($originalLine -match '(\w+<[^>]+>)\s+(\w+)\s*=\s*new\s+\1\s*\(') {
                $updatedLine = $originalLine -replace '(\w+<[^>]+>)\s+(\w+)\s*=\s*new\s+\1\s*\(', '$1 $2 = new('
                $appliedPatterns += 'target-typed-new'
                $appliedCount++
            }
            else {
                # Skip - pattern not recognized as safe to auto-fix
                $appliedPatterns += 'skipped-unsafe-pattern'
            }

            $status = if ($appliedCount -gt 0) { 'fixed' } elseif ($appliedCount -eq 0) { 'skipped' } else { 'partial' }

            $results += [pscustomobject]@{
                File = $FilePath
                Line = $lineNumber
                ExpectedCount = $expectedCount
                AppliedCount = $appliedCount
                Status = $status
                Applied = $appliedPatterns -join ', '
                OriginalLine = $originalLine
                UpdatedLine = $updatedLine
            }

            $totalProcessed++
        }

        return $results
    }
    catch {
        Write-ErrorMessage "Error processing file $FilePath : $_"

        # Return error results for all diagnostics in this file
        $errorResults = @()
        foreach ($lineNumber in $lineDiagnostics.Keys) {
            $diagnostics = $lineDiagnostics[$lineNumber]
            $errorResults += [pscustomobject]@{
                File = $FilePath
                Line = $lineNumber
                ExpectedCount = $diagnostics.Count
                AppliedCount = 0
                Status = 'missing-file'
                Applied = 'error-file-access'
                OriginalLine = ''
                UpdatedLine = ''
            }
        }
        return $errorResults
    }
}

# Write reports in both TSV and JSON formats
function Write-Reports {
    param(
        [array]$Results,
        [string]$OutputDirectory,
        [string]$Timestamp = (Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')
    )

    $outputDir = Join-Path $OutputDirectory $Timestamp
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # TSV Report
    $tsvPath = Join-Path $outputDir 'ide0028-fixes.tsv'
    $Results | Export-Csv -Path $tsvPath -Delimiter "`t" -NoTypeInformation

    # JSON Report
    $jsonPath = Join-Path $outputDir 'ide0028-fixes.json'
    $Results | ConvertTo-Json | Set-Content $jsonPath

    Write-SuccessMessage "Reports written to: $outputDir"
    Write-InfoMessage "TSV: $tsvPath"
    Write-InfoMessage "JSON: $jsonPath"
}

# Main execution
try {
    Write-Step "IDE0028 Collection Initialization AutoFixer (Roslyn-First, TSV-Driven)"
    Write-InfoMessage "Processing IDE0028 diagnostics from TSV and applying conservative fixes"

    # Legacy/orchestrator mode: run a Roslyn fix pass and exit (no TSV required).
    if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
        $startPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
        $startPathValue = if ($startPath) { $startPath.Path } else { $Path }

        if (-not (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
            Write-InfoMessage "RoslynFixes module not available; skipping IDE0028 fixer in legacy mode."
            exit 0
        }

        Write-Step "Roslyn Fix Pass (Legacy Mode)"
        try {
            $roslynResult = Invoke-RoslynFormatFix -StartPath $startPathValue -Diagnostics @('IDE0028') -Severity 'info' -Include @($startPathValue)
            if ($roslynResult.Attempted) {
                if ($roslynResult.Applied) {
                    Write-SuccessMessage "IDE0028 fixes applied via dotnet format"
                } else {
                    Write-InfoMessage "Roslyn pass completed but did not report applied fixes (IDE0028)."
                }
            } else {
                Write-InfoMessage "Roslyn pass skipped (no single solution discovered under repo root)."
            }
        } catch {
            Write-ErrorMessage "Roslyn pass failed in legacy mode: $($_.Exception.Message)"
            exit 1
        }

        exit 0
    }

    # TSV mode: Validate inputs
    if (-not (Test-Path $RepoRoot)) {
        throw "Repository root not found: $RepoRoot"
    }

    $resolvedRepoRoot = Resolve-Path $RepoRoot
    Write-InfoMessage "Repository root: $resolvedRepoRoot"

    # Load and validate diagnostics
    Write-InfoMessage "Loading diagnostics from: $DiagnosticsTsvPath"
    $diagnostics = Get-DiagnosticsFromTsv -TsvPath $DiagnosticsTsvPath

    if ($diagnostics.Count -eq 0) {
        Write-InfoMessage "No IDE0028 diagnostics found in TSV"
        exit 0
    }

    # Group diagnostics by file and line
    $groupedDiagnostics = Group-Diagnostics -Diagnostics $diagnostics
    Write-InfoMessage "Grouped into $($groupedDiagnostics.Count) files with diagnostics"

    # Roslyn pre-pass (optional)
    # In report-only mode (-NoApplyChanges), skip Roslyn because dotnet format applies changes.
    if (-not $SkipRoslyn -and -not $NoApplyChanges -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        Write-Step "Roslyn Pre-Pass (Report-Only)"
        try {
            $roslynDiagnostics = @('IDE0028')
            $roslynResult = Invoke-RoslynFormatFix -StartPath $resolvedRepoRoot -Diagnostics $roslynDiagnostics -Severity 'info' -Include $Include

            if ($roslynResult.Attempted) {
                if ($roslynResult.Applied) {
                    Write-InfoMessage "Roslyn pre-pass applied fixes."
                } else {
                    Write-InfoMessage "Roslyn pre-pass completed but no fixes applied."
                }
            } else {
                Write-InfoMessage "Roslyn pre-pass skipped (no solution found)."
            }
        } catch {
            Write-InfoMessage "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with TSV-driven fixes."
        }
    } else {
        Write-InfoMessage "Roslyn pre-pass skipped (disabled or module not available)."
    }

    # Process files with diagnostics
    Write-Step "TSV-Driven Fixes"
    $allResults = @()
    $filesProcessed = 0
    $totalApplied = 0

    foreach ($filePath in $groupedDiagnostics.Keys) {
        # Apply include filters (file paths in TSV are absolute, check for src/ or tst/ in path)
        if ($Include -and $Include.Count -gt 0) {
            $matchesInclude = $false
            foreach ($pattern in $Include) {
                # Check if path contains \src\ or \tst\ (for absolute Windows paths)
                $normalizedPattern = $pattern -replace '/', '\\'
                if ($filePath -like "*\$normalizedPattern*") {
                    $matchesInclude = $true
                    break
                }
            }
            if (-not $matchesInclude) {
                Write-InfoMessage "Skipping $filePath (not in include patterns)"
                continue
            }
        }

        # Limit files if specified
        if ($MaxFiles -gt 0 -and $filesProcessed -ge $MaxFiles) {
            Write-InfoMessage "Reached MaxFiles limit ($MaxFiles)"
            break
        }

        $filesProcessed++
        # File paths in TSV are already absolute, use them directly
        $absoluteFilePath = $filePath

        if (-not (Test-Path $absoluteFilePath)) {
            Write-ErrorMessage "File not found: $absoluteFilePath"
            # Add error results for missing file
            foreach ($lineNumber in $groupedDiagnostics[$filePath].Keys) {
                $diagnostics = $groupedDiagnostics[$filePath][$lineNumber]
                $allResults += [pscustomobject]@{
                    File = $filePath
                    Line = $lineNumber
                    ExpectedCount = $diagnostics.Count
                    AppliedCount = 0
                    Status = 'missing-file'
                    Applied = ''
                    OriginalLine = ''
                    UpdatedLine = ''
                }
            }
            continue
        }

        Write-InfoMessage "Processing: $filePath ($($groupedDiagnostics[$filePath].Count) diagnostic lines)"
        $fileResults = Process-FileDiagnostics -FilePath $absoluteFilePath -LineDiagnostics $groupedDiagnostics[$filePath] -MaxLines $MaxLines
        $allResults += $fileResults

        # Apply changes if not in report-only mode
        if (-not $NoApplyChanges) {
            $changesToApply = $fileResults | Where-Object { $_.AppliedCount -gt 0 }

            if ($changesToApply.Count -gt 0) {
                # Read file content
                $content = Get-Content $absoluteFilePath -Raw
                $lines = $content -split "`n"

                # Apply changes in reverse line order to preserve line numbers
                foreach ($change in ($changesToApply | Sort-Object Line -Descending)) {
                    if ($change.Line -le $lines.Count) {
                        $lines[$change.Line - 1] = $change.UpdatedLine
                    }
                }

                # Write back to file
                $newContent = $lines -join "`n"
                $newContent | Set-Content $absoluteFilePath -NoNewline

                Write-SuccessMessage "Applied $($changesToApply.Count) fixes to $filePath"
                $totalApplied += $changesToApply.Count
            }
        }
    }

    # Write reports
    Write-Step "Generating Reports"
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
    $reportOutputDir = Join-Path $OutputDirectory $timestamp
    Write-Reports -Results $allResults -OutputDirectory $OutputDirectory -Timestamp $timestamp

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-ErrorMessage "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
            exit 2
        }

        $repoRootForRel = [string]$resolvedRepoRoot
        $instructionRecords = New-Object System.Collections.Generic.List[object]
        foreach ($r in @($allResults)) {
            $rawStatus = [string]$r.Status
            if ($rawStatus -eq 'fixed') { continue }

            $status = switch ($rawStatus) {
                'partial' { 'partial' }
                'skipped' { 'skipped' }
                'missing-file' { 'error' }
                'line-out-of-range' { 'error' }
                default { 'error' }
            }

            $reason = switch ($rawStatus) {
                'partial' { 'partially_fixed' }
                'skipped' { [string]$r.Applied }
                'missing-file' { 'missing-file' }
                'line-out-of-range' { 'line-out-of-range' }
                default { $rawStatus }
            }

            $filePath = [string]$r.File
            $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
                Convert-ToRepoRelativePath -RepoRoot $repoRootForRel -FullPath $filePath
            } else {
                $filePath
            }

            $lineNumber = if ([int]$r.Line -gt 0) { [int]$r.Line } else { 0 }
            $originalLine = [string]$r.OriginalLine
            $updatedLine = [string]$r.UpdatedLine
            $kind = if (-not [string]::IsNullOrWhiteSpace($updatedLine) -and $updatedLine -ne $originalLine) { 'replace' } else { 'unknown' }
            $notes = "ExpectedCount=$($r.ExpectedCount); AppliedCount=$($r.AppliedCount); Applied=$([string]$r.Applied)"

            $instructionRecords.Add(
                (New-AiFixInstructionRecord `
                    -Status $status `
                    -RuleId "ide0028" `
                    -RunId $timestamp `
                    -DiagnosticCode "IDE0028" `
                    -Reason $reason `
                    -RepoRoot $repoRootForRel `
                    -FilePath $filePath `
                    -RelativeFilePath $relative `
                    -Line $lineNumber `
                    -ContextStartLine $lineNumber `
                    -ContextEndLine $lineNumber `
                    -ContextBefore $originalLine `
                    -ContextAfter $updatedLine `
                    -TransformationKind $kind `
                    -TransformationBefore $originalLine `
                    -TransformationAfter $updatedLine `
                    -TransformationNotes $notes `
                    -DoNotAutoApply $true)
            ) | Out-Null
        }

        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($instructionRecords) `
            -OutputDirectory $reportOutputDir `
            -RuleId "ide0028" `
            -RunId $timestamp `
            -InputPath $DiagnosticsTsvPath `
            -MarkdownPath $AiInstructionsPath

        Write-InfoMessage "AI instructions TSV : $($artifact.TsvPath)"
        Write-InfoMessage "AI instructions JSON: $($artifact.JsonPath)"
        Write-InfoMessage "AI instructions MD  : $($artifact.MarkdownPath)"
    }

    # Summary
    Write-Step "Summary"
    Write-InfoMessage "Files processed: $filesProcessed"
    Write-InfoMessage "Total diagnostics: $($diagnostics.Count)"
    Write-InfoMessage "Results generated: $($allResults.Count)"

    $fixedCount = ($allResults | Where-Object { $_.Status -eq 'fixed' }).Count
    $skippedCount = ($allResults | Where-Object { $_.Status -eq 'skipped' }).Count
    $partialCount = ($allResults | Where-Object { $_.Status -eq 'partial' }).Count
    $errorCount = ($allResults | Where-Object { $_.Status -in @('missing-file', 'line-out-of-range') }).Count

    Write-InfoMessage "Fixed: $fixedCount"
    Write-InfoMessage "Skipped (unsafe): $skippedCount"
    Write-InfoMessage "Partial: $partialCount"
    Write-InfoMessage "Errors: $errorCount"

    if (-not $NoApplyChanges) {
        Write-InfoMessage "Changes applied: $totalApplied"
    } else {
        Write-InfoMessage "Report-only mode - no changes applied"
    }

    # Safe patterns implemented:
    # 1. empty-constructor: new List<T>() → []
    # 2. dictionary-initializer: { { key, value } } → { [key] = value }
    # 3. target-typed-new: List<T> x = new List<T>() → List<T> x = new()

    Write-Step "Safe Patterns Applied"
    Write-InfoMessage "1. empty-constructor: Converts 'new List<T>()' to '[]' for empty collections"
    Write-InfoMessage "2. dictionary-initializer: Converts '{ { ""key"", value } }' to '{ [""key""] = value }'"
    Write-InfoMessage "3. target-typed-new: Uses 'new()' when type can be inferred from variable declaration"

    Write-Step "Intentionally Skipped Patterns"
    Write-InfoMessage "- Complex multi-line initializers (require full AST analysis)"
    Write-InfoMessage "- Add() method calls to initializers (context-dependent)"
    Write-InfoMessage "- Nested collection initializers (risk of incorrect inference)"
    Write-InfoMessage "- Generic type parameter inference (beyond simple cases)"

    if ($fixedCount -gt 0) {
        Write-SuccessMessage "IDE0028 autofix completed successfully"
        exit 0
    } else {
        Write-InfoMessage "No safe fixes could be applied - diagnostics may require manual review"
        exit 0
    }

} catch {
    Write-ErrorMessage "Script execution failed: $_"
    exit 1
}


