#Requires -Version 7.0

<#
.SYNOPSIS
    Generates documentation coverage report for all source projects

.DESCRIPTION
    Analyzes XML documentation files and generates a comprehensive coverage report:
    - Per-project documentation statistics
    - XML file presence and size
    - Overall solution documentation coverage
    - Generates markdown report for easy viewing
    
    Useful for tracking documentation progress and identifying undocumented code.

.PARAMETER Configuration
    Build configuration to analyze (Debug or Release). Default: Release

.PARAMETER OutputPath
    Directory to write documentation reports. Default: docs-report

.EXAMPLE
    .\generate-doc-report.ps1
    
    Generates documentation report with default settings

.EXAMPLE
    .\generate-doc-report.ps1 -Configuration Debug
    
    Generates report for Debug configuration

.EXAMPLE
    .\generate-doc-report.ps1 -OutputPath "C:\reports\docs"
    
    Writes documentation report to custom directory

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Generate Documentation Report'
      inputs:
        filePath: 'cicd/scripts/generate-doc-report.ps1'
        arguments: '-OutputPath "$(Build.ArtifactStagingDirectory)/docs-report"'

.NOTES
    File Name      : generate-doc-report.ps1
    Prerequisite   : .NET SDK, projects must be built first
    Portability    : Works in Azure Pipelines and locally
    Output         : documentation-coverage-report.md
    
.LINK
    docs/DOCUMENTATION-STANDARDS.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration,
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for documentation reports")]
    [string]$OutputPath,

    [Parameter(Mandatory=$false, HelpMessage="Disable parallel processing")]
    [switch]$DisableParallel,

    [Parameter(Mandatory=$false, HelpMessage="Maximum number of concurrent threads")]
    [int]$ThrottleLimit,

    [Parameter(Mandatory=$false, HelpMessage="Enable performance profiling")]
    [switch]$EnableProfiling,

    [Parameter(Mandatory=$false, HelpMessage="Path to JSON configuration file")]
    [string]$ConfigFile
)

# Determine config file path with CI/CD and local support
if (-not $ConfigFile) {
    if ($env:BUILD_SOURCESDIRECTORY) {
        # Running in Azure Pipelines - use BUILD_SOURCESDIRECTORY
        $ConfigFile = Join-Path $env:BUILD_SOURCESDIRECTORY "cicd/scripts/generate-doc-report-config.json"
    } else {
        # Running locally - use script-relative path
        $ConfigFile = Join-Path $PSScriptRoot "generate-doc-report-config.json"
    }
}

$ErrorActionPreference = "Stop"

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ConfigurationLoader.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules\ProjectUtilities.psm1") -Force

# Load configuration from JSON file if it exists
$config = Import-ScriptConfiguration -ConfigFile $ConfigFile

if ($config) {
    # Define parameter mapping
    $paramMap = @{
        'Configuration' = 'Configuration'
        'OutputPath' = 'OutputPath'
        'DisableParallel' = 'DisableParallel'
        'ThrottleLimit' = 'ThrottleLimit'
        'EnableProfiling' = 'EnableProfiling'
    }
    
    # Merge configuration with CLI parameters (CLI takes precedence)
    $appliedValues = Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParameters -ParameterMap $paramMap
    foreach ($entry in $appliedValues.GetEnumerator()) {
        Set-Variable -Name $entry.Key -Value $entry.Value -Scope Script
    }
}

# Apply defaults for any parameters still not set
if (-not $Configuration) { $Configuration = "Release" }
if (-not $OutputPath) { $OutputPath = "docs-report" }
if (-not $ThrottleLimit -or $ThrottleLimit -le 0) { $ThrottleLimit = $env:NUMBER_OF_PROCESSORS }
if (-not $ThrottleLimit -or $ThrottleLimit -le 0) { $ThrottleLimit = 4 }

# Import shared profiling module
$ProfilingModulePath = Join-Path $PSScriptRoot "modules\ScriptProfiling.psm1"
Import-Module $ProfilingModulePath -Force

Write-Log "========================================" -Level INFO
Write-Log "Generating Documentation Coverage Report" -Level INFO
Write-Log "Configuration: $Configuration" -Level INFO
Write-Log "Output Path: $OutputPath" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "" -Level INFO

$p_init = Start-Profile "Initialization"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$ReportPath = Join-Path $OutputPath "documentation-coverage-report.md"

# Find solution file automatically
$repoRoot = Get-Location
$solutionFile = Get-ChildItem -Path $repoRoot -Filter "*.sln" -File | Select-Object -First 1

if (-not $solutionFile) {
    $solutionName = "Unknown"
} else {
    $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($solutionFile.Name)
}

# Initialize report content
$ReportContent = @"
# Documentation Coverage Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")  
**Configuration:** $Configuration  
**Solution:** $solutionName

---

"@

# Find all source projects
$SourceProjects = Get-ChildItem -Path "src" -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue

if ($SourceProjects.Count -eq 0) {
    Write-Log "[ERROR] No source projects found" -Level ERROR
    $ReportContent += "`n**ERROR:** No source projects found in 'src' directory`n"
    $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8
    exit 1
}

Write-Log "Found $($SourceProjects.Count) source project(s)" -Level INFO
Write-Log "" -Level INFO

Stop-Profile "Initialization" $p_init

# Report table header
$ReportContent += @"
## Project Coverage Summary

| Project | XML File | File Size | Status | Notes |
|---------|----------|-----------|--------|-------|
"@

# Get-TargetFramework function now provided by ProjectUtilities module

$AllProjectsDocumented = $true
$ProjectDetails = @()

    $p_analysis = Start-Profile "Analysis"
    $results = @()
    
    if ($DisableParallel -or $SourceProjects.Count -le 1) {
        Write-Log "Processing $($SourceProjects.Count) projects sequentially..." -Level INFO
        
        $results = $SourceProjects | ForEach-Object {
            $Project = $_
            $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($Project.Name)
            $ProjectDir = $Project.DirectoryName
            $ProjectPath = $Project.FullName
            $TargetFramework = Get-TargetFramework -ProjectPath $ProjectPath
            $XmlPath = Join-Path $ProjectDir "bin\$Configuration\$TargetFramework\$ProjectName.xml"
            
            Write-Log "Analyzing: $ProjectName" -Level INFO
            
            $Status = "Missing"
            $FileSize = "-"
            $XmlExists = "No"
            $Notes = "XML file not generated"
            
            if (Test-Path $XmlPath) {
                $FileSizeBytes = (Get-Item $XmlPath).Length
                $FileSizeKB = [math]::Round($FileSizeBytes / 1024, 2)
                $FileSize = "$FileSizeKB KB"
                $XmlExists = "Yes"
                
                if ($FileSizeBytes -eq 0) {
                    $Status = "Empty"
                    $Notes = "XML file is empty"
                } else {
                    try {
                        [xml]$XmlDoc = Get-Content $XmlPath
                        $MemberCount = 0
                        
                        if ($XmlDoc.doc.members.member) {
                            $MemberCount = $XmlDoc.doc.members.member.Count
                        }
                        
                        if ($MemberCount -eq 0) {
                            $Status = "Low"
                            $Notes = "No documented members found"
                        } else {
                            $Status = "Good"
                            $Notes = "$MemberCount member(s) documented"
                        }
                        
                    } catch {
                        $Status = "Invalid"
                        $Notes = "Unable to parse XML file"
                    }
                }
            }
            
            return [PSCustomObject]@{
                Name = $ProjectName
                Status = $Status
                XmlExists = $XmlExists
                FileSize = $FileSize
                Notes = $Notes
            }
        }
    } else {
        Write-Log "Processing $($SourceProjects.Count) projects in parallel (Throttle: $ThrottleLimit)..." -Level INFO
        
        $progress = [Hashtable]::Synchronized(@{ Completed = 0 })
        $total = $SourceProjects.Count
        
        $results = $SourceProjects | ForEach-Object -Parallel {
            $Project = $_
            $config = $using:Configuration
            $syncProgress = $using:progress
            $syncTotal = $using:total
            
            # Import ProjectUtilities module in parallel scriptblock
            # (Modules must be imported in each parallel runspace)
            $ProjectUtilitiesPath = Join-Path $using:PSScriptRoot "modules\ProjectUtilities.psm1"
            Import-Module $ProjectUtilitiesPath -Force
            
            $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($Project.Name)
            $ProjectDir = $Project.DirectoryName
            $ProjectPath = $Project.FullName
            $TargetFramework = Get-TargetFramework -ProjectPath $ProjectPath
            $XmlPath = Join-Path $ProjectDir "bin\$config\$TargetFramework\$ProjectName.xml"
            
            $Status = "Missing"
            $FileSize = "-"
            $XmlExists = "No"
            $Notes = "XML file not generated"
            
            if (Test-Path $XmlPath) {
                $FileSizeBytes = (Get-Item $XmlPath).Length
                $FileSizeKB = [math]::Round($FileSizeBytes / 1024, 2)
                $FileSize = "$FileSizeKB KB"
                $XmlExists = "Yes"
                
                if ($FileSizeBytes -eq 0) {
                    $Status = "Empty"
                    $Notes = "XML file is empty"
                } else {
                    try {
                        [xml]$XmlDoc = Get-Content $XmlPath
                        $MemberCount = 0
                        if ($XmlDoc.doc.members.member) {
                            $MemberCount = $XmlDoc.doc.members.member.Count
                        }
                        
                        if ($MemberCount -eq 0) {
                            $Status = "Low"
                            $Notes = "No documented members found"
                        } else {
                            $Status = "Good"
                            $Notes = "$MemberCount member(s) documented"
                        }
                    } catch {
                        $Status = "Invalid"
                        $Notes = "Unable to parse XML file"
                    }
                }
            }
            
            $syncProgress.Completed++
            $percent = [math]::Round(($syncProgress.Completed / $syncTotal) * 100)
            Write-Host "[$($syncProgress.Completed)/$syncTotal] Analyzed $ProjectName - $percent%"
            
            return [PSCustomObject]@{
                Name = $ProjectName
                Status = $Status
                XmlExists = $XmlExists
                FileSize = $FileSize
                Notes = $Notes
            }
        } -ThrottleLimit $ThrottleLimit
    }
    
    Stop-Profile "Analysis" $p_analysis
    
    # Process results for reporting
    foreach ($res in $results) {
        if ($res.Status -ne "Good") {
            $AllProjectsDocumented = $false
        }
        
        $ProjectDetails += $res
        $ReportContent += "`n| $($res.Name) | $($res.XmlExists) | $($res.FileSize) | $($res.Status) | $($res.Notes) |"
        
        $logLevel = if ($res.Status -eq "Good") { "SUCCESS" } 
                    elseif ($res.Status -eq "Low" -or $res.Status -eq "Invalid") { "WARN" } 
                    else { "ERROR" }
        Write-Log "  $($res.Name): $($res.Status) - $($res.Notes)" -Level $logLevel
    }
    
    Write-Log "" -Level INFO

$p_report = Start-Profile "Report Generation"

# Overall status
$ReportContent += "`n`n---`n`n"

if ($AllProjectsDocumented) {
    $ReportContent += "## Overall Status: PASS`n`n"
    $ReportContent += "All projects have XML documentation files with content.`n"
} else {
    $ReportContent += "## Overall Status: NEEDS ATTENTION`n`n"
    $ReportContent += "Some projects are missing documentation or have issues.`n"
}

# Recommendations
$ReportContent += "`n## Recommendations`n`n"

$ProjectsNeedingAttention = $ProjectDetails | Where-Object { $_.Status -ne "Good" }

if ($ProjectsNeedingAttention.Count -eq 0) {
    $ReportContent += "No action required. All projects are well-documented.`n"
} else {
    $ReportContent += "The following projects need attention:`n`n"
    foreach ($ProjectDetail in $ProjectsNeedingAttention) {
        $ReportContent += "- **$($ProjectDetail.Name)**: $($ProjectDetail.Notes)`n"
    }
    $ReportContent += "`n### Action Items`n`n"
    $ReportContent += "1. Add XML documentation comments (///) to all public members`n"
    $ReportContent += "2. Ensure ``<GenerateDocumentationFile>true</GenerateDocumentationFile>`` is in .csproj files`n"
    $ReportContent += "3. Build in $Configuration configuration to generate XML files`n"
    $ReportContent += "4. Review documentation standards: ``docs/DOCUMENTATION-STANDARDS.md```n"
}

# References
$ReportContent += "`n## References`n`n"
$ReportContent += "- [Documentation Standards](../docs/DOCUMENTATION-STANDARDS.md)`n"
$ReportContent += "- [Documentation Rules](.cursor/rules/documentation/)`n"
$ReportContent += "- [CI/CD Setup Guide](cicd/QUICK-START.md)`n"

$ReportContent += "`n---`n`n"
$ReportContent += "*This report was automatically generated by the CI/CD pipeline.*`n"

# Write report
$ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8

Write-Log "========================================" -Level INFO
Write-Log "Report Generation Complete" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Report saved to: $ReportPath" -Level SUCCESS
Write-Log "" -Level INFO

Stop-Profile "Report Generation" $p_report
Show-ProfilingReport

if ($AllProjectsDocumented) {
    Write-Log "[PASS] All projects documented successfully!" -Level SUCCESS
    exit 0
} else {
    Write-Log "[WARN] Some projects need attention. Review the report for details." -Level WARN
    exit 0  # Don't fail the pipeline on report generation, just inform
}
