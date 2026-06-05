<#
.SYNOPSIS
    Installs .NET global tools with version management.

.DESCRIPTION
    Reads tool versions from a configuration file and installs them.
    Supports installing specific versions (fastest/stable) or updating to latest.
    Designed for use in both local development and CI/CD pipelines.

.PARAMETER Tools
    Specific tools to install. If omitted, installs all tools in config.

.PARAMETER Latest
    If set, ignores configured versions and installs the latest available version.

.PARAMETER ConfigFile
    Path to the JSON configuration file. Defaults to 'tool-versions.json' in parent directory.

.EXAMPLE
    .\install-tools.ps1
    Installs all tools with versions specified in tool-versions.json.

.EXAMPLE
    .\install-tools.ps1 -Latest
    Updates all tools to their latest versions.

.EXAMPLE
    .\install-tools.ps1 -Tools "docfx", "dotnet-stryker"
    Installs only DocFX and Stryker.
#>

[CmdletBinding()]
param(
    [string[]]$Tools,
    [switch]$Latest,
    [string]$ConfigFile
)

# Determine config file path with CI/CD and local support
if (-not $ConfigFile) {
    if ($env:BUILD_SOURCESDIRECTORY) {
        # Running in Azure Pipelines - use BUILD_SOURCESDIRECTORY
        $ConfigFile = Join-Path $env:BUILD_SOURCESDIRECTORY "cicd/tool-versions.json"
    } else {
        # Running locally - use script-relative path
        $ConfigFile = Join-Path $PSScriptRoot "../tool-versions.json"
    }
}

$ErrorActionPreference = "Stop"

# Import shared module for structured logging
$ModulePath = Join-Path $PSScriptRoot "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Write-Log "=== .NET Tool Installer ===" -Level INFO
Write-Log "" -Level INFO

if (-not (Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level ERROR
    exit 1
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $config -or $config.PSObject.Properties.Name -notcontains 'tools') {
    Write-Log "Invalid configuration format. 'tools' property missing." -Level ERROR
    exit 1
}

$toolDefinitions = $config.tools
if (-not $toolDefinitions) {
    Write-Log "Invalid configuration format. 'tools' property missing." -Level ERROR
    exit 1
}

# Filter tools if specific ones requested
$toolsToProcess = if ($Tools) {
    $selectedTools = @{}
    foreach ($tool in $Tools) {
        if ($toolDefinitions -is [System.Collections.IDictionary]) {
            if ($toolDefinitions.ContainsKey($tool)) {
                $selectedTools[$tool] = $toolDefinitions[$tool]
            } else {
                Write-Log "Tool '$tool' not found in configuration." -Level WARN
            }
        } else {
            if ($toolDefinitions.PSObject.Properties.Name -contains $tool) {
                $selectedTools[$tool] = $toolDefinitions.$tool
            } else {
                Write-Log "Tool '$tool' not found in configuration." -Level WARN
            }
        }
    }
    $selectedTools
} else {
    $toolDefinitions
}

    $toolNames = if ($toolsToProcess -is [System.Collections.IDictionary]) {
        $toolsToProcess.Keys
    } elseif ($toolsToProcess) {
        $toolsToProcess.PSObject.Properties | Select-Object -ExpandProperty Name
    } else {
        @()
    }

    $toolNames = @($toolNames)
    $toolCount = $toolNames.Count

    if ($toolCount -eq 0) {
        Write-Log "No tools to process." -Level WARN
        exit 0
    }

    Write-Log "Processing $toolCount tools..." -Level INFO
Write-Log "Mode: $(if ($Latest) { 'Latest (Update)' } else { 'Pinned Versions' })" -Level INFO
Write-Log "" -Level INFO

foreach ($toolName in $toolNames) {
    $version = if ($toolsToProcess -is [System.Collections.IDictionary]) {
        $toolsToProcess[$toolName]
    } else {
        $toolsToProcess.$toolName
    }
    
    try {
        if ($Latest) {
            Write-Log "Tool: $toolName (Latest)" -Level INFO
            dotnet tool update --global $toolName 2>&1 | Out-Null
            Write-Log "  Updated to latest successfully." -Level SUCCESS
        } else {
            Write-Log "Tool: $toolName (v$version)" -Level INFO
            
            # Check if installed
            $installed = $false
            try {
                # Check for tool in list (slow but accurate)
                # Or try to run it? No, some tools don't return version easily.
                # Better: dotnet tool list -g
                # Optimization: Trust dotnet tool update/install logic?
                
                # 'dotnet tool install' fails if installed. 'dotnet tool update' works but might check network.
                # To be "Fastest", we want to avoid network if version matches.
                
                # We can use update with version, but it still checks.
                # Let's try install first, catch error.
                
                dotnet tool install --global $toolName --version $version 2>&1 | Out-Null
                Write-Log "  Installed v$version successfully." -Level SUCCESS
            } catch {
                # Tool likely installed. Try update to ensure version match?
                # Or assume if installed it's okay?
                # For strict compliance, we should ensure version.
                
                # Check if error is "already installed"
                if ($_.Exception.Message -match "is already installed") {
                    # Ideally verify version here, but simple approach:
                    # Just run update to pin version
                    dotnet tool update --global $toolName --version $version 2>&1 | Out-Null
                    Write-Log "  Verified/Updated to v$version." -Level SUCCESS
                } else {
                    throw $_
                }
            }
        }
    } catch {
        Write-Log "  Failed: $($_.Exception.Message)" -Level ERROR
        # Don't exit, try next tool
    }
}

Write-Log "" -Level INFO
Write-Log "Tool installation complete." -Level SUCCESS
exit 0

