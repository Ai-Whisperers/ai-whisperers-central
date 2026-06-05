#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes specific IDE1006 naming rule violations using targeted patterns

.DESCRIPTION
    This script applies targeted fixes for known IDE1006 naming violations
    that follow specific patterns, useful when you know exactly what needs fixing.

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-targeted-patterns.ps1
    Applies targeted fixes for known naming violations

.EXAMPLE
    .\fix-ide1006-targeted-patterns.ps1 -WhatIf
    Shows what would be fixed without making changes
#>

[CmdletBinding()]
param(
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the targeted fixer")]
    [switch]$SkipRoslyn
)

$ErrorActionPreference = 'Stop'

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

if (-not $SkipRoslyn -and -not $WhatIf -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
    try {
        $startPath = (Get-Location).Path
        $roslynResult = Invoke-RoslynFormatFix -StartPath $startPath -Diagnostics @('IDE1006') -Severity 'info' -Include @($startPath)
        if ($roslynResult.Attempted) {
            if ($roslynResult.Applied) {
                Write-Host "Roslyn pre-pass applied fixes via dotnet format (IDE1006). Continuing with targeted fixer for any remaining cases." -ForegroundColor Gray
            } else {
                Write-Host "Roslyn pre-pass ran but did not apply fixes (IDE1006). Continuing with targeted fixer." -ForegroundColor Gray
            }
        } else {
            Write-Host "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with targeted fixer." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with targeted fixer." -ForegroundColor Gray
    }
}

# Add your targeted fix patterns here
# This is a template - update patterns based on specific violations found
$fixes = @(
    # Example patterns - update these based on actual violations
    # @{
    #     File = "path/to/file.cs"
    #     Pattern = 'exact pattern to match'
    #     Replacement = 'corrected pattern'
    # }
)

$fixedCount = 0

foreach ($fix in $fixes) {
    $filePath = $fix.File
    $pattern = $fix.Pattern
    $replacement = $fix.Replacement

    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -Raw
        if ($content -match [regex]::Escape($pattern)) {
            if ($WhatIf) {
                Write-Host "Would fix in $filePath" -ForegroundColor Yellow
                Write-Host "  Pattern: $pattern" -ForegroundColor Gray
                Write-Host "  Replacement: $replacement" -ForegroundColor Gray
            } else {
                $content = $content -replace [regex]::Escape($pattern), $replacement
                Set-Content -Path $filePath -Value $content -NoNewline
                Write-Host "Fixed in $filePath" -ForegroundColor Green
                $fixedCount++
            }
        } else {
            Write-Host "Pattern not found in $filePath" -ForegroundColor Red
        }
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
    }
}

if ($WhatIf) {
    Write-Host "`nWhatIf mode: No changes were made. Remove -WhatIf to apply fixes." -ForegroundColor Cyan
} else {
    Write-Host "`nFixed $fixedCount naming violations." -ForegroundColor Green
}

