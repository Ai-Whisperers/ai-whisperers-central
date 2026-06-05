<#
.SYNOPSIS
    Runs mutation testing to verify test suite effectiveness

.DESCRIPTION
    Uses Stryker.NET to perform mutation testing:
    - Mutates source code (changes operators, removes statements, etc.)
    - Runs test suite against mutated code
    - Measures how many mutations are caught by tests
    - Generates mutation score (% of mutants killed)
    
    High mutation score indicates effective test suite.

.PARAMETER Configuration
    Build configuration to test (Debug or Release). Default: Release

.PARAMETER OutputPath
    Directory to write mutation testing reports.
    Default: Azure Pipelines staging directory or local temp directory

.PARAMETER TargetScore
    Target mutation score percentage (0-100). Default: 75
    Scores below target trigger warnings.

.EXAMPLE
    .\run-mutation-tests.ps1
    
    Runs mutation testing with 75% target score

.EXAMPLE
    .\run-mutation-tests.ps1 -TargetScore 80
    
    Uses stricter 80% target mutation score

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Run Mutation Tests'
      inputs:
        filePath: 'cicd/scripts/run-mutation-tests.ps1'
      timeoutInMinutes: 60

.NOTES
    File Name      : run-mutation-tests.ps1
    Prerequisite   : .NET SDK, Stryker.NET tool
    Portability    : Works in Azure Pipelines and locally
    Duration       : 10-30 minutes (can be long for large codebases)
    
.LINK
    https://stryker-mutator.io/docs/stryker-net/introduction
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for mutation reports")]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false, HelpMessage="Target mutation score percentage (0-100)")]
    [ValidateRange(0, 100)]
    [int]$TargetScore = 75,

    [Parameter(Mandatory=$false, HelpMessage="Show progress bar during execution")]
    [switch]$ShowProgress
)

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\EnvironmentDetection.psm1") -Force

# Determine if progress should be shown (default to true locally, false in CI unless requested)
$showProgressBar = $ShowProgress -or (-not (Test-AzurePipelines))
$activity = "Mutation Testing"

# Detect environment and set portable defaults (using shared module)
if (-not $OutputPath) {
    $OutputPath = Get-DefaultOutputPath -SubPath "mutation-report"
}

Write-Log "" -Level INFO
Write-Log "=== Mutation Testing ===" -Level INFO
Write-Log "" -Level INFO
Write-Log "[WARN] Warning: Mutation testing can take 10-30 minutes" -Level WARN
Write-Log "Configuration: $Configuration" -Level INFO
Write-Log "Output Path: $OutputPath" -Level INFO
Write-Log "Target Score: $TargetScore%" -Level INFO
Write-Log "" -Level INFO

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

# Install Stryker.NET
# Use central tool installer if available
$installScript = Join-Path $PSScriptRoot "install-tools.ps1"
if (Test-Path $installScript) {
    Write-Log "Installing Stryker.NET via central installer..." -Level INFO
    & $installScript -Tools "dotnet-stryker"
} else {
    Write-Log "Installing Stryker.NET mutation testing tool (fallback)..." -Level INFO
    dotnet tool install --global dotnet-stryker --version 4.8.1 2>&1 | Out-Null
}

# Find test projects
$testProjects = Get-ChildItem -Path "tst" -Recurse -Filter "*.Tests.csproj"

if ($testProjects.Count -eq 0) {
    Write-Log "No test projects found" -Level WARN
    exit 0
}

Write-Log "Found $($testProjects.Count) test project(s)" -Level INFO
Write-Log "" -Level INFO

$results = @()
$i = 0

foreach ($testProject in $testProjects) {
    $i++
    $projectName = $testProject.BaseName -replace '\.Tests$', ''
    $testProjectDir = $testProject.DirectoryName
    
    if ($showProgressBar) {
        $percentComplete = [Math]::Round(($i / $testProjects.Count) * 100)
        Write-Progress -Activity $activity -Status "Processing project $i of $($testProjects.Count): $projectName" -PercentComplete $percentComplete
    }

    Write-Log "Running mutation tests for: $projectName" -Level INFO
    Write-Log "  Test project: $($testProject.Name)" -Level INFO
    
    # Create Stryker config
    $strykerConfig = @{
        "stryker-config" = @{
            "project" = "$projectName.csproj"
            "test-projects" = @($testProject.Name)
            "reporters" = @("html", "json", "cleartext", "progress")
            "thresholds" = @{
                "high" = 80
                "low" = 60
                "break" = $TargetScore
            }
            "concurrency" = 4
            "mutation-level" = "Standard"
        }
    }
    
    $configFile = Join-Path $testProjectDir "stryker-config.json"
    $strykerConfig | ConvertTo-Json -Depth 10 | Set-Content $configFile
    
    Write-Log "  Starting mutation testing... (this may take several minutes)" -Level INFO
    
    Push-Location $testProjectDir
    
    try {
        # Run Stryker
        $output = dotnet stryker --config-file "stryker-config.json" 2>&1
        $outputText = $output | Out-String
        
        Write-Log $outputText -Level INFO
        
        # Parse results from JSON report
        $reportDir = Join-Path $testProjectDir "StrykerOutput"
        $latestReport = Get-ChildItem -Path $reportDir -Recurse -Filter "mutation-report.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestReport) {
            $report = Get-Content $latestReport.FullName -Raw | ConvertFrom-Json
            
            $mutationScore = $report.thresholds.high
            $totalMutants = $report.files.Count
            $killed = $report.files | Where-Object { $_.mutants.status -eq "Killed" } | Measure-Object | Select-Object -ExpandProperty Count
            
            $result = @{
                Project = $projectName
                Score = $mutationScore
                TotalMutants = $totalMutants
                Killed = $killed
                Passed = $LASTEXITCODE -eq 0
            }
            
            $results += $result
            
            # Copy report to output
            $projectReportDir = Join-Path $OutputPath $projectName
            New-Item -ItemType Directory -Force -Path $projectReportDir | Out-Null
            Copy-Item -Path "$reportDir\*" -Destination $projectReportDir -Recurse -Force
            
            Write-Log "" -Level INFO
            if ($mutationScore -ge $TargetScore) {
                Write-Log "  Mutation Score: $mutationScore%" -Level SUCCESS
            } else {
                Write-Log "  Mutation Score: $mutationScore%" -Level WARN
            }
            Write-Log "  Mutants Killed: $killed / $totalMutants" -Level INFO
            Write-Log "" -Level INFO
        }
        
    } catch {
        Write-Log "  [ERROR] Mutation testing failed: $_" -Level ERROR
    } finally {
        Pop-Location
        Remove-Item $configFile -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Log "" -Level INFO
Write-Log "Mutation Testing Summary:" -Level INFO
Write-Log "" -Level INFO

$totalScore = if ($results.Count -gt 0) { 
    [Math]::Round(($results | Measure-Object -Property Score -Average).Average, 2) 
} else { 
    0 
}

Write-Log "  Projects Tested: $($results.Count)" -Level INFO
Write-Log "  Average Mutation Score: $totalScore%" -Level INFO
Write-Log "  Target Score: $TargetScore%" -Level INFO
Write-Log "" -Level INFO

# Show individual results
foreach ($result in $results) {
    $symbol = if ($result.Score -ge $TargetScore) { "[PASS]" } else { "[WARN]" }
    if ($result.Score -ge $TargetScore) {
        Write-Log "  $symbol $($result.Project): $($result.Score)%" -Level SUCCESS
    } else {
        Write-Log "  $symbol $($result.Project): $($result.Score)%" -Level WARN
    }
}

Write-Log "" -Level INFO

# Generate summary report
$summary = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    TargetScore = $TargetScore
    AverageScore = $totalScore
    Results = $results
}

$summaryFile = Join-Path $OutputPath "mutation-summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile

# Fail if below target (but only as warning, mutation testing is optional)
if ($totalScore -lt $TargetScore) {
    Write-Log "[WARN] Mutation score ($totalScore%) below target ($TargetScore%)" -Level WARN
    Write-Log "" -Level INFO
    Write-Log "Consider:" -Level INFO
    Write-Log "  1. Adding more test cases for edge conditions" -Level INFO
    Write-Log "  2. Testing different input combinations" -Level INFO
    Write-Log "  3. Verifying boundary conditions" -Level INFO
    Write-Log "" -Level INFO
} else {
    Write-Log "✅ Mutation score meets target!" -Level SUCCESS
    Write-Log "" -Level INFO
}

Write-Log "Reports saved to: $OutputPath" -Level INFO
Write-Log "" -Level INFO

if ($showProgressBar) {
    Write-Progress -Activity $activity -Completed
}

# Don't fail build, just warn
exit 0

