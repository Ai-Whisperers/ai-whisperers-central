<#
.SYNOPSIS
    Orchestrates local metric collection for historical tracking.

.DESCRIPTION
    Runs code metrics and coverage analysis scripts to collect data for historical trending.
    Designed for local execution to populate the .history folder.
    Supports configuration of all underlying script parameters via CLI or JSON config file.

.PARAMETER ConfigFile
    Path to JSON configuration file. If provided, settings are loaded from file.
    CLI parameters override config file values. Default: "$PSScriptRoot/collect-local-metrics.config.json"

.PARAMETER Configuration
    Build configuration to analyze (Debug or Release). Default: Release

.PARAMETER OutputPath
    Base directory for output. Defaults to local temp or pipeline artifact directory.

.PARAMETER EnableHistoryTracking
    Enable writing to history files. Default: $true for this script.

.PARAMETER MaxHistoryEntries
    Maximum number of history entries to keep (0 or -1 for infinite). Default: 0 (Infinite).

.PARAMETER MaxComplexity
    [Metrics] Maximum acceptable cyclomatic complexity. Default: 15

.PARAMETER MinMaintainability
    [Metrics] Minimum acceptable maintainability index. Default: 60

.PARAMETER MinLineCoverage
    [Coverage] Minimum line coverage percentage. Default: 80

.PARAMETER MinBranchCoverage
    [Coverage] Minimum branch coverage percentage. Default: 70

.PARAMETER MinPublicApiCoverage
    [Coverage] Minimum public API coverage percentage. Default: 90

.PARAMETER ReportTypes
    [Coverage] Report types to generate. Default: "Cobertura;HtmlInline_AzurePipelines;JsonSummary;Badges"

.PARAMETER AssemblyFilters
    [Coverage] Assembly filters. Default: "+*; -*Tests; -*Benchmarks"

.PARAMETER EnableProfiling
    Enable performance profiling for underlying scripts.

.PARAMETER ShowProgress
    Show progress bars.

.EXAMPLE
    .\collect-local-metrics.ps1
    Runs all metrics collection with default settings.

.EXAMPLE
    .\collect-local-metrics.ps1 -MaxHistoryEntries 50
    Runs collection and rotates history to keep only last 50 entries.

.EXAMPLE
    .\collect-local-metrics.ps1 -ConfigFile .\my-config.json
    Runs collection using settings from JSON config file.

.NOTES
    Configuration File Schema (JSON):
    {
      "CoverageThresholds": {
        "Line": 80,
        "Branch": 75,
        "PublicApi": 90
      },
      "MetricsThresholds": {
        "MaxCyclomaticComplexity": 15,
        "MinMaintainability": 60
      },
      "EnabledChecks": {
        "RunMetrics": true,
        "RunCoverage": true
      },
      "OutputSettings": {
        "OutputPath": "./local-reports",
        "EnableHistoryTracking": true,
        "MaxHistoryEntries": 0,
        "ReportTypes": "Cobertura;HtmlInline_AzurePipelines;JsonSummary;Badges",
        "AssemblyFilters": "+*;-*Tests;-*Benchmarks"
      },
      "PerformanceSettings": {
        "EnableProfiling": false,
        "ShowProgress": false
      }
    }
#>
[CmdletBinding()]
param(
    # Configuration File
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "$PSScriptRoot/collect-local-metrics.config.json",

    # Common
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [switch]$EnableHistoryTracking = $true,

    [Parameter(Mandatory=$false)]
    [int]$MaxHistoryEntries = 0,

    [Parameter(Mandatory=$false)]
    [switch]$EnableProfiling,

    [Parameter(Mandatory=$false)]
    [switch]$ShowProgress,

    # Metrics Specific
    [Parameter(Mandatory=$false)]
    [int]$MaxComplexity = 15,

    [Parameter(Mandatory=$false)]
    [int]$MinMaintainability = 60,

    # Coverage Specific
    [Parameter(Mandatory=$false)]
    [int]$MinLineCoverage = 80,

    [Parameter(Mandatory=$false)]
    [int]$MinBranchCoverage = 70,

    [Parameter(Mandatory=$false)]
    [int]$MinPublicApiCoverage = 90,

    [Parameter(Mandatory=$false)]
    [string]$ReportTypes = "Cobertura;HtmlInline_AzurePipelines;JsonSummary;Badges",

    [Parameter(Mandatory=$false)]
    [string]$AssemblyFilters = "+*;-*Tests;-*Benchmarks"
)

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\ConfigurationLoader.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\EnvironmentDetection.psm1") -Force

# Load and merge configuration
$loadedConfig = Import-ScriptConfiguration -ConfigFile $ConfigFile

if ($loadedConfig) {
    Write-Log "Configuration loaded from: $ConfigFile" -Level SUCCESS
    
    # Define parameter mapping with nested property paths
    $paramMap = @{
        'MinLineCoverage' = 'CoverageThresholds.Line'
        'MinBranchCoverage' = 'CoverageThresholds.Branch'
        'MinPublicApiCoverage' = 'CoverageThresholds.PublicApi'
        'MaxComplexity' = 'MetricsThresholds.MaxCyclomaticComplexity'
        'MinMaintainability' = 'MetricsThresholds.MinMaintainability'
        'OutputPath' = 'OutputSettings.OutputPath'
        'EnableHistoryTracking' = 'OutputSettings.EnableHistoryTracking'
        'MaxHistoryEntries' = 'OutputSettings.MaxHistoryEntries'
        'ReportTypes' = 'OutputSettings.ReportTypes'
        'AssemblyFilters' = 'OutputSettings.AssemblyFilters'
        'EnableProfiling' = 'PerformanceSettings.EnableProfiling'
        'ShowProgress' = 'PerformanceSettings.ShowProgress'
    }
    
    # Merge configuration with CLI parameters (CLI takes precedence)
    $appliedValues = Merge-ConfigurationWithParameters -Config $loadedConfig -BoundParameters $PSBoundParameters -ParameterMap $paramMap
    foreach ($entry in $appliedValues.GetEnumerator()) {
        Set-Variable -Name $entry.Key -Value $entry.Value -Scope Script
    }
}

# Determine enabled checks from configuration
$runMetrics = $true
$runCoverage = $true
if ($loadedConfig -and $loadedConfig.EnabledChecks) {
    if ($null -ne $loadedConfig.EnabledChecks.RunMetrics) {
        $runMetrics = $loadedConfig.EnabledChecks.RunMetrics
    }
    if ($null -ne $loadedConfig.EnabledChecks.RunCoverage) {
        $runCoverage = $loadedConfig.EnabledChecks.RunCoverage
    }
}

# Script Locations
$metricsScript = Join-Path $PSScriptRoot "calculate-code-metrics.ps1"
$coverageScript = Join-Path $PSScriptRoot "enhanced-coverage-analysis.ps1"

# Determine Output Paths (use shared module for environment detection)
if (-not $OutputPath) {
    $OutputPath = Get-DefaultOutputPath -SubPath "local-metrics"
}

$metricsOutput = Join-Path $OutputPath "code-metrics"
$coverageOutput = Join-Path $OutputPath "enhanced-coverage"

Write-Log "=== Starting Local Metrics Collection ===" -Level INFO
Write-Log "Output Base: $OutputPath" -Level INFO
Write-Log "History Tracking: $EnableHistoryTracking" -Level INFO
Write-Log "Max History Entries: $(if ($MaxHistoryEntries -le 0) { 'Infinite' } else { $MaxHistoryEntries })" -Level INFO
Write-Log "Enabled Checks: Metrics=$runMetrics, Coverage=$runCoverage" -Level INFO
Write-Host ""

# 1. Run Code Metrics
if ($runMetrics) {
    if (Test-Path $metricsScript) {
        Write-Log ">>> Running Code Metrics Analysis..." -Level INFO
        $metricsArgs = @{
            Configuration = $Configuration
            OutputPath = $metricsOutput
            MaxComplexity = $MaxComplexity
            MinMaintainability = $MinMaintainability
            EnableHistoryTracking = $EnableHistoryTracking
            MaxHistoryEntries = $MaxHistoryEntries
            EnableProfiling = $EnableProfiling
        }
        
        & $metricsScript @metricsArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Code metrics calculation encountered issues" -Level WARN
        }
    } else {
        Write-Log "Code metrics script not found at $metricsScript" -Level WARN
    }
} else {
    Write-Log ">>> Code Metrics Analysis: SKIPPED (disabled in configuration)" -Level INFO
}

Write-Host ""

# 2. Run Coverage Analysis
if ($runCoverage) {
    if (Test-Path $coverageScript) {
        Write-Log ">>> Running Enhanced Coverage Analysis..." -Level INFO
        $coverageArgs = @{
            Configuration = $Configuration
            OutputPath = $coverageOutput
            MinLineCoverage = $MinLineCoverage
            MinBranchCoverage = $MinBranchCoverage
            MinPublicApiCoverage = $MinPublicApiCoverage
            ReportTypes = $ReportTypes
            AssemblyFilters = $AssemblyFilters
            EnableHistoryTracking = $EnableHistoryTracking
            MaxHistoryEntries = $MaxHistoryEntries
            EnableProfiling = $EnableProfiling
            ShowProgress = $ShowProgress
        }

        & $coverageScript @coverageArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Coverage analysis encountered issues" -Level WARN
        }
    } else {
        Write-Log "Coverage analysis script not found at $coverageScript" -Level WARN
    }
} else {
    Write-Log ">>> Enhanced Coverage Analysis: SKIPPED (disabled in configuration)" -Level INFO
}

Write-Host ""
Write-Log "=== Local Metrics Collection Complete ===" -Level SUCCESS

