#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE1006 private field casing violations where the first character after '_' is upper-case

.DESCRIPTION
    Some IDE1006 naming rules require private fields to be named using `_camelCase`.
    This script targets a common pattern found in tests and legacy code:

    - `private ... _Type1Array ...;` -> `private ... _type1Array ...;`

    The script:
    - Detects private (non-const) field declarations where the identifier begins with `_` and the next character is A-Z
    - Renames the field by lowercasing the first character after `_`
    - Updates all references in the same file using whole-word replacement

.PARAMETER Path
    Path to search for C# files. Defaults to current directory.

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-private-field-casing.ps1 -Path "tst/"
    Fixes private field casing violations under tst/

.EXAMPLE
    .\fix-ide1006-private-field-casing.ps1 -Path "." -WhatIf
    Shows what would be changed without applying changes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Optional diagnostics report file to restrict processing to reported files/lines")]
    [ValidateNotNullOrEmpty()]
    [string]$DiagnosticsFile,

    [Parameter(Mandatory = $false, HelpMessage = "Diagnostic code to filter within DiagnosticsFile (default: IDE1006)")]
    [ValidatePattern('^[A-Z]{2,10}\d{1,6}$')]
    [string]$DiagnosticCode = 'IDE1006',

    [Parameter(Mandatory = $false, HelpMessage = "Number of lines around each diagnostic to treat as eligible (default: 2)")]
    [ValidateRange(0, 50)]
    [int]$LinePadding = 2,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the naming fixer")]
    [switch]$SkipRoslyn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$diagnosticsModulePath = Join-Path $PSScriptRoot 'modules\Diagnostics.psm1'
if (Test-Path $diagnosticsModulePath) {
    Import-Module $diagnosticsModulePath -Force
}

function Get-CamelCasedPrivateFieldName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FieldName
    )

    if (-not $FieldName.StartsWith('_')) {
        return $FieldName
    }

    if ($FieldName.Length -lt 2) {
        return $FieldName
    }

    $afterUnderscore = $FieldName.Substring(1)
    if ($afterUnderscore.Length -eq 0) {
        return $FieldName
    }

    if (-not [char]::IsUpper($afterUnderscore[0])) {
        return $FieldName
    }

    return '_' + [char]::ToLowerInvariant($afterUnderscore[0]) + $afterUnderscore.Substring(1)
}

function Update-WholeWord {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$OldName,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    $escapedOldName = [regex]::Escape($OldName)
    return [regex]::Replace($Content, "\b$escapedOldName\b", [System.Text.RegularExpressions.MatchEvaluator] { param($m) $NewName })
}

$csFiles = @(Get-ChildItem -Path $Path -Recurse -Filter "*.cs" -File)
$rangesByFile = $null

if (-not $SkipRoslyn -and -not $WhatIf -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
    try {
        $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('IDE1006') -Severity 'info' -Include @($Path)
        if ($roslynResult.Attempted) {
            if ($roslynResult.Applied) {
                Write-Host "Roslyn pre-pass applied fixes via dotnet format (IDE1006). Continuing with naming fixer for any remaining cases." -ForegroundColor Gray
            } else {
                Write-Host "Roslyn pre-pass ran but did not apply fixes (IDE1006). Continuing with naming fixer." -ForegroundColor Gray
            }
        } else {
            Write-Host "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with naming fixer." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with naming fixer." -ForegroundColor Gray
    }
}

if (-not [string]::IsNullOrWhiteSpace($DiagnosticsFile)) {
    if (-not (Get-Command Get-DiagnosticTargetsFromReport -ErrorAction SilentlyContinue)) {
        Write-Host "Diagnostics module not available; ignoring -DiagnosticsFile filter." -ForegroundColor Yellow
    } else {
        $targets = Get-DiagnosticTargetsFromReport -ReportFilePath $DiagnosticsFile -Codes @($DiagnosticCode) -LinePadding $LinePadding
        $rangesByFile = $targets.FileRanges
        if ($rangesByFile.Count -gt 0) {
            $csFiles = @($csFiles | Where-Object { $rangesByFile.ContainsKey($_.FullName) })
        } else {
            $csFiles = @()
        }
    }
}

$fixedCount = 0

foreach ($file in $csFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        continue
    }
    $originalContent = $content

    $targetRanges = @()
    if ($null -ne $rangesByFile -and $rangesByFile.ContainsKey($file.FullName)) {
        $targetRanges = @($rangesByFile[$file.FullName])
    }

    $declPattern = '^\s*private\b(?!.*\bconst\b).*\s+(?<field>_[A-Za-z][A-Za-z0-9_]*)\b'

    $declMatches = New-Object System.Collections.Generic.HashSet[string]
    foreach ($matchInfo in (Select-String -LiteralPath $file.FullName -Pattern $declPattern -AllMatches)) {
        if ($targetRanges.Count -gt 0 -and (Get-Command Test-LineInRanges -ErrorAction SilentlyContinue)) {
            if (-not (Test-LineInRanges -Ranges $targetRanges -LineNumber $matchInfo.LineNumber)) {
                continue
            }
        }

        foreach ($m in $matchInfo.Matches) {
            $field = $m.Groups['field'].Value
            if (-not [string]::IsNullOrWhiteSpace($field)) {
                [void]$declMatches.Add($field)
            }
        }
    }

    $declMatches = @($declMatches | Sort-Object)

    foreach ($oldFieldName in $declMatches) {
        $newFieldName = Get-CamelCasedPrivateFieldName -FieldName $oldFieldName

        if ($newFieldName -eq $oldFieldName) {
            continue
        }

        # Guard against creating ambiguous duplicates within the same file.
        if ($content -match "\b$([regex]::Escape($newFieldName))\b") {
            Write-Host "Skipping $($file.FullName): would rename $oldFieldName -> $newFieldName but $newFieldName already exists in file" -ForegroundColor Yellow
            continue
        }

        if ($WhatIf) {
            Write-Host "Would fix in $($file.FullName): $oldFieldName -> $newFieldName" -ForegroundColor Yellow
        } else {
            $content = Update-WholeWord -Content $content -OldName $oldFieldName -NewName $newFieldName
            Write-Host "Fixed in $($file.FullName): $oldFieldName -> $newFieldName" -ForegroundColor Green
            $fixedCount++
        }
    }

    if (-not $WhatIf -and $content -ne $originalContent) {
        Set-Content -LiteralPath $file.FullName -Value $content -NoNewline
    }
}

if ($WhatIf) {
    Write-Host "`nWhatIf mode: No changes were made. Remove -WhatIf to apply fixes." -ForegroundColor Cyan
    exit 0
}

Write-Host "`nFixed $fixedCount IDE1006 private field casing violation(s)." -ForegroundColor Green
exit 0



