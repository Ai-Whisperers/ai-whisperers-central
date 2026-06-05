#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fix CA1848 by converting eligible ILogger.LogX calls to LoggerMessage delegates.

.DESCRIPTION
    Parses a tab-delimited diagnostics export (VS Error List "Copy" format) for CA1848 entries and produces
    a stable report of what would be touched by an automated fixer.

    When -Apply is specified, the script will also apply conservative fixes:
    - Introduce `LoggerMessage.Define` delegates inside the containing type
    - Rewrite the targeted `_logger.LogX(...)` call sites to invoke the delegate

    Apply mode is intentionally conservative and will skip cases that are ambiguous or risky to rewrite.

.PARAMETER TsvPath
    Path to the CA1848 TSV input (tab-delimited with columns: Severity, Code, Description, Project, File, Line, Suppression State).

.PARAMETER RepoRoot
    Repository root. Defaults to three levels above this script (..\\..\\..).

.PARAMETER OutputDirectory
    Directory to write report files to. Defaults to: <RepoRoot>\\out\\quality\\ca1848\\<RunId>

.PARAMETER RunId
    Run identifier used in output file names and directory. Default: yyyyMMdd-HHmmss.

.PARAMETER MaxContextBacktrackLines
    Maximum number of lines to search upward from the reported line to find the start of the log call.
    Default: 12.

.PARAMETER Apply
    Apply changes to eligible call sites and introduce LoggerMessage delegates.

.PARAMETER EmitAiInstructions
    Emit an AI-friendly Markdown playbook describing the exact edits to apply per diagnostic record.
    This is intended for cases where the script skips apply mode or when you want a reviewable, copy/paste
    set of instructions for another agent.

.PARAMETER AiInstructionsPath
    Optional explicit path for the generated AI instructions Markdown file. If omitted, defaults to:
    <OutputDirectory>\instructions.ca1848.<RunId>.md

.EXAMPLE
    pwsh -NoProfile -File .cursor/scripts/quality/fix-ca1848-logger-message.ps1
    Uses the default ticket TSV path (if present) and writes reports under out/quality/ca1848/<RunId>.

.EXAMPLE
    pwsh -NoProfile -File .cursor/scripts/quality/fix-ca1848-logger-message.ps1 `
      -TsvPath "tickets/EPP-192/EPP-192-CODEQUALITY/EPP-192-CODEQUALITY-01-CA1848-FOR-IMPROVED-PERFORMANCE-USE/data/2025-12-22/diagnostics.CA1848.2025-12-22.tsv"
    Runs against an explicit TSV and writes report outputs.

.NOTES
    File Name      : fix-ca1848-logger-message.ps1
    Status         : ACTIVE (report + optional apply)
    Prerequisite   : PowerShell 7.2+
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to CA1848 TSV input")]
    [string]$TsvPath = "tickets/EPP-192/EPP-192-CODEQUALITY/EPP-192-CODEQUALITY-01-CA1848-FOR-IMPROVED-PERFORMANCE-USE/data/2025-12-22/diagnostics.CA1848.2025-12-22.tsv",

    [Parameter(Mandatory = $false, HelpMessage = "Repository root path")]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for reports")]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false, HelpMessage = "Run identifier used in output file names")]
    [ValidatePattern('^[0-9]{8}-[0-9]{6}$')]
    [string]$RunId = (Get-Date -Format 'yyyyMMdd-HHmmss'),

    [Parameter(Mandatory = $false, HelpMessage = "Max lines to search upward for the log call start")]
    [ValidateRange(0, 200)]
    [int]$MaxContextBacktrackLines = 12,

    [Parameter(Mandatory = $false, HelpMessage = "Apply changes to eligible CA1848 call sites (supports -WhatIf)")]
    [switch]$Apply,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI-friendly Markdown instructions (does not require -Apply)")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot "modules\Common.psm1"
if (Test-Path $commonModule -PathType Leaf) {
    Import-Module $commonModule -Force
}

$diagnosticsModule = Join-Path $PSScriptRoot "modules\Diagnostics.psm1"
if (Test-Path $diagnosticsModule -PathType Leaf) {
    Import-Module $diagnosticsModule -Force
}

$aiFixInstructionsModule = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModule -PathType Leaf) {
    Import-Module $aiFixInstructionsModule -Force
}

function Write-Info {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    if (Get-Command Write-InfoMessage -ErrorAction SilentlyContinue) { Write-InfoMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Gray
}

function Write-Ok {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    if (Get-Command Write-SuccessMessage -ErrorAction SilentlyContinue) { Write-SuccessMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    if (Get-Command Write-WarningMessage -ErrorAction SilentlyContinue) { Write-WarningMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Err {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    if (Get-Command Write-ErrorMessage -ErrorAction SilentlyContinue) { Write-ErrorMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Red
}

function Write-StructuredError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Explanation,
        [Parameter(Mandatory)][string[]]$Solution,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$Help
    )

    Write-Err "❌ ERROR: $Title"
    Write-Host ""
    Write-Host "Explanation: $Explanation" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Solution:" -ForegroundColor Green
    foreach ($s in $Solution) { Write-Host "  $s" -ForegroundColor Green }
    Write-Host ""
    Write-Host "Location: $Location" -ForegroundColor Gray
    Write-Host "Help: $Help" -ForegroundColor Cyan
}

function Get-RelativeToRepo {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [Parameter(Mandatory)][string]$Root
    )

    $rootNorm = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullNorm = [IO.Path]::GetFullPath($FullPath)

    if ($fullNorm.StartsWith($rootNorm, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $fullNorm.Substring($rootNorm.Length).TrimStart('\', '/')
        return $rel
    }

    return $fullNorm
}

function Find-LoggerCallStartLine {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Lines = @(),
        [Parameter(Mandatory)][int]$ReportedLineNumber,
        [Parameter(Mandatory)][int]$MaxBacktrack
    )

    if ($Lines.Count -eq 0) { return 0 }
    if ($ReportedLineNumber -lt 1) { return 0 }
    if ($ReportedLineNumber -gt $Lines.Count) { return 0 }

    $logPattern = [regex]'(?i)\b(?:this\.)?_logger\.Log(?:Trace|Debug|Information|Warning|Error|Critical)\s*\('
    $start = [Math]::Max(1, $ReportedLineNumber - $MaxBacktrack)
    for ($ln = $ReportedLineNumber; $ln -ge $start; $ln--) {
        $text = $Lines[$ln - 1]
        if ($logPattern.IsMatch($text)) {
            return $ln
        }
    }

    # Some analyzers report a line slightly above the call; if we didn't find anything
    # when searching upward, also scan forward a small window.
    $end = [Math]::Min($Lines.Count, $ReportedLineNumber + $MaxBacktrack)
    for ($ln = $ReportedLineNumber + 1; $ln -le $end; $ln++) {
        $text = $Lines[$ln - 1]
        if ($logPattern.IsMatch($text)) {
            return $ln
        }
    }

    return 0
}

function Get-CallSlice {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Lines = @(),
        [Parameter(Mandatory)][int]$StartLine,
        [Parameter(Mandatory)][int]$MaxLines
    )

    if ($StartLine -lt 1) { return '' }
    if ($StartLine -gt $Lines.Count) { return '' }

    $end = [Math]::Min($Lines.Count, $StartLine + $MaxLines - 1)
    $slice = $Lines[($StartLine - 1)..($end - 1)]
    return ($slice -join "`n")
}

function Get-LoggerCallShape {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$CallText)

    if ([string]::IsNullOrWhiteSpace($CallText)) { return 'unknown' }
    if ($CallText -match '(?i)\bLoggerMessage\.' ) { return 'already-logger-message' }
    if ($CallText -match '(?i)\bLogTrace\s*\(') { return 'log-trace' }
    if ($CallText -match '(?i)\bLogDebug\s*\(') { return 'log-debug' }
    if ($CallText -match '(?i)\bLogInformation\s*\(') { return 'log-information' }
    if ($CallText -match '(?i)\bLogWarning\s*\(') { return 'log-warning' }
    if ($CallText -match '(?i)\bLogError\s*\(') { return 'log-error' }
    if ($CallText -match '(?i)\bLogCritical\s*\(') { return 'log-critical' }
    return 'unknown'
}

function Get-PlaceholderCount {
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][string]$CallText)

    if ([string]::IsNullOrWhiteSpace($CallText)) { return 0 }

    # Heuristic: count {Name} tokens in the first string literal (best effort).
    $m = [regex]::Match($CallText, '"(?<msg>(?:[^"\\]|\\.)*)"')
    if (-not $m.Success) { return 0 }

    $msg = $m.Groups['msg'].Value
    return ([regex]::Matches($msg, '\{[^{}]+\}')).Count
}

function New-LineStartsSafe {
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if (Get-Command New-LineIndex -ErrorAction SilentlyContinue) {
        return New-LineIndex -Text $Text
    }

    $starts = New-Object System.Collections.Generic.List[int]
    $starts.Add(0) | Out-Null
    if ([string]::IsNullOrEmpty($Text)) { return @($starts) }

    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq "`n") {
            $next = $i + 1
            if ($next -lt $Text.Length) { $starts.Add($next) | Out-Null }
        }
    }

    return @($starts)
}

function Find-MatchingBraceIndex {
    [CmdletBinding()]
    [OutputType([int])]
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

        if ($inLineComment) { if ($c -eq "`n") { $inLineComment = $false }; continue }
        if ($inBlockComment) { if ($c -eq '*' -and $next -eq '/') { $inBlockComment = $false; $i++; continue }; continue }

        if ($inString) {
            if ($inVerbatimString) {
                if ($c -eq '"' -and $next -eq '"') { $i++; continue }
                if ($c -eq '"') { $inString = $false; $inVerbatimString = $false; continue }
            } else {
                if ($c -eq '\') { $i++; continue }
                if ($c -eq '"') { $inString = $false; continue }
            }
            continue
        }

        if ($inChar) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq "'") { $inChar = $false; continue }
            continue
        }

        if ($c -eq '/' -and $next -eq '/') { $inLineComment = $true; $i++; continue }
        if ($c -eq '/' -and $next -eq '*') { $inBlockComment = $true; $i++; continue }

        if ($c -eq '@' -and $next -eq '"') { $inString = $true; $inVerbatimString = $true; $i++; continue }
        if ($c -eq '"') { $inString = $true; $inVerbatimString = $false; continue }
        if ($c -eq "'") { $inChar = $true; continue }

        if ($c -eq '{') { $depth++; continue }
        if ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }

    return -1
}

function Get-ContainingTypeSpan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Content,
        [Parameter(Mandatory)]
        [int]$Index
    )

    $typePattern = '(?m)^\s*(?:public|internal|private|protected)?\s*(?:sealed|abstract|static|partial)?\s*(?:class|struct|record)\s+[A-Za-z_][A-Za-z0-9_]*[^{]*\{'
    $typeMatches = [regex]::Matches($Content, $typePattern)
    if ($typeMatches.Count -eq 0) { return $null }

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($m in $typeMatches) {
        $openBraceIndex = $Content.IndexOf('{', $m.Index)
        if ($openBraceIndex -lt 0) { continue }
        $closeBraceIndex = Find-MatchingBraceIndex -Text $Content -OpenBraceIndex $openBraceIndex
        if ($closeBraceIndex -lt 0) { continue }
        if ($Index -lt $openBraceIndex -or $Index -gt $closeBraceIndex) { continue }
        $candidates.Add([pscustomobject]@{ OpenBraceIndex = $openBraceIndex; CloseBraceIndex = $closeBraceIndex })
    }

    if ($candidates.Count -eq 0) { return $null }
    return @($candidates | Sort-Object { $_.CloseBraceIndex - $_.OpenBraceIndex } | Select-Object -First 1)[0]
}

function Split-TopLevelArguments {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ArgumentListText
    )

    $parsedArguments = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder

    $depthParen = 0
    $depthBracket = 0
    $depthBrace = 0

    $inLineComment = $false
    $inBlockComment = $false
    $inString = $false
    $inChar = $false
    $inVerbatimString = $false

    for ($i = 0; $i -lt $ArgumentListText.Length; $i++) {
        $c = $ArgumentListText[$i]
        $next = if ($i + 1 -lt $ArgumentListText.Length) { $ArgumentListText[$i + 1] } else { [char]0 }

        if ($inLineComment) {
            [void]$sb.Append($c)
            if ($c -eq "`n") { $inLineComment = $false }
            continue
        }

        if ($inBlockComment) {
            [void]$sb.Append($c)
            if ($c -eq '*' -and $next -eq '/') { [void]$sb.Append($next); $inBlockComment = $false; $i++; continue }
            continue
        }

        if ($inString) {
            [void]$sb.Append($c)
            if ($inVerbatimString) {
                if ($c -eq '"' -and $next -eq '"') { [void]$sb.Append($next); $i++; continue }
                if ($c -eq '"') { $inString = $false; $inVerbatimString = $false; continue }
            } else {
                if ($c -eq '\') { [void]$sb.Append($next); $i++; continue }
                if ($c -eq '"') { $inString = $false; continue }
            }
            continue
        }

        if ($inChar) {
            [void]$sb.Append($c)
            if ($c -eq '\') { [void]$sb.Append($next); $i++; continue }
            if ($c -eq "'") { $inChar = $false; continue }
            continue
        }

        if ($c -eq '/' -and $next -eq '/') { [void]$sb.Append($c); [void]$sb.Append($next); $inLineComment = $true; $i++; continue }
        if ($c -eq '/' -and $next -eq '*') { [void]$sb.Append($c); [void]$sb.Append($next); $inBlockComment = $true; $i++; continue }

        if ($c -eq '@' -and $next -eq '"') { [void]$sb.Append($c); [void]$sb.Append($next); $inString = $true; $inVerbatimString = $true; $i++; continue }
        if ($c -eq '"') { [void]$sb.Append($c); $inString = $true; $inVerbatimString = $false; continue }
        if ($c -eq "'") { [void]$sb.Append($c); $inChar = $true; continue }

        switch ($c) {
            '(' { $depthParen++; [void]$sb.Append($c); continue }
            ')' { if ($depthParen -gt 0) { $depthParen-- }; [void]$sb.Append($c); continue }
            '[' { $depthBracket++; [void]$sb.Append($c); continue }
            ']' { if ($depthBracket -gt 0) { $depthBracket-- }; [void]$sb.Append($c); continue }
            '{' { $depthBrace++; [void]$sb.Append($c); continue }
            '}' { if ($depthBrace -gt 0) { $depthBrace-- }; [void]$sb.Append($c); continue }
        }

        if ($c -eq ',' -and $depthParen -eq 0 -and $depthBracket -eq 0 -and $depthBrace -eq 0) {
            $parsedArguments.Add(($sb.ToString()).Trim()) | Out-Null
            [void]$sb.Clear()
            continue
        }

        [void]$sb.Append($c)
    }

    $tail = ($sb.ToString()).Trim()
    if (-not [string]::IsNullOrWhiteSpace($tail)) { $parsedArguments.Add($tail) | Out-Null }
    return @($parsedArguments)
}

function Find-InvocationEndIndex {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Content,
        [Parameter(Mandatory)]
        [int]$CallStartIndex
    )

    $openParenIndex = $Content.IndexOf('(', $CallStartIndex)
    if ($openParenIndex -lt 0) { return -1 }

    $depthParen = 0
    $inLineComment = $false
    $inBlockComment = $false
    $inString = $false
    $inChar = $false
    $inVerbatimString = $false

    for ($i = $openParenIndex; $i -lt $Content.Length; $i++) {
        $c = $Content[$i]
        $next = if ($i + 1 -lt $Content.Length) { $Content[$i + 1] } else { [char]0 }

        if ($inLineComment) { if ($c -eq "`n") { $inLineComment = $false }; continue }
        if ($inBlockComment) { if ($c -eq '*' -and $next -eq '/') { $inBlockComment = $false; $i++; continue }; continue }

        if ($inString) {
            if ($inVerbatimString) {
                if ($c -eq '"' -and $next -eq '"') { $i++; continue }
                if ($c -eq '"') { $inString = $false; $inVerbatimString = $false; continue }
            } else {
                if ($c -eq '\') { $i++; continue }
                if ($c -eq '"') { $inString = $false; continue }
            }
            continue
        }

        if ($inChar) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq "'") { $inChar = $false; continue }
            continue
        }

        if ($c -eq '/' -and $next -eq '/') { $inLineComment = $true; $i++; continue }
        if ($c -eq '/' -and $next -eq '*') { $inBlockComment = $true; $i++; continue }
        if ($c -eq '@' -and $next -eq '"') { $inString = $true; $inVerbatimString = $true; $i++; continue }
        if ($c -eq '"') { $inString = $true; $inVerbatimString = $false; continue }
        if ($c -eq "'") { $inChar = $true; continue }

        if ($c -eq '(') { $depthParen++; continue }
        if ($c -eq ')') {
            $depthParen--
            if ($depthParen -eq 0) {
                for ($j = $i + 1; $j -lt $Content.Length; $j++) {
                    $ch = $Content[$j]
                    if ([char]::IsWhiteSpace($ch)) { continue }
                    if ($ch -eq ';') { return ($j + 1) }
                    return -1
                }
                return -1
            }
        }
    }

    return -1
}

function Normalize-TypeofDoubleParens {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    # Some formatting tools may introduce extra parentheses around typeof arguments (e.g., typeof((T)).Name).
    # Normalize to typeof(T) to keep suggested replacements as text-stable as possible.
    return ([regex]::Replace($Text, 'typeof\(\((?<t>[^)]+)\)\)', 'typeof(${t})'))
}

function Test-IsSupportedStringLiteral {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Expression)

    $t = $Expression.TrimStart()
    if ($t.StartsWith('"""')) { return $false } # raw string literal
    if ($t.StartsWith('$')) { return $false }   # interpolated
    if ($t.StartsWith('@$')) { return $false }
    if ($t.StartsWith('$@')) { return $false }
    return ($t.StartsWith('"') -or $t.StartsWith('@"'))
}

function Test-IsProbablyExceptionExpression {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Expression)

    $t = $Expression.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { return $false }
    if ($t -eq 'null') { return $true }
    if ($t -match '(?i)\bexception\b') { return $true }
    if ($t -match '(?i)\bex\b') { return $true }
    if ($t -match '\b[A-Za-z_][A-Za-z0-9_]*Exception\b') { return $true }
    if ($t -match '(?i)\bnew\s+[A-Za-z0-9_.]*Exception\b') { return $true }
    return $false
}

function Test-IsSupportedEventIdExpression {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Expression)

    $t = $Expression.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { return $false }
    if ($t -match '^\s*new\s+(?:global::)?Microsoft\.Extensions\.Logging\.EventId\s*\(\s*\d+\s*(?:,\s*(@?"[^"]*"|"[^"]*")\s*)?\)\s*$') { return $true }
    if ($t -match '^\s*new\s+EventId\s*\(\s*\d+\s*(?:,\s*(@?"[^"]*"|"[^"]*")\s*)?\)\s*$') { return $true }
    if ($t -match '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+$' -and $t -notmatch '\(') { return $true }
    return $false
}

function Get-LogLevelToken {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][ValidateSet('Trace','Debug','Information','Warning','Error','Critical')][string]$Level)

    return "global::Microsoft.Extensions.Logging.LogLevel.$Level"
}

function New-DelegateFieldName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][ValidateSet('Trace','Debug','Information','Warning','Error','Critical')][string]$Level,
        [Parameter(Mandatory)][int]$CallStartLine,
        [Parameter(Mandatory)][string]$ExistingText
    )

    $base = "_logCa1848$Level" + "Line$CallStartLine"
    $name = $base
    $suffix = 1
    while ($ExistingText -match "\b$([regex]::Escape($name))\b") {
        $name = "${base}_$suffix"
        $suffix++
    }
    return $name
}

function Update-Ca1848Edits {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][object]$Edits
    )

    # Sort by StartIndex descending so earlier edits don't invalidate later offsets.
    $editsArray = @($Edits)
    $ordered = @($editsArray | Sort-Object -Property StartIndex -Descending)
    $updated = $Text
    foreach ($e in $ordered) {
        $start = [int]$e.StartIndex
        $end = [int]$e.EndIndexExclusive
        $replacement = [string]$e.Replacement
        if ($start -lt 0 -or $end -lt $start -or $end -gt $updated.Length) {
            throw "Invalid edit bounds: start=$start end=$end len=$($updated.Length)"
        }
        $updated = $updated.Substring(0, $start) + $replacement + $updated.Substring($end)
    }
    return $updated
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    if (Get-Command Get-RepoRoot -ErrorAction SilentlyContinue) {
        $RepoRoot = Get-RepoRoot -StartPath $PSScriptRoot
    } else {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
    }
} else {
    $RepoRoot = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
}

if (-not (Test-Path $RepoRoot -PathType Container)) {
    Write-StructuredError `
        -Title "RepoRoot not found" `
        -Explanation "The repository root directory is required to resolve relative paths and to place report outputs under out/quality/ca1848." `
        -Solution @(
            "Provide a valid repo root: -RepoRoot <path>",
            "Or run the script from anywhere and let it auto-discover the repo root (requires git or marker files)."
        ) `
        -Location "RepoRoot: $RepoRoot" `
        -Help "Try: pwsh -NoProfile -File .cursor/scripts/quality/fix-ca1848-logger-message.ps1 -RepoRoot <repoRoot>"
    exit 2
}

if (-not (Test-Path $TsvPath -PathType Leaf)) {
    $alt = Join-Path $RepoRoot $TsvPath
    if (Test-Path $alt -PathType Leaf) {
        $TsvPath = $alt
    } else {
        Write-StructuredError `
            -Title "TSV input not found" `
            -Explanation "The script expects a TSV exported from Visual Studio Error List (Copy) containing CA1848 diagnostics." `
            -Solution @(
                "Export CA1848 diagnostics to a TSV file and pass it via -TsvPath <path>",
                "Or place the TSV under the repo and pass a repo-relative path (e.g., tickets/.../diagnostics.CA1848.<date>.tsv)."
            ) `
            -Location "TsvPath: $TsvPath" `
            -Help "Example: pwsh -NoProfile -File .cursor/scripts/quality/fix-ca1848-logger-message.ps1 -TsvPath tickets/<...>/diagnostics.CA1848.<date>.tsv"
        exit 2
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoRoot (Join-Path "out\quality\ca1848" $RunId)
}

# Always create the report directory even under -WhatIf so the preview still emits reports.
New-Item -Path $OutputDirectory -ItemType Directory -Force -WhatIf:$false | Out-Null

Write-Info "CA1848 run: $RunId"
Write-Info "Input: $TsvPath"
Write-Info "Output: $OutputDirectory"
Write-Info ("Mode: {0}{1}" -f ($(if ($Apply) { 'APPLY' } else { 'REPORT-ONLY' })), $(if ($WhatIfPreference) { ' (WhatIf)' } else { '' }))

$rows = Import-Csv -LiteralPath $TsvPath -Delimiter "`t"
if (-not $rows -or $rows.Count -eq 0) {
    Write-Warn "No rows found in TSV."
    exit 0
}

$requiredColumns = @('Severity','Code','Description','Project','File','Line','Suppression State')
foreach ($col in $requiredColumns) {
    if (-not ($rows[0].PSObject.Properties.Name -contains $col)) {
        Write-StructuredError `
            -Title "Invalid TSV schema: missing required column '$col'" `
            -Explanation "The TSV must match Visual Studio Error List 'Copy' output with the expected column headers so the script can locate files and line numbers." `
            -Solution @(
                "Re-export the diagnostics using Visual Studio Error List -> Copy (tab-delimited).",
                "Ensure the TSV includes columns: Severity, Code, Description, Project, File, Line, Suppression State."
            ) `
            -Location "TsvPath: $TsvPath" `
            -Help "Open TSV and verify header row contains the required column names."
        exit 2
    }
}

$results = New-Object System.Collections.Generic.List[object]
$errors = 0
$skipped = 0
$plannedCount = 0
$appliedCount = 0

$targetsByFile = @{}
foreach ($r in $rows) {
    $file = [string]$r.File
    if ([string]::IsNullOrWhiteSpace($file)) { continue }
    if (-not $targetsByFile.ContainsKey($file)) {
        $targetsByFile[$file] = New-Object System.Collections.Generic.List[object]
    }
    $targetsByFile[$file].Add($r)
}

foreach ($filePath in ($targetsByFile.Keys | Sort-Object)) {
    $fileExists = Test-Path $filePath -PathType Leaf
    if (-not $fileExists) {
        foreach ($r in $targetsByFile[$filePath]) {
            $code = [string]$r.Code
            $project = [string]$r.Project
            $lineRaw = [string]$r.Line
            $line = 0
            [void][int]::TryParse($lineRaw, [ref]$line)
            $rel = Get-RelativeToRepo -FullPath $filePath -Root $RepoRoot

            $results.Add([pscustomobject]@{
                Code = $code
                Project = $project
                File = $filePath
                RelativeFile = $rel
                Line = $line
                CallStartLine = 0
                CallShape = 'unknown'
                PlaceholderCount = 0
                Action = 'skipped'
                Reason = 'file_not_found'
                DelegateName = ''
                CallText = ''
                SuggestedDelegate = ''
                SuggestedReplacement = ''
            })
            $skipped++
            $errors++
        }
        continue
    }

    $content = Get-Content -LiteralPath $filePath -Raw -ErrorAction Stop
    $lines = @(Get-Content -LiteralPath $filePath -ErrorAction Stop)
    $lineStarts = New-LineStartsSafe -Text $content

    $edits = New-Object System.Collections.Generic.List[object]
    $fileResultRecords = New-Object System.Collections.Generic.List[object]
    $insertByType = @{}     # key: openBraceIndex -> list of field declarations
    $delegateByKey = @{}    # key: openBraceIndex|level|eventId|message|placeholderCount -> delegateName

    foreach ($r in $targetsByFile[$filePath]) {
        $code = [string]$r.Code
        $project = [string]$r.Project
        $lineRaw = [string]$r.Line
        $line = 0
        [void][int]::TryParse($lineRaw, [ref]$line)
        $rel = Get-RelativeToRepo -FullPath $filePath -Root $RepoRoot

        $action = 'skipped'
        $reason = ''
        $callStartLine = 0
        $shape = 'unknown'
        $placeholders = 0
        $delegateName = ''
        $callText = ''
        $suggestedDelegate = ''
        $suggestedReplacement = ''

        if ($code -and ($code -ne 'CA1848')) {
            $reason = "unexpected_code:$code"
            $errors++
        } elseif ($line -lt 1) {
            $reason = 'invalid_line_number'
            $errors++
        } elseif ($line -gt $lines.Count) {
            $reason = 'line_out_of_range'
            $errors++
        } else {
            $callStartLine = Find-LoggerCallStartLine -Lines $lines -ReportedLineNumber $line -MaxBacktrack $MaxContextBacktrackLines
            if ($callStartLine -eq 0) {
                $reason = 'log_call_not_found_near_line'
            } else {
                $callStartLineText = $lines[$callStartLine - 1]
                $pattern = [regex]'(?i)\b(?<logger>(?:this\.)?_logger)\.Log(?<level>Trace|Debug|Information|Warning|Error|Critical)\s*\('
                $m = $pattern.Match($callStartLineText)
                if (-not $m.Success) {
                    $reason = 'log_call_pattern_not_found_on_start_line'
                } else {
                    $loggerExpr = $m.Groups['logger'].Value
                    $level = $m.Groups['level'].Value

                    $lineStartIndex = $lineStarts[$callStartLine - 1]
                    $callStartIndex = $lineStartIndex + $m.Index
                    $callEndExclusive = Find-InvocationEndIndex -Content $content -CallStartIndex $callStartIndex
                    if ($callEndExclusive -lt 0) {
                        $reason = 'log_call_end_not_found'
                    } else {
                        $invocationText = $content.Substring($callStartIndex, $callEndExclusive - $callStartIndex)
                        $shape = Get-LoggerCallShape -CallText $invocationText
                        $placeholders = Get-PlaceholderCount -CallText $invocationText
                        $callText = $invocationText

                        if ($shape -eq 'already-logger-message') {
                            $reason = 'already_uses_loggermessage'
                        } elseif ($placeholders -gt 6) {
                            $reason = 'too_many_placeholders_for_loggermessage'
                        } else {
                            $openParenIndex = $invocationText.IndexOf('(')
                            $closeParenIndex = $invocationText.LastIndexOf(')')
                            if ($openParenIndex -lt 0 -or $closeParenIndex -lt $openParenIndex) {
                                $reason = 'argument_list_not_found'
                            } else {
                                $argsText = $invocationText.Substring($openParenIndex + 1, $closeParenIndex - $openParenIndex - 1)
                                $callArguments = [string[]](Split-TopLevelArguments -ArgumentListText $argsText)
                                if ($callArguments.Length -eq 0) {
                                    $reason = 'no_arguments_found'
                                } else {
                                    $messageIndex = -1
                                    for ($ai = 0; $ai -lt $callArguments.Length; $ai++) {
                                        if (Test-IsSupportedStringLiteral -Expression $callArguments[$ai]) { $messageIndex = $ai; break }
                                    }

                                    if ($messageIndex -lt 0) {
                                        $reason = 'message_string_literal_not_found_or_not_supported'
                                    } else {
                                        $messageLiteral = $callArguments[$messageIndex].Trim()
                                        $preArgs = [string[]]@()
                                        if ($messageIndex -gt 0) { $preArgs = @($callArguments[0..($messageIndex - 1)]) }
                                        $postArgs = [string[]]@()
                                        if ($messageIndex + 1 -le ($callArguments.Length - 1)) { $postArgs = @($callArguments[($messageIndex + 1)..($callArguments.Length - 1)]) }

                                        if ($postArgs.Length -ne $placeholders) {
                                            $reason = 'placeholder_argument_count_mismatch'
                                        } else {
                                            $eventIdExpr = 'new global::Microsoft.Extensions.Logging.EventId(0)'
                                            $exceptionExpr = 'null'

                                            if ($preArgs.Length -eq 1) {
                                                if (Test-IsSupportedEventIdExpression -Expression $preArgs[0]) {
                                                    $eventIdExpr = $preArgs[0].Trim()
                                                } elseif (Test-IsProbablyExceptionExpression -Expression $preArgs[0]) {
                                                    $exceptionExpr = $preArgs[0].Trim()
                                                } else {
                                                    $reason = 'unsupported_single_prefix_argument'
                                                }
                                            } elseif ($preArgs.Length -eq 2) {
                                                if (-not (Test-IsSupportedEventIdExpression -Expression $preArgs[0])) {
                                                    $reason = 'unsupported_eventid_expression'
                                                } elseif (-not (Test-IsProbablyExceptionExpression -Expression $preArgs[1])) {
                                                    $reason = 'unsupported_exception_expression'
                                                } else {
                                                    $eventIdExpr = $preArgs[0].Trim()
                                                    $exceptionExpr = $preArgs[1].Trim()
                                                }
                                            } elseif ($preArgs.Length -gt 2) {
                                                $reason = 'unsupported_prefix_arguments'
                                            }

                                            if ([string]::IsNullOrWhiteSpace($reason)) {
                                                $typeSpan = Get-ContainingTypeSpan -Content $content -Index $callStartIndex
                                                if ($null -eq $typeSpan) {
                                                    $reason = 'containing_type_not_found'
                                                } else {
                                                    $typeOpen = [int]$typeSpan.OpenBraceIndex
                                                    $logLevelToken = Get-LogLevelToken -Level $level
                                                    $delegateKey = "$typeOpen|$level|$eventIdExpr|$messageLiteral|$placeholders"

                                                    if ($delegateByKey.ContainsKey($delegateKey)) {
                                                        $delegateName = $delegateByKey[$delegateKey]
                                                    } else {
                                                        $delegateName = New-DelegateFieldName -Level $level -CallStartLine $callStartLine -ExistingText $content
                                                        $delegateByKey[$delegateKey] = $delegateName

                                                        $genericArgs = ''
                                                        if ($placeholders -gt 0) {
                                                            $genericArgs = '<' + (@(1..$placeholders | ForEach-Object { 'object?' }) -join ', ') + '>'
                                                        }

                                                        $actionType = if ($placeholders -eq 0) {
                                                            'global::System.Action<global::Microsoft.Extensions.Logging.ILogger, global::System.Exception?>'
                                                        } else {
                                                            'global::System.Action<global::Microsoft.Extensions.Logging.ILogger, ' + ((@(1..$placeholders | ForEach-Object { 'object?' }) -join ', ') + ', global::System.Exception?') + '>'
                                                        }

                                                        $fieldLine = "    private static readonly $actionType $delegateName = global::Microsoft.Extensions.Logging.LoggerMessage.Define$genericArgs($logLevelToken, $eventIdExpr, $messageLiteral);"
                                                        $suggestedDelegate = $fieldLine
                                                        if (-not $insertByType.ContainsKey($typeOpen)) {
                                                            $insertByType[$typeOpen] = New-Object System.Collections.Generic.List[string]
                                                        }
                                                        $insertByType[$typeOpen].Add($fieldLine)
                                                    }

                                                    $indentMatch = [regex]::Match($callStartLineText, '^\s*')
                                                    $indent = $indentMatch.Value

                                                    $invocationArgs = @($loggerExpr)
                                                    if ($placeholders -gt 0) { $invocationArgs += @($postArgs) }
                                                    $invocationArgs += @($exceptionExpr)

                                                    $replacementCall = $indent + $delegateName + '(' + ($invocationArgs -join ', ') + ');'
                                                    $replacementCall = Normalize-TypeofDoubleParens -Text $replacementCall
                                                    $suggestedReplacement = $replacementCall
                                                    $edits.Add([pscustomobject]@{
                                                        StartIndex = $callStartIndex
                                                        EndIndexExclusive = $callEndExclusive
                                                        Replacement = $replacementCall
                                                    })

                                                    $action = 'planned'
                                                    $plannedCount++
                                                    $reason = if ($Apply) { 'planned' } else { 'report_only' }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if ($action -eq 'skipped' -and [string]::IsNullOrWhiteSpace($reason)) { $reason = 'not_applicable' }

        $record = [pscustomobject]@{
            Code = $code
            Project = $project
            File = $filePath
            RelativeFile = $rel
            Line = $line
            CallStartLine = $callStartLine
            CallShape = $shape
            PlaceholderCount = $placeholders
            Action = $action
            Reason = $reason
            DelegateName = $delegateName
            CallText = $callText
            SuggestedDelegate = $suggestedDelegate
            SuggestedReplacement = $suggestedReplacement
        }

        $results.Add($record)
        $fileResultRecords.Add($record)

        if ($action -eq 'skipped') { $skipped++ }
    }

    if ($Apply -and $edits.Count -gt 0) {
        $insertEdits = New-Object System.Collections.Generic.List[object]
        foreach ($typeOpen in ($insertByType.Keys | Sort-Object)) {
            $insertionIndex = ([int]$typeOpen) + 1
            $fields = @($insertByType[$typeOpen] | Sort-Object -Unique)
            if ($fields.Count -eq 0) { continue }
            $block = "`r`n" + ($fields -join "`r`n") + "`r`n"
            $insertEdits.Add([pscustomobject]@{
                StartIndex = $insertionIndex
                EndIndexExclusive = $insertionIndex
                Replacement = $block
            })
        }

        $allEdits = @()
        if ($edits -and (Get-Member -InputObject $edits -Name ToArray -MemberType Method -ErrorAction SilentlyContinue)) {
            $allEdits += $edits.ToArray()
        } else {
            $allEdits += @($edits)
        }

        if ($insertEdits -and (Get-Member -InputObject $insertEdits -Name ToArray -MemberType Method -ErrorAction SilentlyContinue)) {
            $allEdits += $insertEdits.ToArray()
        } else {
            $allEdits += @($insertEdits)
        }

        $newContent = Update-Ca1848Edits -Text $content -Edits $allEdits
        if ($newContent -ne $content) {
            if ($PSCmdlet.ShouldProcess($filePath, "Apply CA1848 LoggerMessage delegate fixes")) {
                Set-Content -LiteralPath $filePath -Value $newContent -Encoding UTF8
                $appliedCount += $edits.Count

                foreach ($r in $fileResultRecords) {
                    if ($r.Action -eq 'planned' -and $r.Reason -eq 'planned') {
                        $r.Action = 'applied'
                        $r.Reason = 'applied'
                    }
                }
            }
        }
    }
}

$results = @(
    $results |
        Sort-Object RelativeFile, Line, CallStartLine, Project, Code, Reason
)

$jsonPath = Join-Path $OutputDirectory "report.ca1848.$RunId.json"
$tsvPath = Join-Path $OutputDirectory "report.ca1848.$RunId.tsv"

$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8 -WhatIf:$false

$results |
    Select-Object Code,Project,RelativeFile,Line,CallStartLine,CallShape,PlaceholderCount,Action,Reason,DelegateName |
    ConvertTo-Csv -Delimiter "`t" -NoTypeInformation |
    ForEach-Object { $_.Trim('"') } |
    Set-Content -LiteralPath $tsvPath -Encoding UTF8 -WhatIf:$false

Write-Ok "Report written:"
Write-Host "  JSON: $jsonPath" -ForegroundColor Gray
Write-Host "  TSV : $tsvPath" -ForegroundColor Gray

Write-Info ("Rows: {0} | Planned: {1} | Applied: {2} | Skipped: {3} | Issues: {4}" -f $results.Count, $plannedCount, $appliedCount, $skipped, $errors)

if ($EmitAiInstructions) {
    if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
        Write-StructuredError `
            -Title "AiFixInstructions module not available" `
            -Explanation "The AI instructions feature requires modules\AiFixInstructions.psm1 to be present and importable." `
            -Solution @(
                "Ensure .cursor/scripts/quality/modules/AiFixInstructions.psm1 exists",
                "Re-run the script from the repo with an up-to-date working tree",
                "Or disable AI instructions: omit -EmitAiInstructions"
            ) `
            -Location "Script: $PSCommandPath" `
            -Help "Expected module: $aiFixInstructionsModule"
        exit 2
    }

    $instructionRecords = New-Object System.Collections.Generic.List[object]
    foreach ($r in @($results)) {
        $status = switch ([string]$r.Action) {
            'planned' { 'planned' }
            'applied' { 'applied' }
            'skipped' { 'skipped' }
            'error' { 'error' }
            default { 'skipped' }
        }

        $relative = [string]$r.RelativeFile
        $full = $null
        if (-not [string]::IsNullOrWhiteSpace($relative)) {
            $full = Join-Path $RepoRoot $relative
        }

        $callText = [string]$r.CallText
        $suggestedDelegate = [string]$r.SuggestedDelegate
        $suggestedReplacement = [string]$r.SuggestedReplacement

        $kind = if (-not [string]::IsNullOrWhiteSpace($suggestedDelegate) -and -not [string]::IsNullOrWhiteSpace($suggestedReplacement)) { 'mixed' }
        elseif (-not [string]::IsNullOrWhiteSpace($suggestedReplacement)) { 'replace' }
        elseif (-not [string]::IsNullOrWhiteSpace($suggestedDelegate)) { 'insert' }
        else { 'unknown' }

        $notesParts = New-Object System.Collections.Generic.List[string]
        if (-not [string]::IsNullOrWhiteSpace([string]$r.DelegateName)) { $notesParts.Add("Delegate name: $($r.DelegateName)") | Out-Null }
        if (-not [string]::IsNullOrWhiteSpace($suggestedDelegate)) { $notesParts.Add("Insert delegate inside containing type:`n$($suggestedDelegate.TrimEnd())") | Out-Null }
        $notes = ($notesParts -join "`n`n")

        $instructionRecords.Add(
            (New-AiFixInstructionRecord `
                -Status $status `
                -RuleId "ca1848" `
                -RunId $RunId `
                -DiagnosticCode ([string]$r.Code) `
                -Reason ([string]$r.Reason) `
                -RepoRoot $RepoRoot `
                -FilePath $full `
                -RelativeFilePath $relative `
                -Line ([int]$r.Line) `
                -ContextBefore $callText `
                -TransformationKind $kind `
                -TransformationBefore $callText `
                -TransformationAfter $suggestedReplacement `
                -TransformationNotes $notes `
                -DoNotAutoApply $true)
        ) | Out-Null
    }

    # Ensure we pass a real object[] to avoid PowerShell binder edge cases with generic lists.
    [object[]]$recordsForArtifact =
        if ($instructionRecords -and (Get-Member -InputObject $instructionRecords -Name ToArray -MemberType Method -ErrorAction SilentlyContinue)) {
            $instructionRecords.ToArray()
        } else {
            @($instructionRecords)
        }

    $artifact = Write-AiFixInstructionsArtifacts `
        -Records $recordsForArtifact `
        -OutputDirectory $OutputDirectory `
        -RuleId "ca1848" `
        -RunId $RunId `
        -InputPath $TsvPath `
        -MarkdownPath $AiInstructionsPath

    Write-Ok "AI instructions written:"
    Write-Host "  TSV : $($artifact.TsvPath)" -ForegroundColor Gray
    Write-Host "  JSON: $($artifact.JsonPath)" -ForegroundColor Gray
    Write-Host "  MD  : $($artifact.MarkdownPath)" -ForegroundColor Gray
}

if ($errors -gt 0) { exit 1 }
exit 0


