#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    IDE0090 Auto-Fixer: Simplify 'new' expression using Roslyn-first approach

.DESCRIPTION
    Applies a Roslyn-first, fallback-to-heuristic approach for IDE0090 "'new' expression can be simplified".

    First attempts Roslyn fixes via `dotnet format --diagnostics IDE0090`. If Roslyn doesn't apply
    all fixes or fails, falls back to a conservative TSV-driven heuristic fixer that applies
    safe, deterministic transformations.

    Roslyn-first ensures compiler-verified changes. Heuristic fallback handles cases Roslyn misses
    while maintaining safety through conservative pattern matching.

.PARAMETER DiagnosticsTsvPath
    Path to the diagnostics TSV export containing IDE0090 diagnostics

.PARAMETER RepoRoot
    Repository root directory

.PARAMETER Include
    Optional file or directory path(s) to restrict processing

.PARAMETER OutputDirectory
    Directory where reports will be written (default: .cursor/scripts/quality/out/)

.PARAMETER MaxFiles
    Maximum number of files to process (for step-by-step runs)

.PARAMETER MaxLines
    Maximum number of lines to process per file (for step-by-step runs)

.PARAMETER NoApplyChanges
    Report-only mode - generates reports but doesn't modify files

.PARAMETER SkipRoslyn
    Skip Roslyn (dotnet format) pre-pass and run only the heuristic TSV-driven fixer

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for entries marked as skipped/partial/error, so another AI can
    apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0090-simplify-new-expression.ps1 -DiagnosticsTsvPath "data/run1/diagnostics.IDE0090.run1.tsv" -RepoRoot "E:\repos\eneve.ebase.foundation"

.EXAMPLE
    .\fix-ide0090-simplify-new-expression.ps1 -DiagnosticsTsvPath "data/run1/diagnostics.IDE0090.run1.tsv" -RepoRoot "E:\repos\eneve.ebase.foundation" -NoApplyChanges -MaxFiles 5
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$DiagnosticsTsvPath,

    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$Include,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "$PSScriptRoot/out",

    [Parameter(Mandatory = $false)]
    [int]$MaxFiles,

    [Parameter(Mandatory = $false)]
    [int]$MaxLines,

    [Parameter(Mandatory = $false)]
    [switch]$NoApplyChanges,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for skipped/partial/error entries")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import shared modules
$commonModulePath = Join-Path $PSScriptRoot "modules\Common.psm1"
if (Test-Path $commonModulePath) {
    Import-Module $commonModulePath -Force
}

$roslynModulePath = Join-Path $PSScriptRoot "modules\RoslynFixes.psm1"
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

# Roslyn-first approach: Attempt Roslyn fixes first
if (-not $SkipRoslyn -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
    try {
        Write-Host "🔧 Attempting Roslyn-based fixes via dotnet format (IDE0090)..." -ForegroundColor Cyan

        if ($PSCmdlet.ShouldProcess($RepoRoot, "Run Roslyn-based fixes via dotnet format (IDE0090)")) {
            $roslynResult = Invoke-RoslynFormatFix -StartPath $RepoRoot -Diagnostics @('IDE0090') -Severity 'info' -Include $Include

            if ($roslynResult.Attempted) {
                if ($roslynResult.Applied) {
                    Write-Host "✅ Roslyn pre-pass applied fixes successfully (IDE0090)." -ForegroundColor Green
                } else {
                    Write-Host "ℹ️  Roslyn pre-pass ran but did not apply fixes (IDE0090). Continuing with heuristic fixer." -ForegroundColor Yellow
                }
            } else {
                Write-Host "⚠️  Roslyn pre-pass could not run (missing solution file or dotnet). Continuing with heuristic fixer." -ForegroundColor Yellow
            }
        } else {
            Write-Host "🔍 Would run Roslyn fixes (IDE0090) [WhatIf mode]" -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠️  Roslyn pre-pass failed: $($_.Exception.Message). Continuing with heuristic fixer." -ForegroundColor Yellow
    }
} elseif ($SkipRoslyn) {
    Write-Host "⏭️  Skipping Roslyn pre-pass as requested. Running heuristic fixer only." -ForegroundColor Cyan
} else {
    Write-Host "ℹ️  Roslyn module not available. Running heuristic fixer only." -ForegroundColor Cyan
}

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Timestamp for reports
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$reportBaseName = "fix-ide0090-simplify-new-expression-$timestamp"

# Report paths
$tsvReportPath = Join-Path $OutputDirectory "$reportBaseName.tsv"
$jsonReportPath = Join-Path $OutputDirectory "$reportBaseName.json"

# Load and validate TSV
Write-Host "🔍 Loading diagnostics from: $DiagnosticsTsvPath" -ForegroundColor Cyan
if (-not (Test-Path $DiagnosticsTsvPath)) {
    Write-Error "Diagnostics TSV file not found: $DiagnosticsTsvPath"
    exit 1
}

$diagnostics = Import-Csv -Path $DiagnosticsTsvPath -Delimiter "`t"

# Validate required columns
$requiredColumns = @('Code', 'File', 'Line')
foreach ($col in $requiredColumns) {
    if (-not $diagnostics[0].PSObject.Properties.Name.Contains($col)) {
        Write-Error "Required column '$col' not found in TSV"
        exit 1
    }
}

# Filter to IDE0090 diagnostics only
$ide0090Diagnostics = $diagnostics | Where-Object { $_.Code -eq 'IDE0090' }
Write-Host "📊 Found $($ide0090Diagnostics.Count) IDE0090 diagnostics" -ForegroundColor Cyan

if ($ide0090Diagnostics.Count -eq 0) {
    Write-Host "ℹ️  No IDE0090 diagnostics found" -ForegroundColor Yellow
    exit 0
}

# Group by file and line (handle duplicates)
$groupedDiagnostics = $ide0090Diagnostics | Group-Object -Property File, Line | ForEach-Object {
    $file = $_.Group[0].File
    $line = [int]$_.Group[0].Line
    $expectedCount = $_.Group.Count

    # Handle absolute vs relative paths
    if ([System.IO.Path]::IsPathRooted($file)) {
        $fullPath = $file
    } else {
        $fullPath = Join-Path $RepoRoot $file
    }

    [PSCustomObject]@{
        File = $file
        Line = $line
        ExpectedCount = $expectedCount
        FullPath = $fullPath
    }
}

# Apply include filters if specified
if ($Include) {
    $groupedDiagnostics = $groupedDiagnostics | Where-Object {
        $includeMatch = $false
        foreach ($filter in $Include) {
            if ($_.File -like $filter -or $_.FullPath -like $filter) {
                $includeMatch = $true
                break
            }
        }
        $includeMatch
    }
}

# Apply MaxFiles limit
if ($MaxFiles -and $groupedDiagnostics.Count -gt $MaxFiles) {
    $groupedDiagnostics = $groupedDiagnostics | Select-Object -First $MaxFiles
    Write-Host "📁 Limited to first $MaxFiles files" -ForegroundColor Yellow
}

#
# Note: $groupedDiagnostics is grouped by (File, Line). We then group again by FullPath so we only
# read/write each file once per run. This avoids repeated writes (and reduces file-lock errors on Windows).
#
$fileGroups = $groupedDiagnostics | Group-Object -Property FullPath

Write-Host "📁 Processing $($fileGroups.Count) files" -ForegroundColor Cyan

# Results collection
$results = @()

# Process each file once
foreach ($fileGroup in $fileGroups) {
    $fullPath = $fileGroup.Name
    $fileItems = $fileGroup.Group | Sort-Object Line

    $file = $fileItems[0].File

    Write-Host "  • Processing: $file" -ForegroundColor Gray

    if (-not (Test-Path $fullPath)) {
        foreach ($diag in $fileItems) {
            $results += [PSCustomObject]@{
                File = $diag.File
                Line = $diag.Line
                ExpectedCount = $diag.ExpectedCount
                AppliedCount = 0
                Status = "missing-file"
                Applied = ""
                OriginalLine = ""
                UpdatedLine = ""
            }
        }
        continue
    }

    try {
        # Read file content once
        $lines = Get-Content -Path $fullPath
        $content = Get-Content -Path $fullPath -Raw

        $lineEnding = if ($content -match '\r\n') { "`r`n" } else { "`n" }
        $hadChanges = $false

        foreach ($diag in $fileItems) {
            $line = $diag.Line
            $expectedCount = $diag.ExpectedCount

            Write-Host "    • Line $line" -ForegroundColor DarkGray

            if ($line -gt $lines.Count) {
                $results += [PSCustomObject]@{
                    File = $diag.File
                    Line = $line
                    ExpectedCount = $expectedCount
                    AppliedCount = 0
                    Status = "line-out-of-range"
                    Applied = ""
                    OriginalLine = ""
                    UpdatedLine = ""
                }
                continue
            }

            $targetLine = $lines[$line - 1]
            $originalLine = $targetLine

            # Apply MaxLines limit if specified
            if ($MaxLines -and $line -gt $MaxLines) {
                $results += [PSCustomObject]@{
                    File = $diag.File
                    Line = $line
                    ExpectedCount = $expectedCount
                    AppliedCount = 0
                    Status = "skipped"
                    Applied = "max-lines-limit"
                    OriginalLine = $originalLine
                    UpdatedLine = $originalLine
                }
                continue
            }

            $updatedLine = $targetLine
            $appliedPatterns = @()
            $appliedCount = 0

            # Pattern 1: Variable declaration with new Type()
            if ($targetLine -match '^\s*([A-Za-z_][A-Za-z0-9_.<>]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*new\s+\1\s*\(\s*\)\s*;') {
                $typeName = $matches[1]
                $updatedLine = $targetLine -replace "new\s+$typeName\s*\(\s*\)", 'new()'
                $appliedPatterns += "var-decl-new-type()"
                $appliedCount++
            }
            # Pattern 1b: Variable declaration with constructor args (target-typed new)
            elseif ($targetLine -match '^\s*([A-Za-z_][A-Za-z0-9_.<>]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*new\s+\1\s*\(') {
                $typeName = $matches[1]
                $updatedLine = $targetLine -replace "new\s+$typeName\s*\(", 'new('
                $appliedPatterns += "var-decl-new-type(args)"
                $appliedCount++
            }
            # Pattern 2: Target-typed new in collection initializer
            elseif ($targetLine -match '\[([^\]]+)\]\s*=\s*new\s+([A-Za-z_][A-Za-z0-9_.]+)') {
                $typeName = $matches[2]
                if ($typeName -notmatch '[<>]' -and $typeName -notmatch '\.') {
                    $updatedLine = $targetLine -replace "new\s+$typeName", 'new()'
                    $appliedPatterns += "collection-init-new-type"
                    $appliedCount++
                }
                else {
                    $appliedPatterns += "skipped-complex-type"
                }
            }
            # Pattern 3: Generic/qualified type instantiation (target-typed new)
            elseif ($targetLine -match '([A-Za-z_][A-Za-z0-9_.<>]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*new\s+\1(\s*\(\s*\)|\s*\(|\s*\{)') {
                $typeName = $matches[1]
                $suffix = $matches[3]

                if ($suffix -match '^\s*\(\s*\)$') {
                    $updatedLine = $targetLine -replace "new\s+$typeName\s*\(\s*\)", 'new()'
                    $appliedPatterns += "generic-var-decl-new-type()"
                    $appliedCount++
                } elseif ($suffix -match '^\s*\(') {
                    $updatedLine = $targetLine -replace "new\s+$typeName\s*\(", 'new('
                    $appliedPatterns += "generic-var-decl-new-type(args)"
                    $appliedCount++
                } elseif ($suffix -match '^\s*\{') {
                    $updatedLine = $targetLine -replace "new\s+$typeName", 'new()'
                    $appliedPatterns += "generic-var-decl-new-type{}"
                    $appliedCount++
                } else {
                    $appliedPatterns += "skipped-unsupported-suffix"
                }
            }
            else {
                $appliedPatterns += "skipped-unrecognized-pattern"
            }

            $status = if ($appliedCount -eq $expectedCount) {
                "fixed"
            } elseif ($appliedCount -gt 0) {
                "partial"
            } else {
                "skipped"
            }

            if (-not $NoApplyChanges -and $updatedLine -ne $originalLine) {
                $lines[$line - 1] = $updatedLine
                $hadChanges = $true
            }

            $results += [PSCustomObject]@{
                File = $diag.File
                Line = $line
                ExpectedCount = $expectedCount
                AppliedCount = $appliedCount
                Status = $status
                Applied = $appliedPatterns -join ";"
                OriginalLine = $originalLine
                UpdatedLine = $updatedLine
            }
        }

        if ($hadChanges -and -not $NoApplyChanges) {
            $newContent = $lines -join $lineEnding
            if ($content.EndsWith($lineEnding)) {
                $newContent += $lineEnding
            }

            Set-Content -Path $fullPath -Value $newContent -NoNewline -Encoding UTF8
            Write-Host "    💾 File updated" -ForegroundColor Green
        }
    } catch {
        Write-Host "    ❌ Error processing file: $($_.Exception.Message)" -ForegroundColor Red
        foreach ($diag in $fileItems) {
            $results += [PSCustomObject]@{
                File = $diag.File
                Line = $diag.Line
                ExpectedCount = $diag.ExpectedCount
                AppliedCount = 0
                Status = "error"
                Applied = "file-processing-error"
                OriginalLine = ""
                UpdatedLine = ""
            }
        }
    }
}

# Generate reports
Write-Host "`n📊 Generating reports..." -ForegroundColor Cyan

# TSV Report
$results | Export-Csv -Path $tsvReportPath -Delimiter "`t" -NoTypeInformation -Encoding UTF8
Write-Host "  ✓ TSV report: $tsvReportPath" -ForegroundColor Green

# JSON Report
$results | ConvertTo-Json | Out-File -FilePath $jsonReportPath -Encoding UTF8
Write-Host "  ✓ JSON report: $jsonReportPath" -ForegroundColor Green

if ($EmitAiInstructions) {
    if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
        Write-Error "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
        exit 2
    }

    $instructionRecords = New-Object System.Collections.Generic.List[object]
    foreach ($r in @($results)) {
        $rawStatus = [string]$r.Status
        if ($rawStatus -eq 'fixed') { continue }

        $status = switch ($rawStatus) {
            'partial' { 'partial' }
            'skipped' { 'skipped' }
            'error' { 'error' }
            'missing-file' { 'error' }
            'line-out-of-range' { 'error' }
            default { 'error' }
        }

        $reason = switch ($rawStatus) {
            'partial' { 'partially_fixed' }
            'skipped' { 'no_safe_pattern_matched' }
            'error' { 'file-processing-error' }
            'missing-file' { 'missing-file' }
            'line-out-of-range' { 'line-out-of-range' }
            default { $rawStatus }
        }

        $filePath = Join-Path $RepoRoot ([string]$r.File)
        $relative = [string]$r.File
        $originalLine = [string]$r.OriginalLine
        $updatedLine = [string]$r.UpdatedLine

        $kind = if (-not [string]::IsNullOrWhiteSpace($updatedLine) -and $updatedLine -ne $originalLine) { 'replace' } else { 'unknown' }
        $notes = "ExpectedCount=$($r.ExpectedCount); AppliedCount=$($r.AppliedCount); AppliedPatterns=$([string]$r.Applied)"

        $instructionRecords.Add(
            (New-AiFixInstructionRecord `
                -Status $status `
                -RuleId "ide0090" `
                -RunId $timestamp `
                -DiagnosticCode "IDE0090" `
                -Reason $reason `
                -RepoRoot $RepoRoot `
                -FilePath $filePath `
                -RelativeFilePath $relative `
                -Line ([int]$r.Line) `
                -ContextStartLine ([int]$r.Line) `
                -ContextEndLine ([int]$r.Line) `
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
        -OutputDirectory $OutputDirectory `
        -RuleId "ide0090" `
        -RunId $timestamp `
        -InputPath $DiagnosticsTsvPath `
        -MarkdownPath $AiInstructionsPath

    Write-Host "  ✓ AI instructions TSV : $($artifact.TsvPath)" -ForegroundColor Green
    Write-Host "  ✓ AI instructions JSON: $($artifact.JsonPath)" -ForegroundColor Green
    Write-Host "  ✓ AI instructions MD  : $($artifact.MarkdownPath)" -ForegroundColor Green
}

# Summary
if ($results -and $results.Count -gt 0) {
    try {
        $fixed = @($results | Where-Object { $_.Status -eq "fixed" }).Count
        $partial = @($results | Where-Object { $_.Status -eq "partial" }).Count
        $skipped = @($results | Where-Object { $_.Status -eq "skipped" }).Count
        $errors = @($results | Where-Object { $_.Status -eq "error" -or $_.Status -eq "missing-file" -or $_.Status -eq "line-out-of-range" }).Count

        Write-Host "`n📈 Summary:" -ForegroundColor Cyan
        Write-Host "  Fixed: $fixed" -ForegroundColor Green
        Write-Host "  Partial: $partial" -ForegroundColor Yellow
        Write-Host "  Skipped: $skipped" -ForegroundColor Gray
        Write-Host "  Errors: $errors" -ForegroundColor Red

        $totalApplied = ($results | Measure-Object -Property AppliedCount -Sum).Sum
        Write-Host "  Total transformations applied: $totalApplied" -ForegroundColor Cyan
    } catch {
        Write-Host "`n⚠️  Error calculating summary: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Results count: $($results.Count)" -ForegroundColor Gray
    }
} else {
    Write-Host "`n📈 Summary: No results to summarize" -ForegroundColor Yellow
}

if ($NoApplyChanges) {
    Write-Host "`n🔍 Report-only mode - no files were modified" -ForegroundColor Yellow
} else {
    Write-Host "`n✅ Processing complete" -ForegroundColor Green
}

Write-Host "`n📁 Reports available at:" -ForegroundColor Cyan
Write-Host "  TSV: $tsvReportPath" -ForegroundColor White
Write-Host "  JSON: $jsonReportPath" -ForegroundColor White
