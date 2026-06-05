#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    IDE0017 Auto-Fixer: Simplify object initialization (Roslyn no-build first, then TSV-driven conservative rewrite).

.DESCRIPTION
    Fixes IDE0017 "Object initialization can be simplified" in a safe, TSV-driven way.

    Strategy (in order):
    1) Optional Roslyn pre-pass (NO-BUILD only): attempts `dotnet format --no-build --diagnostics IDE0017`
       If dotnet format cannot run without build in this environment/tooling, this step is skipped.
    2) Conservative script fallback: for each TSV diagnostic row (grouped by File+Line), looks for a local
       object creation assignment at the given line and folds simple, contiguous member assignments into
       an object initializer, removing the assignment lines.

    The fallback fixer intentionally skips anything ambiguous/risky (multi-line assignments, inline
    line-comments, indexers, chained member access, intervening non-trivial statements).

.PARAMETER DiagnosticsTsvPath
    Path to the diagnostics TSV export (must contain columns: Code, File, Line).

.PARAMETER RepoRoot
    Repository root directory.

.PARAMETER Include
    Optional file/folder filters. If set, only diagnostics whose File/FullPath match at least one filter are processed.
    Filters are treated as wildcard patterns (PowerShell -like).

.PARAMETER OutputDirectory
    Directory where reports will be written (default: .cursor/scripts/quality/out).

.PARAMETER MaxFiles
    Maximum number of (File, Line) groups to process.

.PARAMETER MaxLines
    Maximum line number to process per file (skips diagnostics with Line > MaxLines).

.PARAMETER NoApplyChanges
    Report-only mode. Produces reports but does not write file changes and does not run the Roslyn pre-pass.

.PARAMETER SkipRoslyn
    Skip Roslyn pre-pass even when not in report-only mode.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for entries marked as skipped/error, so another AI can
    apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ide0017-object-initialization.ps1 `
      -DiagnosticsTsvPath "tickets/EPP-192/EPP-192-CODEQUALITY/EPP-192-CODEQUALITY-04-IDE0017-OBJECT-INIT/data/run1/diagnostics.IDE0017.run1.tsv" `
      -RepoRoot "E:\WPG\Git\E21\GitRepos\eneve.ebase.foundation" `
      -NoApplyChanges

.EXAMPLE
    .\fix-ide0017-object-initialization.ps1 `
      -DiagnosticsTsvPath "tickets/EPP-192/EPP-192-CODEQUALITY/EPP-192-CODEQUALITY-04-IDE0017-OBJECT-INIT/data/run1/diagnostics.IDE0017.run1.tsv" `
      -RepoRoot "E:\WPG\Git\E21\GitRepos\eneve.ebase.foundation" `
      -MaxFiles 10
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsTsvPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$Include,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = "$PSScriptRoot/out",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000000)]
    [int]$MaxFiles,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000000)]
    [int]$MaxLines,

    [Parameter(Mandatory = $false)]
    [switch]$NoApplyChanges,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for skipped/error entries")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

trap {
    Write-Host "`n❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "`nStack:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
    exit 1
}

function Split-CodeAndLineComment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    $inString = $false
    $escaped = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]

        if ($escaped) {
            $escaped = $false
            continue
        }

        if ($inString -and $c -eq '\') {
            $escaped = $true
            continue
        }

        if ($c -eq '"') {
            $inString = -not $inString
            continue
        }

        if (-not $inString -and $c -eq '/' -and $i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '/') {
            return [pscustomobject]@{
                Code    = $Line.Substring(0, $i)
                Comment = $Line.Substring($i)
            }
        }
    }

    return [pscustomobject]@{ Code = $Line; Comment = '' }
}

function Get-FileTextInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $content = [System.IO.File]::ReadAllText($Path)
    $lineEnding = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $endsWithNewline = $false
    if ($content.Length -gt 0 -and ($content.EndsWith("`r`n") -or $content.EndsWith("`n"))) {
        $endsWithNewline = $true
    }

    $normalized = $content.Replace("`r`n", "`n")
    $lines = $normalized.Split("`n", [System.StringSplitOptions]::None)

    return [pscustomobject]@{
        Content          = $content
        LineEnding       = $lineEnding
        EndsWithNewline  = $endsWithNewline
        Lines            = $lines
    }
}

function Write-FileTextInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory)]
        [string[]]$Lines,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LineEnding,
        [Parameter(Mandatory)]
        [bool]$EndsWithNewline
    )

    $newContent = ($Lines -join $LineEnding)
    if ($EndsWithNewline) {
        $newContent += $LineEnding
    }

    Set-Content -Path $Path -Value $newContent -NoNewline -Encoding UTF8
}

function Try-ParseObjectCreationLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    $split = Split-CodeAndLineComment -Line $Line
    $code = $split.Code
    $comment = $split.Comment

    if (-not [string]::IsNullOrWhiteSpace($comment)) {
        return $null
    }

    $m1 = [regex]::Match(
        $code,
        '^(?<indent>\s*)(?<decl>(?<type>(?:var|[\w\.\<\>\[\]\?,\s]+?))\s+(?<var>[A-Za-z_]\w*))\s*=\s*(?<newexpr>new\b.*)\s*;\s*$'
    )
    if ($m1.Success) {
        return [pscustomobject]@{
            Indent      = $m1.Groups['indent'].Value
            VarName     = $m1.Groups['var'].Value
            Prefix      = $m1.Groups['decl'].Value
            NewExpr     = $m1.Groups['newexpr'].Value.Trim()
            HasDecl     = $true
        }
    }

    $m2 = [regex]::Match(
        $code,
        '^(?<indent>\s*)(?<var>[A-Za-z_]\w*)\s*=\s*(?<newexpr>new\b.*)\s*;\s*$'
    )
    if ($m2.Success) {
        return [pscustomobject]@{
            Indent      = $m2.Groups['indent'].Value
            VarName     = $m2.Groups['var'].Value
            Prefix      = $m2.Groups['var'].Value
            NewExpr     = $m2.Groups['newexpr'].Value.Trim()
            HasDecl     = $false
        }
    }

    return $null
}

function Try-ParseSimpleMemberAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Line,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VarName
    )

    $split = Split-CodeAndLineComment -Line $Line
    $code = $split.Code
    $comment = $split.Comment

    if (-not [string]::IsNullOrWhiteSpace($comment)) {
        return $null
    }

    $pattern = '^\s*' + [regex]::Escape($VarName) + '\.(?<member>[A-Za-z_]\w*)\s*=\s*(?<expr>.+?)\s*;\s*$'
    $m = [regex]::Match($code, $pattern)
    if (-not $m.Success) {
        return $null
    }

    $expr = $m.Groups['expr'].Value.Trim()

    # Guardrail: avoid obvious multi-statement / block constructs.
    if ($expr.Contains('{') -or $expr.Contains('}') -or $expr.Contains(';')) {
        return $null
    }

    return [pscustomobject]@{
        Member = $m.Groups['member'].Value
        Expr   = $expr
    }
}

function Resolve-FullPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$File
    )

    if ([System.IO.Path]::IsPathRooted($File)) { return $File }
    return (Join-Path $RepoRoot $File)
}

function Matches-IncludeFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$File,
        [Parameter(Mandatory)]
        [string]$FullPath,
        [Parameter(Mandatory = $false)]
        [string[]]$Include
    )

    if (-not $Include -or $Include.Count -eq 0) { return $true }

    foreach ($filter in $Include) {
        if ([string]::IsNullOrWhiteSpace($filter)) { continue }
        if ($File -like $filter -or $FullPath -like $filter) { return $true }
    }

    return $false
}

function Invoke-RoslynNoBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Diagnostics,
        [Parameter(Mandatory = $false)]
        [string[]]$Include
    )

    $slnFiles = @(Get-ChildItem -Path $RepoRoot -Filter '*.sln' -File -ErrorAction SilentlyContinue)
    if ($slnFiles.Count -ne 1) {
        return [pscustomobject]@{ Attempted = $false; Applied = $false; Reason = 'solution-not-found-or-not-unique'; Output = '' }
    }

    $sln = $slnFiles[0].FullName

    $args = @('format', $sln, '--no-build', '--severity', 'info')
    foreach ($d in $Diagnostics) { $args += @('--diagnostics', $d) }
    foreach ($inc in ($Include | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) { $args += @('--include', $inc) }

    Push-Location $RepoRoot
    try {
        $output = & dotnet @args 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            Attempted = $true
            Applied   = ($exitCode -eq 0)
            Reason    = "exit-code-$exitCode"
            Output    = $output
        }
    } catch {
        return [pscustomobject]@{ Attempted = $true; Applied = $false; Reason = 'exception'; Output = $_.Exception.Message }
    } finally {
        Pop-Location
    }
}

function Remove-OrphanedActMarkerIfEmpty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines
    )

    # Removes a "// Act" line only when the next non-empty line is "// Assert" (or end of file).
    # This is a small readability cleanup after moving assignments into the initializer.
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -notmatch '^\s*//\s*Act\s*$') { continue }

        $j = $i + 1
        while ($j -lt $Lines.Count -and [string]::IsNullOrWhiteSpace($Lines[$j])) { $j++ }

        if ($j -ge $Lines.Count -or $Lines[$j] -match '^\s*//\s*Assert\s*$') {
            $list = New-Object System.Collections.Generic.List[string]
            for ($k = 0; $k -lt $Lines.Count; $k++) {
                if ($k -eq $i) { continue }
                $list.Add($Lines[$k])
            }
            return @($list)
        }
    }

    return $Lines
}

function Replace-LinesInArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines,
        [Parameter(Mandatory)]
        [ValidateRange(0, 10000000)]
        [int]$StartIndex,
        [Parameter(Mandatory)]
        [ValidateRange(0, 10000000)]
        [int]$RemoveCount,
        [Parameter(Mandatory = $false)]
        [string[]]$InsertLines = @()
    )

    $list = [System.Collections.Generic.List[string]]::new()
    $list.AddRange($Lines)

    if ($StartIndex -gt $list.Count) {
        throw "Replace-LinesInArray: StartIndex out of range ($StartIndex > $($list.Count))."
    }
    if ($StartIndex + $RemoveCount -gt $list.Count) {
        throw "Replace-LinesInArray: RemoveCount out of range (StartIndex $StartIndex + RemoveCount $RemoveCount > $($list.Count))."
    }

    if ($RemoveCount -gt 0) {
        $list.RemoveRange($StartIndex, $RemoveCount)
    }

    if ($InsertLines.Count -gt 0) {
        $list.InsertRange($StartIndex, $InsertLines)
    }

    return ,$list.ToArray()
}

if (-not (Test-Path $DiagnosticsTsvPath)) {
    throw "Diagnostics TSV file not found: $DiagnosticsTsvPath"
}
if (-not (Test-Path $RepoRoot -PathType Container)) {
    throw "RepoRoot directory not found: $RepoRoot"
}

if (-not (Test-Path $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$reportBaseName = "fix-ide0017-object-initialization-$timestamp"
$tsvReportPath = Join-Path $OutputDirectory "$reportBaseName.tsv"
$jsonReportPath = Join-Path $OutputDirectory "$reportBaseName.json"

Write-Host "🔍 Loading diagnostics from: $DiagnosticsTsvPath" -ForegroundColor Cyan
$diagnostics = Get-Content -Path $DiagnosticsTsvPath -Raw | ConvertFrom-Csv -Delimiter "`t"

if (-not $diagnostics -or $diagnostics.Count -eq 0) {
    Write-Host "ℹ️  TSV contains no rows." -ForegroundColor Yellow
    exit 0
}

$requiredColumns = @('Code', 'File', 'Line')
foreach ($col in $requiredColumns) {
    if (-not $diagnostics[0].PSObject.Properties.Name.Contains($col)) {
        throw "TSV is missing required column '$col'. Regenerate the TSV export to include: Code, File, Line."
    }
}

$ide0017Diagnostics = @($diagnostics | Where-Object { $_.Code -eq 'IDE0017' })
Write-Host "📊 Found $($ide0017Diagnostics.Count) IDE0017 diagnostics rows" -ForegroundColor Cyan
if ($ide0017Diagnostics.Count -eq 0) { exit 0 }

$groupedDiagnostics = $ide0017Diagnostics | Group-Object -Property File, Line | ForEach-Object {
    $file = $_.Group[0].File
    $line = [int]$_.Group[0].Line
    $expectedCount = $_.Group.Count
    $fullPath = Resolve-FullPath -RepoRoot $RepoRoot -File $file

    [pscustomobject]@{
        File          = $file
        Line          = $line
        ExpectedCount = $expectedCount
        FullPath      = $fullPath
    }
}

$groupedDiagnostics = @($groupedDiagnostics | Where-Object { Matches-IncludeFilter -File $_.File -FullPath $_.FullPath -Include $Include })

if ($MaxFiles -and $groupedDiagnostics.Count -gt $MaxFiles) {
    $groupedDiagnostics = @($groupedDiagnostics | Select-Object -First $MaxFiles)
}

if (-not $NoApplyChanges -and -not $SkipRoslyn) {
    Write-Host "🔧 Roslyn pre-pass (no-build): dotnet format --no-build --diagnostics IDE0017" -ForegroundColor Cyan
    $roslynResult = Invoke-RoslynNoBuild -RepoRoot $RepoRoot -Diagnostics @('IDE0017') -Include $Include

    if ($roslynResult.Attempted -and $roslynResult.Applied) {
        Write-Host "✅ Roslyn pre-pass succeeded (IDE0017)." -ForegroundColor Green
    } elseif ($roslynResult.Attempted) {
        Write-Host "⚠️  Roslyn pre-pass did not apply (IDE0017). Continuing with TSV fallback. ($($roslynResult.Reason))" -ForegroundColor Yellow
    } else {
        Write-Host "ℹ️  Skipped Roslyn pre-pass (IDE0017): $($roslynResult.Reason). Continuing with TSV fallback." -ForegroundColor Yellow
    }
} elseif ($NoApplyChanges) {
    Write-Host "ℹ️  Report-only mode: skipping Roslyn pre-pass." -ForegroundColor Gray
} else {
    Write-Host "ℹ️  Skipping Roslyn pre-pass as requested." -ForegroundColor Gray
}

$results = New-Object System.Collections.Generic.List[object]

$items = @($groupedDiagnostics | Sort-Object FullPath, Line)
$fileGroups = $items | Group-Object -Property FullPath

foreach ($fileGroup in $fileGroups) {
    $fullPath = $fileGroup.Name
    $relativeFile = $fileGroup.Group[0].File

    if (-not (Test-Path $fullPath -PathType Leaf)) {
        foreach ($diag in $fileGroup.Group) {
            [void]$results.Add([pscustomobject]@{
                File          = $diag.File
                Line          = $diag.Line
                ExpectedCount = $diag.ExpectedCount
                AppliedCount  = 0
                Status        = 'missing-file'
                Applied       = ''
                OriginalLine  = ''
                UpdatedLine   = ''
            })
        }
        continue
    }

    $fileInfo = Get-FileTextInfo -Path $fullPath
    $lines = @($fileInfo.Lines)
    $lineEnding = $fileInfo.LineEnding
    $endsWithNewline = $fileInfo.EndsWithNewline

    $changed = $false

    foreach ($diag in ($fileGroup.Group | Sort-Object Line -Descending)) {
        $lineNumber = [int]$diag.Line

        if ($MaxLines -and $lineNumber -gt $MaxLines) {
            [void]$results.Add([pscustomobject]@{
                File          = $diag.File
                Line          = $lineNumber
                ExpectedCount = $diag.ExpectedCount
                AppliedCount  = 0
                Status        = 'skipped'
                Applied       = 'max-lines-limit'
                OriginalLine  = ''
                UpdatedLine   = ''
            })
            continue
        }

        if ($lineNumber -lt 1 -or $lineNumber -gt $lines.Count) {
            [void]$results.Add([pscustomobject]@{
                File          = $diag.File
                Line          = $lineNumber
                ExpectedCount = $diag.ExpectedCount
                AppliedCount  = 0
                Status        = 'line-out-of-range'
                Applied       = ''
                OriginalLine  = ''
                UpdatedLine   = ''
            })
            continue
        }

        $idx = $lineNumber - 1
        $originalLine = $lines[$idx]

        $creation = Try-ParseObjectCreationLine -Line $originalLine
        if (-not $creation) {
            [void]$results.Add([pscustomobject]@{
                File          = $diag.File
                Line          = $lineNumber
                ExpectedCount = $diag.ExpectedCount
                AppliedCount  = 0
                Status        = 'skipped'
                Applied       = 'skipped-not-object-creation-line'
                OriginalLine  = $originalLine
                UpdatedLine   = $originalLine
            })
            continue
        }

        $varName = $creation.VarName
        $assignments = New-Object System.Collections.Generic.List[object]
        $assignmentLineIndexes = New-Object System.Collections.Generic.List[int]

        $lookAheadLimit = [Math]::Min($lines.Count - 1, $idx + 12)
        for ($j = $idx + 1; $j -le $lookAheadLimit; $j++) {
            $candidate = $lines[$j]

            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            if ($candidate -match '^\s*//') { continue }

            $assignment = Try-ParseSimpleMemberAssignment -Line $candidate -VarName $varName
            if ($assignment) {
                [void]$assignments.Add($assignment)
                [void]$assignmentLineIndexes.Add($j)
                continue
            }

            break
        }

        if ($assignments.Count -eq 0) {
            [void]$results.Add([pscustomobject]@{
                File          = $diag.File
                Line          = $lineNumber
                ExpectedCount = $diag.ExpectedCount
                AppliedCount  = 0
                Status        = 'skipped'
                Applied       = 'skipped-no-contiguous-assignments'
                OriginalLine  = $originalLine
                UpdatedLine   = $originalLine
            })
            continue
        }

        $indent = $creation.Indent
        $innerIndent = $indent + '    '
        $initItems = @()
        foreach ($a in $assignments) {
            $initItems += "$innerIndent$($a.Member) = $($a.Expr),"
        }

        # Remove trailing comma on last initializer item.
        if ($initItems.Count -gt 0) {
            $initItems[$initItems.Count - 1] = $initItems[$initItems.Count - 1].TrimEnd(',') 
        }

        $lhs = if ($creation.HasDecl) { $creation.Prefix } else { $creation.Prefix }
        $newFirstLine = "$indent$lhs = $($creation.NewExpr)"

        $newBlock = @(
            $newFirstLine,
            "$indent{",
            $initItems,
            "$indent};"
        ) | ForEach-Object { $_ }  # ensure array flatten

        $updatedLine = $newFirstLine

        if (-not $NoApplyChanges) {
            if ($PSCmdlet.ShouldProcess($diag.File, "Fold $($assignments.Count) assignments into object initializer at line $lineNumber")) {
                # Replace the creation line with the initializer block.
                $lines = Replace-LinesInArray -Lines $lines -StartIndex $idx -RemoveCount 1 -InsertLines $newBlock

                # After insertion, indexes after $idx shift by ($newBlock.Count - 1)
                $delta = $newBlock.Count - 1
                $adjustedAssignmentIndexes = @($assignmentLineIndexes | ForEach-Object { $_ + $delta })

                # Remove assignment lines (descending).
                foreach ($rm in ($adjustedAssignmentIndexes | Sort-Object -Descending)) {
                    if ($rm -ge 0 -and $rm -lt $lines.Count) {
                        $lines = Replace-LinesInArray -Lines $lines -StartIndex $rm -RemoveCount 1
                    }
                }

                $lines = Remove-OrphanedActMarkerIfEmpty -Lines $lines
                $changed = $true
            }
        }

        [void]$results.Add([pscustomobject]@{
            File          = $diag.File
            Line          = $lineNumber
            ExpectedCount = $diag.ExpectedCount
            AppliedCount  = $assignments.Count
            Status        = 'fixed'
            Applied       = 'P1-fold-assignments-to-object-initializer'
            OriginalLine  = $originalLine
            UpdatedLine   = $updatedLine
        })
    }

    if ($changed -and -not $NoApplyChanges) {
        if ($fileInfo.Lines.Count -ne $lines.Count -or ($fileInfo.Lines -join "`n") -ne ($lines -join "`n")) {
            Write-FileTextInfo -Path $fullPath -Lines $lines -LineEnding $lineEnding -EndsWithNewline $endsWithNewline
            $changed = $true
        } else {
            $changed = $false
        }
    }
}

# Reports
$resultsArray = @($results.ToArray())
$resultsArray | Export-Csv -Path $tsvReportPath -Delimiter "`t" -NoTypeInformation -Encoding UTF8
$resultsArray | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonReportPath -Encoding UTF8

Write-Host "`n📁 Reports:" -ForegroundColor Cyan
Write-Host "  TSV : $tsvReportPath" -ForegroundColor White
Write-Host "  JSON: $jsonReportPath" -ForegroundColor White

if ($EmitAiInstructions) {
    if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
        Write-Host "❌ AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath" -ForegroundColor Red
        exit 2
    }

    $instructionRecords = New-Object System.Collections.Generic.List[object]
    foreach ($r in @($resultsArray)) {
        $rawStatus = [string]$r.Status
        if ($rawStatus -eq 'fixed') { continue }

        $status = switch ($rawStatus) {
            'skipped' { 'skipped' }
            'missing-file' { 'error' }
            'line-out-of-range' { 'error' }
            default { 'error' }
        }

        $reason = switch ($rawStatus) {
            'skipped' { [string]$r.Applied }
            'missing-file' { 'missing-file' }
            'line-out-of-range' { 'line-out-of-range' }
            default { $rawStatus }
        }

        $relative = [string]$r.File
        $fullPath = if ($relative -match '^[A-Za-z]:\\') { $relative } else { Join-Path $RepoRoot $relative }
        $lineNumber = if ([int]$r.Line -gt 0) { [int]$r.Line } else { 0 }

        $originalLine = [string]$r.OriginalLine
        $updatedLine = [string]$r.UpdatedLine
        $kind = if (-not [string]::IsNullOrWhiteSpace($updatedLine) -and $updatedLine -ne $originalLine) { 'replace' } else { 'unknown' }
        $notes = "ExpectedCount=$($r.ExpectedCount); AppliedCount=$($r.AppliedCount); Applied=$([string]$r.Applied)"

        $instructionRecords.Add(
            (New-AiFixInstructionRecord `
                -Status $status `
                -RuleId "ide0017" `
                -RunId $timestamp `
                -DiagnosticCode "IDE0017" `
                -Reason $reason `
                -RepoRoot $RepoRoot `
                -FilePath $fullPath `
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
        -RuleId "ide0017" `
        -RunId $timestamp `
        -InputPath $DiagnosticsTsvPath `
        -MarkdownPath $AiInstructionsPath

    Write-Host "`n🤖 AI instructions:" -ForegroundColor Cyan
    Write-Host "  TSV : $($artifact.TsvPath)" -ForegroundColor White
    Write-Host "  JSON: $($artifact.JsonPath)" -ForegroundColor White
    Write-Host "  MD  : $($artifact.MarkdownPath)" -ForegroundColor White
}

if ($NoApplyChanges) {
    Write-Host "`n🔍 Report-only mode: no files were modified." -ForegroundColor Yellow
}



