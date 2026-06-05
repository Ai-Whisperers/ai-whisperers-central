#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes CA1861 by hoisting constant array/collection arguments into static readonly fields.

.DESCRIPTION
    CA1861 warns when a constant array is created repeatedly at call sites (e.g. inline array literals).
    This script finds common constant array argument patterns in C# source files and replaces them with
    a reusable `private static readonly T[]` field declared on the containing type.

    Supported argument patterns:
    - `new[] { ... }`
    - `new T[] { ... }`
    - C# 12 collection expressions used as arguments: `[...]` (e.g. `["Country"]`)

    Safety rules:
    - Only rewrites when element type can be inferred safely (string, int, bool, char, Type),
      or when the array type is explicit (`new T[] { ... }`).
    - Skips complex expressions (spreads `..`, lambdas, nested `new`, method calls inside elements).
    - Inserts fields into the first type declaration in the file (class/struct/record) for predictability.

.PARAMETER Path
    Path to a C# file or directory to process.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for cases the script intentionally skips due to
    conservative guardrails (e.g., non-argument contexts, complex element expressions, or unknown element types),
    so another AI can apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.PARAMETER WhatIf
    Shows what would be changed without writing files.

.PARAMETER Verbose
    Enables verbose output.

.EXAMPLE
    .\.cursor\scripts\quality\fix-ca1861-static-readonly-array-arguments.ps1 -Path "tst/" -Recurse

.EXAMPLE
    .\.cursor\scripts\quality\fix-ca1861-static-readonly-array-arguments.ps1 -Path "SomeTests.cs" -WhatIf -Verbose

.NOTES
    File Name    : fix-ca1861-static-readonly-array-arguments.ps1
    Prerequisite : PowerShell 7.2+
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (Test-Path $commonModule) {
    Import-Module $commonModule -Force
}

$roslynModule = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModule) {
    Import-Module $roslynModule -Force
}

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

function Write-Info {
    param([string]$Message)
    if (Get-Command Write-InfoMessage -ErrorAction SilentlyContinue) { Write-InfoMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Gray
}

function Write-Ok {
    param([string]$Message)
    if (Get-Command Write-SuccessMessage -ErrorAction SilentlyContinue) { Write-SuccessMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    if (Get-Command Write-WarningMessage -ErrorAction SilentlyContinue) { Write-WarningMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    if (Get-Command Write-ErrorMessage -ErrorAction SilentlyContinue) { Write-ErrorMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Red
}

function Get-CSharpFiles {
    param([string]$TargetPath, [bool]$RecurseDirectories)

    $results = @()
    if (Test-Path $TargetPath -PathType Leaf) {
        if ($TargetPath -like '*.cs') {
            $results += $TargetPath
        }
        return $results
    }

    if (Test-Path $TargetPath -PathType Container) {
        $opts = @{
            Path   = $TargetPath
            Filter = '*.cs'
            File   = $true
        }
        if ($RecurseDirectories) { $opts.Recurse = $true }
        $results += (Get-ChildItem @opts | Select-Object -ExpandProperty FullName)
        return $results
    }

    return $results
}

function Get-FirstTypeInsertionPoint {
    param([string]$Content)

    # First class/struct/record with an opening brace.
    $typePattern = '(?m)(?:^|\s)(?:public|internal|private|protected)?\s*(?:sealed|abstract|static|partial)?\s*(?:class|struct|record)\s+\w[^{]*\{'
    $m = [regex]::Match($Content, $typePattern)
    if (-not $m.Success) { return $null }

    $openBraceIndex = $Content.IndexOf('{', $m.Index)
    if ($openBraceIndex -lt 0) { return $null }
    return ($openBraceIndex + 1)
}

function Get-NextNonWhitespaceIndex {
    param([string]$Text, [int]$StartIndex, [ValidateSet('forward','backward')][string]$Direction)

    if ($Direction -eq 'forward') {
        for ($i = $StartIndex; $i -lt $Text.Length; $i++) {
            if (-not [char]::IsWhiteSpace($Text[$i])) { return $i }
        }
        return $null
    }

    for ($i = $StartIndex; $i -ge 0; $i--) {
        if (-not [char]::IsWhiteSpace($Text[$i])) { return $i }
    }
    return $null
}

function Test-IsArgumentContext {
    param(
        [string]$Content,
        [int]$StartIndex,
        [int]$EndIndexExclusive
    )

    $prevIdx = Get-NextNonWhitespaceIndex -Text $Content -StartIndex ($StartIndex - 1) -Direction backward
    $nextIdx = Get-NextNonWhitespaceIndex -Text $Content -StartIndex $EndIndexExclusive -Direction forward
    if ($null -eq $prevIdx -or $null -eq $nextIdx) { return $false }

    $prevCh = $Content[$prevIdx]
    $nextCh = $Content[$nextIdx]

    # Argument starts after '(' or ',' and ends before ',' or ')'
    if ($prevCh -notin @('(', ',')) { return $false }
    if ($nextCh -notin @(',', ')')) { return $false }
    return $true
}

function Get-InferredElementType {
    param([string]$ElementsText)

    $t = $ElementsText.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }

    # Skip complex patterns that are hard to type safely.
    if ($t -match '\.\.' -or $t -match '=>' -or $t -match '\bnew\b' -or $t -match '\(' -or $t -match '\)' ) {
        # Allow typeof(...) even though it has parentheses.
        if ($t -match '\btypeof\s*\(') {
            return 'Type'
        }
        return $null
    }

    if ($t -match 'nameof\s*\(') { return 'string' }
    if ($t -match '["'']') { return 'string' }
    if ($t -match '^\s*(true|false)\s*(,\s*(true|false)\s*)*$') { return 'bool' }
    if ($t -match '^\s*''[^'']''\s*(,\s*''[^'']''\s*)*$') { return 'char' }
    if ($t -match '^\s*-?\d+\s*(,\s*-?\d+\s*)*$') { return 'int' }

    return $null
}

function Get-FieldNameFromElements {
    param(
        [string]$ElementsText,
        [hashtable]$ExistingNames
    )

    $base = '_arrayValues'
    if ($ElementsText -match '["'']([^"''\\]+)["'']') {
        $raw = $matches[1]
        $sanitized = ($raw -replace '[^A-Za-z0-9]', '')
        if ($sanitized.Length -gt 0) {
            $base = '_' + [char]::ToLowerInvariant($sanitized[0]) + $sanitized.Substring(1) + 'Array'
        }
    }

    $name = $base
    $i = 1
    while ($ExistingNames.ContainsKey($name)) {
        $name = "$base$i"
        $i++
    }
    $ExistingNames[$name] = $true
    return $name
}

function Fix-File {
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

    $content = Get-Content -LiteralPath $FilePath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return $false }

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
            [string]$ContextLine,

            [Parameter(Mandatory = $false)]
            [string]$Notes
        )

        if (-not $AiInstructionRecords) { return }
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) { return }

        $repoRootForRel = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { (Get-Location).Path } else { $RepoRoot }
        $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
            Convert-ToRepoRelativePath -RepoRoot $repoRootForRel -FullPath $FilePath
        } else {
            $FilePath
        }

        $line = Get-LineNumberAtIndex -Text $content -Index $Index

        $AiInstructionRecords.Add(
            (New-AiFixInstructionRecord `
                -Status 'skipped' `
                -RuleId 'ca1861' `
                -RunId $RunId `
                -DiagnosticCode 'CA1861' `
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
                -TransformationNotes $Notes `
                -DoNotAutoApply $true)
        ) | Out-Null
    }

    $insertionPoint = Get-FirstTypeInsertionPoint -Content $content
    if ($null -eq $insertionPoint) {
        Try-AddAiSkipRecord -Reason 'skipped-no-type-declaration-found' -Index 0 -ContextLine '' -Notes 'No class/struct/record declaration found; cannot insert static readonly field safely.'
        if ($PSBoundParameters.ContainsKey('Verbose')) { Write-Warn "Skipping (no type declaration found): $FilePath" }
        return $false
    }

    $existingNames = @{}
    foreach ($m in [regex]::Matches($content, '(?m)^\s*private\s+static\s+readonly\s+\w[\w\.]*\s*\[\]\s+(?<name>_[A-Za-z0-9_]+)\b')) {
        $existingNames[$m.Groups['name'].Value] = $true
    }

    $edits = New-Object System.Collections.Generic.List[object]
    $fields = New-Object System.Collections.Generic.List[string]
    $dedupe = @{}

    # 1) new T[] { ... }
    $typedNewArray = [regex]::Matches($content, '(?s)new\s+(?<type>[\w\.]+)\s*\[\]\s*\{\s*(?<elements>[^}]*)\s*\}')
    foreach ($m in $typedNewArray) {
        $start = $m.Index
        $end = $m.Index + $m.Length
        if (-not (Test-IsArgumentContext -Content $content -StartIndex $start -EndIndexExclusive $end)) {
            Try-AddAiSkipRecord -Reason 'skipped-not-argument-context' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Match is not in a clear argument context (not between (/, and ,/)).'
            continue
        }

        $arrayType = $m.Groups['type'].Value
        $elements = $m.Groups['elements'].Value.Trim()
        if ($elements -match '\.\.' -or $elements -match '=>' -or $elements -match '\bnew\b') {
            Try-AddAiSkipRecord -Reason 'skipped-complex-elements' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Elements include spread (..), lambda (=>), or nested new; heuristic typing/hoist is intentionally conservative.'
            continue
        }

        $key = "typed|$arrayType|$($elements -replace '\s+',' ')"
        if (-not $dedupe.ContainsKey($key)) {
            $fieldName = Get-FieldNameFromElements -ElementsText $elements -ExistingNames $existingNames
            $fields.Add("    private static readonly $arrayType[] $fieldName = new $arrayType[] { $elements };")
            $dedupe[$key] = $fieldName
        }

        $edits.Add([pscustomobject]@{ Start = $start; Length = $m.Length; Replacement = $dedupe[$key] }) | Out-Null
    }

    # 2) new[] { ... }
    $implicitNewArray = [regex]::Matches($content, '(?s)new\s*\[\]\s*\{\s*(?<elements>[^}]*)\s*\}')
    foreach ($m in $implicitNewArray) {
        $start = $m.Index
        $end = $m.Index + $m.Length
        if (-not (Test-IsArgumentContext -Content $content -StartIndex $start -EndIndexExclusive $end)) {
            Try-AddAiSkipRecord -Reason 'skipped-not-argument-context' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Match is not in a clear argument context (not between (/, and ,/)).'
            continue
        }

        $elements = $m.Groups['elements'].Value.Trim()
        $elementType = Get-InferredElementType -ElementsText $elements
        if ($null -eq $elementType) {
            Try-AddAiSkipRecord -Reason 'skipped-uninferred-element-type' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Could not infer a safe element type for hoisting (allowed: string, int, bool, char, Type; or explicit new T[]).'
            continue
        }

        $key = "implicit|$elementType|$($elements -replace '\s+',' ')"
        if (-not $dedupe.ContainsKey($key)) {
            $fieldName = Get-FieldNameFromElements -ElementsText $elements -ExistingNames $existingNames
            $fields.Add("    private static readonly $elementType[] $fieldName = new[] { $elements };")
            $dedupe[$key] = $fieldName
        }

        $edits.Add([pscustomobject]@{ Start = $start; Length = $m.Length; Replacement = $dedupe[$key] }) | Out-Null
    }

    # 3) collection expressions: [ ... ] used as an argument
    $collectionExpr = [regex]::Matches($content, '(?s)\[\s*(?<elements>[^\]]*?)\s*\]')
    foreach ($m in $collectionExpr) {
        $start = $m.Index
        $end = $m.Index + $m.Length
        if (-not (Test-IsArgumentContext -Content $content -StartIndex $start -EndIndexExclusive $end)) { continue }

        $elements = $m.Groups['elements'].Value.Trim()
        if ($elements -match '\.\.' -or $elements -match '=>' -or $elements -match '\bnew\b') {
            Try-AddAiSkipRecord -Reason 'skipped-complex-elements' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Elements include spread (..), lambda (=>), or nested new; heuristic typing/hoist is intentionally conservative.'
            continue
        }

        $elementType = Get-InferredElementType -ElementsText $elements
        if ($null -eq $elementType) {
            Try-AddAiSkipRecord -Reason 'skipped-uninferred-element-type' -Index $start -ContextLine (Get-LineAtIndex -Text $content -Index $start) -Notes 'Could not infer a safe element type for hoisting (allowed: string, int, bool, char, Type; or explicit new T[]).'
            continue
        }

        $key = "collection|$elementType|$($elements -replace '\s+',' ')"
        if (-not $dedupe.ContainsKey($key)) {
            $fieldName = Get-FieldNameFromElements -ElementsText $elements -ExistingNames $existingNames
            $fields.Add("    private static readonly $elementType[] $fieldName = [$elements];")
            $dedupe[$key] = $fieldName
        }

        $edits.Add([pscustomobject]@{ Start = $start; Length = $m.Length; Replacement = $dedupe[$key] }) | Out-Null
    }

    if ($edits.Count -eq 0) {
        return $false
    }

    # Apply replacements from end -> start to keep indices stable.
    $updated = $content
    foreach ($e in ($edits | Sort-Object Start -Descending)) {
        $updated = $updated.Remove($e.Start, $e.Length).Insert($e.Start, $e.Replacement)
    }

    # Insert fields after the first type's opening brace.
    $finalInsertionPoint = Get-FirstTypeInsertionPoint -Content $updated
    if ($null -eq $finalInsertionPoint) { return $false }

    $fieldsToAdd = @()
    foreach ($f in $fields) {
        if ($f -match '\s+(?<name>_[A-Za-z0-9_]+)\s*=') {
            $fn = $matches['name']
            if ($updated -notmatch "(?m)^\s*private\s+static\s+readonly\s+.*\[\]\s+$([regex]::Escape($fn))\s*=") {
                $fieldsToAdd += $f
            }
        }
    }

    if ($fieldsToAdd.Count -gt 0) {
        $block = "`n" + ($fieldsToAdd -join "`n") + "`n"
        $updated = $updated.Insert($finalInsertionPoint, $block)
    }

    if ($updated -eq $content) { return $false }

    if ($WhatIfPreference) {
        Write-Info "Would fix CA1861 in: $FilePath ($($fieldsToAdd.Count) field(s), $($edits.Count) replacement(s))"
        return $true
    }

    if ($PSCmdlet.ShouldProcess($FilePath, "Apply CA1861 static readonly array argument fixes")) {
        Set-Content -LiteralPath $FilePath -Value $updated 
        Write-Ok "Fixed CA1861 in: $FilePath ($($fieldsToAdd.Count) field(s), $($edits.Count) replacement(s))"
        return $true
    }

    return $false
}

try {
    $runId = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
    $repoRootForRel = if (Get-Command Get-RepoRoot -ErrorAction SilentlyContinue) { Get-RepoRoot -StartPath (Get-Location).Path } else { (Get-Location).Path }
    $aiInstructionRecords = $null
    $aiInstructionsOutputDir = $null

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-Err "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
            exit 2
        }

        $aiInstructionRecords = New-Object System.Collections.Generic.List[object]
        $aiInstructionsOutputDir = Join-Path (Join-Path $PSScriptRoot 'out') $runId
    }

    if (-not $SkipRoslyn -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        try {
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (CA1861)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('CA1861') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-Info "Roslyn pre-pass applied fixes via dotnet format (CA1861)."
                    } else {
                        Write-Info "Roslyn pre-pass ran but did not apply fixes (CA1861). Continuing with heuristic fixer."
                    }
                } else {
                    Write-Info "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with heuristic fixer."
                }
            }
        } catch {
            Write-Warn "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with heuristic fixer."
        }
    }

    $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories ([bool]$Recurse)
    $files = @($files)
    if ($files.Count -eq 0) {
        Write-Err "No C# files found for Path: $Path"
        exit 1
    }

    Write-Info "Found $($files.Count) C# file(s)"

    $changed = 0
    foreach ($file in $files) {
        $didChange = Fix-File -FilePath $file -AiInstructionRecords $aiInstructionRecords -RepoRoot $repoRootForRel -RunId $runId
        if ($didChange) { $changed++ }
    }

    if ($EmitAiInstructions) {
        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($aiInstructionRecords) `
            -OutputDirectory $aiInstructionsOutputDir `
            -RuleId "ca1861" `
            -RunId $runId `
            -InputPath $Path `
            -MarkdownPath $AiInstructionsPath

        Write-Info "AI instructions TSV : $($artifact.TsvPath)"
        Write-Info "AI instructions JSON: $($artifact.JsonPath)"
        Write-Info "AI instructions MD  : $($artifact.MarkdownPath)"
    }

    if ($WhatIfPreference) {
        Write-Info "WhatIf mode: no files were modified."
    }

    Write-Ok "Done. Files changed: $changed"
    exit 0
} catch {
    Write-Err "Script failed: $($_.Exception.Message)"
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Err $_.ScriptStackTrace
    }
    exit 1
}



