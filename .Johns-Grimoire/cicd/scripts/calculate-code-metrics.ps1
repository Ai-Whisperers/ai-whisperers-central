<#
.SYNOPSIS
    Calculates code quality metrics for maintainability and complexity

.DESCRIPTION
    Uses Microsoft.CodeAnalysis.Metrics to generate industry-standard code metrics:
    - Maintainability Index (0-100, higher is better)
    - Cyclomatic Complexity (lower is better)
    - Lines of Code
    - Identifies high-complexity and low-maintainability code
    
    Provides actionable insights for code quality improvement.

.PARAMETER Configuration
    Build configuration to analyze (Debug or Release). Default: Release

.PARAMETER OutputPath
    Directory to write metrics reports and JSON summaries.
    Default: Azure Pipelines staging directory or local temp directory

.PARAMETER MaxComplexity
    Maximum acceptable cyclomatic complexity. Default: 15
    Methods exceeding this are flagged as high complexity.

.PARAMETER MinMaintainability
    Minimum acceptable maintainability index. Default: 60
    Code below this threshold is flagged as low maintainability.

.EXAMPLE
    .\calculate-code-metrics.ps1
    
    Calculates metrics with default thresholds (complexity ≤15, maintainability ≥60)

.EXAMPLE
    .\calculate-code-metrics.ps1 -MaxComplexity 10 -MinMaintainability 70
    
    Uses stricter quality thresholds

.EXAMPLE
    .\calculate-code-metrics.ps1 -OutputPath "C:\reports\metrics"
    
    Writes metrics report to custom directory

.EXAMPLE
    .\calculate-code-metrics.ps1 -ConfigFile "cicd/config/code-metrics-config.json"
    
    Runs metrics calculation using settings from the specified configuration file.

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Calculate Code Metrics'
      inputs:
        filePath: 'cicd/scripts/calculate-code-metrics.ps1'
        arguments: '-MaxComplexity 12'

.NOTES
    File Name      : calculate-code-metrics.ps1
    Prerequisite   : .NET SDK, Microsoft.CodeAnalysis.Metrics
    Portability    : Works in Azure Pipelines and locally
    
.LINK
    https://docs.microsoft.com/visualstudio/code-quality/code-metrics-values
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for metrics reports")]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false, HelpMessage="Maximum cyclomatic complexity threshold")]
    [ValidateRange(1, 100)]
    [int]$MaxComplexity = 15,
    
    [Parameter(Mandatory=$false, HelpMessage="Minimum maintainability index threshold")]
    [ValidateRange(0, 100)]
    [int]$MinMaintainability = 60,

    [Parameter(Mandatory=$false, HelpMessage="Enable historical tracking of metrics")]
    [switch]$EnableHistoryTracking,

    [Parameter(Mandatory=$false, HelpMessage="Maximum number of history entries to keep (0 or -1 for infinite)")]
    [int]$MaxHistoryEntries = 0,

    [Parameter(Mandatory=$false, HelpMessage="Path to JSON configuration file")]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false, HelpMessage="Enable performance profiling")]
    [switch]$EnableProfiling
)

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptProfiling.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\ConfigurationLoader.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\EnvironmentDetection.psm1") -Force

# Load configuration from file
if (-not $ConfigFile) {
    # Check default location
    $defaultConfig = Join-Path $PSScriptRoot "../config/code-metrics-config.json"
    if (Test-Path $defaultConfig) {
        $ConfigFile = $defaultConfig
    }
}

$config = Import-ScriptConfiguration -ConfigFile $ConfigFile

if ($config) {
    Write-Host "Configuration loaded from: $ConfigFile" -ForegroundColor Cyan
    
    # Define parameter mapping
    $paramMap = @{
        'Configuration' = 'Configuration'
        'OutputPath' = 'OutputPath'
        'MaxComplexity' = 'MaxComplexity'
        'MinMaintainability' = 'MinMaintainability'
        'EnableProfiling' = 'EnableProfiling'
    }
    
    # Merge configuration with CLI parameters (CLI takes precedence)
    $appliedValues = Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParameters -ParameterMap $paramMap
    foreach ($entry in $appliedValues.GetEnumerator()) {
        Set-Variable -Name $entry.Key -Value $entry.Value -Scope Script
    }
}

Write-Host ""
Write-Host "=== Code Metrics Analysis (Microsoft.CodeAnalysis.Metrics) ===" -ForegroundColor Cyan
Write-Host ""

# Detect environment and set portable defaults (using shared module)
if (-not $OutputPath) {
    $OutputPath = Get-DefaultOutputPath -SubPath "code-metrics"
}

Write-Host "Configuration: $Configuration"
Write-Host "Output Path: $OutputPath"
Write-Host "Max Complexity: $MaxComplexity"
Write-Host "Min Maintainability: $MinMaintainability"
Write-Host ""

$p_setup = Start-Profile "Project Discovery"

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

# 1. Find Solution File Automatically
$repoRoot = Resolve-Path "$PSScriptRoot/../.."
$solutionFile = Get-ChildItem -Path $repoRoot -Filter "*.sln" -File | Select-Object -First 1

if (-not $solutionFile) {
    Write-Host "##vso[task.logissue type=error]No solution file found in repository root: $repoRoot"
    exit 1
}

Write-Host "Found solution: $($solutionFile.Name)" -ForegroundColor Cyan

Stop-Profile "Project Discovery" $p_setup

# 2. Run Metrics Calculation via MSBuild
Write-Host "Calculating metrics..."
$p_calc = Start-Profile "Metrics Calculation"
# /t:Metrics triggers the analysis. /p:MetricsOutputFile=... allows custom output but defaults to project output dir
dotnet build $solutionFile.FullName /t:Metrics /p:Configuration=$Configuration /v:q

if ($LASTEXITCODE -ne 0) {
    Write-Host "##vso[task.logissue type=error]Metrics calculation failed!"
    exit 1
}

Stop-Profile "Metrics Calculation" $p_calc

# 3. Find and Parse Metrics Files
Write-Host "Analyzing results..."
$p_analysis = Start-Profile "Result Analysis"
$metricsFiles = Get-ChildItem -Path "." -Recurse -Filter "*.Metrics.xml"

if ($metricsFiles.Count -eq 0) {
    Write-Host "##vso[task.logissue type=warning]No metrics files generated."
    exit 0
}

$highComplexity = @()
$lowMaintainability = @()
$totalMethods = 0
$projectMetricsList = @()

foreach ($file in $metricsFiles) {
    [xml]$xml = Get-Content $file.FullName
    
    # Structure: CodeMetricsReport -> Targets -> Target -> Assembly -> Namespaces -> ...
    # We want to drill down to Member level for complexity
    
    $assemblyName = $xml.CodeMetricsReport.Targets.Target.Name
    $assemblyMetrics = $xml.CodeMetricsReport.Targets.Target.Assembly.Metrics
    
    # Assembly Level Metrics
    $maintainability = ($assemblyMetrics.Metric | Where-Object { $_.Name -eq "MaintainabilityIndex" }).Value
    $complexity = ($assemblyMetrics.Metric | Where-Object { $_.Name -eq "CyclomaticComplexity" }).Value
    $loc = ($assemblyMetrics.Metric | Where-Object { $_.Name -eq "SourceLines" }).Value
    
    if (-not $maintainability) { $maintainability = 0 }
    if (-not $complexity) { $complexity = 0 }
    if (-not $loc) { $loc = 0 }
    
    Write-Host "  Project: $assemblyName" -ForegroundColor Yellow
    Write-Host "    Maintainability: $maintainability"
    Write-Host "    Total Complexity: $complexity"
    Write-Host "    Lines of Code: $loc"
    
    $projectMetricsList += @{
        Project = $assemblyName
        Maintainability = $maintainability
        Complexity = $complexity
        SourceLines = $loc
    }

    # Drill down to method level for high complexity checks
    $members = $xml.SelectNodes("//Member")
    
    foreach ($member in $members) {
        $memberName = $member.Name
        $memberComplexity = ($member.Metrics.Metric | Where-Object { $_.Name -eq "CyclomaticComplexity" }).Value
        $memberMaintainability = ($member.Metrics.Metric | Where-Object { $_.Name -eq "MaintainabilityIndex" }).Value
        
        if (-not $memberComplexity) { $memberComplexity = 0 }
        if (-not $memberMaintainability) { $memberMaintainability = 100 } # Default to perfect if missing

        
        $totalMethods++
        
        if ([int]$memberComplexity -gt $MaxComplexity) {
            $highComplexity += "$assemblyName | $memberName (Complexity: $memberComplexity)"
        }
        
        if ([int]$memberMaintainability -lt $MinMaintainability) {
            $lowMaintainability += "$assemblyName | $memberName (Maintainability: $memberMaintainability)"
        }
    }
}

Stop-Profile "Result Analysis" $p_analysis

# 4. Report Results
$p_report = Start-Profile "Reporting"
Write-Host ""
Write-Host "Code Metrics Summary:" -ForegroundColor Yellow
Write-Host "  Projects Analyzed: $($metricsFiles.Count)"
Write-Host "  Total Methods: $totalMethods"
Write-Host ""
Write-Host "  High Complexity Issues (> $MaxComplexity): $($highComplexity.Count)" -ForegroundColor $(if ($highComplexity.Count -gt 0) { "Red" } else { "Green" })
Write-Host "  Low Maintainability Issues (< $MinMaintainability): $($lowMaintainability.Count)" -ForegroundColor $(if ($lowMaintainability.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

# Show high complexity methods
if ($highComplexity.Count -gt 0) {
    Write-Host "[WARN] HIGH COMPLEXITY DETECTED:" -ForegroundColor Yellow
    foreach ($item in $highComplexity) {
        Write-Host "  - $item"
    }
    Write-Host "##vso[task.logissue type=warning]High complexity methods detected. Consider refactoring."
}

# Show low maintainability methods
if ($lowMaintainability.Count -gt 0) {
    Write-Host "[WARN] LOW MAINTAINABILITY:" -ForegroundColor Yellow
    foreach ($item in $lowMaintainability) {
        Write-Host "  - $item"
    }
    Write-Host "##vso[task.logissue type=warning]Low maintainability detected. Consider refactoring."
}

# 5. Save Summary Artifact
$summary = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Projects = $projectMetricsList
    HighComplexity = $highComplexity
    LowMaintainability = $lowMaintainability
}

$summaryFile = Join-Path $OutputPath "metrics-summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile

# History Tracking
if ($EnableHistoryTracking) {
    Write-Host "Updating metrics history..."
    
    Import-Module (Join-Path $PSScriptRoot "modules\HistoryTracking.psm1") -Force
    
    $historyDir = Join-Path (Resolve-Path "$PSScriptRoot/../..") ".history"
    $historyFile = Join-Path $historyDir "code-metrics-history.jsonl"
    
    $avgMaintainability = ($projectMetricsList.Maintainability | Measure-Object -Average).Average
    $avgComplexity = ($projectMetricsList.Complexity | Measure-Object -Average).Average
    $totalLoc = ($projectMetricsList.SourceLines | Measure-Object -Sum).Sum
    
    $metrics = @{
        AvgMaintainability = [Math]::Round($avgMaintainability, 2)
        AvgComplexity = [Math]::Round($avgComplexity, 2)
        TotalLinesOfCode = $totalLoc
    }
    
    Add-HistoryEntry -HistoryFile $historyFile -Metrics $metrics -MaxEntries $MaxHistoryEntries
}

Write-Host "Report saved to: $summaryFile" -ForegroundColor Green
Write-Host ""

Stop-Profile "Reporting" $p_report
Show-ProfilingReport

# Fail if *critical* threshold (e.g. strict gate), currently just warning
# if ($highComplexity.Count -gt 0) { exit 1 }

exit 0
