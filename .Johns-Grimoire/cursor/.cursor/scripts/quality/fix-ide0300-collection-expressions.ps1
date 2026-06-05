#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE0300 suggestions by converting eligible array initializers to C# collection expressions.

.DESCRIPTION
    Converts C# array initializers like:
      - new[] { "a", "b" }
      - new byte[] { 1, 2, 3 }
    into C# 12 collection expressions:
      - ["a", "b"]
      - [1, 2, 3]

    This script is intentionally conservative:
      - Only rewrites initializers where the left-hand side is an explicit array type (T[]),
        e.g. 'string[] x = new[] { ... };' or 'byte[] x = new byte[] { ... };'
      - Skips 'var x = new[] { ... };' to avoid producing 'var x = [ ... ];' which may not compile.

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory (and optionally subdirectories) are processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for cases the script intentionally skips due to
    conservative guardrails, so another AI can apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0300-collection-expressions.ps1 -Path "tst/MyTests.cs"
    Fix eligible IDE0300 array initializers in a specific file.

.EXAMPLE
    .\fix-ide0300-collection-expressions.ps1 -Path "tst/" -Recurse -WhatIf
    Show what would be changed without applying any changes.

.NOTES
    File Name      : fix-ide0300-collection-expressions.ps1
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes IDE0300 (collection initialization can be simplified)
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
        if ($TargetPath -like "*.cs") {
            return @($TargetPath)
        }

        Write-Failure "Specified file is not a C# file: $TargetPath"
        return @()
    }

    if (Test-Path $TargetPath -PathType Container) {
        $searchOptions = @{
            Path   = $TargetPath
            Filter = "*.cs"
            File   = $true
        }
        if ($RecurseDirectories) {
            $searchOptions.Recurse = $true
        }

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
            continue
        }
    }

    return -1
}

function Fix-Ide0300InContent {
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [object]$AiInstructionRecords,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$RunId
    )

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
                -RuleId 'ide0300' `
                -RunId $RunId `
                -DiagnosticCode 'IDE0300' `
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
                -TransformationNotes 'Guardrail skip: heuristic fixer intentionally avoided this context.' `
                -DoNotAutoApply $true)
        ) | Out-Null
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

    function Is-InAnonymousObjectInitializer {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Index
        )

        $windowStart = [Math]::Max(0, $Index - 600)
        $window = $Text.Substring($windowStart, $Index - $windowStart)
        $m = [regex]::Matches($window, 'new\s*\{') | Select-Object -Last 1
        if (-not $m) { return $false }

        $fromNewToHere = $window.Substring($m.Index)
        if ($fromNewToHere -match ';') { return $false }
        return $true
    }

    function Is-CommaInArgumentListOnLine {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Index
        )

        $lineStart = $Text.LastIndexOf("`n", [Math]::Max(0, $Index - 1))
        if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }
        $prefix = $Text.Substring($lineStart, $Index - $lineStart)

        $lastParen = $prefix.LastIndexOf('(')
        $lastBrace = $prefix.LastIndexOf('{')
        return ($lastParen -ge 0 -and $lastParen -gt $lastBrace)
    }

    function Get-EnclosingInvocationNameOnLine {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [int]$Index
        )

        $lineStart = $Text.LastIndexOf("`n", [Math]::Max(0, $Index - 1))
        if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }
        $prefix = $Text.Substring($lineStart, $Index - $lineStart)

        $parenIndex = $prefix.LastIndexOf('(')
        if ($parenIndex -lt 0) { return '' }

        $i = $parenIndex - 1
        while ($i -ge 0 -and [char]::IsWhiteSpace($prefix[$i])) { $i-- }
        if ($i -lt 0) { return '' }

        $end = $i
        while ($i -ge 0) {
            $ch = $prefix[$i]
            if ($ch -eq '.' -or $ch -eq '_' -or [char]::IsLetterOrDigit($ch)) {
                $i--
                continue
            }
            break
        }

        $token = $prefix.Substring($i + 1, $end - $i)
        if ([string]::IsNullOrWhiteSpace($token)) { return '' }
        $lastDot = $token.LastIndexOf('.')
        if ($lastDot -ge 0) { return $token.Substring($lastDot + 1) }
        return $token
    }

    function Test-OverlapsExistingReplacement {
        param(
            [Parameter(Mandatory)]
            [int]$StartIndex,

            [Parameter(Mandatory)]
            [int]$Length
        )

        $end = $StartIndex + $Length
        foreach ($r in $replacements) {
            $rStart = [int]$r.StartIndex
            $rEnd = $rStart + [int]$r.Length
            if ($StartIndex -lt $rEnd -and $end -gt $rStart) {
                return $true
            }
        }
        return $false
    }

    # Match explicit array typed declarations with an array creation initializer.
    # Examples:
    #   private static readonly string[] _x = new[] { "a" };
    #   private static readonly byte[] _b = new byte[] { 1, 2, 3 };
    $pattern = '(?m)^(?<indent>\s*)(?<mods>(?:(?:public|private|protected|internal|static|readonly|volatile|const|sealed|partial|new)\s+)*)?(?<type>[\w\.]+)\[\]\s+(?<name>[@\w]+)\s*=\s*(?<newexpr>new\s*(?<rtype>[\w\.]+)?\s*\[\]\s*\{)'
    $matches = [regex]::Matches($Content, $pattern)

    foreach ($m in $matches) {
        $newExprGroup = $m.Groups['newexpr']
        $newStart = $newExprGroup.Index
        $openBraceIndex = $newExprGroup.Index + $newExprGroup.Length - 1

        $closeBraceIndex = Find-MatchingBraceIndex -Text $Content -OpenBraceIndex $openBraceIndex
        if ($closeBraceIndex -lt 0) {
            continue
        }

        $innerRaw = $Content.Substring($openBraceIndex + 1, $closeBraceIndex - $openBraceIndex - 1)

        $inner = if ($innerRaw -match "[\r\n]") { $innerRaw } else { $innerRaw.Trim() }

        $oldExpr = $Content.Substring($newStart, $closeBraceIndex - $newStart + 1)
        $newExpr = '[' + $inner + ']'

        $replacements.Add([pscustomobject]@{
            StartIndex = $newStart
            Length     = $oldExpr.Length
            OldValue   = $oldExpr
            NewValue   = $newExpr
        })
    }

    # Match array initializers used as method arguments or initializer assignments:
    #   Foo(new[] { "x" }, ...)
    #   Foo(new string[] { "x" })
    # Also supports object/dictionary initializers:
    #   Property = new[] { ... }
    #   ["Key"] = new[] { ... }
    #
    # Conservative:
    #   - Requires a clear preceding token: '(' ',' or '='
    #   - Requires a clear trailing token: ',' ')' or '}'
    #   - Skips 'var x = new[] { ... }' assignments to avoid producing 'var x = [ ... ]' which may not compile.
    $argPattern = 'new\s*(?<rtype>[\w\.]+)?\s*\[\]\s*\{'
    $argMatches = [regex]::Matches($Content, $argPattern)
    foreach ($m in $argMatches) {
        $newStart = $m.Index
        $openBraceIndex = $m.Index + $m.Length - 1
        $contextLine = Get-LineAtIndex -Text $Content -Index $newStart

        # Check preceding significant character.
        $prev = $newStart - 1
        while ($prev -ge 0 -and [char]::IsWhiteSpace($Content[$prev])) { $prev-- }
        if ($prev -lt 0) { continue }
        $prevChar = $Content[$prev]
        if ($prevChar -ne '(' -and $prevChar -ne ',' -and $prevChar -ne '=') { continue }
        if ($prevChar -eq ',' -and -not (Is-CommaInArgumentListOnLine -Text $Content -Index $newStart)) { continue }
        if ($prevChar -eq '=' -and (Is-VarDeclarationBeforeIndex -Text $Content -Index $newStart)) {
            Try-AddAiSkipRecord -Reason 'skipped-var-assignment' -Index $newStart -ContextLine $contextLine
            continue
        }
        if ($prevChar -eq '=' -and (Is-InAnonymousObjectInitializer -Text $Content -Index $newStart)) {
            Try-AddAiSkipRecord -Reason 'skipped-anonymous-object-initializer' -Index $newStart -ContextLine $contextLine
            continue
        }
        if ($prevChar -eq '(' -or $prevChar -eq ',') {
            $invocation = Get-EnclosingInvocationNameOnLine -Text $Content -Index $newStart
            if ($invocation -eq 'BeEquivalentTo') {
                Try-AddAiSkipRecord -Reason 'skipped-invocation-beequivalentto' -Index $newStart -ContextLine $contextLine
                continue
            }
        }

        $closeBraceIndex = Find-MatchingBraceIndex -Text $Content -OpenBraceIndex $openBraceIndex
        if ($closeBraceIndex -lt 0) { continue }

        # Check next significant character.
        $next = $closeBraceIndex + 1
        while ($next -lt $Content.Length -and [char]::IsWhiteSpace($Content[$next])) { $next++ }
        if ($next -ge $Content.Length) { continue }
        $nextChar = $Content[$next]
        if ($nextChar -ne ',' -and $nextChar -ne ')' -and $nextChar -ne '}') { continue }

        $innerRaw = $Content.Substring($openBraceIndex + 1, $closeBraceIndex - $openBraceIndex - 1)
        $inner = if ($innerRaw -match "[\r\n]") { $innerRaw } else { $innerRaw.Trim() }
        $oldExpr = $Content.Substring($newStart, $closeBraceIndex - $newStart + 1)
        if (Test-OverlapsExistingReplacement -StartIndex $newStart -Length $oldExpr.Length) { continue }

        $newExpr = '[' + $inner + ']'
        $replacements.Add([pscustomobject]@{
            StartIndex = $newStart
            Length     = $oldExpr.Length
            OldValue   = $oldExpr
            NewValue   = $newExpr
        })
    }

    if ($replacements.Count -eq 0) {
        return [pscustomobject]@{
            Content = $Content
            Changes = 0
        }
    }

    # Apply from end to start to avoid index shifting.
    $ordered = $replacements | Sort-Object StartIndex -Descending
    $updated = $Content
    $changes = 0

    foreach ($r in $ordered) {
        $before = $updated.Substring(0, $r.StartIndex)
        $after = $updated.Substring($r.StartIndex + $r.Length)
        $updated = $before + $r.NewValue + $after
        $changes++
    }

    return [pscustomobject]@{
        Content = $updated
        Changes = $changes
    }
}

function Fix-Ide0300File {
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
        if ([string]::IsNullOrWhiteSpace($content)) {
            return $false
        }
        $result = Fix-Ide0300InContent `
            -Content $content `
            -FilePath $FilePath `
            -AiInstructionRecords $AiInstructionRecords `
            -RepoRoot $RepoRoot `
            -RunId $RunId

        if ($result.Changes -le 0) {
            return $false
        }

        if ($PSCmdlet.ShouldProcess($FilePath, "Rewrite $($result.Changes) IDE0300 array initializer(s) to collection expressions")) {
            $result.Content | Set-Content $FilePath -NoNewline -ErrorAction Stop
        }

        Write-Success "Rewrote $($result.Changes) IDE0300 array initializer(s) in $FilePath"
        return $true
    } catch {
        Write-Failure "Error processing $FilePath : $_"
        return $false
    }
}

try {
    Write-Step "IDE0300 Collection Expression Fixer"
    Write-InfoMessage "Converts eligible 'new[] { ... }' and 'new T[] { ... }' initializers to '[ ... ]' (C# collection expressions)"

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
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (IDE0300)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('IDE0300') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (IDE0300)."
                    } else {
                        Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (IDE0300). Continuing with heuristic fixer."
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
        $changed = Fix-Ide0300File -FilePath $file -AiInstructionRecords $aiInstructionRecords -RepoRoot $repoRootForRel -RunId $runId
        if ($changed) { $filesChanged++ }
    }

    if ($EmitAiInstructions) {
        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($aiInstructionRecords) `
            -OutputDirectory $aiInstructionsOutputDir `
            -RuleId "ide0300" `
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
        Write-Success "IDE0300 collection expression fixes completed successfully"
        exit 0
    }

    Write-InfoMessage "No eligible IDE0300 patterns found - files are already simplified or require manual review"
    exit 0
} catch {
    Write-Failure "Script execution failed: $_"
    exit 1
}



