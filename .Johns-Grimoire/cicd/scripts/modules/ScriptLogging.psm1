<#
.SYNOPSIS
    Reusable logging module for CI/CD scripts with conditional Unicode support

.DESCRIPTION
    Provides structured logging functions with automatic environment detection.
    Supports Unicode emojis in PowerShell 7+/Azure Pipelines, ASCII fallback in PS5.1
    
.NOTES
    File Name      : ScriptLogging.psm1
    Author         : CI/CD Team
    Prerequisite   : PowerShell 5.1+
    
.EXAMPLE
    Import-Module "$PSScriptRoot/modules/ScriptLogging.psm1"
    Write-Log "Starting process" -Level INFO
    Write-Separator -Level SUCCESS
#>

#region Unicode Detection
<#
.SYNOPSIS
    Detects if Unicode is supported in current environment

.DESCRIPTION
    Checks environment capabilities to determine if Unicode emojis can be safely displayed.
    Detection logic:
    - PowerShell 7+ → Unicode supported
    - Azure Pipelines ($env:AGENT_TEMPDIRECTORY exists) → Unicode supported
    - UTF-8 console encoding → Unicode supported
    - Windows PowerShell 5.1 → ASCII fallback

.OUTPUTS
    [bool] True if Unicode is safe to use, False if ASCII fallback needed
    
.EXAMPLE
    if (Test-UnicodeSupport) {
        Write-Host "✅ Unicode supported!"
    }
#>
function Test-UnicodeSupport {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    # PowerShell 7+ always supports Unicode
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return $true
    }
    
    # Azure Pipelines supports Unicode (web-based logs)
    if ($env:AGENT_TEMPDIRECTORY) {
        return $true
    }
    
    # Check console encoding (if available)
    try {
        if ([Console]::OutputEncoding.WebName -match 'utf-8|unicode') {
            return $true
        }
    }
    catch {
        # If Console is not available, default to false
    }
    
    # Default to ASCII-safe for Windows PowerShell 5.1
    return $false
}

# Module-level variable cached for performance
$script:SupportsUnicode = Test-UnicodeSupport
#endregion

#region Write-Log Function
<#
.SYNOPSIS
    Writes structured log messages with severity levels

.DESCRIPTION
    Provides consistent logging with:
    - Conditional Unicode emojis (PS7+/Azure) or ASCII (PS5.1)
    - Timestamps on all messages
    - Color-coded output by severity
    - Azure Pipelines integration (##vso commands)
    - Empty message handling for blank lines

.PARAMETER Message
    The message to log. Can be empty for blank lines.

.PARAMETER Level
    Severity level: INFO, SUCCESS, WARN, ERROR, DEBUG. Default: INFO

.EXAMPLE
    Write-Log "Operation completed" -Level SUCCESS
    # PS7+: [2025-12-07 10:00:00] ✅ Operation completed
    # PS5.1: [2025-12-07 10:00:00] [PASS] Operation completed

.EXAMPLE
    Write-Log "File not found" -Level ERROR
    # PS7+: [2025-12-07 10:00:00] ❌ File not found
    # PS5.1: [2025-12-07 10:00:00] [FAIL] File not found

.EXAMPLE
    Write-Log  # Empty line
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string]$Message = "",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [string]$LogFile
    )
    
    process {
        # Handle empty messages (blank lines)
        if ([string]::IsNullOrWhiteSpace($Message)) {
            Write-Host ""
            return
        }
        
        # Timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Choose emoji or ASCII based on environment (using cached module variable)
        if ($script:SupportsUnicode) {
            # Unicode emojis (PowerShell 7+, Azure Pipelines, modern terminals)
            # Using Unicode code points to avoid PS5.1 parsing errors
            $prefix = switch ($Level) {
                "INFO"    { [char]0x2139 + [char]0xFE0F }  # ℹ️ information
                "SUCCESS" { [char]0x2705 }                  # ✅ check mark
                "WARN"    { [char]0x26A0 + [char]0xFE0F }  # ⚠️ warning
                "ERROR"   { [char]0x274C }                  # ❌ cross mark
                "DEBUG"   { [char]0xD83D + [char]0xDD0D }  # 🔍 magnifying glass (surrogate pair)
            }
        } else {
            # ASCII-safe fallbacks (Windows PowerShell 5.1)
            $prefix = switch ($Level) {
                "INFO"    { "[INFO]" }
                "SUCCESS" { "[PASS]" }
                "WARN"    { "[WARN]" }
                "ERROR"   { "[FAIL]" }
                "DEBUG"   { "[DEBUG]" }
            }
        }
        
        # Color mapping
        $color = switch ($Level) {
            "INFO"    { "Cyan" }
            "SUCCESS" { "Green" }
            "WARN"    { "Yellow" }
            "ERROR"   { "Red" }
            "DEBUG"   { "Gray" }
        }
        
        # Azure Pipelines logging integration
        if ($env:AGENT_TEMPDIRECTORY) {
            if ($Level -eq "ERROR") {
                Write-Host "##vso[task.logissue type=error]$Message"
            }
            elseif ($Level -eq "WARN") {
                Write-Host "##vso[task.logissue type=warning]$Message"
            }
        }
        
        # Console output with color
        $logLine = "[$timestamp] $prefix $Message"
        Write-Host $logLine -ForegroundColor $color

        # Optional file logging
        if ($LogFile) {
            try {
                $logDir = Split-Path -Parent $LogFile
                if ($logDir -and -not (Test-Path $logDir)) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                }

                Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
            }
            catch {
                Write-Warning @"
WARNING: Failed to write log entry to file '$LogFile'

Impact: Log file output for this run is incomplete; console output is still available.

Solution: Ensure the log file directory exists and is writable, then re-run the script.

Location: ScriptLogging.psm1::Write-Log

Help: See cicd/docs/CICD-PROCESS.md for logging guidance.
"@
            }
        }
    }
}
#endregion

#region Write-Separator Function
<#
.SYNOPSIS
    Writes separator lines for visual grouping

.DESCRIPTION
    Outputs separator lines with conditional Unicode support:
    - Unicode box-drawing (══) in PowerShell 7+/Azure Pipelines
    - ASCII equals (==) in Windows PowerShell 5.1
    Color-coded by severity level

.PARAMETER Level
    Severity level for color coding: INFO, SUCCESS, WARN, ERROR. Default: INFO

.EXAMPLE
    Write-Separator -Level INFO
    # PS7+: ══════════════════════════════════════════════
    # PS5.1: ======================================================================

.EXAMPLE
    Write-Separator -Level ERROR
    # Red separator line
#>
function Write-Separator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    # Color mapping
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    # Choose box-drawing or equals based on environment (using cached module variable)
    if ($script:SupportsUnicode) {
        # Unicode box-drawing characters
        Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor $color
    } else {
        # ASCII-safe equals signs
        Write-Host "======================================================================" -ForegroundColor $color
    }
}
#endregion

#region Write-Header Function
<#
.SYNOPSIS
    Writes formatted header with title and separator

.DESCRIPTION
    Convenience function for common pattern of separator + title + separator

.PARAMETER Title
    Header title text

.PARAMETER Level
    Severity level for color coding

.EXAMPLE
    Write-Header "Starting Validation" -Level INFO
    # Outputs:
    # ══════════════════════════════════════════════
    # [2025-12-07 10:00:00] ℹ️ Starting Validation
    # ══════════════════════════════════════════════
#>
function Write-Header {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Title,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    Write-Log ""
    Write-Separator -Level $Level
    Write-Log $Title -Level $Level
    Write-Separator -Level $Level
    Write-Log ""
}
#endregion

# Export functions
Export-ModuleMember -Function @(
    'Test-UnicodeSupport',
    'Write-Log',
    'Write-Separator',
    'Write-Header'
)

