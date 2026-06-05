<#
.SYNOPSIS
    History tracking module for metric persistence and trend analysis

.DESCRIPTION
    Provides functions to append metric results to JSON Lines history files,
    manage history rotation, and retrieve historical trends for analysis.
    
    Uses JSON Lines format (one JSON object per line) for append-friendly
    persistence without full file rewrite.

.NOTES
    File Name   : HistoryTracking.psm1
    Location    : cicd/scripts/modules/
    
.EXAMPLE
    Import-Module (Join-Path $PSScriptRoot "modules\HistoryTracking.psm1") -Force
    
    $metrics = @{ LineCoverage = 80.5; BranchCoverage = 75.2 }
    Add-HistoryEntry -HistoryFile ".history/coverage.jsonl" -Metrics $metrics -MaxEntries 100
    
    $trend = Get-HistoryTrend -HistoryFile ".history/coverage.jsonl" -LastN 10
#>

function Add-HistoryEntry {
    <#
    .SYNOPSIS
        Appends a new metric entry to the specified history file with automatic rotation
    
    .DESCRIPTION
        Adds a timestamped metric entry to a JSON Lines history file with automatic
        git context (commit, branch). Supports optional rotation to keep last N entries.
        Creates parent directory if needed.
        
        JSON Lines format: One JSON object per line for efficient append operations.
    
    .PARAMETER HistoryFile
        Path to the history file (JSON Lines format: .jsonl)
        Parent directory will be created if it doesn't exist
    
    .PARAMETER Metrics
        Hashtable of metrics to record
        Example: @{ LineCoverage = 80; BranchCoverage = 70 }
    
    .PARAMETER MaxEntries
        Maximum number of entries to keep (0 or -1 for infinite)
        When exceeded, oldest entries are removed
        Default: 0 (unlimited)
    
    .OUTPUTS
        None. Writes to file and provides verbose output.
    
    .EXAMPLE
        Add-HistoryEntry -HistoryFile ".history/coverage.jsonl" -Metrics @{ Line = 80; Branch = 70 }
        
        Appends coverage metrics to history file with unlimited retention
    
    .EXAMPLE
        Add-HistoryEntry -HistoryFile ".history/metrics.jsonl" -Metrics $metrics -MaxEntries 100
        
        Appends metrics and keeps only last 100 entries (automatic rotation)
    
    .EXAMPLE
        $metrics = @{
            LineCoverage = 85.5
            BranchCoverage = 78.2
            PublicApiCoverage = 92.0
        }
        Add-HistoryEntry -HistoryFile ".history/coverage.jsonl" -Metrics $metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path to the history file (JSON Lines)")]
        [string]$HistoryFile,

        [Parameter(Mandatory=$true, HelpMessage="Hashtable of metrics to record")]
        [hashtable]$Metrics,
        
        [Parameter(Mandatory=$false, HelpMessage="Maximum number of entries to keep (0 or -1 for infinite)")]
        [int]$MaxEntries = 0
    )

    try {
        $dir = Split-Path $HistoryFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        
        try {
            $commit = git rev-parse --short HEAD 2>$null
            $branch = git branch --show-current 2>$null
        } catch {
            $commit = "unknown"
            $branch = "unknown"
        }
        
        if ([string]::IsNullOrWhiteSpace($commit)) { $commit = "unknown" }
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "detached HEAD" }
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }

        $entry = [ordered]@{
            timestamp = $timestamp
            commit    = $commit
            branch    = $branch
            metrics   = $Metrics
        }

        $jsonLine = $entry | ConvertTo-Json -Compress -Depth 10

        $jsonLine | Out-File -FilePath $HistoryFile -Append -Encoding UTF8

        if ($MaxEntries -gt 0) {
            $content = Get-Content -Path $HistoryFile -ErrorAction SilentlyContinue
            if ($content.Count -gt $MaxEntries) {
                $keep = $content | Select-Object -Last $MaxEntries
                $keep | Set-Content -Path $HistoryFile -Encoding UTF8
            }
        }
        
        Write-Verbose "Added history entry to $HistoryFile"
    }
    catch {
        Write-Warning "Failed to update history file: $_"
    }
}

function Get-HistoryTrend {
    <#
    .SYNOPSIS
        Retrieves the last N entries from a history file for trend analysis
    
    .DESCRIPTION
        Reads a JSON Lines history file and returns the most recent N entries
        as PowerShell objects for trend analysis and reporting.
        Returns empty array if file doesn't exist.
    
    .PARAMETER HistoryFile
        Path to the history file (JSON Lines format: .jsonl)
    
    .PARAMETER LastN
        Number of recent entries to retrieve
        Default: 10
    
    .OUTPUTS
        [PSCustomObject[]] Array of history entries (most recent entries)
        Each entry contains: timestamp, commit, branch, metrics
        Returns empty array if file doesn't exist
    
    .EXAMPLE
        $trend = Get-HistoryTrend -HistoryFile ".history/coverage.jsonl"
        
        Retrieves last 10 entries for trend analysis
    
    .EXAMPLE
        $trend = Get-HistoryTrend -HistoryFile ".history/coverage.jsonl" -LastN 30
        foreach ($entry in $trend) {
            Write-Host "$($entry.timestamp): Line=$($entry.metrics.LineCoverage)%"
        }
        
        Retrieves last 30 entries and displays trend
    
    .EXAMPLE
        $trend = Get-HistoryTrend -HistoryFile ".history/metrics.jsonl" -LastN 5
        if ($trend.Count -ge 2) {
            $first = $trend[0].metrics.Value
            $last = $trend[-1].metrics.Value
            $change = $last - $first
            Write-Host "Trend: $change (from $first to $last)"
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path to the history file (JSON Lines)")]
        [string]$HistoryFile,
        
        [Parameter(Mandatory=$false, HelpMessage="Number of recent entries to retrieve")]
        [ValidateRange(1, 1000)]
        [int]$LastN = 10
    )

    if (-not (Test-Path -Path $HistoryFile -PathType Leaf)) {
        Write-Output -NoEnumerate @()
        return
    }

    $lines = Get-Content -Path $HistoryFile -ErrorAction SilentlyContinue
    if (-not $lines) {
        Write-Output -NoEnumerate @()
        return
    }

    $entries = $lines |
        Select-Object -Last $LastN |
        ForEach-Object { $_ | ConvertFrom-Json }

    Write-Output -NoEnumerate @($entries)
}

Export-ModuleMember -Function Add-HistoryEntry, Get-HistoryTrend

