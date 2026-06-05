<#
.SYNOPSIS
    Runs performance benchmarks and detects regressions

.DESCRIPTION
    Executes BenchmarkDotNet performance tests and analyzes results:
    - Runs all benchmark projects
    - Compares against baseline results
    - Detects performance regressions
    - Generates comprehensive performance reports
    
    Useful for tracking performance trends and preventing regressions.

.PARAMETER Configuration
    Build configuration for benchmarks (Debug or Release). Default: Release
    Note: Always use Release for accurate performance measurements

.PARAMETER OutputPath
    Directory to write benchmark reports and results.
    Default: Azure Pipelines staging directory or local directory

.PARAMETER MaxRegressionPercent
    Maximum allowed performance regression percentage. Default: 10
    Benchmarks exceeding this threshold trigger warnings.

.EXAMPLE
    .\run-benchmarks.ps1
    
    Runs benchmarks with default settings (10% regression threshold)

.EXAMPLE
    .\run-benchmarks.ps1 -MaxRegressionPercent 5
    
    Uses stricter 5% regression threshold

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Run Performance Benchmarks'
      inputs:
        filePath: 'cicd/scripts/run-benchmarks.ps1'

.NOTES
    File Name      : run-benchmarks.ps1
    Prerequisite   : .NET SDK, BenchmarkDotNet NuGet package
    Portability    : Works in Azure Pipelines and locally
    Duration       : Can take 10-30 minutes for comprehensive benchmarks
    
.LINK
    https://benchmarkdotnet.org/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (always use Release for accurate benchmarks)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for benchmark reports")]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory=$false, HelpMessage="Maximum allowed performance regression percentage")]
    [ValidateRange(0, 100)]
    [int]$MaxRegressionPercent = 10,

    [Parameter(Mandatory=$false, HelpMessage="Show progress bar during execution")]
    [switch]$ShowProgress
)

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\EnvironmentDetection.psm1") -Force

# Determine if progress should be shown (default to true locally, false in CI unless requested)
$showProgressBar = $ShowProgress -or (-not (Test-AzurePipelines))
$activity = "Performance Benchmarking"

# Set default OutputPath if not provided (using shared module)
if ([string]::IsNullOrEmpty($OutputPath)) {
    if (Test-AzurePipelines) {
        $OutputPath = Get-DefaultOutputPath -SubPath "benchmarks"
    } else {
        $OutputPath = Join-Path $PWD "benchmarks"
    }
}

Write-Log
Write-Log "=== Performance Benchmarks ===" -Level INFO
Write-Log

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

# Find benchmark projects
$benchmarkProjects = Get-ChildItem -Path "." -Recurse -Filter "*.Benchmarks.csproj"

if ($benchmarkProjects.Count -eq 0) {
    Write-Log "No benchmark projects found (*.Benchmarks.csproj)" -Level WARN
    Write-Log
    Write-Log "To add benchmarks:"
    Write-Log "  1. Create project: dotnet new console -n ProjectName.Benchmarks"
    Write-Log "  2. Add package: dotnet add package BenchmarkDotNet"
    Write-Log "  3. Create benchmark classes with [Benchmark] attributes"
    Write-Log
    exit 0
}

Write-Log "Found $($benchmarkProjects.Count) benchmark project(s)"
Write-Log

$results = @()
$i = 0

foreach ($project in $benchmarkProjects) {
    $i++
    $projectName = $project.BaseName
    $projectDir = $project.DirectoryName
    
    if ($showProgressBar) {
        $percentComplete = [Math]::Round(($i / $benchmarkProjects.Count) * 100)
        Write-Progress -Activity $activity -Status "Benchmarking project $i of $($benchmarkProjects.Count): $projectName" -PercentComplete $percentComplete
    }

    Write-Log "Running benchmarks: $projectName" -Level INFO
    
    # Build benchmark project
    Write-Log "  Building..."
    dotnet build $project.FullName --configuration $Configuration --verbosity quiet
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "  Build failed" -Level ERROR
        continue
    }
    
    # Run benchmarks
    Write-Log "  Running benchmarks... (this may take several minutes)"
    
    Push-Location $projectDir
    
    try {
        # Run with JSON exporter for programmatic analysis
        dotnet run --configuration $Configuration --no-build -- --filter "*" --exporters json --memory --threading
        
        # Find results
        $resultsDir = Join-Path $projectDir "BenchmarkDotNet.Artifacts/results"
        
        if (Test-Path $resultsDir) {
            # Copy results to output
            $projectOutputDir = Join-Path $OutputPath $projectName
            New-Item -ItemType Directory -Force -Path $projectOutputDir | Out-Null
            Copy-Item -Path "$resultsDir\*" -Destination $projectOutputDir -Recurse -Force
            
            # Parse JSON results
            $jsonFiles = Get-ChildItem -Path $resultsDir -Filter "*.json"
            
            foreach ($jsonFile in $jsonFiles) {
                $benchmarkData = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
                
                $result = @{
                    Project = $projectName
                    File = $jsonFile.Name
                    Benchmarks = $benchmarkData.Benchmarks.Count
                    Results = @()
                }
                
                foreach ($benchmark in $benchmarkData.Benchmarks) {
                    $stats = $benchmark.Statistics
                    
                    $benchmarkResult = @{
                        Name = $benchmark.FullName
                        Mean = $stats.Mean
                        StdDev = $stats.StandardDeviation
                        Median = $stats.Median
                        Iterations = $stats.N
                    }
                    
                    $result.Results += $benchmarkResult
                    
                    Write-Log "    - $($benchmark.FullName):"
                    Write-Log "      Mean: $([Math]::Round($stats.Mean, 2)) ns"
                    Write-Log "      StdDev: $([Math]::Round($stats.StandardDeviation, 2)) ns"
                }
                
                $results += $result
            }
        }
        
    } catch {
        Write-Log "  Benchmark execution failed: $_" -Level WARN
    } finally {
        Pop-Location
    }
    
    Write-Log
}

# Compare with baseline if available
$baselineFile = "cicd/baseline-benchmarks.json"
$hasBaseline = Test-Path $baselineFile

if ($hasBaseline) {
    Write-Log "Comparing with baseline..." -Level WARN
    Write-Log
    
    $baseline = Get-Content $baselineFile -Raw | ConvertFrom-Json
    $regressions = @()
    
    foreach ($result in $results) {
        foreach ($benchmarkResult in $result.Results) {
            # Find baseline for this benchmark
            $baselineResult = $baseline | Where-Object { $_.Name -eq $benchmarkResult.Name }
            
            if ($baselineResult) {
                $percentChange = (($benchmarkResult.Mean - $baselineResult.Mean) / $baselineResult.Mean) * 100
                
                if ($percentChange -gt $MaxRegressionPercent) {
                    $regressions += @{
                        Name = $benchmarkResult.Name
                        Baseline = $baselineResult.Mean
                        Current = $benchmarkResult.Mean
                        Change = $percentChange
                    }
                    
                    Write-Log "  REGRESSION: $($benchmarkResult.Name)" -Level ERROR
                    Write-Log "     Baseline: $([Math]::Round($baselineResult.Mean, 2)) ns"
                    Write-Log "     Current:  $([Math]::Round($benchmarkResult.Mean, 2)) ns"
                    Write-Log "     Change:   +$([Math]::Round($percentChange, 2))%" -Level ERROR
                    Write-Log
                } elseif ($percentChange -lt -5) {
                    Write-Log "  IMPROVEMENT: $($benchmarkResult.Name)" -Level SUCCESS
                    Write-Log "     Baseline: $([Math]::Round($baselineResult.Mean, 2)) ns"
                    Write-Log "     Current:  $([Math]::Round($benchmarkResult.Mean, 2)) ns"
                    Write-Log "     Change:   $([Math]::Round($percentChange, 2))%" -Level SUCCESS
                    Write-Log
                }
            }
        }
    }
    
    if ($regressions.Count -gt 0) {
        Write-Log "Performance regressions detected!" -Level ERROR
        Write-Log
        Write-Log "Regressions exceeding $MaxRegressionPercent%:"
        foreach ($regression in $regressions) {
            Write-Log "  - $($regression.Name): +$([Math]::Round($regression.Change, 2))%"
        }
        Write-Log
        exit 1
    }
    
} else {
    Write-Log "No baseline found. Run this on main branch to establish baseline."
    Write-Log
}

# Generate summary
$summary = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Branch = $env:BUILD_SOURCEBRANCHNAME
    Projects = $results.Count
    TotalBenchmarks = ($results | ForEach-Object { $_.Benchmarks } | Measure-Object -Sum).Sum
    Results = $results
}

$summaryFile = Join-Path $OutputPath "benchmark-summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile

Write-Log "Benchmark Summary:" -Level WARN
Write-Log "  Projects: $($results.Count)"
Write-Log "  Total Benchmarks: $($summary.TotalBenchmarks)"
Write-Log

# Save as new baseline if this is main branch
if ($env:BUILD_SOURCEBRANCHNAME -eq "main") {
    Write-Log "Saving benchmark results as baseline..."
    Copy-Item $summaryFile $baselineFile -Force
    Write-Log "Baseline updated" -Level SUCCESS
    Write-Log
}

Write-Log "Performance benchmarks complete" -Level SUCCESS
Write-Log
Write-Log "Reports saved to: $OutputPath"
Write-Log

if ($showProgressBar) {
    Write-Progress -Activity $activity -Completed
}

exit 0

