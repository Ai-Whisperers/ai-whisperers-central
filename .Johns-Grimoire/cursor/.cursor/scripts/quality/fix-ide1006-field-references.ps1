#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE1006 field reference violations after field names are updated

.DESCRIPTION
    When field names are changed to comply with naming conventions,
    this script updates all references to use the corrected field names.

.PARAMETER FilePath
    Path to the specific file to fix references in

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-field-references.ps1 -FilePath "TestClass.cs"
    Fixes field references in a specific file

.EXAMPLE
    .\fix-ide1006-field-references.ps1 -FilePath "TestClass.cs" -WhatIf
    Shows what references would be fixed without making changes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

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
        $start = (Resolve-Path -Path $FilePath -ErrorAction SilentlyContinue)
        $startPath = if ($start) { $start.Path } else { $FilePath }
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

# Field reference mappings - update these based on renamed fields
$fieldMappings = @(
    # Add mappings like:
    # @{ Old = 'oldFieldName'; New = '_newFieldName' }
)

$fixedCount = 0

if (Test-Path $FilePath) {
    $content = Get-Content -Path $FilePath -Raw
    $originalContent = $content

    foreach ($mapping in $fieldMappings) {
        # Use regex replace with word boundaries to avoid replacing parts of other words
        $pattern = '\b' + [regex]::Escape($mapping.Old) + '\b'
        $newContent = [regex]::Replace($content, $pattern, $mapping.New)

        if ($newContent -ne $content) {
            if ($WhatIf) {
                Write-Host "Would replace $($mapping.Old) with $($mapping.New) in $FilePath" -ForegroundColor Yellow
            } else {
                $content = $newContent
                Write-Host "Replaced $($mapping.Old) with $($mapping.New) in $FilePath" -ForegroundColor Green
                $fixedCount++
            }
        }
    }

    if (-not $WhatIf -and $content -ne $originalContent) {
        Set-Content -Path $FilePath -Value $content -NoNewline
    }
} else {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    exit 1
}

if ($WhatIf) {
    Write-Host "`nWhatIf mode: No changes were made." -ForegroundColor Cyan
} else {
    Write-Host "`nFixed $fixedCount field references." -ForegroundColor Green
}

