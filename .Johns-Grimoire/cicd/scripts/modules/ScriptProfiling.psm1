<#
.SYNOPSIS
    Script execution profiling utilities

.DESCRIPTION
    Provides performance profiling functions for measuring script execution time.
    Includes Start-Profile, Stop-Profile, and Show-ProfilingReport for tracking
    and reporting performance metrics.

.NOTES
    File Name   : ScriptProfiling.psm1
    Location    : cicd/scripts/modules/
    Requires    : PowerShell 5.1 or higher
    
.EXAMPLE
    Import-Module "$PSScriptRoot/modules/ScriptProfiling.psm1" -Force
    
    $sw = Start-Profile "DataProcessing"
    # ... processing logic ...
    Stop-Profile "DataProcessing" $sw
    
    Show-ProfilingReport
#>

# Module-level profiler storage
$script:Profiler = @{}

<#
.SYNOPSIS
    Start profiling timer for named section

.DESCRIPTION
    Creates and starts a new Stopwatch for measuring execution time of a named section.
    Returns stopwatch object if profiling is enabled via script-level $EnableProfiling variable.

.PARAMETER Name
    Name of the section being profiled

.OUTPUTS
    [System.Diagnostics.Stopwatch] Stopwatch object, or $null if profiling disabled

.EXAMPLE
    $sw = Start-Profile "DataProcessing"
    # ... processing logic ...
    Stop-Profile "DataProcessing" $sw
#>
function Start-Profile {
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Stopwatch])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )
    
    # Check if calling script has $EnableProfiling variable
    $enableProfiling = Get-Variable -Name EnableProfiling -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    
    if ($enableProfiling) {
        return [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    return $null
}

<#
.SYNOPSIS
    Stop profiling timer and store result

.DESCRIPTION
    Stops the specified stopwatch and stores the elapsed time in the module-level
    profiler hashtable for later reporting.

.PARAMETER Name
    Name of the section being profiled (same as Start-Profile)

.PARAMETER Stopwatch
    Stopwatch object returned from Start-Profile

.EXAMPLE
    $sw = Start-Profile "DataProcessing"
    # ... processing logic ...
    Stop-Profile "DataProcessing" $sw
#>
function Stop-Profile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name,
        
        [Parameter(Mandatory=$false, Position=1)]
        [System.Diagnostics.Stopwatch]$Stopwatch
    )
    
    if ($Stopwatch) {
        $Stopwatch.Stop()
        $script:Profiler[$Name] = $Stopwatch.Elapsed.TotalSeconds
    }
}

<#
.SYNOPSIS
    Display profiling results summary

.DESCRIPTION
    Generates and displays a formatted report of all profiling measurements
    collected during script execution. Shows individual section times and total.
    Requires Write-Log function to be available in calling script or via module.

.EXAMPLE
    Show-ProfilingReport
    
.NOTES
    This function expects Write-Log function to be available. Import ScriptLogging.psm1
    in the calling script for best results.
#>
function Show-ProfilingReport {
    [CmdletBinding()]
    param()
    
    # Check if profiling is enabled
    $enableProfiling = Get-Variable -Name EnableProfiling -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    
    if ($enableProfiling -and $script:Profiler.Count -gt 0) {
        # Try to use Write-Log if available, otherwise fall back to Write-Host
        $hasWriteLog = Get-Command Write-Log -ErrorAction SilentlyContinue
        
        if ($hasWriteLog) {
            Write-Log "Performance Profiling:" -Level INFO
            Write-Log ("=" * 50) -Level INFO
            
            $sorted = $script:Profiler.GetEnumerator() | Sort-Object Value -Descending
            foreach ($entry in $sorted) {
                $seconds = [math]::Round($entry.Value, 2)
                Write-Log "  $($entry.Key): $seconds seconds" -Level INFO
            }
            
            $total = ($script:Profiler.Values | Measure-Object -Sum).Sum
            Write-Log ("=" * 50) -Level INFO
            Write-Log "  Total: $([math]::Round($total, 2)) seconds" -Level SUCCESS
        } else {
            Write-Host ""
            Write-Host "=== Performance Profile ===" -ForegroundColor Cyan
            $script:Profiler.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
                $seconds = [math]::Round($_.Value, 2)
                Write-Host "  $($_.Key): $seconds seconds" -ForegroundColor White
            }
            $total = ($script:Profiler.Values | Measure-Object -Sum).Sum
            Write-Host ("=" * 50) -ForegroundColor Cyan
            Write-Host "  Total: $([math]::Round($total, 2)) seconds" -ForegroundColor Green
        }
    }
}

<#
.SYNOPSIS
    Clear all profiling data

.DESCRIPTION
    Resets the module-level profiler hashtable, clearing all stored measurements.

.EXAMPLE
    Clear-ProfilingData
#>
function Clear-ProfilingData {
    [CmdletBinding()]
    param()
    
    $script:Profiler.Clear()
}

# Export public functions
Export-ModuleMember -Function Start-Profile, Stop-Profile, Show-ProfilingReport, Clear-ProfilingData

