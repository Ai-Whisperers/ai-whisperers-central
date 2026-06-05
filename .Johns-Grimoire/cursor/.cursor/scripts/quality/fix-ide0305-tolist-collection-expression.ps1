#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE0305 suggestions by rewriting eligible `.ToList()` materializations to C# collection expressions.

.DESCRIPTION
    Converts common IDE0305 "Collection initialization can be simplified" patterns such as:

        entityData["MeterPictogram"] = meterPictograms.ToList();

    into:

        entityData["MeterPictogram"] = [..meterPictograms];

    This script is intentionally conservative:
      - Only rewrites single-line assignments where the right-hand side ends with `.ToList()`.
      - Skips `var x = y.ToList();` declarations because `var x = [..y];` may not infer the same type.
      - Does not attempt to rewrite multi-line expressions or argument/return contexts.

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory (and optionally subdirectories) are processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER DiagnosticsFile
    Optional path to a text file containing analyzer output (for example, a Visual Studio Error List copy/paste).
    When provided, the script will only process C# files mentioned in the report (and matching -DiagnosticCode).

.PARAMETER DiagnosticCode
    Diagnostic code to filter from DiagnosticsFile (default: IDE0305).

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for cases the script intentionally skips due to
    conservative guardrails (e.g., non-target-typed `var` assignments), so another AI can apply safe, deterministic edits
    with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0305-tolist-collection-expression.ps1 -Path "src/MyFile.cs" -WhatIf
    Show what would be changed without applying any changes.

.EXAMPLE
    .\fix-ide0305-tolist-collection-expression.ps1 -Path "src/" -Recurse
    Fix eligible IDE0305 patterns in all C# files under src/.

.NOTES
    File Name      : fix-ide0305-tolist-collection-expression.ps1
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes IDE0305 (collection initialization can be simplified)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to C# file or directory to process")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Recurse into subdirectories when Path is a directory")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "Optional diagnostics report file to restrict processing to reported files")]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsFile,

    [Parameter(Mandatory = $false, HelpMessage = "Diagnostic code to filter within DiagnosticsFile (default: IDE0305)")]
    [ValidatePattern('^[A-Z]{2,10}\d{1,6}$')]
    [string]$DiagnosticCode = 'IDE0305',

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the heuristic fixer")]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for intentionally skipped cases")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

$ErrorActionPreference = 'Stop'

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

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

function Get-CSharpFiles {
    param([string]$TargetPath, [bool]$RecurseDirectories)

    if (Test-Path $TargetPath -PathType Leaf) {
        if ($TargetPath -like "*.cs") { return @($TargetPath) }
        Write-Failure "Specified file is not a C# file: $TargetPath"
        return @()
    }

    if (Test-Path $TargetPath -PathType Container) {
        $searchOptions = @{
            Path   = $TargetPath
            Filter = "*.cs"
            File   = $true
        }
        if ($RecurseDirectories) { $searchOptions.Recurse = $true }
        return Get-ChildItem @searchOptions | Select-Object -ExpandProperty FullName
    }

    Write-Failure "Path does not exist: $TargetPath"
    return @()
}

function Get-DiagnosticsReportedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ReportFilePath,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Z]{2,10}\d{1,6}$')]
        [string]$Code
    )

    if (-not (Test-Path $ReportFilePath -PathType Leaf)) {
        Write-Failure "DiagnosticsFile not found: $ReportFilePath"
        return @()
    }

    $text = Get-Content $ReportFilePath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }

    $escapedCode = [regex]::Escape($Code)
    $pattern = "(?m)\b$escapedCode\b.*?(?<file>[A-Za-z]:\\[^\r\n]+?\.cs)\s+(?<line>\d+)\b"
    $matches = [regex]::Matches($text, $pattern)
    if ($matches.Count -eq 0) { return @() }

    $files = @()
    foreach ($m in $matches) {
        $filePath = $m.Groups['file'].Value
        if (-not [string]::IsNullOrWhiteSpace($filePath)) {
            $files += $filePath
        }
    }

    return ($files | Sort-Object -Unique)
}

function Convert-Ide0305Content {
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [object]$AiInstructionRecords,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$RunId
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return [pscustomobject]@{ Content = $Content; Changes = 0 }
    }

    $changeMarkers = New-Object System.Collections.Generic.List[object]

    function Get-LineNumberAtIndex {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Index
        )

        if ($Index -le 0) { return 1 }
        if ($Index -ge $Text.Length) { $Index = $Text.Length - 1 }

        return ([regex]::Matches($Text.Substring(0, $Index), "`n").Count + 1)
    }

    function Get-LineAtIndex {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Index
        )

        $lineStart = $Text.LastIndexOf("`n", [Math]::Max(0, $Index - 1))
        if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }

        $lineEnd = $Text.IndexOf("`n", $Index)
        if ($lineEnd -lt 0) { $lineEnd = $Text.Length }

        return $Text.Substring($lineStart, $lineEnd - $lineStart).TrimEnd("`r")
    }

    function Try-AddAiSkipRecord {
        param(
            [Parameter(Mandatory)]
            [string]$Reason,

            [Parameter(Mandatory)]
            [int]$Index,

            [Parameter(Mandatory)]
            [string]$ContextLine
        )

        if (-not $AiInstructionRecords) { return }
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) { return }

        $repoRootForRel = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { (Get-Location).Path } else { $RepoRoot }
        $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
            Convert-ToRepoRelativePath -RepoRoot $repoRootForRel -FullPath $FilePath
        } else {
            $FilePath
        }

        $line = Get-LineNumberAtIndex -Text $Content -Index $Index

        $AiInstructionRecords.Add(
            (New-AiFixInstructionRecord `
                -Status 'skipped' `
                -RuleId 'ide0305' `
                -RunId $RunId `
                -DiagnosticCode 'IDE0305' `
                -Reason $Reason `
                -RepoRoot $repoRootForRel `
                -FilePath $FilePath `
                -RelativeFilePath $relative `
                -Line $line `
                -ContextStartLine $line `
                -ContextEndLine $line `
                -ContextBefore $ContextLine `
                -ContextAfter '' `
                -TransformationKind 'unknown' `
                -TransformationBefore '' `
                -TransformationAfter '' `
                -TransformationNotes 'Guardrail skip: non-target-typed context (e.g., var assignment) may not infer the intended type with [..expr].' `
                -DoNotAutoApply $true)
        ) | Out-Null
    }

    # Single-line assignment where RHS ends with .ToList()
    # Example: entityData["MeterPictogram"] = meterPictograms.ToList();
    $pattern = '(?m)^(?<indent>\s*)(?<lhs>[^=\r\n;]+?)\s*=\s*(?<expr>[^;\r\n]+?)\.ToList\s*\(\s*\)\s*;\s*$'

    $updated = [regex]::Replace($Content, $pattern, {
        param($m)

        $lhs = ($m.Groups['lhs'].Value).Trim()
        if ($lhs -match '^\bvar\b\s+[@\w]+\s*$') {
            Try-AddAiSkipRecord -Reason 'skipped-var-assignment' -Index $m.Index -ContextLine (Get-LineAtIndex -Text $Content -Index $m.Index)
            return $m.Value
        }

        $expr = ($m.Groups['expr'].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($expr)) { return $m.Value }

        [void]$changeMarkers.Add($true)
        return "$($m.Groups['indent'].Value)$lhs = [..$expr];"
    })

    return [pscustomobject]@{ Content = $updated; Changes = $changeMarkers.Count }
}

function Invoke-Ide0305FixOnFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [object]$AiInstructionRecords,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$RunId
    )

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) { return $false }

        $result = Convert-Ide0305Content `
            -Content $content `
            -FilePath $FilePath `
            -AiInstructionRecords $AiInstructionRecords `
            -RepoRoot $RepoRoot `
            -RunId $RunId
        if ($result.Changes -le 0) { return $false }

        if ($PSCmdlet.ShouldProcess($FilePath, "Rewrite $($result.Changes) IDE0305 ToList() materialization(s) to collection expressions")) {
            $result.Content | Set-Content $FilePath -NoNewline -ErrorAction Stop
        }

        Write-Success "Rewrote $($result.Changes) IDE0305 ToList() materialization(s) in $FilePath"
        return $true
    } catch {
        Write-Failure "Error processing $FilePath : $_"
        return $false
    }
}

try {
    Write-Step "IDE0305 ToList() Collection Expression Fixer"
    Write-InfoMessage "Rewrites eligible '<expr>.ToList()' assignment patterns to '[..<expr>]'"

    $runId = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
    $repoRootForRel = (Get-Location).Path
    $aiInstructionRecords = $null
    $aiInstructionsOutputDir = $null

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-Failure "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
            exit 2
        }

        $aiInstructionRecords = New-Object System.Collections.Generic.List[object]
        $aiInstructionsOutputDir = Join-Path (Join-Path $PSScriptRoot 'out') $runId
    }

    if (-not $SkipRoslyn -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        try {
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (IDE0305)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('IDE0305') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (IDE0305)."
                    } else {
                        Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (IDE0305). Continuing with heuristic fixer."
                    }
                } else {
                    Write-InfoMessage "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with heuristic fixer."
                }
            }
        } catch {
            Write-InfoMessage "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with heuristic fixer."
        }
    }

    $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories $Recurse
    if ($files.Count -eq 0) {
        Write-Failure "No C# files found to process"
        exit 1
    }

    if (-not [string]::IsNullOrWhiteSpace($DiagnosticsFile)) {
        $reportedFiles = Get-DiagnosticsReportedFiles -ReportFilePath $DiagnosticsFile -Code $DiagnosticCode
        if ($reportedFiles.Count -eq 0) {
            Write-Failure "No files found in DiagnosticsFile for diagnostic '$DiagnosticCode'"
            exit 1
        }

        $reportedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($rf in $reportedFiles) { [void]$reportedSet.Add($rf) }

        $files = $files | Where-Object { $reportedSet.Contains($_) }
    }

    if ($files.Count -eq 0) {
        Write-Failure "No C# files found to process"
        exit 1
    }

    Write-InfoMessage "Found $($files.Count) C# file(s) to process"

    $filesProcessed = 0
    $filesChanged = 0
    foreach ($file in $files) {
        $filesProcessed++
        if (Invoke-Ide0305FixOnFile -FilePath $file -AiInstructionRecords $aiInstructionRecords -RepoRoot $repoRootForRel -RunId $runId) { $filesChanged++ }
    }

    if ($EmitAiInstructions) {
        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($aiInstructionRecords) `
            -OutputDirectory $aiInstructionsOutputDir `
            -RuleId "ide0305" `
            -RunId $runId `
            -InputPath $Path `
            -MarkdownPath $AiInstructionsPath

        Write-InfoMessage "AI instructions TSV : $($artifact.TsvPath)"
        Write-InfoMessage "AI instructions JSON: $($artifact.JsonPath)"
        Write-InfoMessage "AI instructions MD  : $($artifact.MarkdownPath)"
    }

    Write-Step "Summary"
    Write-InfoMessage "Processed: $filesProcessed file(s)"
    Write-InfoMessage "Changed: $filesChanged file(s)"

    if ($filesChanged -gt 0) {
        Write-Success "IDE0305 fixes completed successfully"
        exit 0
    }

    Write-InfoMessage "No eligible IDE0305 ToList() assignment patterns found - files are already simplified or require manual review"
    exit 0
} catch {
    Write-Failure "Script execution failed: $_"
    exit 1
}



