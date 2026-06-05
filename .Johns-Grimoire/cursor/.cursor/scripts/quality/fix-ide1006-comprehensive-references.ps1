#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Comprehensive IDE1006 field reference fixer for multiple files

.DESCRIPTION
    Fixes all field references across multiple files when field names
    are changed to comply with IDE1006 naming conventions.

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-comprehensive-references.ps1
    Fixes field references in all configured files

.EXAMPLE
    .\fix-ide1006-comprehensive-references.ps1 -WhatIf
    Shows what field references would be fixed across all files
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the reference fixer")]
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
                Write-Host "Roslyn pre-pass applied fixes via dotnet format (IDE1006). Continuing with reference fixer for any remaining cases." -ForegroundColor Gray
            } else {
                Write-Host "Roslyn pre-pass ran but did not apply fixes (IDE1006). Continuing with reference fixer." -ForegroundColor Gray
            }
        } else {
            Write-Host "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with reference fixer." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with reference fixer." -ForegroundColor Gray
    }
}

# List of all files that need field reference fixes
$filesToFix = @(
    # Add file paths that need reference fixes
    # "path/to/TestFile.cs"
)

# Field reference mappings
$fieldMappings = @(
    # Add mappings like:
    # @{ Old = 'oldFieldName'; New = '_newFieldName' }
)

$totalFixed = 0

foreach ($filePath in $filesToFix) {
    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -Raw
        $originalContent = $content
        $fileChanged = $false

        foreach ($mapping in $fieldMappings) {
            # Use regex replace with word boundaries to avoid replacing parts of other words
            $pattern = '\b' + [regex]::Escape($mapping.Old) + '\b'
            $newContent = [regex]::Replace($content, $pattern, $mapping.New)

            if ($newContent -ne $content) {
                if ($WhatIf) {
                    Write-Host "Would replace $($mapping.Old) with $($mapping.New) in $filePath" -ForegroundColor Yellow
                } else {
                    $content = $newContent
                    Write-Host "Replaced $($mapping.Old) with $($mapping.New) in $filePath" -ForegroundColor Green
                    $fileChanged = $true
                    $totalFixed++
                }
            }
        }

        if (-not $WhatIf -and $fileChanged) {
            Set-Content -Path $filePath -Value $content -NoNewline
        }
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
    }
}

if ($WhatIf) {
    Write-Host "`nWhatIf mode: No changes were made." -ForegroundColor Cyan
} else {
    Write-Host "`nTotal field references fixed: $totalFixed" -ForegroundColor Green
}

