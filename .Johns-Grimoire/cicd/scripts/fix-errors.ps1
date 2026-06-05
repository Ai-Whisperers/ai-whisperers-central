#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated error fix script for CI/CD quality checks
.DESCRIPTION
    Automatically fixes common errors to achieve zero-error goal
    Part of the Zero Errors, Zero Warnings quality initiative
.PARAMETER Fix
    Type of error to fix
.PARAMETER Version
    Version number for fixes that require it
.PARAMETER DryRun
    Show what would be fixed without making changes
.EXAMPLE
    .\fix-errors.ps1 -Fix MissingChangelog -Version "1.0.0-rc1"
.EXAMPLE
    .\fix-errors.ps1 -Fix All -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'MissingChangelog',
        'InvalidTagContext',
        'MissingXmlFiles',
        'All'
    )]
    [string]$Fix,
    
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         Automated Error Fix - Zero Errors Goal               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if ($DryRun) {
    Write-Log "DRY RUN MODE - No changes will be made" -Level WARN
}

Write-Log "Fix Type: $Fix"
if ($Version) {
    Write-Log "Version: $Version"
}

function Fix-MissingChangelog {
    param([string]$ReleaseVersion)
    
    Write-Log "Generating CHANGELOG entry for version: $ReleaseVersion"
    
    $changelogPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "CHANGELOG.md"
    
    if (-not (Test-Path $changelogPath)) {
        Write-Log "CHANGELOG.md not found, creating new file" -Level WARN
        
        if (-not $DryRun) {
            @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

"@ | Set-Content $changelogPath -Encoding UTF8
        }
    }
    
    # Get git commits since last tag
    $lastTag = git describe --tags --abbrev=0 2>$null
    $commits = if ($lastTag) {
        git log "$lastTag..HEAD" --pretty=format:"%s" 2>$null
    } else {
        git log --pretty=format:"%s" 2>$null
    }
    
    if (-not $commits) {
        Write-Log "No commits found for changelog" -Level WARN
        return $false
    }
    
    # Categorize commits
    $added = $commits | Where-Object { $_ -match '^(feat|feature):' }
    $changed = $commits | Where-Object { $_ -match '^(change|refactor|perf):' }
    $fixed = $commits | Where-Object { $_ -match '^(fix|bugfix):' }
    $breaking = $commits | Where-Object { $_ -match 'BREAKING CHANGE' }
    
    $entry = @"

## [$ReleaseVersion] - $(Get-Date -Format yyyy-MM-dd)

"@
    
    if ($breaking) {
        $entry += "`n### Breaking Changes`n"
        foreach ($commit in $breaking) {
            $entry += "- $commit`n"
        }
    }
    
    if ($added) {
        $entry += "`n### Added`n"
        foreach ($commit in $added) {
            $msg = $commit -replace '^(feat|feature):\s*', ''
            $entry += "- $msg`n"
        }
    }
    
    if ($changed) {
        $entry += "`n### Changed`n"
        foreach ($commit in $changed) {
            $msg = $commit -replace '^(change|refactor|perf):\s*', ''
            $entry += "- $msg`n"
        }
    }
    
    if ($fixed) {
        $entry += "`n### Fixed`n"
        foreach ($commit in $fixed) {
            $msg = $commit -replace '^(fix|bugfix):\s*', ''
            $entry += "- $msg`n"
        }
    }
    
    if ($DryRun) {
        Write-Log "Would add the following to CHANGELOG.md:" -Level WARN
        Write-Host $entry -ForegroundColor Cyan
    } else {
        $content = Get-Content $changelogPath -Raw
        $newContent = $content -replace "(# Changelog\s+.*?## \[)", "`$1`n$entry`n## ["
        if ($newContent -eq $content) {
            # No existing entries, add after header
            $newContent = $content + $entry
        }
        $newContent | Set-Content $changelogPath -Encoding UTF8
        Write-Log "CHANGELOG entry added successfully" -Level SUCCESS
    }
    
    return $true
}

function Fix-MissingXmlFiles {
    Write-Log "Ensuring XML documentation files are generated"
    
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $projects = Get-ChildItem -Path "$repoRoot/src" -Filter "*.csproj" -Recurse
    
    $fixed = 0
    foreach ($project in $projects) {
        [xml]$proj = Get-Content $project.FullName
        $propertyGroup = $proj.Project.PropertyGroup | Select-Object -First 1
        
        if (-not $propertyGroup.GenerateDocumentationFile -or $propertyGroup.GenerateDocumentationFile -ne 'true') {
            Write-Log "  Enabling documentation generation for: $($project.Name)" -Level SUCCESS
            
            if (-not $DryRun) {
                if (-not $propertyGroup.GenerateDocumentationFile) {
                    $newElement = $proj.CreateElement('GenerateDocumentationFile')
                    $newElement.InnerText = 'true'
                    $propertyGroup.AppendChild($newElement) | Out-Null
                } else {
                    $propertyGroup.GenerateDocumentationFile = 'true'
                }
                $proj.Save($project.FullName)
            }
            $fixed++
        }
    }
    
    if ($fixed -gt 0) {
        if (-not $DryRun) {
            Write-Log "Enabled documentation generation in $fixed project(s)" -Level SUCCESS
            Write-Log "Run 'dotnet build' to generate XML files" -Level INFO
        } else {
            Write-Log "Would enable documentation generation in $fixed project(s)" -Level WARN
        }
    } else {
        Write-Log "All projects already have documentation generation enabled" -Level SUCCESS
    }
    
    return $true
}

function Fix-All {
    Write-Log "Running all automated error fixes..."
    
    $allSuccess = $true
    
    # Fix missing XML generation
    Write-Log "`nFixing XML documentation generation..." -Level INFO
    if (-not (Fix-MissingXmlFiles)) {
        $allSuccess = $false
    }
    
    # Other fixes require version/context
    if ($Version) {
        Write-Log "`nFixing missing CHANGELOG entry..." -Level INFO
        if (-not (Fix-MissingChangelog -ReleaseVersion $Version)) {
            $allSuccess = $false
        }
    }
    
    return $allSuccess
}

# Main execution
try {
    $success = switch ($Fix) {
        'MissingChangelog' {
            if (-not $Version) {
                Write-Log "Version parameter required for MissingChangelog fix" -Level ERROR
                $false
            } else {
                Fix-MissingChangelog -ReleaseVersion $Version
            }
        }
        'MissingXmlFiles' { Fix-MissingXmlFiles }
        'InvalidTagContext' {
            Write-Log -Message "Invalid tag context requires manual intervention" -Level ERROR -AIFix (Get-ErrorFix -ErrorType 'InvalidTagContext' -Context @{Tag = $Version})
            $false
        }
        'All' { Fix-All }
    }
    
    if ($success) {
        Write-Log "`nError fix completed successfully!" -Level SUCCESS
        exit 0
    } else {
        Write-Log "`nError fix completed with some issues" -Level ERROR
        exit 1
    }
    
} catch {
    Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

