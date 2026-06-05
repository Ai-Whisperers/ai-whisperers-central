#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Applies a conservative mass-fix for IDE0009 ("Add 'this' qualification") using exported diagnostics TSV data.

.DESCRIPTION
    This script reads an analyzer diagnostics TSV export (tab-separated, with columns including File and Line),
    groups IDE0009 occurrences by file and line, and applies targeted, line-stable edits by inserting `this.`
    in safe, matchable patterns.

    The script is intentionally conservative:
    - It only performs transformations that can be validated from the line text itself.
    - It avoids touching code inside string literals and line comments.
    - If a line cannot be fixed confidently, it is left unchanged and recorded as "skipped" in the report.

    This is designed as a first-pass mass fixer. Remaining cases should be handled with Roslyn-based tooling
    or manual review.

.PARAMETER DiagnosticsTsvPath
    Path to the diagnostics TSV export file (tab-separated). Expected columns include:
    Severity, Code, Description, Project, File, Line, Suppression State.

.PARAMETER RepoRoot
    Repository root directory. Used to resolve relative paths and determine default output locations.
    Defaults to current directory (and will walk up to find a git root if Common.psm1 is available).

.PARAMETER Include
    Optional file or directory path(s) to restrict processing. When provided, only diagnostic entries whose
    File path is under an Include path are processed.

.PARAMETER OutputDirectory
    Directory to write reports into. Defaults to: .cursor/scripts/quality/out (under RepoRoot).

.PARAMETER MaxFiles
    Maximum number of distinct files to process (useful for step-by-step runs). Default: 0 (no limit).

.PARAMETER MaxLines
    Maximum number of distinct (File, Line) entries to process (useful for step-by-step runs). Default: 0 (no limit).

.PARAMETER Passes
    Number of passes over each file's targeted lines. Some lines may become fixable after earlier edits on the same line.
    Default: 1.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for entries marked as skipped/partial/error, so another AI can
    apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0009-this-qualification.ps1 -DiagnosticsTsvPath "tickets/EPP-192/.../diagnostics.IDE0009.run1.tsv" -WhatIf
    Show what would be changed without writing files.

.EXAMPLE
    .\fix-ide0009-this-qualification.ps1 -DiagnosticsTsvPath ".\diagnostics.IDE0009.tsv" -MaxFiles 5
    Apply fixes for the first 5 files, writing reports to .cursor/scripts/quality/out/.

.EXAMPLE
    .\fix-ide0009-this-qualification.ps1 -DiagnosticsTsvPath ".\diagnostics.IDE0009.tsv" -Include "src/Infrastructure/Calendars"
    Restrict processing to diagnostics under a specific folder.

.NOTES
    File Name      : fix-ide0009-this-qualification.ps1
    Prerequisite   : PowerShell 7.2+, file write permissions
    Fixes          : IDE0009 ('this' qualification)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the diagnostics TSV export file")]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsTsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Repository root path for resolving relative paths and default outputs")]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false, HelpMessage = "Optional file/folder paths to restrict processing")]
    [ValidateNotNullOrEmpty()]
    [string[]]$Include,

    [Parameter(Mandatory = $false, HelpMessage = "Directory to write reports into (default: .cursor/scripts/quality/out under RepoRoot)")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false, HelpMessage = "Max distinct files to process (0 = no limit)")]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MaxFiles = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Max distinct (File,Line) entries to process (0 = no limit)")]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MaxLines = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Number of passes per file (default: 1)")]
    [ValidateRange(1, 5)]
    [int]$Passes = 1,

    [Parameter(Mandatory = $false, HelpMessage = "Do not write changes to C# files (reports are still produced)")]
    [switch]$NoApplyChanges,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the TSV-driven fixer")]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Allow heuristic TSV-driven fallback edits (NOT recommended; can produce invalid qualifications like this.string or this.targetUnit)")]
    [switch]$AllowHeuristicFallback,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for skipped/partial/error entries")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Write-Die {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 1
    )

    if (Get-Command -Name Write-ErrorMessage -ErrorAction SilentlyContinue) {
        Write-ErrorMessage -Message $Message
    } else {
        Write-Host "❌ $Message" -ForegroundColor Red
    }
    exit $ExitCode
}

function Resolve-RepoRoot {
    param([Parameter(Mandatory)][string]$StartPath)

    if (Get-Command -Name Get-RepoRoot -ErrorAction SilentlyContinue) {
        return Get-RepoRoot -StartPath $StartPath
    }

    $resolved = Resolve-Path -Path $StartPath -ErrorAction SilentlyContinue
    if ($resolved) { return $resolved.Path }
    return $StartPath
}

function Resolve-PathRelativeToRoot {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if (Split-Path -IsAbsolute $Path) {
        $rp = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
        if ($rp) { return $rp.Path }
        return $Path
    }

    $candidate = Join-Path $Root $Path
    $rp2 = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
    if ($rp2) { return $rp2.Path }
    return $candidate
}

function Resolve-IncludePaths {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory = $false)][string[]]$IncludePaths
    )

    if (-not $IncludePaths -or $IncludePaths.Count -eq 0) {
        return @()
    }

    $resolved = @()
    foreach ($p in $IncludePaths) {
        $candidate = $p
        if (-not (Split-Path -IsAbsolute $candidate)) {
            $candidate = Join-Path $Root $candidate
        }

        $rp = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
        if (-not $rp) {
            Write-Die "Include path does not exist: $p" 4
        }
        $resolved += $rp.Path
    }

    return @($resolved | Sort-Object -Unique)
}

function New-OutputDirectory {
    param([Parameter(Mandatory)][string]$Dir)
    if (-not (Test-Path $Dir -PathType Container)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    }
}

function Read-DiagnosticsTsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath
    )

    if (-not (Test-Path $FilePath -PathType Leaf)) {
        Write-Die "Diagnostics TSV not found: $FilePath" 2
    }

    $raw = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    # ConvertFrom-Csv supports a custom delimiter and quoted fields.
    $rows = $raw | ConvertFrom-Csv -Delimiter "`t"

    $required = @('Code', 'File', 'Line')
    foreach ($col in $required) {
        if (-not ($rows | Get-Member -Name $col -MemberType NoteProperty, Property -ErrorAction SilentlyContinue)) {
            Write-Die "Diagnostics TSV is missing required column '$col'. Expected a tab-separated export with headers including: $($required -join ', ')." 2
        }
    }

    return @($rows)
}

function Split-LineAndComment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    $inString = $false
    $inChar = $false
    $inVerbatimString = $false
    $escape = $false

    for ($i = 0; $i -lt $Line.Length - 1; $i++) {
        $c = $Line[$i]
        $next = $Line[$i + 1]

        if ($inChar) {
            if ($escape) { $escape = $false; continue }
            if ($c -eq '\') { $escape = $true; continue }
            if ($c -eq "'") { $inChar = $false; continue }
            continue
        }

        if ($inVerbatimString) {
            if ($c -eq '"' -and $next -eq '"') { $i++; continue }
            if ($c -eq '"') { $inVerbatimString = $false; continue }
            continue
        }

        if ($inString) {
            if ($escape) { $escape = $false; continue }
            if ($c -eq '\') { $escape = $true; continue }
            if ($c -eq '"') { $inString = $false; continue }
            continue
        }

        if ($c -eq '@' -and $next -eq '"') { $inVerbatimString = $true; $i++; continue }
        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq "'") { $inChar = $true; continue }

        if ($c -eq '/' -and $next -eq '/') {
            return [pscustomobject]@{
                CodePart    = $Line.Substring(0, $i)
                CommentPart = $Line.Substring($i)
            }
        }
    }

    return [pscustomobject]@{
        CodePart    = $Line
        CommentPart = ''
    }
}

function Split-TextIntoLines {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $newline = if ($Text -match "`r`n") { "`r`n" } else { "`n" }
    $hasTrailingNewline = $false

    if ($Text.Length -ge $newline.Length -and $Text.EndsWith($newline)) {
        $hasTrailingNewline = $true
    }

    # Use a non-regex split to avoid subtle -split max-substring behavior differences.
    # Normalize to '\n' for splitting but preserve original newline choice for re-join.
    $normalized = $Text.Replace("`r`n", "`n")
    $lines = $normalized.Split("`n", [System.StringSplitOptions]::None)

    return [pscustomobject]@{
        Lines               = $lines
        NewLine             = $newline
        HasTrailingNewLine  = $hasTrailingNewline
    }
}

function Join-LinesToText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,
        [Parameter(Mandatory)][string]$NewLine,
        [Parameter(Mandatory)][bool]$HasTrailingNewLine
    )

    $text = ($Lines -join $NewLine)
    if ($HasTrailingNewLine -and -not $text.EndsWith($NewLine)) {
        $text += $NewLine
    }
    return $text
}

function Try-AddThisToAssignmentLhs {
    param(
        [Parameter(Mandatory)][string]$CodePart,
        [Parameter(Mandatory)][int]$Remaining
    )

    if ($Remaining -le 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    # LHS assignment in a statement:  <indent><id><ws><op><ws>...
    $pattern = '^(?<indent>\s*)(?<id>[_a-z][A-Za-z0-9_]*)(?<ws1>\s*)(?<op>(?:<<|>>)?=|\+=|-=|\*=|/=|%=|&=|\|=|\^=)(?<ws2>\s*)'
    $m = [regex]::Match($CodePart, $pattern)
    if (-not $m.Success) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $id = $m.Groups['id'].Value
    if ($id -eq 'this') {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $updated = [regex]::Replace($CodePart, $pattern, {
        param($rm)
        return "$($rm.Groups['indent'].Value)this.$($rm.Groups['id'].Value)$($rm.Groups['ws1'].Value)$($rm.Groups['op'].Value)$($rm.Groups['ws2'].Value)"
    })

    if ($updated -eq $CodePart) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    return [pscustomobject]@{ Updated = $updated; Applied = @($id) }
}

function Try-AddThisToReceivers {
    param(
        [Parameter(Mandatory)][string]$CodePart,
        [Parameter(Mandatory)][int]$Remaining
    )

    if ($Remaining -le 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $applied = New-Object System.Collections.Generic.List[string]
    $updated = $CodePart

    $pattern = '(?<!\bthis\.)\b(?<id>[_a-z][A-Za-z0-9_]*)\b(?=\s*\.)'
    $matches = [regex]::Matches($updated, $pattern)
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $remainingLocal = $Remaining
    foreach ($m in @($matches | Sort-Object { $_.Index } -Descending)) {
        if ($remainingLocal -le 0) { break }

        $id = $m.Groups['id'].Value
        if ($id -eq 'this') { continue }

        $start = $m.Index
        $len = $m.Length
        $updated = $updated.Substring(0, $start) + "this.$id" + $updated.Substring($start + $len)
        [void]$applied.Add($id)
        $remainingLocal--
    }

    return [pscustomobject]@{ Updated = $updated; Applied = @($applied) }
}

function Try-AddThisToAddDbConnectionArgs {
    param(
        [Parameter(Mandatory)][string]$CodePart,
        [Parameter(Mandatory)][int]$Remaining
    )

    if ($Remaining -le 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    # If this line calls AddDbConnection(...), qualify simple identifier args.
    # Example:
    #   dapper.AddDbConnection(connection, transaction)
    $pattern = '(?<call>\bAddDbConnection\s*\()\s*(?<args>[^)]*)(?<close>\))'
    $m = [regex]::Match($CodePart, $pattern)
    if (-not $m.Success) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $args = $m.Groups['args'].Value
    $updatedArgs = $args
    $applied = New-Object System.Collections.Generic.List[string]

    $remainingLocal = $Remaining

    # Only qualify the common repository base members we can confidently match from text-only data.
    $safeArgNames = @('connection', 'transaction', 'dapper')

    foreach ($name in $safeArgNames) {
        if ($remainingLocal -le 0) { break }
        # The args group excludes the closing ')', so qualify identifier tokens delimited by start/end or commas.
        $escapedName = [regex]::Escape($name)
        $argPattern = "(?<sep>^|,)(?<ws>\\s*)\\b$escapedName\\b(?=\\s*(,|$))"

        $matches = [regex]::Matches($updatedArgs, $argPattern)
        if ($matches.Count -le 0) { continue }

        foreach ($mm in @($matches | Sort-Object { $_.Index } -Descending)) {
            if ($remainingLocal -le 0) { break }

            $idStart = $mm.Index + $mm.Groups['sep'].Length + $mm.Groups['ws'].Length
            $updatedArgs = $updatedArgs.Substring(0, $idStart) + "this.$name" + $updatedArgs.Substring($idStart + $name.Length)

            [void]$applied.Add($name)
            $remainingLocal--
        }
    }

    if ($updatedArgs -eq $args) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $updated = $CodePart.Substring(0, $m.Groups['args'].Index) + $updatedArgs + $CodePart.Substring($m.Groups['args'].Index + $m.Groups['args'].Length)
    return [pscustomobject]@{ Updated = $updated; Applied = @($applied) }
}

function Try-AddThisToKnownBareIdentifiers {
    param(
        [Parameter(Mandatory)][string]$CodePart,
        [Parameter(Mandatory)][int]$Remaining
    )

    if ($Remaining -le 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    # Fallback: qualify common repository base member identifiers even when not in AddDbConnection args.
    $known = @('connection', 'transaction')
    $pattern = '(?<!\.)' + '(?<!\bthis\.)' + '\b(?<id>connection|transaction)\b'

    $matches = [regex]::Matches($CodePart, $pattern)
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    $updated = $CodePart
    $applied = New-Object System.Collections.Generic.List[string]
    $remainingLocal = $Remaining

    foreach ($m in @($matches | Sort-Object { $_.Index } -Descending)) {
        if ($remainingLocal -le 0) { break }

        $id = $m.Groups['id'].Value
        if ($known -notcontains $id) { continue }

        $start = $m.Index
        $len = $m.Length
        $updated = $updated.Substring(0, $start) + "this.$id" + $updated.Substring($start + $len)
        [void]$applied.Add($id)
        $remainingLocal--
    }

    if ($updated -eq $CodePart) {
        return [pscustomobject]@{ Updated = $CodePart; Applied = @() }
    }

    return [pscustomobject]@{ Updated = $updated; Applied = @($applied) }
}

function Fix-Ide0009Line {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory)][int]$ExpectedCount,
        [Parameter(Mandatory)][int]$PassCount
    )

    $original = $Line
    $split = Split-LineAndComment -Line $Line
    $codePart = $split.CodePart
    $commentPart = $split.CommentPart

    $applied = New-Object System.Collections.Generic.List[string]
    $updatedCode = $codePart

    for ($pass = 1; $pass -le $PassCount; $pass++) {
        $remaining = $ExpectedCount - $applied.Count
        if ($remaining -le 0) { break }

        $r1 = Try-AddThisToAssignmentLhs -CodePart $updatedCode -Remaining $remaining
        $updatedCode = $r1.Updated
        foreach ($x in @($r1.Applied)) { [void]$applied.Add($x) }

        $remaining = $ExpectedCount - $applied.Count
        if ($remaining -le 0) { break }

        $r2 = Try-AddThisToReceivers -CodePart $updatedCode -Remaining $remaining
        $updatedCode = $r2.Updated
        foreach ($x in @($r2.Applied)) { [void]$applied.Add($x) }

        $remaining = $ExpectedCount - $applied.Count
        if ($remaining -le 0) { break }

        $r3 = Try-AddThisToAddDbConnectionArgs -CodePart $updatedCode -Remaining $remaining
        $updatedCode = $r3.Updated
        foreach ($x in @($r3.Applied)) { [void]$applied.Add($x) }

        $remaining = $ExpectedCount - $applied.Count
        if ($remaining -le 0) { break }

        $r4 = Try-AddThisToKnownBareIdentifiers -CodePart $updatedCode -Remaining $remaining
        $updatedCode = $r4.Updated
        foreach ($x in @($r4.Applied)) { [void]$applied.Add($x) }
    }

    $updatedLine = $updatedCode + $commentPart

    $status = 'skipped'
    if ($updatedLine -ne $original) {
        $status = if ($applied.Count -ge $ExpectedCount) { 'fixed' } else { 'partial' }
    } else {
        $status = 'skipped'
    }

    return [pscustomobject]@{
        OriginalLine   = $original
        UpdatedLine    = $updatedLine
        ExpectedCount  = $ExpectedCount
        AppliedCount   = $applied.Count
        Applied        = @($applied)
        Status         = $status
    }
}

try {
    if (Get-Command -Name Write-Section -ErrorAction SilentlyContinue) {
        Write-Section -Title "IDE0009 This Qualification Fixer (Conservative)"
    } else {
        Write-Host "`n=== IDE0009 This Qualification Fixer (Conservative) ===`n" -ForegroundColor Cyan
    }

    $repoRoot = Resolve-RepoRoot -StartPath $RepoRoot
    if (-not (Test-Path $repoRoot -PathType Container)) {
        Write-Die "RepoRoot does not exist or is not a directory: $RepoRoot" 2
    }

    $diagnosticsPath = Resolve-PathRelativeToRoot -Root $repoRoot -Path $DiagnosticsTsvPath
    $includeResolved = @(Resolve-IncludePaths -Root $repoRoot -IncludePaths $Include)

    $roslynResult = $null
    if (-not $SkipRoslyn -and -not $NoApplyChanges -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        try {
            if ($PSCmdlet.ShouldProcess($repoRoot, "Run Roslyn-based fixes via dotnet format (IDE0009)")) {
                $roslynInclude = if (@($includeResolved).Count -gt 0) { @($includeResolved) } else { @() }
                $roslynResult = Invoke-RoslynFormatFix -StartPath $repoRoot -RepoRoot $repoRoot -Diagnostics @('IDE0009') -Severity 'info' -Include $roslynInclude
            }
        } catch {
            Write-InfoMessage -Message "Roslyn pre-pass failed: $($_.Exception.Message)."
        }
    }

    if (-not $AllowHeuristicFallback) {
        if ($roslynResult -and $roslynResult.Attempted -and $roslynResult.Applied) {
            Write-InfoMessage -Message "Roslyn fixes applied (IDE0009) via dotnet format. Heuristic TSV fallback is disabled; exiting."
            exit 0
        }

        if ($roslynResult -and $roslynResult.Attempted -and -not $roslynResult.Applied) {
            Write-Die "Roslyn fixer ran but did not apply IDE0009 fixes. Heuristic fallback is disabled. Re-run with -AllowHeuristicFallback only if you accept potentially unsafe edits." 2
        }

        Write-Die "Roslyn fixer unavailable or failed. Heuristic TSV fallback is disabled because it can produce invalid code (e.g., this.string, this.targetUnit). Fix Roslyn execution or re-run with -AllowHeuristicFallback if you accept the risk." 2
    }

    $outDir = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Join-Path $repoRoot ".cursor/scripts/quality/out"
    } else {
        Resolve-PathRelativeToRoot -Root $repoRoot -Path $OutputDirectory
    }
    New-OutputDirectory -Dir $outDir

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportTsvPath = Join-Path $outDir "ide0009-fix-report.$timestamp.tsv"
    $reportJsonPath = Join-Path $outDir "ide0009-fix-report.$timestamp.json"

    if (Get-Command -Name Write-InfoMessage -ErrorAction SilentlyContinue) {
        Write-InfoMessage -Message "RepoRoot          : $repoRoot"
        Write-InfoMessage -Message "Diagnostics TSV   : $diagnosticsPath"
        if (@($includeResolved).Count -gt 0) { Write-InfoMessage -Message ("Include          : " + (@($includeResolved) -join "; ")) }
        Write-InfoMessage -Message "OutputDirectory   : $outDir"
        Write-InfoMessage -Message "Report TSV        : $reportTsvPath"
        Write-InfoMessage -Message "Report JSON       : $reportJsonPath"
    } else {
        Write-Host "RepoRoot        : $repoRoot" -ForegroundColor Gray
        Write-Host "Diagnostics TSV : $diagnosticsPath" -ForegroundColor Gray
        if (@($includeResolved).Count -gt 0) { Write-Host ("Include        : " + (@($includeResolved) -join "; ")) -ForegroundColor Gray }
        Write-Host "OutputDirectory : $outDir" -ForegroundColor Gray
        Write-Host "Report TSV      : $reportTsvPath" -ForegroundColor Gray
        Write-Host "Report JSON     : $reportJsonPath" -ForegroundColor Gray
    }

    $rows = @(Read-DiagnosticsTsv -FilePath $diagnosticsPath)
    if ($rows.Count -eq 0) {
        Write-Die "Diagnostics TSV contains no rows." 2
    }

    $ide0009 = @($rows | Where-Object { $_.Code -eq 'IDE0009' })
    if ($ide0009.Count -eq 0) {
        Write-Die "No IDE0009 entries found in diagnostics TSV." 2
    }

    # Normalize file paths and filter by Include (if provided).
    $normalized = foreach ($r in $ide0009) {
        $filePath = [string]$r.File
        $lineText = [string]$r.Line
        $lineNumber = 0
        [void][int]::TryParse($lineText, [ref]$lineNumber)

        if ([string]::IsNullOrWhiteSpace($filePath) -or $lineNumber -le 0) {
            continue
        }

        if (@($includeResolved).Count -gt 0) {
            $included = $false
            foreach ($inc in $includeResolved) {
                if ($filePath.StartsWith($inc, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $included = $true
                    break
                }
            }
            if (-not $included) { continue }
        }

        [pscustomobject]@{
            File = $filePath
            Line = $lineNumber
        }
    }

    if ($normalized.Count -eq 0) {
        Write-Die "After filtering, there are no IDE0009 entries to process." 2
    }

    $byFile = $normalized | Group-Object File | Sort-Object Name
    if ($MaxFiles -gt 0 -and $byFile.Count -gt $MaxFiles) {
        $byFile = $byFile | Select-Object -First $MaxFiles
    }

    $reportRows = New-Object System.Collections.Generic.List[object]
    $filesWithEdits = 0
    $filesWritten = 0
    $filesProcessed = 0
    $lineEntriesProcessed = 0

    foreach ($fileGroup in $byFile) {
        $filePath = $fileGroup.Name
        $filesProcessed++

        if (-not (Test-Path $filePath -PathType Leaf)) {
            foreach ($entry in $fileGroup.Group) {
                [void]$reportRows.Add([pscustomobject]@{
                    File          = $filePath
                    Line          = $entry.Line
                    ExpectedCount = 1
                    AppliedCount  = 0
                    Status        = 'missing-file'
                    Applied       = ''
                    OriginalLine  = ''
                    UpdatedLine   = ''
                })
            }
            continue
        }

        $content = Get-Content -LiteralPath $filePath -Raw -ErrorAction Stop
        $split = Split-TextIntoLines -Text $content
        $lines = [string[]]$split.Lines

        $lineGroups = $fileGroup.Group | Group-Object Line | Sort-Object { [int]$_.Name } -Descending
        foreach ($lg in $lineGroups) {
            if ($MaxLines -gt 0 -and $lineEntriesProcessed -ge $MaxLines) { break }
            $lineEntriesProcessed++

            $lineNumber = [int]$lg.Name
            $expectedCount = $lg.Count

            $idx = $lineNumber - 1
            if ($idx -lt 0 -or $idx -ge $lines.Length) {
                [void]$reportRows.Add([pscustomobject]@{
                    File          = $filePath
                    Line          = $lineNumber
                    ExpectedCount = $expectedCount
                    AppliedCount  = 0
                    Status        = 'line-out-of-range'
                    Applied       = ''
                    OriginalLine  = ''
                    UpdatedLine   = ''
                })
                continue
            }

            $result = Fix-Ide0009Line -Line $lines[$idx] -ExpectedCount $expectedCount -PassCount $Passes

            if ($result.UpdatedLine -ne $result.OriginalLine) {
                $lines[$idx] = $result.UpdatedLine
            }

            [void]$reportRows.Add([pscustomobject]@{
                File          = $filePath
                Line          = $lineNumber
                ExpectedCount = $expectedCount
                AppliedCount  = $result.AppliedCount
                Status        = $result.Status
                Applied       = ($result.Applied -join ';')
                OriginalLine  = $result.OriginalLine
                UpdatedLine   = $result.UpdatedLine
            })
        }

        if ($MaxLines -gt 0 -and $lineEntriesProcessed -ge $MaxLines) {
            # Still write out report below; stop processing additional files/lines.
        }

        $updatedContent = Join-LinesToText -Lines $lines -NewLine $split.NewLine -HasTrailingNewLine $split.HasTrailingNewLine
        if ($updatedContent -ne $content) {
            $filesWithEdits++

            if (-not $NoApplyChanges) {
                if ($PSCmdlet.ShouldProcess($filePath, "Apply IDE0009 'this.' qualification fixes")) {
                    $updatedContent | Set-Content -LiteralPath $filePath -ErrorAction Stop
                    $filesWritten++
                }
            }
        }

        if ($MaxLines -gt 0 -and $lineEntriesProcessed -ge $MaxLines) { break }
    }

    # Write reports
    $reportRowsArray = @($reportRows.ToArray())
    $reportRowsArray | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportJsonPath  -ErrorAction Stop

    # TSV: write explicit header and tab-separated values.
    $tsvHeader = @('File', 'Line', 'ExpectedCount', 'AppliedCount', 'Status', 'Applied', 'OriginalLine', 'UpdatedLine') -join "`t"
    $tsvLines = New-Object System.Collections.Generic.List[string]
    [void]$tsvLines.Add($tsvHeader)
    foreach ($r in $reportRowsArray) {
        $fields = @(
            [string]$r.File,
            [string]$r.Line,
            [string]$r.ExpectedCount,
            [string]$r.AppliedCount,
            [string]$r.Status,
            [string]$r.Applied,
            ([string]$r.OriginalLine).Replace("`t", '    '),
            ([string]$r.UpdatedLine).Replace("`t", '    ')
        )
        [void]$tsvLines.Add(($fields -join "`t"))
    }
    ($tsvLines -join "`n") | Set-Content -LiteralPath $reportTsvPath  -ErrorAction Stop

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-Die "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath" 2
        }

        $instructionRecords = New-Object System.Collections.Generic.List[object]
        foreach ($r in $reportRowsArray) {
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
                'skipped' { 'no_safe_pattern_matched' }
                'missing-file' { 'missing-file' }
                'line-out-of-range' { 'line-out-of-range' }
                default { $rawStatus }
            }

            $filePath = [string]$r.File
            $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
                Convert-ToRepoRelativePath -RepoRoot $repoRoot -FullPath $filePath
            } else {
                $filePath
            }

            $originalLine = [string]$r.OriginalLine
            $updatedLine = [string]$r.UpdatedLine

            $kind = if (-not [string]::IsNullOrWhiteSpace($updatedLine) -and $updatedLine -ne $originalLine) { 'replace' } else { 'unknown' }
            $notes = "ExpectedCount=$($r.ExpectedCount); AppliedCount=$($r.AppliedCount); AppliedPatterns=$([string]$r.Applied)"

            $instructionRecords.Add(
                (New-AiFixInstructionRecord `
                    -Status $status `
                    -RuleId "ide0009" `
                    -RunId $timestamp `
                    -DiagnosticCode "IDE0009" `
                    -Reason $reason `
                    -RepoRoot $repoRoot `
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
            -OutputDirectory $outDir `
            -RuleId "ide0009" `
            -RunId $timestamp `
            -InputPath $diagnosticsPath `
            -MarkdownPath $AiInstructionsPath

        if (Get-Command -Name Write-InfoMessage -ErrorAction SilentlyContinue) {
            Write-InfoMessage -Message "AI Instructions TSV : $($artifact.TsvPath)"
            Write-InfoMessage -Message "AI Instructions JSON: $($artifact.JsonPath)"
            Write-InfoMessage -Message "AI Instructions MD  : $($artifact.MarkdownPath)"
        } else {
            Write-Host "AI Instructions TSV : $($artifact.TsvPath)" -ForegroundColor Gray
            Write-Host "AI Instructions JSON: $($artifact.JsonPath)" -ForegroundColor Gray
            Write-Host "AI Instructions MD  : $($artifact.MarkdownPath)" -ForegroundColor Gray
        }
    }

    if (Get-Command -Name Write-SuccessMessage -ErrorAction SilentlyContinue) {
        if ($NoApplyChanges) {
            Write-SuccessMessage -Message "Processed $filesProcessed file(s); would modify $filesWithEdits file(s). Report entries: $($reportRowsArray.Count)."
        } else {
            Write-SuccessMessage -Message "Processed $filesProcessed file(s); modified $filesWritten file(s). Report entries: $($reportRowsArray.Count)."
        }
        Write-InfoMessage -Message "Report TSV : $reportTsvPath"
        Write-InfoMessage -Message "Report JSON: $reportJsonPath"
    } else {
        if ($NoApplyChanges) {
            Write-Host "✅ Processed $filesProcessed file(s); would modify $filesWithEdits file(s). Report entries: $($reportRowsArray.Count)." -ForegroundColor Green
        } else {
            Write-Host "✅ Processed $filesProcessed file(s); modified $filesWritten file(s). Report entries: $($reportRowsArray.Count)." -ForegroundColor Green
        }
        Write-Host "Report TSV : $reportTsvPath" -ForegroundColor Gray
        Write-Host "Report JSON: $reportJsonPath" -ForegroundColor Gray
    }

    exit 0
} catch {
    Write-Die "Unhandled error: $($_.Exception.Message)`n$($_.ScriptStackTrace)" 1
}



