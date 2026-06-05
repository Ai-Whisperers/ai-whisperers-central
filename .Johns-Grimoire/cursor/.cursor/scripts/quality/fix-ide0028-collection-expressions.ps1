#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE0028 suggestions by converting eligible collection initializers to C# collection expressions.

.DESCRIPTION
    Converts common IDE0028 "Collection initialization can be simplified" patterns to C# 12 collection expressions:

      - new List<T>()               -> []
      - new Dictionary<K, V>()      -> []
      - new HashSet<T>()            -> []
      - new List<T> { a, b, c }     -> [a, b, c]

    This script is intentionally conservative:
      - Skips simple 'var x = new List<T>();' declarations (because 'var x = []' may not compile).
      - Handles property assignments in object initializers (e.g., 'ResolutionPriority = new List<string>()').

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory (and optionally subdirectories) are processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for cases the script intentionally skips due to
    conservative guardrails (e.g., non-target-typed `var` assignments), so another AI can apply safe, deterministic edits
    with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0028-collection-expressions.ps1 -Path "tst/MyTests.cs" -WhatIf
    Show what would be changed without applying any changes.

.EXAMPLE
    .\fix-ide0028-collection-expressions.ps1 -Path "tst/" -Recurse
    Fix eligible IDE0028 patterns in all C# files under tst/.

.NOTES
    File Name      : fix-ide0028-collection-expressions.ps1
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes IDE0028 (collection initialization can be simplified)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to C# file or directory to process")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Recurse into subdirectories when Path is a directory")]
    [switch]$Recurse,

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

function Find-MatchingBraceIndex {
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        [Parameter(Mandatory)]
        [int]$OpenBraceIndex
    )

    if ($OpenBraceIndex -lt 0 -or $OpenBraceIndex -ge $Text.Length -or $Text[$OpenBraceIndex] -ne '{') {
        return -1
    }

    $depth = 0
    $inLineComment = $false
    $inBlockComment = $false
    $inString = $false
    $inChar = $false
    $inVerbatimString = $false

    for ($i = $OpenBraceIndex; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

        if ($inLineComment) {
            if ($c -eq "`n") { $inLineComment = $false }
            continue
        }

        if ($inBlockComment) {
            if ($c -eq '*' -and $next -eq '/') { $inBlockComment = $false; $i++; continue }
            continue
        }

        if ($inChar) {
            if ($c -eq '\' -and $next -ne [char]0) { $i++; continue }
            if ($c -eq "'") { $inChar = $false }
            continue
        }

        if ($inVerbatimString) {
            if ($c -eq '"') {
                if ($next -eq '"') { $i++; continue }
                $inVerbatimString = $false
            }
            continue
        }

        if ($inString) {
            if ($c -eq '\' -and $next -ne [char]0) { $i++; continue }
            if ($c -eq '"') { $inString = $false }
            continue
        }

        if ($c -eq '/' -and $next -eq '/') { $inLineComment = $true; $i++; continue }
        if ($c -eq '/' -and $next -eq '*') { $inBlockComment = $true; $i++; continue }
        if ($c -eq '@' -and $next -eq '"') { $inVerbatimString = $true; $i++; continue }
        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq "'") { $inChar = $true; continue }

        if ($c -eq '{') { $depth++; continue }
        if ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }

    return -1
}

function Is-VarDeclarationBeforeIndex {
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        [Parameter(Mandatory)]
        [int]$Index
    )

    $lineStart = $Text.LastIndexOf("`n", [Math]::Max(0, $Index - 1))
    if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }
    $prefix = $Text.Substring($lineStart, $Index - $lineStart)
    return ($prefix -match '\bvar\s+[@\w]+\s*=\s*$')
}

function Fix-Ide0028InContent {
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

    $replacements = New-Object System.Collections.Generic.List[object]

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
                -RuleId 'ide0028' `
                -RunId $RunId `
                -DiagnosticCode 'IDE0028' `
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
                -TransformationNotes 'Guardrail skip: non-target-typed context (e.g., var assignment) may not compile with [].' `
                -DoNotAutoApply $true)
        ) | Out-Null
    }

    function Add-Replacement {
        param([int]$StartIndex, [int]$Length, [string]$NewValue)
        $replacements.Add([pscustomobject]@{
            StartIndex = $StartIndex
            Length     = $Length
            NewValue   = $NewValue
        })
    }

    function Test-Overlaps {
        param([int]$StartIndex, [int]$Length)
        $end = $StartIndex + $Length
        foreach ($r in $replacements) {
            $rStart = [int]$r.StartIndex
            $rEnd = $rStart + [int]$r.Length
            if ($StartIndex -lt $rEnd -and $end -gt $rStart) { return $true }
        }
        return $false
    }

    # 1) Empty constructors: new List<T>() / new Dictionary<K,V>() / new HashSet<T>() -> []
    $emptyCtorPattern = 'new\s+(?<kind>List|Dictionary|HashSet)\s*<[^>]+>\s*\(\s*\)'
    $emptyMatches = [regex]::Matches($Content, $emptyCtorPattern)
    foreach ($m in $emptyMatches) {
        if (Is-VarDeclarationBeforeIndex -Text $Content -Index $m.Index) {
            Try-AddAiSkipRecord -Reason 'skipped-var-assignment' -Index $m.Index -ContextLine (Get-LineAtIndex -Text $Content -Index $m.Index)
            continue
        }
        if (Test-Overlaps -StartIndex $m.Index -Length $m.Length) { continue }
        Add-Replacement -StartIndex $m.Index -Length $m.Length -NewValue '[]'
    }

    # 2) List collection initializer: new List<T> { ... } -> [ ... ]
    $listInitPattern = 'new\s+List\s*<[^>]+>\s*\{'
    $listMatches = [regex]::Matches($Content, $listInitPattern)
    foreach ($m in $listMatches) {
        if (Is-VarDeclarationBeforeIndex -Text $Content -Index $m.Index) {
            Try-AddAiSkipRecord -Reason 'skipped-var-assignment' -Index $m.Index -ContextLine (Get-LineAtIndex -Text $Content -Index $m.Index)
            continue
        }
        $openBraceIndex = $m.Index + $m.Length - 1
        $closeBraceIndex = Find-MatchingBraceIndex -Text $Content -OpenBraceIndex $openBraceIndex
        if ($closeBraceIndex -lt 0) { continue }

        $innerRaw = $Content.Substring($openBraceIndex + 1, $closeBraceIndex - $openBraceIndex - 1)
        $inner = if ($innerRaw -match "[\r\n]") { $innerRaw } else { $innerRaw.Trim() }

        $oldExpr = $Content.Substring($m.Index, $closeBraceIndex - $m.Index + 1)
        if (Test-Overlaps -StartIndex $m.Index -Length $oldExpr.Length) { continue }

        Add-Replacement -StartIndex $m.Index -Length $oldExpr.Length -NewValue ('[' + $inner + ']')
    }

    if ($replacements.Count -eq 0) {
        return [pscustomobject]@{ Content = $Content; Changes = 0 }
    }

    $ordered = $replacements | Sort-Object StartIndex -Descending
    $updated = $Content
    $changes = 0
    foreach ($r in $ordered) {
        $before = $updated.Substring(0, $r.StartIndex)
        $after = $updated.Substring($r.StartIndex + $r.Length)
        $updated = $before + $r.NewValue + $after
        $changes++
    }

    return [pscustomobject]@{ Content = $updated; Changes = $changes }
}

function Fix-Ide0028File {
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

        $result = Fix-Ide0028InContent `
            -Content $content `
            -FilePath $FilePath `
            -AiInstructionRecords $AiInstructionRecords `
            -RepoRoot $RepoRoot `
            -RunId $RunId
        if ($result.Changes -le 0) { return $false }

        if ($PSCmdlet.ShouldProcess($FilePath, "Rewrite $($result.Changes) IDE0028 collection initialization(s) to collection expressions")) {
            $result.Content | Set-Content $FilePath -NoNewline -ErrorAction Stop
        }

        Write-Success "Rewrote $($result.Changes) IDE0028 collection initialization(s) in $FilePath"
        return $true
    } catch {
        Write-Failure "Error processing $FilePath : $_"
        return $false
    }
}

try {
    Write-Step "IDE0028 Collection Expression Fixer"
    Write-InfoMessage "Converts eligible 'new List<T>()', 'new Dictionary<K,V>()', 'new HashSet<T>()', and 'new List<T> { ... }' to '[ ... ]'"

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
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (IDE0028)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('IDE0028') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (IDE0028)."
                    } else {
                        Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (IDE0028). Continuing with heuristic fixer."
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

    Write-InfoMessage "Found $($files.Count) C# file(s) to process"

    $filesProcessed = 0
    $filesChanged = 0
    foreach ($file in $files) {
        $filesProcessed++
        if (Fix-Ide0028File -FilePath $file -AiInstructionRecords $aiInstructionRecords -RepoRoot $repoRootForRel -RunId $runId) { $filesChanged++ }
    }

    if ($EmitAiInstructions) {
        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($aiInstructionRecords) `
            -OutputDirectory $aiInstructionsOutputDir `
            -RuleId "ide0028" `
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
        Write-Success "IDE0028 collection expression fixes completed successfully"
        exit 0
    }

    Write-InfoMessage "No eligible IDE0028 patterns found - files are already simplified or require manual review"
    exit 0
} catch {
    Write-Failure "Script execution failed: $_"
    exit 1
}



