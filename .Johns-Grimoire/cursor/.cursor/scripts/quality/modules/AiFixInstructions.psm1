#Requires -Version 7.2
#Requires -PSEdition Core

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToRepoRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FullPath
    )

    $rootNorm = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $fullNorm = [IO.Path]::GetFullPath($FullPath)

    if ($fullNorm.StartsWith($rootNorm, [StringComparison]::OrdinalIgnoreCase)) {
        return $fullNorm.Substring($rootNorm.Length).TrimStart('\', '/')
    }

    return $fullNorm
}

function New-AiFixInstructionRecord {
    <#
    .SYNOPSIS
        Creates a standardized instruction record for AI-assisted code fixes.

    .DESCRIPTION
        Builds a stable, machine-readable record describing a diagnostic instance, its status
        (fixed/partial/skipped/etc.), a bounded context window, and the intended transformation
        when deterministically known.

        Scripts should emit these records when they intentionally skip or only partially fix items,
        so another agent can apply safe, deterministic edits with minimal extra discovery.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('fixed', 'partial', 'planned', 'applied', 'skipped', 'not_applicable', 'error')]
        [string]$Status,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RuleId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiagnosticCode,

        [Parameter(Mandatory = $false)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$RelativeFilePath,

        [Parameter(Mandatory = $false)]
        [int]$Line,

        [Parameter(Mandatory = $false)]
        [int]$Column,

        [Parameter(Mandatory = $false)]
        [int]$ContextStartLine,

        [Parameter(Mandatory = $false)]
        [int]$ContextEndLine,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ContextBefore,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ContextAfter,

        [Parameter(Mandatory = $false)]
        [ValidateSet('replace', 'insert', 'delete', 'mixed', 'unknown')]
        [string]$TransformationKind = 'unknown',

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$TransformationBefore,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$TransformationAfter,

        [Parameter(Mandatory = $false)]
        [string]$TransformationNotes,

        [Parameter(Mandatory = $false)]
        [bool]$DoNotAutoApply = $true
    )

    $resolvedFilePath = $null
    if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        try { $resolvedFilePath = (Resolve-Path -Path $FilePath -ErrorAction SilentlyContinue).Path } catch { $resolvedFilePath = $FilePath }
    }

    $resolvedRelative = $RelativeFilePath
    if ([string]::IsNullOrWhiteSpace($resolvedRelative) -and -not [string]::IsNullOrWhiteSpace($resolvedFilePath)) {
        $resolvedRelative = Convert-ToRepoRelativePath -RepoRoot $RepoRoot -FullPath $resolvedFilePath
    }

    $lineValue = if ($Line -gt 0) { $Line } else { $null }
    $colValue = if ($Column -gt 0) { $Column } else { $null }
    $ctxStart = if ($ContextStartLine -gt 0) { $ContextStartLine } else { $null }
    $ctxEnd = if ($ContextEndLine -gt 0) { $ContextEndLine } else { $null }

    return [pscustomobject]@{
        SchemaVersion = '1.0'
        RuleId        = $RuleId
        RunId         = $RunId
        Diagnostic    = [pscustomobject]@{
            Code   = $DiagnosticCode
            Status = $Status
            Reason = $Reason
        }
        Location      = [pscustomobject]@{
            RepoRoot         = $RepoRoot
            FilePath         = $resolvedFilePath
            RelativeFilePath = $resolvedRelative
            Line             = $lineValue
            Column           = $colValue
        }
        Context       = [pscustomobject]@{
            StartLine = $ctxStart
            EndLine   = $ctxEnd
            Before    = $ContextBefore
            After     = $ContextAfter
        }
        Transformation = [pscustomobject]@{
            Kind   = $TransformationKind
            Before = $TransformationBefore
            After  = $TransformationAfter
            Notes  = $TransformationNotes
        }
        Safety        = [pscustomobject]@{
            DoNotAutoApply = $DoNotAutoApply
        }
    }
}

function Write-AiFixInstructionsArtifacts {
    <#
    .SYNOPSIS
        Writes AI fix instructions artifacts (JSON + Markdown) for a run.

    .PARAMETER Records
        Array of instruction records from New-AiFixInstructionRecord.

    .PARAMETER OutputDirectory
        Output directory for the artifacts.

    .PARAMETER RuleId
        Rule/diagnostic family identifier (e.g., ca1848, ide0009).

    .PARAMETER RunId
        Run identifier used in filenames.

    .PARAMETER InputPath
        Optional input source (TSV/report path) to include in the Markdown header.

    .PARAMETER MarkdownPath
        Optional explicit Markdown path override.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Records,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectory,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RuleId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory = $false)]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [string]$MarkdownPath
    )

    New-Item -Path $OutputDirectory -ItemType Directory -Force -WhatIf:$false | Out-Null

    function ConvertTo-TsvSafeField {
        [CmdletBinding()]
        [OutputType([string])]
        param([AllowNull()][object]$Value)

        if ($null -eq $Value) { return '' }

        $v = if ($Value -is [string]) {
            $Value
        } elseif ($Value -is [System.Array]) {
            (@($Value) | ForEach-Object { [string]$_ }) -join ';'
        } else {
            [string]$Value
        }
        # TSV is line-oriented; escape backslashes, tabs, and newlines to keep the file stable and machine-readable.
        $v = $v.Replace('\', '\\')
        $v = $v.Replace("`t", '\t')
        $v = $v.Replace("`r`n", '\n')
        $v = $v.Replace("`r", '\n')
        $v = $v.Replace("`n", '\n')
        return $v
    }

    $jsonPath = Join-Path $OutputDirectory ("ai-instructions.{0}.{1}.json" -f $RuleId, $RunId)
    $tsvPath = Join-Path $OutputDirectory ("ai-instructions.{0}.{1}.tsv" -f $RuleId, $RunId)
    $mdPath = if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
        Join-Path $OutputDirectory ("ai-instructions.{0}.{1}.md" -f $RuleId, $RunId)
    } else {
        $MarkdownPath
    }

    $recordsArray = @($Records)
    $recordsArray | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8 -WhatIf:$false

    $tsvHeader = @(
        'SchemaVersion',
        'RuleId',
        'RunId',
        'DiagnosticCode',
        'Status',
        'Reason',
        'RelativeFilePath',
        'Line',
        'Column',
        'ContextStartLine',
        'ContextEndLine',
        'TransformationKind',
        'DoNotAutoApply',
        'ContextBefore',
        'ContextAfter',
        'TransformationBefore',
        'TransformationAfter',
        'TransformationNotes'
    ) -join "`t"

    $tsvLines = New-Object System.Collections.Generic.List[string]
    $tsvLines.Add($tsvHeader) | Out-Null

    foreach ($r in $recordsArray) {
        $lineValue = if ($null -ne $r.Location.Line) { [string]$r.Location.Line } else { '' }
        $columnValue = if ($null -ne $r.Location.Column) { [string]$r.Location.Column } else { '' }
        $contextStartValue = if ($null -ne $r.Context.StartLine) { [string]$r.Context.StartLine } else { '' }
        $contextEndValue = if ($null -ne $r.Context.EndLine) { [string]$r.Context.EndLine } else { '' }
        $doNotAutoApplyValue = if ($r.Safety.DoNotAutoApply) { 'true' } else { 'false' }

        $rawFields = @(
            $r.SchemaVersion
            $r.RuleId
            $r.RunId
            $r.Diagnostic.Code
            $r.Diagnostic.Status
            $r.Diagnostic.Reason
            $r.Location.RelativeFilePath
            $lineValue
            $columnValue
            $contextStartValue
            $contextEndValue
            $r.Transformation.Kind
            $doNotAutoApplyValue
            $r.Context.Before
            $r.Context.After
            $r.Transformation.Before
            $r.Transformation.After
            $r.Transformation.Notes
        )

        $fields = @($rawFields | ForEach-Object { ConvertTo-TsvSafeField $_ })

        $tsvLines.Add(($fields -join "`t")) | Out-Null
    }

    ($tsvLines -join "`n") | Set-Content -LiteralPath $tsvPath -Encoding UTF8 -WhatIf:$false

    $statusCounts = $recordsArray |
        Group-Object { $_.Diagnostic.Status } |
        Sort-Object Name

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# AI Fix Instructions ($RuleId / $RunId)") | Out-Null
    $lines.Add('') | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $lines.Add("**Input**: `"$InputPath`"") | Out-Null
    }
    $lines.Add("**Artifacts**:") | Out-Null
    $lines.Add("- TSV: `"$tsvPath`"") | Out-Null
    $lines.Add("- JSON: `"$jsonPath`"") | Out-Null
    $lines.Add("- Markdown: `"$mdPath`"") | Out-Null
    $lines.Add('') | Out-Null

    $repoRootForPrompt = '<unknown repo root>'
    if ($recordsArray.Count -gt 0) {
        $rootFromRecord = [string]$recordsArray[0].Location.RepoRoot
        if (-not [string]::IsNullOrWhiteSpace($rootFromRecord)) {
            $repoRootForPrompt = $rootFromRecord
        }
    }

    $lines.Add("## AI execution guidance") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('```text') | Out-Null
    $lines.Add("You are an AI coding agent working in the repository rooted at: $repoRootForPrompt") | Out-Null
    $lines.Add("Goal: Apply the fix instructions in this document for rule '$RuleId' (run '$RunId').") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Inputs:") | Out-Null
    $lines.Add("- Machine-readable records: $jsonPath (or $tsvPath)") | Out-Null
    $lines.Add("- Human-readable guide: $mdPath") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Rules / constraints:") | Out-Null
    $lines.Add("- Only edit files referenced by the records (RelativeFilePath).") | Out-Null
    $lines.Add("- Preserve existing behavior. Do not change logic beyond the described transformation.") | Out-Null
    $lines.Add("- Treat Safety.DoNotAutoApply=true as 'review required': apply only deterministic edits described in the record's Transformation fields.") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("For each record:") | Out-Null
    $lines.Add("1) Open the file at RelativeFilePath and navigate to Line (1-based).") | Out-Null
    $lines.Add("2) Confirm Context.Before matches what you see (allowing for small whitespace differences).") | Out-Null
    $lines.Add("3) If Transformation.Kind is known and Transformation.After is provided, apply the exact before->after change.") | Out-Null
    $lines.Add("4) If Transformation.After is missing, do not invent a change; mark it as needing manual review.") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Output: Provide a patch implementing the safe changes.") | Out-Null
    $lines.Add('```') | Out-Null
    $lines.Add('') | Out-Null

    $lines.Add("## Summary") | Out-Null
    $lines.Add('') | Out-Null
    foreach ($g in $statusCounts) {
        $lines.Add("- $($g.Name): $($g.Count)") | Out-Null
    }
    $lines.Add('') | Out-Null

    $byFile = $recordsArray | Group-Object { $_.Location.RelativeFilePath } | Sort-Object Name
    foreach ($fileGroup in $byFile) {
        $fileName = if ([string]::IsNullOrWhiteSpace($fileGroup.Name)) { '<unknown file>' } else { $fileGroup.Name }
        $lines.Add("## $fileName") | Out-Null
        $lines.Add('') | Out-Null

        foreach ($r in @($fileGroup.Group | Sort-Object { $_.Location.Line }, { $_.Diagnostic.Code })) {
            $code = $r.Diagnostic.Code
            $status = $r.Diagnostic.Status
            $reason = $r.Diagnostic.Reason
            $lineNum = if ($null -ne $r.Location.Line) { [string]$r.Location.Line } else { '?' }

            $lines.Add("### $code @ line $lineNum") | Out-Null
            $lines.Add('') | Out-Null
            $lines.Add("- **Status**: $status") | Out-Null
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                $lines.Add("- **Reason**: $reason") | Out-Null
            }
            if ($r.Safety.DoNotAutoApply) {
                $lines.Add("- **Safety**: Do not auto-apply (review required)") | Out-Null
            }
            $lines.Add('') | Out-Null

            $ctxBefore = [string]$r.Context.Before
            if (-not [string]::IsNullOrWhiteSpace($ctxBefore)) {
                $lines.Add("**Context (before)**:") | Out-Null
                $lines.Add('```csharp') | Out-Null
                $lines.Add($ctxBefore.TrimEnd()) | Out-Null
                $lines.Add('```') | Out-Null
                $lines.Add('') | Out-Null
            }

            $ctxAfter = [string]$r.Context.After
            if (-not [string]::IsNullOrWhiteSpace($ctxAfter)) {
                $lines.Add("**Context (after)**:") | Out-Null
                $lines.Add('```csharp') | Out-Null
                $lines.Add($ctxAfter.TrimEnd()) | Out-Null
                $lines.Add('```') | Out-Null
                $lines.Add('') | Out-Null
            }

            $before = [string]$r.Transformation.Before
            $after = [string]$r.Transformation.After
            if (-not [string]::IsNullOrWhiteSpace($before) -or -not [string]::IsNullOrWhiteSpace($after)) {
                $lines.Add("**Intended transformation** ($($r.Transformation.Kind)):" ) | Out-Null
                $lines.Add('') | Out-Null
                if (-not [string]::IsNullOrWhiteSpace($before)) {
                    $lines.Add("Before:") | Out-Null
                    $lines.Add('```csharp') | Out-Null
                    $lines.Add($before.TrimEnd()) | Out-Null
                    $lines.Add('```') | Out-Null
                    $lines.Add('') | Out-Null
                }
                if (-not [string]::IsNullOrWhiteSpace($after)) {
                    $lines.Add("After:") | Out-Null
                    $lines.Add('```csharp') | Out-Null
                    $lines.Add($after.TrimEnd()) | Out-Null
                    $lines.Add('```') | Out-Null
                    $lines.Add('') | Out-Null
                }
            }

            $notes = [string]$r.Transformation.Notes
            if (-not [string]::IsNullOrWhiteSpace($notes)) {
                $lines.Add("**Notes**: $notes") | Out-Null
                $lines.Add('') | Out-Null
            }
        }
    }

    ($lines -join "`r`n") + "`r`n" | Set-Content -LiteralPath $mdPath -Encoding UTF8 -WhatIf:$false

    return [pscustomobject]@{
        TsvPath      = $tsvPath
        JsonPath     = $jsonPath
        MarkdownPath = $mdPath
    }
}

Export-ModuleMember -Function `
    Convert-ToRepoRelativePath, `
    New-AiFixInstructionRecord, `
    Write-AiFixInstructionsArtifacts


