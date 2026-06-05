#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Analyzes code quality configuration across the repository.

.DESCRIPTION
    Discovers and analyzes quality-related configuration from:
    - .editorconfig files (diagnostic severity overrides)
    - Directory.Build.props (NoWarn, TreatWarningsAsErrors, AnalysisLevel)
    - Directory.Packages.props (analyzer package versions)
    - Project files (.csproj) for project-specific overrides
    
    Provides structured output showing:
    - What diagnostics are suppressed
    - What severity levels are configured
    - What analysis level is active
    - Conflicts or inconsistencies

.PARAMETER OutputFormat
    Output format: 'console' (default), 'json', 'markdown'

.PARAMETER ShowSuppressedOnly
    Show only suppressed diagnostics (NoWarn entries)

.PARAMETER ShowConflicts
    Show only conflicting configurations between files

.EXAMPLE
    .\analyze-quality-config.ps1
    
.EXAMPLE
    .\analyze-quality-config.ps1 -OutputFormat json > quality-config-report.json
    
.EXAMPLE
    .\analyze-quality-config.ps1 -ShowSuppressedOnly

.NOTES
    Version: 1.0.0
    Evolution Level: 1 (Basic extraction and reporting)
    Created: 2025-12-14
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('console', 'json', 'markdown')]
    [string]$OutputFormat = 'console',
    
    [Parameter()]
    [switch]$ShowSuppressedOnly,
    
    [Parameter()]
    [switch]$ShowConflicts
)

$ErrorActionPreference = 'Stop'
$script:Version = '1.0.0'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

#region Helper Functions

function Write-Section {
    param([string]$Title)
    
    if ($OutputFormat -eq 'console') {
        Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
        Write-Host $Title -ForegroundColor Cyan
        Write-Host $('=' * 80) -ForegroundColor Cyan
    }
}

function Write-SubSection {
    param([string]$Title)
    
    if ($OutputFormat -eq 'console') {
        Write-Host "`n$Title" -ForegroundColor Yellow
        Write-Host $('-' * $Title.Length) -ForegroundColor Yellow
    }
}

function Get-EditorConfigRules {
    Write-Verbose "Scanning for .editorconfig files..."
    
    $editorConfigFiles = Get-ChildItem -Path $repoRoot -Filter ".editorconfig" -Recurse -ErrorAction SilentlyContinue
    $allRules = @{}
    
    foreach ($file in $editorConfigFiles) {
        $relativePath = $file.FullName.Replace($repoRoot, '').TrimStart('\', '/')
        
        $content = Get-Content $file.FullName -Raw
        $lines = $content -split "`r?`n"
        $currentSection = "[*]"
        
        foreach ($line in $lines) {
            if ($line -match '^\s*\[(?<section>[^\]]+)\]\s*$') {
                $currentSection = "[$($Matches['section'])]"
                continue
            }

            if ($line -match '^\s*dotnet_diagnostic\.([A-Z]{2,4}\d{4})\.severity\s*=\s*(\w+)') {
                $ruleId = $Matches[1]
                $severity = $Matches[2]
                
                if (-not $allRules.ContainsKey($ruleId)) {
                    $allRules[$ruleId] = @()
                }
                
                $allRules[$ruleId] += @{
                    File = $relativePath
                    Section = $currentSection
                    Severity = $severity
                    Line = $line.Trim()
                }
            }
        }
    }
    
    return @{
        Files = $editorConfigFiles
        Rules = $allRules
    }
}

function Get-DirectoryBuildPropsSettings {
    Write-Verbose "Analyzing Directory.Build.props..."
    
    $buildPropsPath = Join-Path $repoRoot "Directory.Build.props"
    
    if (-not (Test-Path $buildPropsPath)) {
        return $null
    }
    
    $content = Get-Content $buildPropsPath -Raw
    $xml = [xml]$content
    
    $settings = @{
        File = "Directory.Build.props"
        NoWarn = @()
        NoWarnConditional = @()
        TreatWarningsAsErrors = $null
        AnalysisLevel = $null
        EnforceCodeStyleInBuild = $null
        GenerateDocumentationFile = $null
    }
    
    # Extract NoWarn (global vs conditional)
    $noWarnNodes = $xml.SelectNodes("//NoWarn")
    foreach ($noWarnNode in $noWarnNodes) {
        $noWarnValue = $noWarnNode.InnerText
        $rules = $noWarnValue -split '[;,]' | Where-Object { $_ } | ForEach-Object { $_.Trim() }

        $propertyGroupNode = $noWarnNode.ParentNode
        while ($propertyGroupNode -and $propertyGroupNode.Name -ne 'PropertyGroup') {
            $propertyGroupNode = $propertyGroupNode.ParentNode
        }

        $condition =
            if ($propertyGroupNode -and $propertyGroupNode.Attributes -and $propertyGroupNode.Attributes["Condition"]) {
                $propertyGroupNode.Attributes["Condition"].Value
            } else {
                ""
            }

        if ([string]::IsNullOrWhiteSpace($condition)) {
            $settings.NoWarn += $rules
        } else {
            $settings.NoWarnConditional += @{
                Condition = $condition
                Rules = $rules
            }
        }
    }

    $settings.NoWarn = $settings.NoWarn | Where-Object { $_ } | Select-Object -Unique
    
    # Extract TreatWarningsAsErrors
    $treatWarningsNode = $xml.SelectSingleNode("//TreatWarningsAsErrors")
    if ($treatWarningsNode) {
        $settings.TreatWarningsAsErrors = $treatWarningsNode.InnerText
    }
    
    # Extract AnalysisLevel
    $analysisLevelNode = $xml.SelectSingleNode("//AnalysisLevel")
    if ($analysisLevelNode) {
        $settings.AnalysisLevel = $analysisLevelNode.InnerText
    }
    
    # Extract EnforceCodeStyleInBuild
    $enforceNode = $xml.SelectSingleNode("//EnforceCodeStyleInBuild")
    if ($enforceNode) {
        $settings.EnforceCodeStyleInBuild = $enforceNode.InnerText
    }
    
    # Extract GenerateDocumentationFile
    $docFileNode = $xml.SelectSingleNode("//GenerateDocumentationFile")
    if ($docFileNode) {
        $settings.GenerateDocumentationFile = $docFileNode.InnerText
    }
    
    return $settings
}

function Get-DirectoryPackagesProps {
    Write-Verbose "Analyzing Directory.Packages.props..."
    
    $packagesPropsPath = Join-Path $repoRoot "Directory.Packages.props"
    
    if (-not (Test-Path $packagesPropsPath)) {
        return $null
    }
    
    $content = Get-Content $packagesPropsPath -Raw
    $xml = [xml]$content
    
    $analyzers = @()
    
    # Find analyzer packages
    $packageNodes = $xml.SelectNodes("//PackageVersion")
    foreach ($node in $packageNodes) {
        $id = $node.Include
        $version = $node.Version
        
        # Common analyzer package patterns
        if ($id -match 'Analyzer|CodeAnalysis|StyleCop|FxCop') {
            $analyzers += @{
                Package = $id
                Version = $version
            }
        }
    }
    
    return @{
        File = "Directory.Packages.props"
        Analyzers = $analyzers
    }
}

function Get-ProjectSpecificSettings {
    Write-Verbose "Scanning project files for quality overrides..."
    
    $projectFiles = Get-ChildItem -Path $repoRoot -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
    $projectSettings = @()
    
    foreach ($project in $projectFiles) {
        $relativePath = $project.FullName.Replace($repoRoot, '').TrimStart('\', '/')
        
        try {
            $content = Get-Content $project.FullName -Raw
            $xml = [xml]$content
            
            # Check for NoWarn overrides
            $noWarnNode = $xml.SelectSingleNode("//NoWarn")
            $treatWarningsNode = $xml.SelectSingleNode("//TreatWarningsAsErrors")
            $analysisLevelNode = $xml.SelectSingleNode("//AnalysisLevel")
            
            if ($noWarnNode -or $treatWarningsNode -or $analysisLevelNode) {
                $settings = @{
                    Project = $relativePath
                    NoWarn = if ($noWarnNode) { $noWarnNode.InnerText } else { $null }
                    TreatWarningsAsErrors = if ($treatWarningsNode) { $treatWarningsNode.InnerText } else { $null }
                    AnalysisLevel = if ($analysisLevelNode) { $analysisLevelNode.InnerText } else { $null }
                }
                
                $projectSettings += $settings
            }
        }
        catch {
            Write-Verbose "Could not parse project file: $relativePath"
        }
    }
    
    return $projectSettings
}

function Find-Conflicts {
    param(
        [hashtable]$EditorConfigRules,
        [hashtable]$BuildPropsSettings
    )
    
    $conflicts = @()
    $scopedOverrides = @()
    
    # Find rules with multiple severity definitions in .editorconfig
    foreach ($ruleId in $EditorConfigRules.Rules.Keys) {
        $definitions = $EditorConfigRules.Rules[$ruleId]
        
        if ($definitions.Count -gt 1) {
            $severitiesBySection = $definitions | Group-Object -Property Section

            # Conflicts: same section has multiple severities
            foreach ($group in $severitiesBySection) {
                $sectionSeverities = $group.Group | Select-Object -ExpandProperty Severity -Unique
                if ($sectionSeverities.Count -gt 1) {
                    $conflicts += @{
                        Type = "EditorConfigConflict"
                        RuleId = $ruleId
                        Definitions = $group.Group
                        Message = "Rule $ruleId has conflicting severities in $($group.Name): $($sectionSeverities -join ', ')"
                    }
                }
            }

            # Overrides: different sections intentionally have different severities
            $uniquePairs = $severitiesBySection | ForEach-Object {
                $severity = ($_.Group | Select-Object -ExpandProperty Severity -First 1)
                "$($_.Name)=$severity"
            }

            if ($uniquePairs.Count -gt 1 -and -not ($conflicts | Where-Object { $_.RuleId -eq $ruleId -and $_.Type -eq 'EditorConfigConflict' })) {
                $scopedOverrides += @{
                    Type = "EditorConfigScopedOverride"
                    RuleId = $ruleId
                    Message = "Rule $ruleId has section-scoped severities: $($uniquePairs -join '; ')"
                    Definitions = $definitions
                }
            }
        }
    }
    
    # Find rules suppressed in NoWarn but configured in .editorconfig
    if ($BuildPropsSettings -and $BuildPropsSettings.NoWarn) {
        foreach ($suppressedRule in $BuildPropsSettings.NoWarn) {
            if ($EditorConfigRules.Rules.ContainsKey($suppressedRule)) {
                $editorConfigSeverity = $EditorConfigRules.Rules[$suppressedRule][0].Severity
                
                $conflicts += @{
                    Type = "NoWarnVsEditorConfig"
                    RuleId = $suppressedRule
                    Message = "Rule $suppressedRule is suppressed in NoWarn but set to '$editorConfigSeverity' in .editorconfig"
                    NoWarnSource = "Directory.Build.props"
                    EditorConfigSeverity = $editorConfigSeverity
                }
            }
        }
    }
    
    return @{
        Conflicts = $conflicts
        ScopedOverrides = $scopedOverrides
    }
}

#endregion

#region Main Analysis

Write-Verbose "Starting quality configuration analysis..."
Write-Verbose "Repository root: $repoRoot"

# Collect all configuration data
$editorConfigData = Get-EditorConfigRules
$buildPropsSettings = Get-DirectoryBuildPropsSettings
$packagesPropsData = Get-DirectoryPackagesProps
$projectSettings = Get-ProjectSpecificSettings

# Find conflicts and scoped overrides
$conflictResults = Find-Conflicts -EditorConfigRules $editorConfigData -BuildPropsSettings $buildPropsSettings
$conflicts = $conflictResults.Conflicts
$scopedOverrides = $conflictResults.ScopedOverrides

#endregion

#region Output Generation

if ($OutputFormat -eq 'json') {
    $report = @{
        AnalysisTimestamp = Get-Date -Format "o"
        RepositoryRoot = $repoRoot
        EditorConfig = @{
            FilesFound = $editorConfigData.Files.Count
            RulesConfigured = $editorConfigData.Rules.Count
            Rules = $editorConfigData.Rules
        }
        DirectoryBuildProps = $buildPropsSettings
        DirectoryPackagesProps = $packagesPropsData
        ProjectOverrides = $projectSettings
        Conflicts = $conflicts
        ScopedOverrides = $scopedOverrides
    }
    
    $report | ConvertTo-Json -Depth 10
    exit 0
}

if ($OutputFormat -eq 'markdown') {
    Write-Output "# Code Quality Configuration Report"
    Write-Output ""
    Write-Output "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "**Repository:** $repoRoot"
    Write-Output ""
    
    # Would expand markdown output here
    # For now, fall back to console
}

# Console output (default)
Write-Section "CODE QUALITY CONFIGURATION ANALYSIS"
Write-Host "Repository: $repoRoot" -ForegroundColor Gray
Write-Host "Analysis Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Directory.Build.props Settings
if ($buildPropsSettings) {
    Write-Section "DIRECTORY.BUILD.PROPS SETTINGS"
    
    Write-Host "Analysis Level: " -NoNewline -ForegroundColor White
    Write-Host ($buildPropsSettings.AnalysisLevel ?? "(not set)") -ForegroundColor $(if ($buildPropsSettings.AnalysisLevel) { 'Green' } else { 'Yellow' })
    
    Write-Host "Treat Warnings As Errors: " -NoNewline -ForegroundColor White
    Write-Host ($buildPropsSettings.TreatWarningsAsErrors ?? "(not set)") -ForegroundColor $(if ($buildPropsSettings.TreatWarningsAsErrors -eq 'true') { 'Green' } else { 'Yellow' })
    
    Write-Host "Enforce Code Style In Build: " -NoNewline -ForegroundColor White
    Write-Host ($buildPropsSettings.EnforceCodeStyleInBuild ?? "(not set)") -ForegroundColor $(if ($buildPropsSettings.EnforceCodeStyleInBuild -eq 'true') { 'Green' } else { 'Yellow' })
    
    Write-Host "Generate Documentation File: " -NoNewline -ForegroundColor White
    Write-Host ($buildPropsSettings.GenerateDocumentationFile ?? "(not set)") -ForegroundColor $(if ($buildPropsSettings.GenerateDocumentationFile -eq 'true') { 'Green' } else { 'Yellow' })
    
    if ($buildPropsSettings.NoWarn -and $buildPropsSettings.NoWarn.Count -gt 0) {
        Write-SubSection "Suppressed Diagnostics (NoWarn)"
        Write-Host "Count: $($buildPropsSettings.NoWarn.Count)" -ForegroundColor Cyan
        
        $buildPropsSettings.NoWarn | Sort-Object | ForEach-Object {
            Write-Host "  • $_" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "`nDirectory.Build.props not found" -ForegroundColor Yellow
}

# .editorconfig Rules
if ($editorConfigData.Files.Count -gt 0) {
    Write-Section ".EDITORCONFIG DIAGNOSTIC RULES"
    Write-Host "Files found: $($editorConfigData.Files.Count)" -ForegroundColor Cyan
    Write-Host "Rules configured: $($editorConfigData.Rules.Count)" -ForegroundColor Cyan
    
    if (-not $ShowSuppressedOnly) {
        Write-SubSection "Rules by Severity"
        
        $bySeverity = @{}
        foreach ($ruleId in $editorConfigData.Rules.Keys) {
            $severity = $editorConfigData.Rules[$ruleId][0].Severity
            if (-not $bySeverity.ContainsKey($severity)) {
                $bySeverity[$severity] = @()
            }
            $bySeverity[$severity] += $ruleId
        }
        
        foreach ($severity in ($bySeverity.Keys | Sort-Object)) {
            $count = $bySeverity[$severity].Count
            $color = switch ($severity.ToLower()) {
                'error' { 'Red' }
                'warning' { 'Yellow' }
                'suggestion' { 'Cyan' }
                'none' { 'Gray' }
                default { 'White' }
            }
            
            Write-Host "`n$severity ($count rules)" -ForegroundColor $color
            $bySeverity[$severity] | Sort-Object | ForEach-Object {
                Write-Host "  • $_" -ForegroundColor Gray
            }
        }
    }
    
    # Show sample of rules with file locations
    Write-SubSection "Sample Rules with Locations (first 10)"
    $editorConfigData.Rules.Keys | Select-Object -First 10 | Sort-Object | ForEach-Object {
        $ruleId = $_
        $definition = $editorConfigData.Rules[$ruleId][0]
        Write-Host "  $ruleId " -NoNewline -ForegroundColor White
        Write-Host "→ $($definition.Severity) " -NoNewline -ForegroundColor Cyan
        Write-Host "($($definition.File))" -ForegroundColor Gray
    }
}
else {
    Write-Host "`nNo .editorconfig files found" -ForegroundColor Yellow
}

# Analyzer Packages
if ($packagesPropsData -and $packagesPropsData.Analyzers.Count -gt 0) {
    Write-Section "ANALYZER PACKAGES"
    Write-Host "Analyzers found: $($packagesPropsData.Analyzers.Count)" -ForegroundColor Cyan
    
    foreach ($analyzer in $packagesPropsData.Analyzers) {
        Write-Host "  • $($analyzer.Package) " -NoNewline -ForegroundColor White
        Write-Host "v$($analyzer.Version)" -ForegroundColor Gray
    }
}

# Project-Specific Overrides
if ($projectSettings.Count -gt 0) {
    Write-Section "PROJECT-SPECIFIC OVERRIDES"
    Write-Host "Projects with overrides: $($projectSettings.Count)" -ForegroundColor Cyan
    
    foreach ($project in $projectSettings) {
        Write-Host "`n$($project.Project)" -ForegroundColor Yellow
        if ($project.NoWarn) {
            Write-Host "  NoWarn: $($project.NoWarn)" -ForegroundColor Gray
        }
        if ($project.TreatWarningsAsErrors) {
            Write-Host "  TreatWarningsAsErrors: $($project.TreatWarningsAsErrors)" -ForegroundColor Gray
        }
        if ($project.AnalysisLevel) {
            Write-Host "  AnalysisLevel: $($project.AnalysisLevel)" -ForegroundColor Gray
        }
    }
}

# Conflicts
if ($conflicts.Count -gt 0) {
    Write-Section "⚠️  CONFIGURATION CONFLICTS"
    Write-Host "Conflicts found: $($conflicts.Count)" -ForegroundColor Red
    
    foreach ($conflict in $conflicts) {
        Write-Host "`n[$($conflict.Type)]" -ForegroundColor Red
        Write-Host "  $($conflict.Message)" -ForegroundColor Yellow
        
        if ($conflict.Definitions) {
            Write-Host "  Definitions:" -ForegroundColor Gray
            foreach ($def in $conflict.Definitions) {
                Write-Host "    - $($def.File): $($def.Severity)" -ForegroundColor Gray
            }
        }
    }
}
else {
    Write-Section "✓ NO CONFIGURATION CONFLICTS"
    Write-Host "All quality settings are consistent" -ForegroundColor Green
}

# Scoped overrides (informational)
if ($scopedOverrides.Count -gt 0 -and -not $ShowConflicts) {
    Write-Section "ℹ️  SCOPED OVERRIDES"
    Write-Host "Scoped overrides found: $($scopedOverrides.Count)" -ForegroundColor Cyan

    foreach ($override in $scopedOverrides) {
        Write-Host "`n[$($override.Type)]" -ForegroundColor Cyan
        Write-Host "  $($override.Message)" -ForegroundColor Gray
    }
}

# Summary
Write-Section "SUMMARY"
Write-Host "Configuration Sources:" -ForegroundColor White
Write-Host "  • .editorconfig files: $($editorConfigData.Files.Count)" -ForegroundColor Gray
Write-Host "  • Directory.Build.props: $(if ($buildPropsSettings) { '✓' } else { '✗' })" -ForegroundColor Gray
Write-Host "  • Directory.Packages.props: $(if ($packagesPropsData) { '✓' } else { '✗' })" -ForegroundColor Gray
Write-Host "  • Project overrides: $($projectSettings.Count)" -ForegroundColor Gray

Write-Host "`nDiagnostics:" -ForegroundColor White
Write-Host "  • Configured in .editorconfig: $($editorConfigData.Rules.Count)" -ForegroundColor Gray
Write-Host "  • Suppressed in NoWarn: $($buildPropsSettings.NoWarn.Count)" -ForegroundColor $(if ($buildPropsSettings.NoWarn.Count -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "  • Conflicts detected: $($conflicts.Count)" -ForegroundColor $(if ($conflicts.Count -eq 0) { 'Green' } else { 'Red' })

Write-Host ""

#endregion
