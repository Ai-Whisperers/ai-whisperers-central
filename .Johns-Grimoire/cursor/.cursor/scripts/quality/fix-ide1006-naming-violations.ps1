#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE1006 naming rule violations by normalizing private field names to `_camelCase`

.DESCRIPTION
    This script fixes common IDE1006 violations for private fields:
    - Adds `_` prefix when missing
    - Ensures the first character after `_` is lower-case (e.g., `_Type1Array` -> `_type1Array`)

.PARAMETER Path
    The path to search for C# files. Defaults to current directory.

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-naming-violations.ps1
    Fixes all naming violations in the current directory

.EXAMPLE
    .\fix-ide1006-naming-violations.ps1 -Path "src/" -WhatIf
    Shows what would be fixed in the src directory without making changes
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

$ErrorActionPreference = 'Stop'

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

# Diagnostics helpers (optional)
$diagnosticsModulePath = Join-Path $PSScriptRoot 'modules\Diagnostics.psm1'
if (Test-Path $diagnosticsModulePath) {
    Import-Module $diagnosticsModulePath -Force
}

# Find all C# files
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
    $content = Get-Content -Path $file.FullName -Raw
    if ($null -eq $content -or $content -eq "") {
        continue
    }
    $originalContent = $content

    $targetRanges = @()
    if ($null -ne $rangesByFile -and $rangesByFile.ContainsKey($file.FullName)) {
        $targetRanges = @($rangesByFile[$file.FullName])
    }

    $lineStarts = $null
    if ($targetRanges.Count -gt 0 -and (Get-Command New-LineIndex -ErrorAction SilentlyContinue)) {
        $lineStarts = New-LineIndex -Text $content
    }

    # Pattern to match private field declarations
    # Matches: private [modifiers] type fieldName [= initializer];
    # Excludes: const fields (const fields should be PascalCase per .editorconfig naming rules)
    #
    # Captures:
    #  - Group 1: type token
    #  - Group 2: field name (supports optional leading underscore)
    # Allow common modifier combinations in any order (e.g., "static readonly", "readonly static").
    $pattern = '(?m)^\s*private\s+(?!const\s)(?:(?:static|readonly|volatile)\s+)*([^\s]+)\s+(_?[a-zA-Z][a-zA-Z0-9_]*)\s*(?:=\s*[^;]+)?;'

    $matches = [regex]::Matches($content, $pattern)

    foreach ($match in $matches) {
        if ($targetRanges.Count -gt 0 -and $null -ne $lineStarts -and (Get-Command Get-LineNumberFromIndex -ErrorAction SilentlyContinue) -and (Get-Command Test-LineInRanges -ErrorAction SilentlyContinue)) {
            $matchLine = Get-LineNumberFromIndex -LineStarts $lineStarts -Index $match.Index
            if (-not (Test-LineInRanges -Ranges $targetRanges -LineNumber $matchLine)) {
                continue
            }
        }

        $fullMatch = $match.Groups[0].Value
        $fieldName = $match.Groups[2].Value

        $newFieldName = $null

        if ($fieldName.StartsWith('_')) {
            # Already has underscore; ensure camelCase after underscore.
            if ($fieldName.Length -gt 1) {
                $afterUnderscore = $fieldName.Substring(1)
                if ($afterUnderscore.Length -gt 0 -and [char]::IsUpper($afterUnderscore[0])) {
                    $newFieldName = '_' + [char]::ToLower($afterUnderscore[0]) + $afterUnderscore.Substring(1)
                }
            }
        } else {
            # Missing underscore; add it and enforce camelCase.
            $newFieldName = '_' + [char]::ToLower($fieldName[0]) + $fieldName.Substring(1)
        }

        if (-not $newFieldName -or $newFieldName -eq $fieldName) {
            continue
        }

        $fixed = $fullMatch -replace "(\s+)($([regex]::Escape($fieldName)))(\s*)", "`$1$($newFieldName)`$3"

        if ($WhatIf) {
            Write-Host "Would fix in $($file.FullName): $fieldName -> $newFieldName" -ForegroundColor Yellow
        } else {
            $content = $content.Replace($fullMatch, $fixed)
            Write-Host "Fixed in $($file.FullName): $fieldName -> $newFieldName" -ForegroundColor Green
            $fixedCount++
        }
    }

    # Save the file if changes were made
    if (-not $WhatIf -and $content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
    }
}

if ($WhatIf) {
    Write-Host "`nWhatIf mode: No changes were made. Remove -WhatIf to apply fixes." -ForegroundColor Cyan
} else {
    Write-Host "`nFixed $fixedCount naming violations." -ForegroundColor Green
}

