<#
.SYNOPSIS
    Environment detection module for CI/CD and local execution contexts

.DESCRIPTION
    Provides functions for detecting execution environment (Azure Pipelines, local,
    PowerShell version, etc.) and retrieving environment-appropriate default paths.
    
    Enables portable scripts that adapt behavior based on execution context.

.NOTES
    File Name      : EnvironmentDetection.psm1
    Author         : CI/CD Team
    Prerequisite   : PowerShell 5.1+
    
.EXAMPLE
    Import-Module "$PSScriptRoot/modules/EnvironmentDetection.psm1"
    if (Test-AzurePipelines) {
        Write-Host "Running in Azure Pipelines"
    }
#>

#region Test-AzurePipelines Function
<#
.SYNOPSIS
    Detects if script is running in Azure Pipelines

.DESCRIPTION
    Checks for Azure Pipelines environment variables to determine if script
    is executing in a CI/CD pipeline context.
    
    Detection logic: Checks for AGENT_TEMPDIRECTORY environment variable,
    which is always present in Azure Pipelines agents.

.OUTPUTS
    [bool] True if running in Azure Pipelines, False if running locally

.EXAMPLE
    if (Test-AzurePipelines) {
        Write-Host "Running in Azure Pipelines CI/CD"
    } else {
        Write-Host "Running in local development environment"
    }

.EXAMPLE
    $isCI = Test-AzurePipelines
    $outputPath = if ($isCI) { "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/reports" } else { "$env:TEMP/reports" }
#>
function Test-AzurePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    return [bool]$env:AGENT_TEMPDIRECTORY
}
#endregion

#region Get-DefaultOutputPath Function
<#
.SYNOPSIS
    Gets appropriate default output path for current environment

.DESCRIPTION
    Returns BUILD_ARTIFACTSTAGINGDIRECTORY in Azure Pipelines for artifact publishing,
    or TEMP directory in local environments for development use.
    
    Optionally appends a subdirectory path for organizing outputs.

.PARAMETER SubPath
    Optional subdirectory name to append to base path

.OUTPUTS
    [string] Full output path appropriate for current environment

.EXAMPLE
    $outputPath = Get-DefaultOutputPath
    # Azure Pipelines: C:\agent\_work\1\a
    # Local: C:\Users\user\AppData\Local\Temp

.EXAMPLE
    $outputPath = Get-DefaultOutputPath -SubPath "coverage-reports"
    # Azure Pipelines: C:\agent\_work\1\a\coverage-reports
    # Local: C:\Users\user\AppData\Local\Temp\coverage-reports
#>
function Get-DefaultOutputPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SubPath
    )
    
    # Determine base path based on environment
    if (Test-AzurePipelines) {
        $basePath = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
    } else {
        $basePath = $env:TEMP
    }
    
    # Append subpath if provided
    if ($SubPath) {
        return Join-Path $basePath $SubPath
    }
    
    return $basePath
}
#endregion

#region Test-PowerShellVersion Function
<#
.SYNOPSIS
    Checks if PowerShell version meets minimum requirement

.DESCRIPTION
    Compares current PowerShell version against a minimum required version.
    Useful for checking if advanced features (like ForEach-Object -Parallel) are available.

.PARAMETER MinimumVersion
    Minimum required version (MAJOR.MINOR format)

.OUTPUTS
    [bool] True if current version >= minimum version, False otherwise

.EXAMPLE
    if (Test-PowerShellVersion -MinimumVersion "7.0") {
        Write-Host "PowerShell 7+ detected, parallel processing available"
    }

.EXAMPLE
    $canUseParallel = Test-PowerShellVersion -MinimumVersion "7.0"
#>
function Test-PowerShellVersion {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [Alias('MinVersion')]
        [string]$MinimumVersion
    )
    
    $normalizedVersion = if ($MinimumVersion -notmatch '\.') { "$MinimumVersion.0" } else { $MinimumVersion }
    $minVer = [version]$normalizedVersion
    $currentVer = $PSVersionTable.PSVersion
    
    return $currentVer -ge $minVer
}
#endregion

#region Get-BuildContext Function
<#
.SYNOPSIS
    Gets build context information (branch, commit, build number)

.DESCRIPTION
    Retrieves build context from Azure Pipelines environment variables with
    git command fallbacks for local execution.
    
    Returns hashtable with: Branch, Commit, BuildNumber, IsCI

.OUTPUTS
    [hashtable] Build context information

.EXAMPLE
    $context = Get-BuildContext
    Write-Host "Branch: $($context.Branch)"
    Write-Host "Commit: $($context.Commit)"
    Write-Host "Build: $($context.BuildNumber)"

.EXAMPLE
    $context = Get-BuildContext
    if ($context.IsCI) {
        Write-Host "CI Build #$($context.BuildNumber)"
    }
#>
function Get-BuildContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    $isCI = Test-AzurePipelines
    
    # Get branch
    $branch = if ($env:BUILD_SOURCEBRANCH) {
        $env:BUILD_SOURCEBRANCH
    } else {
        try {
            $branchResult = git branch --show-current 2>$null
            if ([string]::IsNullOrWhiteSpace($branchResult)) {
                "detached HEAD"
            } else {
                $branchResult
            }
        } catch {
            "unknown"
        }
    }
    
    # Get commit
    $commit = if ($env:BUILD_SOURCEVERSION) {
        $env:BUILD_SOURCEVERSION
    } else {
        try {
            git rev-parse --short HEAD 2>$null
        } catch {
            "unknown"
        }
    }
    
    # Get build number
    $buildNumber = if ($env:BUILD_BUILDNUMBER) {
        $env:BUILD_BUILDNUMBER
    } else {
        "local-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }
    
    return @{
        IsCI = $isCI
        Branch = $branch
        Commit = $commit
        BuildNumber = $buildNumber
    }
}
#endregion

#region Export Module Members
Export-ModuleMember -Function @(
    'Import-ScriptConfiguration',
    'Get-ConfigValue',
    'Merge-ConfigurationWithParameters',
    'Test-AzurePipelines',
    'Get-DefaultOutputPath',
    'Test-PowerShellVersion',
    'Get-BuildContext'
)
#endregion

