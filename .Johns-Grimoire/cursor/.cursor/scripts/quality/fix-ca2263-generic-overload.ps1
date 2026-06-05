#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes CA2263: Using a generic overload is preferable to the 'System.Type' overload when the type is known.

.DESCRIPTION
    This script addresses CA2263 diagnostic violations by replacing System.Type overloads with generic overloads
    where the type is known at compile-time. Specifically targets FluentAssertions .Be(typeof(SomeType))
    patterns and converts them to .Be<SomeType>() for improved type safety and cleaner code.

.PARAMETER DiagnosticsTsvPath
    Path to the TSV file containing CA2263 diagnostics from code analysis.

.PARAMETER RepoRoot
    Root directory of the repository containing the files to fix.

.PARAMETER Include
    Optional array of file path patterns to include (e.g., "*.cs", "src/**", "test/**").

.PARAMETER OutputDirectory
    Directory where reports will be written. Defaults to .cursor/scripts/quality/out/

.PARAMETER MaxFiles
    Maximum number of files to process for testing.

.PARAMETER MaxLines
    Maximum number of lines to process per file for testing.

.PARAMETER NoApplyChanges
    When specified, reports what would be changed without applying changes.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for entries marked as skipped/error, so another AI can
    apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    # Report-only mode
    .\fix-ca2263-generic-overload.ps1 -DiagnosticsTsvPath "tickets\EPP-192-CODEQUALITY-07-CA2263-GENERIC-OVERLOAD\data\run1\diagnostics.CA2263.run1.tsv" -RepoRoot "E:\WPG\Git\E21\GitRepos\eneve.ebase.foundation" -NoApplyChanges

.EXAMPLE
    # Apply fixes
    .\fix-ca2263-generic-overload.ps1 -DiagnosticsTsvPath "tickets\EPP-192-CODEQUALITY-07-CA2263-GENERIC-OVERLOAD\data\run1\diagnostics.CA2263.run1.tsv" -RepoRoot "E:\WPG\Git\E21\GitRepos\eneve.ebase.foundation"

.NOTES
    Safe Patterns Implemented:
    1. .Be(typeof(SomeType)) → .Be<SomeType>()
    2. .NotBe(typeof(SomeType)) → .NotBe<SomeType>()

    Patterns Intentionally Skipped:
    - Complex expressions involving typeof() that aren't simple method calls
    - Cases where the type parameter cannot be safely extracted
    - Multi-line typeof expressions
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DiagnosticsTsvPath,

    [Parameter(Mandatory=$true)]
    [string]$RepoRoot,

    [Parameter(Mandatory=$false)]
    [string[]]$Include,

    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$false)]
    [int]$MaxFiles,

    [Parameter(Mandatory=$false)]
    [int]$MaxLines,

    [Parameter(Mandatory=$false)]
    [switch]$NoApplyChanges,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for skipped/error entries")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

# Set strict mode and error preference after param block
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

# Script configuration
$DiagnosticCode = "CA2263"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportBaseName = "fix-ca2263-generic-overload_$Timestamp"

# Set default output directory if not provided
if (-not $OutputDirectory) {
    $OutputDirectory = ".cursor/scripts/quality/out"
}

# Ensure output directory exists
$OutputDirectory = Join-Path $RepoRoot $OutputDirectory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Initialize counters and results
$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$filesProcessed = 0
$linesProcessed = 0

function Write-Progress-Report {
    param([string]$Message, [string]$Color = "White")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Write-Error-Report {
    param([string]$Message)

    Write-Progress-Report "ERROR: $Message" "Red"
}

function Write-Success-Report {
    param([string]$Message)

    Write-Progress-Report "SUCCESS: $Message" "Green"
}

function Test-File-Include {
    param([string]$FilePath)

    if (-not $Include -or $Include.Count -eq 0) {
        return $true
    }

    foreach ($pattern in $Include) {
        if ($FilePath -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-TypeFromTypeOf {
    param([string]$TypeOfExpression)

    # Extract type name from typeof(SomeType) or typeof(Some.Namespace.Type)
    if ($TypeOfExpression -match 'typeof\(([^)]+)\)') {
        return $matches[1].Trim()
    }

    return $null
}

function Convert-TypeOf-To-Generic {
    param([string]$Line, [int]$LineNumber, [string]$FilePath)

    $originalLine = $Line
    $appliedCount = 0
    $updatedLine = $Line

    # Pattern 1: .Be(typeof(SomeType), message) → .Be<SomeType>()
    $bePattern = '\.Be\(\s*typeof\(([^)]+)\)\s*,'
    if ($updatedLine -match $bePattern) {
        $typeName = $matches[1].Trim()
        if ($typeName) {
            # Replace the entire .Be(typeof(SomeType), message) with .Be<SomeType>()
            $oldPattern = "\.Be\(\s*typeof\($typeName\)\s*,[^)]+\)"
            $newPattern = ".Be<$typeName>()"
            $updatedLine = $updatedLine -replace $oldPattern, $newPattern
            $appliedCount++
            Write-Progress-Report "Applied pattern 1: typeof → generic overload" "Cyan"
        }
    }

    # Pattern 2: .NotBe(typeof(SomeType), message) → .NotBe<SomeType>()
    $notBePattern = '\.NotBe\(\s*typeof\(([^)]+)\)\s*,'
    if ($updatedLine -match $notBePattern) {
        $typeName = $matches[1].Trim()
        if ($typeName) {
            # Replace the entire .NotBe(typeof(SomeType), message) with .NotBe<SomeType>()
            $oldPattern = "\.NotBe\(\s*typeof\($typeName\)\s*,[^)]+\)"
            $newPattern = ".NotBe<$typeName>()"
            $updatedLine = $updatedLine -replace $oldPattern, $newPattern
            $appliedCount++
            Write-Progress-Report "Applied pattern 2: typeof → generic overload (NotBe)" "Cyan"
        }
    }

    return @{
        AppliedCount = $appliedCount
        OriginalLine = $originalLine
        UpdatedLine = $updatedLine
        Status = if ($appliedCount -gt 0) { "fixed" } else { "skipped" }
    }
}

function Process-File {
    param([string]$FilePath, [int[]]$DiagnosticLines)

    if (-not (Test-Path $FilePath)) {
        Write-Error-Report "File not found: $FilePath"
        $results.Add([PSCustomObject]@{
            File = $FilePath
            Line = 0
            ExpectedCount = $DiagnosticLines.Count
            AppliedCount = 0
            Status = "missing-file"
            Applied = ""
            OriginalLine = ""
            UpdatedLine = ""
        })
        return
    }

    if (-not (Test-File-Include -FilePath $FilePath)) {
        Write-Progress-Report "Skipping file (not in include patterns): $FilePath" "Yellow"
        return
    }

    Write-Progress-Report "Processing file: $FilePath" "White"

    # Read file content once
    $content = Get-Content $FilePath -Raw
    $lines = $content -replace "`r`n", "`n" -split "`n"

    # Group diagnostics by line number
    $lineGroups = $DiagnosticLines | Group-Object | Sort-Object Name

    $fileChanged = $false
    $updatedLines = $lines.Clone()

    foreach ($group in $lineGroups) {
        $lineNumber = [int]$group.Name
        $expectedCount = $group.Count

        if ($lineNumber -lt 1 -or $lineNumber -gt $lines.Count) {
            Write-Error-Report "Line $lineNumber out of range for file $FilePath"
            $results.Add([PSCustomObject]@{
                File = $FilePath
                Line = $lineNumber
                ExpectedCount = $expectedCount
                AppliedCount = 0
                Status = "line-out-of-range"
                Applied = ""
                OriginalLine = $lines[$lineNumber - 1] ?? ""
                UpdatedLine = ""
            })
            continue
        }

        $originalLine = $lines[$lineNumber - 1]
        Write-Progress-Report "Processing line $lineNumber ($expectedCount diagnostics)" "Gray"

        $conversionResult = Convert-TypeOf-To-Generic -Line $originalLine -LineNumber $lineNumber -FilePath $FilePath

        $results.Add([PSCustomObject]@{
            File = $FilePath
            Line = $lineNumber
            ExpectedCount = $expectedCount
            AppliedCount = $conversionResult.AppliedCount
            Status = $conversionResult.Status
            Applied = if ($conversionResult.AppliedCount -gt 0) { "generic-overload" } else { "" }
            OriginalLine = $conversionResult.OriginalLine
            UpdatedLine = $conversionResult.UpdatedLine
        })

        if ($conversionResult.AppliedCount -gt 0) {
            $updatedLines[$lineNumber - 1] = $conversionResult.UpdatedLine
            $fileChanged = $true
        }

        $script:linesProcessed++
        if ($script:MaxLines -and $script:linesProcessed -ge $script:MaxLines) {
            Write-Progress-Report "Reached MaxLines limit ($script:MaxLines)" "Yellow"
            break
        }
    }

    # Write file if changed and not in report-only mode
    if ($fileChanged -and -not $NoApplyChanges) {
        $updatedContent = $updatedLines -join "`n"
        $updatedContent | Set-Content $FilePath 
        Write-Success-Report "Updated file: $FilePath"
    }

    $script:filesProcessed++
    if ($script:MaxFiles -and $script:filesProcessed -ge $script:MaxFiles) {
        Write-Progress-Report "Reached MaxFiles limit ($script:MaxFiles)" "Yellow"
        break
    }
}

# Main execution
try {
    Write-Progress-Report "Starting CA2263 generic overload fixer" "White"
    Write-Progress-Report "Diagnostic Code: $DiagnosticCode" "White"
    Write-Progress-Report "TSV Path: $DiagnosticsTsvPath" "White"
    Write-Progress-Report "Repository Root: $RepoRoot" "White"
    Write-Progress-Report "Output Directory: $OutputDirectory" "White"
    Write-Progress-Report "Report-only Mode: $NoApplyChanges" "White"

    # Validate TSV file exists
    $fullTsvPath = Join-Path $RepoRoot $DiagnosticsTsvPath
    if (-not (Test-Path $fullTsvPath)) {
        throw "Diagnostics TSV file not found: $fullTsvPath"
    }

    # Parse TSV file
    Write-Progress-Report "Parsing diagnostics TSV..." "White"
    $diagnostics = Import-Csv -Path $fullTsvPath -Delimiter "`t"

    # Validate required columns
    $requiredColumns = @("Code", "File", "Line")
    foreach ($col in $requiredColumns) {
        if (-not ($diagnostics[0].PSObject.Properties.Name -contains $col)) {
            throw "Required column '$col' not found in TSV file. Available columns: $($diagnostics[0].PSObject.Properties.Name -join ', ')"
        }
    }

    # Filter to CA2263 diagnostics
    $ca2263Diagnostics = $diagnostics | Where-Object { $_.Code -eq $DiagnosticCode }

    if ($ca2263Diagnostics.Count -eq 0) {
        Write-Progress-Report "No CA2263 diagnostics found in TSV file" "Yellow"
        exit 0
    }

    Write-Progress-Report "Found $($ca2263Diagnostics.Count) CA2263 diagnostics" "White"

    # Group diagnostics by file
    $fileGroups = $ca2263Diagnostics | Group-Object -Property File

    # Process each file
    foreach ($fileGroup in $fileGroups) {
        $filePathFromTsv = $fileGroup.Name

        # Check if path is absolute (starts with drive letter like E:\)
        if ($filePathFromTsv -match '^[A-Za-z]:\\') {
            $fullFilePath = $filePathFromTsv
        } else {
            $fullFilePath = Join-Path $RepoRoot $filePathFromTsv
        }

        # Extract line numbers for this file
        $lineNumbers = @($fileGroup.Group | ForEach-Object {
            try {
                [int]$_.Line
            } catch {
                Write-Error-Report "Invalid line number '$($_.Line)' in file $filePathFromTsv"
                $null
            }
        } | Where-Object { $_ -ne $null })

        if ($lineNumbers.Count -gt 0) {
            Process-File -FilePath $fullFilePath -DiagnosticLines $lineNumbers
        }

        if ($script:MaxFiles -and $script:filesProcessed -ge $script:MaxFiles) {
            break
        }
    }

    # Generate reports
    Write-Progress-Report "Generating reports..." "White"

    # TSV Report
    $tsvReportPath = Join-Path $OutputDirectory "$ReportBaseName.tsv"
    $results | Export-Csv -Path $tsvReportPath -Delimiter "`t" -NoTypeInformation
    Write-Success-Report "TSV report written: $tsvReportPath"

    # JSON Report
    $jsonReportPath = Join-Path $OutputDirectory "$ReportBaseName.json"
    $results | ConvertTo-Json | Set-Content $jsonReportPath
    Write-Success-Report "JSON report written: $jsonReportPath"

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-Error-Report "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
            exit 2
        }

        $instructionRecords = New-Object System.Collections.Generic.List[object]
        foreach ($r in @($results)) {
            $rawStatus = [string]$r.Status
            if ($rawStatus -eq 'fixed') { continue }

            $status = switch ($rawStatus) {
                'skipped' { 'skipped' }
                'missing-file' { 'error' }
                'line-out-of-range' { 'error' }
                default { 'error' }
            }

            $reason = switch ($rawStatus) {
                'skipped' { 'no_safe_pattern_matched' }
                'missing-file' { 'missing-file' }
                'line-out-of-range' { 'line-out-of-range' }
                default { $rawStatus }
            }

            $filePath = [string]$r.File
            $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
                Convert-ToRepoRelativePath -RepoRoot $RepoRoot -FullPath $filePath
            } else {
                $filePath
            }

            $lineNumber = if ([int]$r.Line -gt 0) { [int]$r.Line } else { 0 }
            $originalLine = [string]$r.OriginalLine
            $updatedLine = [string]$r.UpdatedLine
            $kind = if (-not [string]::IsNullOrWhiteSpace($updatedLine) -and $updatedLine -ne $originalLine) { 'replace' } else { 'unknown' }
            $notes = "ExpectedCount=$($r.ExpectedCount); AppliedCount=$($r.AppliedCount)"

            $instructionRecords.Add(
                (New-AiFixInstructionRecord `
                    -Status $status `
                    -RuleId "ca2263" `
                    -RunId $Timestamp `
                    -DiagnosticCode "CA2263" `
                    -Reason $reason `
                    -RepoRoot $RepoRoot `
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
            -OutputDirectory $OutputDirectory `
            -RuleId "ca2263" `
            -RunId $Timestamp `
            -InputPath $fullTsvPath `
            -MarkdownPath $AiInstructionsPath

        Write-Success-Report "AI instructions TSV: $($artifact.TsvPath)"
        Write-Success-Report "AI instructions JSON: $($artifact.JsonPath)"
        Write-Success-Report "AI instructions MD: $($artifact.MarkdownPath)"
    }

    # Summary
    $validResults = @($results | Where-Object { $_.Status -ne "missing-file" })
    $uniqueFiles = @($validResults | Select-Object -Property File -Unique)
    $totalFiles = $uniqueFiles.Count
    $totalFixed = @($results | Where-Object { $_.Status -eq "fixed" }).Count
    $totalSkipped = @($results | Where-Object { $_.Status -eq "skipped" }).Count
    $totalErrors = @($results | Where-Object { $_.Status -notin @("fixed", "skipped", "missing-file") }).Count

    Write-Progress-Report "Processing complete!" "Green"
    Write-Progress-Report "Summary:" "White"
    Write-Progress-Report "  Files processed: $totalFiles" "White"
    Write-Progress-Report "  Diagnostics fixed: $totalFixed" "Green"
    Write-Progress-Report "  Diagnostics skipped: $totalSkipped" "Yellow"
    Write-Progress-Report "  Errors: $totalErrors" $(if ($totalErrors -gt 0) { "Red" } else { "White" })

    # Safe patterns summary
    Write-Progress-Report "Safe patterns implemented:" "Cyan"
    Write-Progress-Report "  1. .Be(typeof(SomeType)) → .Be<SomeType>()" "Gray"
    Write-Progress-Report "  2. .NotBe(typeof(SomeType)) → .NotBe<SomeType>()" "Gray"

    Write-Progress-Report "Patterns intentionally skipped:" "Cyan"
    Write-Progress-Report "  - Complex expressions with typeof() that aren't simple method calls" "Gray"
    Write-Progress-Report "  - Cases where type parameter cannot be safely extracted" "Gray"
    Write-Progress-Report "  - Multi-line typeof expressions" "Gray"

    exit 0

} catch {
    Write-Error-Report "Script execution failed: $($_.Exception.Message)"
    Write-Error-Report "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

