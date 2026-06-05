#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Enable a specific analyzer by modifying configuration files

.DESCRIPTION
    This script enables a single analyzer at a time by:
    - Finding where the analyzer is disabled (NoWarn, .editorconfig severity = none)
    - Changing severity from "none" to "warning" or "error"
    - Removing from NoWarn lists
    - Reporting what was changed

.PARAMETER AnalyzerId
    The analyzer ID to enable (e.g., CA1062, CS1591, IDE1006)

.PARAMETER Severity
    Target severity level: "error", "warning", "suggestion". Default: "warning"

.PARAMETER WhatIf
    Show what would be changed without actually changing anything

.PARAMETER ConfigFile
    Specific config file to modify (.editorconfig, Directory.Build.props, or project file)
    If not specified, auto-detects where the analyzer is configured

.EXAMPLE
    .\enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning
    Enable CA1062 analyzer as a warning

.EXAMPLE
    .\enable-analyzer.ps1 -AnalyzerId CS1591 -Severity error -WhatIf
    Show what would change to enable CS1591 as an error (without actually changing)

.EXAMPLE
    .\enable-analyzer.ps1 -AnalyzerId IDE1006 -ConfigFile .editorconfig
    Enable IDE1006 in .editorconfig specifically

.NOTES
    File Name      : enable-analyzer.ps1
    Prerequisite   : PowerShell 7.2+
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Analyzer ID to enable (e.g., CA1062, CS1591)")]
    [ValidatePattern('^[A-Z]{2,4}\d{4}$')]
    [string]$AnalyzerId,

    [Parameter(Mandatory = $false, HelpMessage = "Target severity: error, warning, suggestion")]
    [ValidateSet('error', 'warning', 'suggestion')]
    [string]$Severity = 'warning',

    [Parameter(Mandatory = $false, HelpMessage = "Show changes without applying them")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Specific config file to modify")]
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Shared helper module (repo root detection, consistent output)
$commonModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (Test-Path $commonModulePath) {
    try {
        Import-Module $commonModulePath -Force -ErrorAction Stop
    } catch {
        # Continue without shared module.
    }
}

# Unicode support with fallbacks
$script:SupportsUnicode = $PSVersionTable.PSVersion.Major -ge 7 -and 
                          [System.Console]::OutputEncoding.EncodingName -notlike '*ASCII*'

function Write-StatusIcon {
    param([string]$Type)
    
    if (-not $script:SupportsUnicode) {
        switch ($Type) {
            'success' { Write-Host '[OK]' -ForegroundColor Green -NoNewline }
            'error' { Write-Host '[ERROR]' -ForegroundColor Red -NoNewline }
            'warning' { Write-Host '[WARN]' -ForegroundColor Yellow -NoNewline }
            'info' { Write-Host '[INFO]' -ForegroundColor Cyan -NoNewline }
        }
    } else {
        switch ($Type) {
            'success' { Write-Host '✅' -NoNewline }
            'error' { Write-Host '❌' -NoNewline }
            'warning' { Write-Host '⚠️ ' -NoNewline }
            'info' { Write-Host 'ℹ️ ' -NoNewline }
        }
    }
    Write-Host ' '
}

function Find-AnalyzerConfiguration {
    param([string]$AnalyzerId)
    
    $locations = @()
    $repoRoot = if (Get-Command Get-RepoRoot -ErrorAction SilentlyContinue) { Get-RepoRoot -StartPath (Get-Location).Path } else { (Get-Location).Path }
    
    # Check .editorconfig
    $editorConfigs = Get-ChildItem -Path $repoRoot -Filter '.editorconfig' -Recurse -ErrorAction SilentlyContinue
    foreach ($editorConfig in $editorConfigs) {
        $content = Get-Content $editorConfig.FullName -Raw
        if ($content -match "dotnet_diagnostic\.$AnalyzerId\.severity\s*=\s*none") {
            $locations += @{
                File = $editorConfig.FullName
                Type = 'EditorConfig'
                Pattern = "dotnet_diagnostic\.$AnalyzerId\.severity\s*=\s*none"
                CurrentValue = 'none'
            }
        }
    }
    
    # Check Directory.Build.props for NoWarn
    $buildPropsFiles = Get-ChildItem -Path $repoRoot -Filter 'Directory.Build.props' -Recurse -ErrorAction SilentlyContinue
    foreach ($buildProps in $buildPropsFiles) {
        $content = Get-Content $buildProps.FullName -Raw
        if ($content -match "<NoWarn>([^<]*\b$AnalyzerId\b[^<]*)</NoWarn>") {
            $locations += @{
                File = $buildProps.FullName
                Type = 'NoWarn'
                Pattern = $AnalyzerId
                CurrentValue = $Matches[1]
            }
        }
    }
    
    # Check project files for NoWarn
    Get-ChildItem -Path $repoRoot -Filter '*.csproj' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match "<NoWarn>([^<]*\b$AnalyzerId\b[^<]*)</NoWarn>") {
            $locations += @{
                File = $_.FullName
                Type = 'NoWarn'
                Pattern = $AnalyzerId
                CurrentValue = $Matches[1]
            }
        }
    }
    
    return $locations
}

function Enable-InEditorConfig {
    param(
        [string]$FilePath,
        [string]$AnalyzerId,
        [string]$TargetSeverity,
        [bool]$DryRun
    )
    
    $content = Get-Content $FilePath -Raw
    $pattern = "dotnet_diagnostic\.$AnalyzerId\.severity\s*=\s*none"
    $replacement = "dotnet_diagnostic.$AnalyzerId.severity = $TargetSeverity"
    
    if ($content -match $pattern) {
        Write-StatusIcon 'info'
        Write-Host "Found in .editorconfig: " -NoNewline
        Write-Host "$FilePath" -ForegroundColor Cyan
        Write-Host "  Current: " -NoNewline -ForegroundColor Gray
        Write-Host "dotnet_diagnostic.$AnalyzerId.severity = none" -ForegroundColor Red
        Write-Host "  Target:  " -NoNewline -ForegroundColor Gray
        Write-Host "dotnet_diagnostic.$AnalyzerId.severity = $TargetSeverity" -ForegroundColor Green
        
        if (-not $DryRun) {
            $newContent = $content -replace $pattern, $replacement
            Set-Content -Path $FilePath -Value $newContent -NoNewline
            Write-StatusIcon 'success'
            Write-Host "Updated .editorconfig" -ForegroundColor Green
        } else {
            Write-Host "  [DRY RUN - No changes made]" -ForegroundColor Yellow
        }
        
        return $true
    }
    
    return $false
}

function Enable-InNoWarn {
    param(
        [string]$FilePath,
        [string]$AnalyzerId,
        [bool]$DryRun
    )
    
    $content = Get-Content $FilePath -Raw
    
    if ($content -match "<NoWarn>([^<]*\b$AnalyzerId\b[^<]*)</NoWarn>") {
        $currentNoWarn = $Matches[1]
        
        Write-StatusIcon 'info'
        Write-Host "Found in NoWarn: " -NoNewline
        Write-Host "$FilePath" -ForegroundColor Cyan
        Write-Host "  Current: " -NoNewline -ForegroundColor Gray
        Write-Host "<NoWarn>$currentNoWarn</NoWarn>" -ForegroundColor Red
        
        # Remove the analyzer from NoWarn list
        $codes = $currentNoWarn -split ';' | Where-Object { $_ -ne $AnalyzerId -and $_.Trim() -ne '' }
        $newNoWarn = $codes -join ';'
        
        Write-Host "  Target:  " -NoNewline -ForegroundColor Gray
        if ($newNoWarn) {
            Write-Host "<NoWarn>$newNoWarn</NoWarn>" -ForegroundColor Green
        } else {
            Write-Host "<NoWarn></NoWarn> (empty - consider removing line)" -ForegroundColor Green
        }
        
        if (-not $DryRun) {
            if ($newNoWarn) {
                $newContent = $content -replace "<NoWarn>$([regex]::Escape($currentNoWarn))</NoWarn>", "<NoWarn>$newNoWarn</NoWarn>"
            } else {
                # Remove the entire NoWarn element if empty
                $newContent = $content -replace "\s*<NoWarn>$([regex]::Escape($currentNoWarn))</NoWarn>\s*", "`n"
            }
            Set-Content -Path $FilePath -Value $newContent -NoNewline
            Write-StatusIcon 'success'
            Write-Host "Updated NoWarn list" -ForegroundColor Green
        } else {
            Write-Host "  [DRY RUN - No changes made]" -ForegroundColor Yellow
        }
        
        return $true
    }
    
    return $false
}

# Main execution
Write-Host "`n"
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Enable Analyzer: $AnalyzerId" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-StatusIcon 'warning'
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Find where analyzer is configured
Write-Host "🔍 Searching for analyzer configuration..." -ForegroundColor Cyan
Write-Host ""

$locations = Find-AnalyzerConfiguration -AnalyzerId $AnalyzerId

if ($locations.Count -eq 0) {
    Write-StatusIcon 'error'
    Write-Host "Analyzer $AnalyzerId not found in any configuration file" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  • Analyzer is already enabled" -ForegroundColor Gray
    Write-Host "  • Analyzer ID is incorrect" -ForegroundColor Gray
    Write-Host "  • Analyzer is not configured in this repository" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-StatusIcon 'info'
Write-Host "Found $($locations.Count) configuration(s) for $AnalyzerId" -ForegroundColor Cyan
Write-Host ""

# Enable analyzer in each location
$changedCount = 0
foreach ($location in $locations) {
    if ($ConfigFile -and $location.File -ne $ConfigFile) {
        Write-Host "Skipping $($location.File) (not target file)" -ForegroundColor Gray
        continue
    }
    
    $changed = $false
    
    if ($location.Type -eq 'EditorConfig') {
        $changed = Enable-InEditorConfig -FilePath $location.File -AnalyzerId $AnalyzerId -TargetSeverity $Severity -DryRun:$WhatIf
    } elseif ($location.Type -eq 'NoWarn') {
        $changed = Enable-InNoWarn -FilePath $location.File -AnalyzerId $AnalyzerId -DryRun:$WhatIf
    }
    
    if ($changed) {
        $changedCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($changedCount -gt 0) {
    Write-StatusIcon 'success'
    if ($WhatIf) {
        Write-Host "Would enable $AnalyzerId in $changedCount location(s)" -ForegroundColor Green
    } else {
        Write-Host "Enabled $AnalyzerId in $changedCount location(s)" -ForegroundColor Green
    }
} else {
    Write-StatusIcon 'warning'
    Write-Host "No changes made" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not $WhatIf -and $changedCount -gt 0) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run build to see new diagnostics: " -NoNewline -ForegroundColor Gray
    Write-Host ".\build-and-find-errors.ps1 -ErrorType $AnalyzerId" -ForegroundColor White
    Write-Host "  2. Fix errors with auto-fix: " -NoNewline -ForegroundColor Gray
    Write-Host "dotnet format" -ForegroundColor White
    Write-Host "  3. Track progress: " -NoNewline -ForegroundColor Gray
    Write-Host ".\track-analyzer-progress.ps1 -AnalyzerId $AnalyzerId -Status in-progress" -ForegroundColor White
    Write-Host ""
}

