#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Track progress of analyzer enablement

.DESCRIPTION
    This script maintains a progress.json file that tracks which analyzers have been
    enabled, fixed, and completed. Provides reporting on enablement progress.

.PARAMETER AnalyzerId
    The analyzer ID to update (e.g., CA1062, CS1591, IDE1006)

.PARAMETER Status
    Status: "pending", "in-progress", "completed", "skipped"

.PARAMETER ErrorsFixed
    Number of errors fixed (optional, for tracking metrics)

.PARAMETER Notes
    Additional notes about the analyzer (optional)

.PARAMETER Report
    Generate a progress report instead of updating progress

.PARAMETER ReportFormat
    Format for report: "console" (default), "json", "markdown"

.PARAMETER ProgressFile
    Path to progress file. Default: .cursor/scripts/quality/analyzer-progress.json

.EXAMPLE
    .\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status in-progress
    Mark CA1062 as in-progress

.EXAMPLE
    .\track-analyzer-progress.ps1 -AnalyzerId CS1591 -Status completed -ErrorsFixed 45
    Mark CS1591 as completed with 45 errors fixed

.EXAMPLE
    .\track-analyzer-progress.ps1 -Report
    Show progress report

.EXAMPLE
    .\track-analyzer-progress.ps1 -Report -ReportFormat markdown
    Generate markdown progress report

.NOTES
    File Name      : track-analyzer-progress.ps1
    Prerequisite   : PowerShell 7.2+
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Analyzer ID (e.g., CA1062, CS1591)")]
    [ValidatePattern('^[A-Z]{2,4}\d{4}$')]
    [string]$AnalyzerId,

    [Parameter(Mandatory = $false, HelpMessage = "Status: pending, in-progress, completed, skipped")]
    [ValidateSet('pending', 'in-progress', 'completed', 'skipped')]
    [string]$Status,

    [Parameter(Mandatory = $false, HelpMessage = "Number of errors fixed")]
    [int]$ErrorsFixed = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Additional notes")]
    [string]$Notes,

    [Parameter(Mandatory = $false, HelpMessage = "Generate progress report")]
    [switch]$Report,

    [Parameter(Mandatory = $false, HelpMessage = "Report format: console, json, markdown")]
    [ValidateSet('console', 'json', 'markdown')]
    [string]$ReportFormat = 'console',

    [Parameter(Mandatory = $false, HelpMessage = "Progress file path")]
    [string]$ProgressFile = '.cursor/scripts/quality/analyzer-progress.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
            'pending' { Write-Host '[PENDING]' -ForegroundColor Gray -NoNewline }
            'progress' { Write-Host '[WORKING]' -ForegroundColor Yellow -NoNewline }
            'complete' { Write-Host '[DONE]' -ForegroundColor Green -NoNewline }
        }
    } else {
        switch ($Type) {
            'success' { Write-Host '✅' -NoNewline }
            'error' { Write-Host '❌' -NoNewline }
            'warning' { Write-Host '⚠️ ' -NoNewline }
            'info' { Write-Host 'ℹ️ ' -NoNewline }
            'pending' { Write-Host '⏳' -NoNewline }
            'progress' { Write-Host '🔄' -NoNewline }
            'complete' { Write-Host '✅' -NoNewline }
        }
    }
    Write-Host ' '
}

function Initialize-ProgressFile {
    param([string]$Path)
    
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    if (-not (Test-Path $Path)) {
        $initial = @{
            version = '1.0'
            lastUpdated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            analyzers = @{}
        }
        $initial | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    }
}

function Read-Progress {
    param([string]$Path)
    
    Initialize-ProgressFile -Path $Path
    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $content
}

function Write-Progress {
    param(
        [string]$Path,
        [object]$Data
    )
    
    $Data.lastUpdated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
}

function Update-AnalyzerProgress {
    param(
        [string]$Path,
        [string]$AnalyzerId,
        [string]$Status,
        [int]$ErrorsFixed,
        [string]$Notes
    )
    
    $progress = Read-Progress -Path $Path
    
    if (-not $progress.analyzers.$AnalyzerId) {
        $progress.analyzers | Add-Member -NotePropertyName $AnalyzerId -NotePropertyValue @{
            status = $Status
            errorsFixed = $ErrorsFixed
            startDate = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            lastUpdated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            completedDate = $null
            notes = $Notes
        }
    } else {
        $analyzer = $progress.analyzers.$AnalyzerId
        
        if ($Status) {
            $analyzer.status = $Status
        }
        
        if ($ErrorsFixed -gt 0) {
            $analyzer.errorsFixed = $ErrorsFixed
        }
        
        if ($Notes) {
            $analyzer.notes = $Notes
        }
        
        $analyzer.lastUpdated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        
        if ($Status -eq 'completed') {
            $analyzer.completedDate = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        }
    }
    
    Write-Progress -Path $Path -Data $progress
}

function Show-ConsoleReport {
    param([object]$Progress)
    
    $analyzers = $Progress.analyzers.PSObject.Properties
    
    $pending = $analyzers | Where-Object { $_.Value.status -eq 'pending' }
    $inProgress = $analyzers | Where-Object { $_.Value.status -eq 'in-progress' }
    $completed = $analyzers | Where-Object { $_.Value.status -eq 'completed' }
    $skipped = $analyzers | Where-Object { $_.Value.status -eq 'skipped' }
    
    $total = $analyzers.Count
    $completedCount = $completed.Count
    $percentComplete = if ($total -gt 0) { [math]::Round(($completedCount / $total) * 100, 1) } else { 0 }
    
    Write-Host "`n"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Analyzer Enablement Progress" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Last Updated: " -NoNewline -ForegroundColor Gray
    Write-Host $Progress.lastUpdated -ForegroundColor White
    Write-Host ""
    
    # Summary
    Write-Host "Progress: " -NoNewline -ForegroundColor Cyan
    Write-Host "$completedCount / $total analyzers ($percentComplete%)" -ForegroundColor White
    Write-Host ""
    
    # Completed
    if ($completed.Count -gt 0) {
        Write-StatusIcon 'complete'
        Write-Host "Completed ($($completed.Count)):" -ForegroundColor Green
        foreach ($analyzer in $completed | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            Write-Host "  • $id " -ForegroundColor Green -NoNewline
            if ($data.errorsFixed -gt 0) {
                Write-Host "($($data.errorsFixed) errors fixed)" -ForegroundColor Gray -NoNewline
            }
            if ($data.notes) {
                Write-Host " - $($data.notes)" -ForegroundColor Gray -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    
    # In Progress
    if ($inProgress.Count -gt 0) {
        Write-StatusIcon 'progress'
        Write-Host "In Progress ($($inProgress.Count)):" -ForegroundColor Yellow
        foreach ($analyzer in $inProgress | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            Write-Host "  • $id " -ForegroundColor Yellow -NoNewline
            if ($data.errorsFixed -gt 0) {
                Write-Host "($($data.errorsFixed) errors fixed so far)" -ForegroundColor Gray -NoNewline
            }
            if ($data.notes) {
                Write-Host " - $($data.notes)" -ForegroundColor Gray -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    
    # Pending
    if ($pending.Count -gt 0) {
        Write-StatusIcon 'pending'
        Write-Host "Pending ($($pending.Count)):" -ForegroundColor Gray
        foreach ($analyzer in $pending | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            Write-Host "  • $id" -ForegroundColor Gray -NoNewline
            if ($data.notes) {
                Write-Host " - $($data.notes)" -ForegroundColor DarkGray -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    
    # Skipped
    if ($skipped.Count -gt 0) {
        Write-StatusIcon 'warning'
        Write-Host "Skipped ($($skipped.Count)):" -ForegroundColor DarkGray
        foreach ($analyzer in $skipped | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            Write-Host "  • $id" -ForegroundColor DarkGray -NoNewline
            if ($data.notes) {
                Write-Host " - $($data.notes)" -ForegroundColor DarkGray -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Show-JsonReport {
    param([object]$Progress)
    
    $analyzers = $Progress.analyzers.PSObject.Properties
    
    $report = @{
        lastUpdated = $Progress.lastUpdated
        summary = @{
            total = $analyzers.Count
            completed = ($analyzers | Where-Object { $_.Value.status -eq 'completed' }).Count
            inProgress = ($analyzers | Where-Object { $_.Value.status -eq 'in-progress' }).Count
            pending = ($analyzers | Where-Object { $_.Value.status -eq 'pending' }).Count
            skipped = ($analyzers | Where-Object { $_.Value.status -eq 'skipped' }).Count
        }
        analyzers = $Progress.analyzers
    }
    
    $report | ConvertTo-Json -Depth 10
}

function Show-MarkdownReport {
    param([object]$Progress)
    
    $analyzers = $Progress.analyzers.PSObject.Properties
    
    $pending = $analyzers | Where-Object { $_.Value.status -eq 'pending' }
    $inProgress = $analyzers | Where-Object { $_.Value.status -eq 'in-progress' }
    $completed = $analyzers | Where-Object { $_.Value.status -eq 'completed' }
    $skipped = $analyzers | Where-Object { $_.Value.status -eq 'skipped' }
    
    $total = $analyzers.Count
    $completedCount = $completed.Count
    $percentComplete = if ($total -gt 0) { [math]::Round(($completedCount / $total) * 100, 1) } else { 0 }
    
    $md = @"
# Analyzer Enablement Progress

**Last Updated**: $($Progress.lastUpdated)

## Summary

- **Progress**: $completedCount / $total analyzers ($percentComplete%)
- **Completed**: $($completed.Count)
- **In Progress**: $($inProgress.Count)
- **Pending**: $($pending.Count)
- **Skipped**: $($skipped.Count)

"@
    
    if ($completed.Count -gt 0) {
        $md += @"

## ✅ Completed

| Analyzer | Errors Fixed | Notes |
|----------|--------------|-------|

"@
        foreach ($analyzer in $completed | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            $errors = if ($data.errorsFixed -gt 0) { $data.errorsFixed } else { '-' }
            $notes = if ($data.notes) { $data.notes } else { '-' }
            $md += "| $id | $errors | $notes |`n"
        }
    }
    
    if ($inProgress.Count -gt 0) {
        $md += @"

## 🔄 In Progress

| Analyzer | Errors Fixed | Notes |
|----------|--------------|-------|

"@
        foreach ($analyzer in $inProgress | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            $errors = if ($data.errorsFixed -gt 0) { "$($data.errorsFixed) (so far)" } else { '-' }
            $notes = if ($data.notes) { $data.notes } else { '-' }
            $md += "| $id | $errors | $notes |`n"
        }
    }
    
    if ($pending.Count -gt 0) {
        $md += @"

## ⏳ Pending

| Analyzer | Notes |
|----------|-------|

"@
        foreach ($analyzer in $pending | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            $notes = if ($data.notes) { $data.notes } else { '-' }
            $md += "| $id | $notes |`n"
        }
    }
    
    if ($skipped.Count -gt 0) {
        $md += @"

## ⊘ Skipped

| Analyzer | Reason |
|----------|--------|

"@
        foreach ($analyzer in $skipped | Sort-Object Name) {
            $id = $analyzer.Name
            $data = $analyzer.Value
            $notes = if ($data.notes) { $data.notes } else { '-' }
            $md += "| $id | $notes |`n"
        }
    }
    
    Write-Host $md
}

# Main execution
if ($Report) {
    # Generate report
    $progress = Read-Progress -Path $ProgressFile
    
    switch ($ReportFormat) {
        'console' { Show-ConsoleReport -Progress $progress }
        'json' { Show-JsonReport -Progress $progress }
        'markdown' { Show-MarkdownReport -Progress $progress }
    }
} else {
    # Update progress
    if (-not $AnalyzerId) {
        Write-StatusIcon 'error'
        Write-Host "Error: -AnalyzerId is required when not generating a report" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Cyan
        Write-Host "  Update progress:  " -NoNewline -ForegroundColor Gray
        Write-Host ".\track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status completed" -ForegroundColor White
        Write-Host "  Generate report:  " -NoNewline -ForegroundColor Gray
        Write-Host ".\track-analyzer-progress.ps1 -Report" -ForegroundColor White
        Write-Host ""
        exit 1
    }
    
    if (-not $Status) {
        Write-StatusIcon 'error'
        Write-Host "Error: -Status is required when updating progress" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    
    Write-Host "`n"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Track Analyzer Progress: $AnalyzerId" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Update-AnalyzerProgress -Path $ProgressFile -AnalyzerId $AnalyzerId -Status $Status -ErrorsFixed $ErrorsFixed -Notes $Notes
    
    Write-StatusIcon 'success'
    Write-Host "Updated progress for $AnalyzerId" -ForegroundColor Green
    Write-Host "  Status: " -NoNewline -ForegroundColor Gray
    
    switch ($Status) {
        'pending' { Write-Host $Status -ForegroundColor Gray }
        'in-progress' { Write-Host $Status -ForegroundColor Yellow }
        'completed' { Write-Host $Status -ForegroundColor Green }
        'skipped' { Write-Host $Status -ForegroundColor DarkGray }
    }
    
    if ($ErrorsFixed -gt 0) {
        Write-Host "  Errors Fixed: " -NoNewline -ForegroundColor Gray
        Write-Host $ErrorsFixed -ForegroundColor White
    }
    
    if ($Notes) {
        Write-Host "  Notes: " -NoNewline -ForegroundColor Gray
        Write-Host $Notes -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "View full progress report: " -NoNewline -ForegroundColor Gray
    Write-Host ".\track-analyzer-progress.ps1 -Report" -ForegroundColor White
    Write-Host ""
}
