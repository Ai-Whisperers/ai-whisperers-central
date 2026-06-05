<#
.SYNOPSIS
    Scans NuGet package dependencies for license compliance

.DESCRIPTION
    Scans all NuGet package dependencies (direct and transitive) for license compliance:
    - Generates comprehensive license report (JSON and text)
    - Checks for prohibited licenses (GPL-3.0, AGPL-3.0, etc.)
    - Identifies unknown or unlicensed packages
    - Provides package-level license details
    
    Uses dotnet-project-licenses tool with Central Package Management support.

.PARAMETER Configuration
    Build configuration to analyze (Debug or Release). Default: Release

.PARAMETER OutputPath
    Directory to write license reports.
    Default: Azure Pipelines staging directory or local temp directory

.EXAMPLE
    .\scan-licenses.ps1
    
    Scans licenses with default settings

.EXAMPLE
    .\scan-licenses.ps1 -OutputPath "C:\reports\licenses"
    
    Writes license report to custom directory

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Scan Dependency Licenses'
      inputs:
        filePath: 'cicd/scripts/scan-licenses.ps1'

.NOTES
    File Name      : scan-licenses.ps1
    Prerequisite   : .NET SDK 7.x, dotnet-project-licenses tool
    Portability    : Works in Azure Pipelines and locally
    Timeout        : 10 minutes for large dependency trees
    
.LINK
    https://github.com/tomchavakis/nuget-license
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for license reports")]
    [string]$OutputPath,

    [Parameter(Mandatory=$false, HelpMessage="Disable parallel processing")]
    [switch]$DisableParallel,

    [Parameter(Mandatory=$false, HelpMessage="Maximum number of concurrent threads")]
    [int]$ThrottleLimit = $env:NUMBER_OF_PROCESSORS
)

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\EnvironmentDetection.psm1") -Force

# Auto-disable parallel on PowerShell < 7
if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $DisableParallel) {
    Write-Log "PowerShell < 7 detected. Disabling parallel processing." -Level INFO
    $DisableParallel = $true
}

Write-Log
Write-Log "=== Dependency License Scan ==="
Write-Log

# Detect environment and set portable defaults (using shared module)
if (-not $OutputPath) {
    $OutputPath = Get-DefaultOutputPath -SubPath "license-report"
}

Write-Log "Configuration: $Configuration"
Write-Log "Output Path: $OutputPath"
Write-Log

# Install license scanning tool
# Use central tool installer if available
$installScript = Join-Path $PSScriptRoot "install-tools.ps1"
if (Test-Path $installScript) {
    Write-Log "Installing license scanner tool via central installer..."
    & $installScript -Tools "dotnet-project-licenses"
} else {
    Write-Log "Installing license scanner tool (fallback)..."
    dotnet tool update --global dotnet-project-licenses --version 2.7.1 2>&1 | Out-Null
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

# Generate license report
Write-Log "Scanning package licenses..."
# Standard tool: dotnet-project-licenses
# Use Start-Process to avoid PowerShell NativeCommandError on non-error output (stderr)
# Note: DOTNET_ROLL_FORWARD is needed because tool targets .NET 7 but agent has .NET 9
# Note: Using --use-project-assets-json because we use Central Package Management (CPM)
#       CPM packages often show as "invalid entry ..., version ," in standard scan mode
# Note: Removed --export-license-texts to prevent hangs when downloading licenses from unreachable URLs
$env:DOTNET_ROLL_FORWARD = "Major"

$projects = Get-ChildItem -Recurse -Filter "*.csproj"

if ($DisableParallel -or $projects.Count -le 1) {
    Write-Log "Running sequential scan..."
    $process = Start-Process -FilePath "dotnet-project-licenses" -ArgumentList "--input . --output-directory `"$OutputPath`" --json --include-transitive --use-project-assets-json --log-level Information" -NoNewWindow -PassThru

    # Wait for process with timeout (10 minutes)
    try {
        $process | Wait-Process -Timeout 600
    }
    catch {
        Write-Log "License scanner timed out after 10 minutes." -Level ERROR
        $process | Stop-Process -Force
        exit 1
    }

    if ($process.ExitCode -ne 0) {
        Write-Log "License scanner failed with exit code $($process.ExitCode)" -Level ERROR
        exit $process.ExitCode
    }
    
    # Read the generated JSON report
    $reportFile = Join-Path $OutputPath "licenses.json"
    if (-not (Test-Path $reportFile)) {
        Write-Log "License report not generated!" -Level ERROR
        exit 1
    }
    
    $licenses = Get-Content $reportFile -Raw | ConvertFrom-Json

} else {
    Write-Log "Running parallel scan on $($projects.Count) projects (Throttle: $ThrottleLimit)..."
    
    $progress = [Hashtable]::Synchronized(@{ Completed = 0 })
    $total = $projects.Count
    
    $results = $projects | ForEach-Object -Parallel {
        $project = $_
        $outPath = $using:OutputPath
        $syncProgress = $using:progress
        $syncTotal = $using:total
        
        # Create temp dir for this project to avoid collision
        $tempDir = Join-Path $outPath "temp_$($project.BaseName)_$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        
        $scanArgs = "--input `"$($project.FullName)`" --output-directory `"$tempDir`" --json --include-transitive --use-project-assets-json --log-level Warning"
        $process = Start-Process -FilePath "dotnet-project-licenses" -ArgumentList $scanArgs -NoNewWindow -PassThru
        
        try {
            $process | Wait-Process -Timeout 300 # 5 minutes per project
        } catch {
            $process | Stop-Process -Force
            Write-Host "  [TIMEOUT] $($project.BaseName)" -ForegroundColor Red
            return $null
        }
        
        $syncProgress.Completed++
        $percent = [math]::Round(($syncProgress.Completed / $syncTotal) * 100)
        Write-Host "[$($syncProgress.Completed)/$syncTotal] Scanned $($project.BaseName) - $percent%"
        
        if ($process.ExitCode -eq 0) {
            $jsonFile = Join-Path $tempDir "licenses.json"
            if (Test-Path $jsonFile) {
                return $jsonFile
            }
        }
        return $null
    } -ThrottleLimit $ThrottleLimit
    
    # Merge reports
    $licenses = @()
    foreach ($file in $results) {
        if ($file) {
            try {
                $content = Get-Content $file -Raw | ConvertFrom-Json
                if ($content) { $licenses += $content }
            } catch {
                Write-Log "Failed to read report: $file" -Level WARN
            }
            # Clean up temp dir
            Remove-Item (Split-Path $file -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Deduplicate
    if ($licenses.Count -gt 0) {
        $licenses = $licenses | Select-Object -Unique -Property PackageName, PackageVersion, LicenseType, LicenseUrl
    }
    
    # Save merged report
    $reportFile = Join-Path $OutputPath "licenses.json"
    $licenses | ConvertTo-Json -Depth 10 | Set-Content $reportFile
}

# Define prohibited licenses (copyleft licenses)
$prohibitedLicenses = @(
    "GPL",
    "GPL-2.0",
    "GPL-3.0",
    "AGPL",
    "AGPL-3.0",
    "LGPL",
    "LGPL-2.1",
    "LGPL-3.0"
)

# Define warning licenses (require legal review)
$warningLicenses = @(
    "MPL",
    "MPL-2.0",
    "EPL",
    "EPL-1.0",
    "EPL-2.0",
    "CDDL",
    "CPL"
)

# Known licenses for packages with missing LicenseType
$licenseOverrides = @{
    "Mono.Cecil"         = "MIT"
    "NetArchTest.Rules"  = "MIT"
    "xunit.abstractions" = "Apache-2.0"
    "Energy21.Dapper"    = "Proprietary-Internal"
}

# URL-based hints for common SPDX identifiers
$licenseUrlHints = @(
    @{ Pattern = "mit"        ; License = "MIT" },
    @{ Pattern = "apache-2.0" ; License = "Apache-2.0" }
)

# Track findings
$prohibited = @()
$warnings = @()
$approved = @()
$unknown = @()

Write-Log
Write-Log "Analyzing $($licenses.Count) package licenses..."
Write-Log

foreach ($package in $licenses) {
    $packageName = $package.PackageName
    $license = $package.LicenseType
    
    if (-not $license) {
        if ($licenseOverrides.ContainsKey($packageName)) {
            $license = $licenseOverrides[$packageName]
        }
        elseif ($package.LicenseUrl) {
            $licenseUrl = $package.LicenseUrl.ToLowerInvariant()
            foreach ($hint in $licenseUrlHints) {
                if ($licenseUrl -like "*$($hint.Pattern)*") {
                    $license = $hint.License
                    break
                }
            }
        }
    }

    if (-not $license) {
        $unknown += $packageName
        continue
    }
    
    # Check for prohibited licenses
    $isProhibited = $false
    foreach ($prohibitedLic in $prohibitedLicenses) {
        if ($license -like "*$prohibitedLic*") {
            $prohibited += "$packageName ($license)"
            $isProhibited = $true
            break
        }
    }
    
    if ($isProhibited) {
        continue
    }
    
    # Check for warning licenses
    $isWarning = $false
    foreach ($warningLic in $warningLicenses) {
        if ($license -like "*$warningLic*") {
            $warnings += "$packageName ($license)"
            $isWarning = $true
            break
        }
    }
    
    if (-not $isWarning) {
        $approved += "$packageName ($license)"
    }
}

# Display results
Write-Log "License Scan Results:" -Level INFO
Write-Log
$warningLevel = if ($warnings.Count -gt 0) { "WARN" } else { "INFO" }
$prohibitedLevel = if ($prohibited.Count -gt 0) { "ERROR" } else { "INFO" }
$unknownLevel = if ($unknown.Count -gt 0) { "WARN" } else { "INFO" }

Write-Log "  Approved: $($approved.Count)" -Level SUCCESS
Write-Log "  Warning: $($warnings.Count)" -Level $warningLevel
Write-Log "  Prohibited: $($prohibited.Count)" -Level $prohibitedLevel
Write-Log "  Unknown: $($unknown.Count)" -Level $unknownLevel
Write-Log

# Show prohibited licenses (build failure)
if ($prohibited.Count -gt 0) {
    Write-Log "PROHIBITED LICENSES DETECTED:" -Level ERROR
    Write-Log
    foreach ($item in $prohibited) {
        Write-Log "  - $item" -Level ERROR
    }
    Write-Log
    Write-Log "Prohibited copyleft licenses found! Build failed." -Level ERROR
    exit 1
}

# Show warning licenses (build continues but warn)
if ($warnings.Count -gt 0) {
    Write-Log "WARNING LICENSES (Require Legal Review):" -Level WARN
    Write-Log
    foreach ($item in $warnings) {
        Write-Log "  - $item" -Level WARN
    }
    Write-Log
    Write-Log "Licenses requiring legal review found. Please review before release." -Level WARN
}

# Show unknown licenses
if ($unknown.Count -gt 0) {
    Write-Log "PACKAGES WITH UNKNOWN LICENSES:" -Level $unknownLevel
    Write-Log
    foreach ($item in $unknown) {
        Write-Log "  - $item" -Level $unknownLevel
    }
    Write-Log
    Write-Log "Packages with unknown licenses detected. Please investigate." -Level $unknownLevel
}

# Success
if ($prohibited.Count -eq 0 -and $warnings.Count -eq 0 -and $unknown.Count -eq 0) {
    Write-Log "ALL LICENSES APPROVED!" -Level SUCCESS
    Write-Log
}

Write-Log "Full report: $reportFile"
Write-Log

exit 0
