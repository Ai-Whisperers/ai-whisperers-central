#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes IDE1006 resource field reference violations in generated code

.DESCRIPTION
    Fixes references to resource fields (like resourceMan, resourceCulture)
    in auto-generated Resource.Designer.cs files when field names are updated.

.PARAMETER FilePath
    Path to the Resources.Designer.cs file

.PARAMETER WhatIf
    Shows what would be changed without actually making changes.

.EXAMPLE
    .\fix-ide1006-resource-references.ps1 -FilePath "Resources.Designer.cs"
    Fixes resource field references in the designer file

.EXAMPLE
    .\fix-ide1006-resource-references.ps1 -FilePath "Resources.Designer.cs" -WhatIf
    Shows what resource references would be fixed
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

if (Test-Path $FilePath) {
    $content = Get-Content -Path $FilePath -Raw
    $originalContent = $content

    # Replace field references (only where they're used as variables, not in field declarations)
    $replacements = @(
        @{ Pattern = '\bresourceMan\b'; Replacement = '_resourceMan' }
        @{ Pattern = '\bresourceCulture\b'; Replacement = '_resourceCulture' }
    )

    $changed = $false
    foreach ($replacement in $replacements) {
        # Use regex replace with word boundaries to avoid replacing parts of other words
        $newContent = [regex]::Replace($content, $replacement.Pattern, $replacement.Replacement)

        if ($newContent -ne $content) {
            if ($WhatIf) {
                Write-Host "Would replace $($replacement.Pattern) with $($replacement.Replacement) in $FilePath" -ForegroundColor Yellow
            } else {
                $content = $newContent
                Write-Host "Replaced $($replacement.Pattern) with $($replacement.Replacement) in $FilePath" -ForegroundColor Green
                $changed = $true
            }
        }
    }

    if (-not $WhatIf -and $changed) {
        Set-Content -Path $FilePath -Value $content -NoNewline
    }

    if ($WhatIf) {
        Write-Host "`nWhatIf mode: No changes were made." -ForegroundColor Cyan
    } elseif ($changed) {
        Write-Host "`nFixed resource field references in $FilePath." -ForegroundColor Green
    } else {
        Write-Host "`nNo resource field references needed fixing in $FilePath." -ForegroundColor Cyan
    }
} else {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    exit 1
}

