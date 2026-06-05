#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Configuration-driven code quality enforcement script for .NET projects

.DESCRIPTION
    Enforces code quality standards by enabling warnings-as-errors and updating
    project configurations using a centralized quality-config.json file.
    
    This script helps maintain zero-warnings, zero-errors discipline by:
    - Enabling TreatWarningsAsErrors in project files
    - Configuring analysis levels and .NET analyzers
    - Updating .editorconfig with diagnostic rules from configuration
    - Testing builds with warnings-as-errors enabled
    - Supporting temporary relaxation of specific rules via IGNORE setting
    
    Configuration File (quality-config.json):
    - Set rules to: error, warning, suggestion, none, or IGNORE
    - IGNORE = do not write to .editorconfig (temporary relaxation)
    - Organize rules by category with _comment entries
    - Control severity levels for incremental quality enforcement

.PARAMETER TargetPath
    Path to the directory containing project files to process. Default: current directory

.PARAMETER Action
    Action to perform:
    - 'enforce': Enable warnings-as-errors in project files
    - 'update-editorconfig': Update .editorconfig from quality configuration

.PARAMETER TimeoutSeconds
    Timeout for build test operation in seconds. Default: 180 (3 minutes)

.PARAMETER ConfigPath
    Path to quality configuration JSON file. Default: quality-config.json in script directory

.EXAMPLE
    .\enforce-quality.ps1
    Enforces quality standards using default configuration

.EXAMPLE
    .\enforce-quality.ps1 -Action update-editorconfig
    Updates .editorconfig from quality-config.json (generates ~200+ diagnostic rules)

.EXAMPLE
    .\enforce-quality.ps1 -TargetPath "src" -Action enforce
    Enables warnings-as-errors in all projects under src directory

.EXAMPLE
    .\enforce-quality.ps1 -ConfigPath ".\custom-config.json"
    Uses custom quality configuration file

.EXAMPLE
    # Workflow: Detect errors, relax rules, fix, tighten
    # 1. Update .editorconfig to detect all issues
    .\enforce-quality.ps1 -Action update-editorconfig
    
    # 2. Build fails - set problematic rules to IGNORE in quality-config.json
    # Edit quality-config.json: "CA1234": "IGNORE"
    
    # 3. Regenerate .editorconfig without those rules
    .\enforce-quality.ps1 -Action update-editorconfig
    
    # 4. Build succeeds - fix issues incrementally
    # 5. Change IGNORE back to error/warning in quality-config.json
    # 6. Repeat

.NOTES
    File Name      : enforce-quality.ps1
    Version        : 2.0.0
    Created        : 2025-12-13
    Updated        : 2025-12-13
    Prerequisite   : .NET SDK 9.x, PowerShell 7.2+, quality-config.json
    
    Configuration File Format:
    {
      "version": "1.0.0",
      "defaultSeverity": "error",
      "rules": {
        "CA1234": "error",      // Enforce as error
        "CA5678": "warning",    // Enforce as warning
        "CA9999": "IGNORE"      // Skip (temporary relaxation)
      }
    }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to directory containing project files")]
    [string]$TargetPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Action to perform")]
    [ValidateSet('enforce', 'update-editorconfig')]
    [string]$Action = 'enforce',

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for build test")]
    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 180,

    [Parameter(Mandatory = $false, HelpMessage = "Path to quality configuration file")]
    [string]$ConfigPath = "$PSScriptRoot\quality-config.json"
)

$ErrorActionPreference = 'Stop'

function Test-Unicode {
    <#
    .SYNOPSIS
        Detects if the environment supports Unicode output.
    #>
    $psVersion = $PSVersionTable.PSVersion.Major
    $inAzure = $null -ne $env:AGENT_TEMPDIRECTORY
    $isUtf8Console = [Console]::OutputEncoding.CodePage -eq 65001

    return ($psVersion -ge 7) -or $inAzure -or $isUtf8Console
}

function Get-StatusEmoji {
    <#
    .SYNOPSIS
        Returns appropriate status indicator based on Unicode support.
    #>
    param([string]$Status)

    if (Test-Unicode) {
        return @{
            'success' = '✅'
            'warning' = '⚠️'
            'error'   = '❌'
            'info'    = 'ℹ️'
            'config'  = '⚙️'
            'build'   = '🔨'
            'check'   = '🔍'
        }[$Status]
    } else {
        return @{
            'success' = '[OK]'
            'warning' = '[WARN]'
            'error'   = '[ERR]'
            'info'    = '[INFO]'
            'config'  = '[CFG]'
            'build'   = '[BUILD]'
            'check'   = '[CHECK]'
        }[$Status]
    }
}

function Read-QualityConfig {
    <#
    .SYNOPSIS
        Reads quality configuration from JSON file.
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "Configuration file not found: $Path"
        return $null
    }

    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "Failed to parse configuration file: $($_.Exception.Message)"
        return $null
    }
}

function Get-EditorConfigRules {
    <#
    .SYNOPSIS
        Generates .editorconfig rules from quality configuration.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    $rules = [System.Collections.Generic.List[string]]::new()
    $rules.Add("")
    $rules.Add("# ============================================================")
    $rules.Add("# Code Quality Enforcement Rules")
    $rules.Add("# Generated by: enforce-quality.ps1")
    $rules.Add("# Config: quality-config.json v$($Config.version)")
    $rules.Add("# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $rules.Add("# ============================================================")
    $rules.Add("")
    $rules.Add("[*.cs]")

    $ruleCount = 0
    $ignoredCount = 0
    $currentCategory = ""

    foreach ($property in $Config.rules.PSObject.Properties) {
        $ruleName = $property.Name
        $severity = $property.Value

        # Skip comment entries
        if ($ruleName.StartsWith("_comment")) {
            # Extract category name for section headers
            if ($currentCategory -ne $severity) {
                $currentCategory = $severity
                $rules.Add("")
                $rules.Add("# $severity")
            }
            continue
        }

        # Skip IGNORE entries
        if ($severity -eq "IGNORE") {
            $ignoredCount++
            continue
        }

        # Validate severity
        if ($severity -notin @("error", "warning", "suggestion", "none")) {
            Write-Warning "Invalid severity '$severity' for rule '$ruleName', skipping"
            continue
        }

        # Add rule
        $rules.Add("dotnet_diagnostic.$ruleName.severity = $severity")
        $ruleCount++
    }

    $rules.Add("")
    $rules.Add("# Summary: $ruleCount rules configured, $ignoredCount rules ignored")
    $rules.Add("")

    return @{
        Content = $rules -join "`n"
        RuleCount = $ruleCount
        IgnoredCount = $ignoredCount
    }
}

try {
    $info = Get-StatusEmoji 'info'
    $success = Get-StatusEmoji 'success'
    $warning = Get-StatusEmoji 'warning'
    $errorEmoji = Get-StatusEmoji 'error'
    $config = Get-StatusEmoji 'config'
    $build = Get-StatusEmoji 'build'
    $check = Get-StatusEmoji 'check'

    Write-Host "$config Code Quality Enforcement: $Action Phase" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "  Target: $TargetPath" -ForegroundColor Gray
    Write-Host "  Timeout: $TimeoutSeconds seconds" -ForegroundColor Gray
    Write-Host ""

    # Resolve and validate target path
    $resolvedPath = Resolve-Path -Path $TargetPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Host "$errorEmoji Target path not found: $TargetPath" -ForegroundColor Red
        exit 1
    }

if ($Action -eq 'enforce') {
    # Enable Warnings-as-Errors in Projects
    Write-Host "$config Enabling warnings-as-errors in project files..." -ForegroundColor Cyan

    $csprojFiles = @(Get-ChildItem -Path $TargetPath -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue)
    
    if ($csprojFiles.Count -eq 0) {
        Write-Host "$errorEmoji No .csproj files found in target path" -ForegroundColor Red
        Write-Host "  Target: $TargetPath" -ForegroundColor Gray
        exit 1
    }

    Write-Host "  Found $($csprojFiles.Count) project file(s)" -ForegroundColor Gray
    Write-Host ""

    $updatedCount = 0
    $alreadyConfigured = 0

    foreach ($file in $csprojFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

        if ($content -and -not ($content -match "<TreatWarningsAsErrors>true</TreatWarningsAsErrors>")) {
            # Find the PropertyGroup section and add the setting
            if ($content -match "(<PropertyGroup>)") {
                $content = $content -replace "(<PropertyGroup>)", "`$1`n    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>`n    <WarningsAsErrors />`n    <AnalysisLevel>latest</AnalysisLevel>`n    <EnableNETAnalyzers>true</EnableNETAnalyzers>"
                Set-Content $file.FullName $content -NoNewline
                Write-Host "  $success Updated: $($file.Name)" -ForegroundColor Green
                $updatedCount++
            } else {
                Write-Host "  $warning No PropertyGroup found: $($file.Name)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  $info Already configured: $($file.Name)" -ForegroundColor Gray
            $alreadyConfigured++
        }
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Updated: $updatedCount project(s)" -ForegroundColor White
    Write-Host "  Already configured: $alreadyConfigured project(s)" -ForegroundColor White
    Write-Host "  Total: $($csprojFiles.Count) project(s)" -ForegroundColor White

    # Test the build with warnings as errors
    Write-Host ""
    Write-Host "$build Testing build with warnings-as-errors..." -ForegroundColor Cyan
    Write-Host "  Note: Build may take longer due to analyzer checks" -ForegroundColor Gray

    $startTime = Get-Date
    Write-Host "  Build started at: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Gray

    try {
        Push-Location $TargetPath

        # Run build in background job with timeout
        $job = Start-Job -ScriptBlock {
            param($path)
            $ErrorActionPreference = 'Continue'
            dotnet build --configuration Release /p:TreatWarningsAsErrors=true 2>&1
            return $LASTEXITCODE
        } -ArgumentList $TargetPath -Name "enforce-quality-build-$(Get-Date -Format 'yyyyMMddHHmmss')"

        # Wait for job with timeout
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds

        $endTime = Get-Date
        $totalDuration = $endTime - $startTime

        if ($null -eq $completed) {
            # Timeout occurred
            Write-Host "`n$errorEmoji Build timed out after $TimeoutSeconds seconds!" -ForegroundColor Red
            Write-Host "  Stopping build process..." -ForegroundColor Yellow
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Write-Host "`nConsider:" -ForegroundColor Cyan
            Write-Host "  - Increasing timeout: -TimeoutSeconds 300" -ForegroundColor Gray
            Write-Host "  - Checking for hung processes or locks" -ForegroundColor Gray
            Write-Host "  - Running: dotnet build-server shutdown" -ForegroundColor Gray
            Pop-Location
            exit 1
        }

        Write-Host "  Build completed in $($totalDuration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green

        # Get build output and exit code
        $testBuild = Receive-Job -Job $job
        $buildExitCode = $testBuild | Select-Object -Last 1
        
        # Clean up job
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

        $buildWarnings = ($testBuild | Select-String "warning" | Measure-Object).Count
        $buildErrors = ($testBuild | Select-String "error" | Measure-Object).Count

        Write-Host ""
        Write-Host "Build Results:" -ForegroundColor Cyan
        Write-Host "  Warnings: $buildWarnings" -ForegroundColor $(if ($buildWarnings -eq 0) { 'Green' } else { 'Yellow' })
        Write-Host "  Errors: $buildErrors" -ForegroundColor $(if ($buildErrors -eq 0) { 'Green' } else { 'Red' })

        if ($buildExitCode -eq 0 -and $buildErrors -eq 0) {
            Write-Host "`n$success Build successful with warnings-as-errors!" -ForegroundColor Green
            Write-Host "  Quality gate: PASSED" -ForegroundColor Green
        } else {
            Write-Host "`n$errorEmoji Build failed with warnings-as-errors" -ForegroundColor Red
            Write-Host "  Quality gate: FAILED" -ForegroundColor Red
            Write-Host ""
            Write-Host "Next Steps:" -ForegroundColor Cyan
            Write-Host "  1. Run: .\.cursor\scripts\quality\build-and-find-errors.ps1" -ForegroundColor Gray
            Write-Host "  2. Fix identified errors" -ForegroundColor Gray
            Write-Host "  3. Consider: dotnet format for auto-fixes" -ForegroundColor Gray
            Write-Host "  4. Re-run: .\enforce-quality.ps1" -ForegroundColor Gray
        }
        
        Pop-Location
    } catch {
        Pop-Location
        Write-Host "$errorEmoji Build test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
        exit 1
    }

} elseif ($Action -eq 'update-editorconfig') {
    # Update .editorconfig with quality rules from configuration
    Write-Host "$config Updating .editorconfig from quality configuration..." -ForegroundColor Cyan
    Write-Host "  Config: $ConfigPath" -ForegroundColor Gray

    # Load configuration
    $qualityConfig = Read-QualityConfig -Path $ConfigPath
    if ($null -eq $qualityConfig) {
        Write-Host "$errorEmoji Failed to load configuration file" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Loaded config version: $($qualityConfig.version)" -ForegroundColor Gray
    Write-Host "  Default severity: $($qualityConfig.defaultSeverity)" -ForegroundColor Gray
    Write-Host ""

    # Generate rules from configuration
    $ruleResult = Get-EditorConfigRules -Config $qualityConfig
    $qualityRules = $ruleResult.Content

    Write-Host "  Generated $($ruleResult.RuleCount) rules ($($ruleResult.IgnoredCount) ignored)" -ForegroundColor Gray
    Write-Host ""

    $editorConfigPath = Join-Path $TargetPath ".editorconfig"

    if (Test-Path $editorConfigPath) {
        Write-Host "  Found existing .editorconfig" -ForegroundColor Gray
        $existing = Get-Content $editorConfigPath -Raw

        # Check if quality rules are already present
        if ($existing -match "# Code Quality Enforcement Rules") {
            Write-Host "  $warning Existing quality rules found - will replace" -ForegroundColor Yellow
            
            # Remove existing quality enforcement section
            $pattern = "(?s)# ={60,}[^\n]*# Code Quality Enforcement Rules.*?# ={60,}.*?(?=\n\[|$)"
            $existing = $existing -replace $pattern, ""
            
            # Append new quality rules
            $updated = $existing.TrimEnd() + $qualityRules
            Set-Content $editorConfigPath $updated -NoNewline
            Write-Host "  $success Replaced quality rules in .editorconfig" -ForegroundColor Green
        } else {
            # Append quality rules
            Add-Content $editorConfigPath $qualityRules
            Write-Host "  $success Added quality rules to .editorconfig" -ForegroundColor Green
        }
    } else {
        Write-Host "  Creating new .editorconfig file" -ForegroundColor Gray
        # Create new .editorconfig
        $newConfig = "root = true$qualityRules"
        Set-Content $editorConfigPath $newConfig -NoNewline
        Write-Host "  $success Created .editorconfig with quality rules" -ForegroundColor Green
    }

    # Display summary by category
    Write-Host ""
    Write-Host "Rules Applied by Severity:" -ForegroundColor Cyan
    
    $severityCounts = @{
        'error' = 0
        'warning' = 0
        'suggestion' = 0
        'none' = 0
    }

    foreach ($property in $qualityConfig.rules.PSObject.Properties) {
        $severity = $property.Value
        if ($severity -in @("error", "warning", "suggestion", "none")) {
            $severityCounts[$severity]++
        }
    }

    Write-Host "  Error: $($severityCounts['error']) rules" -ForegroundColor Red
    Write-Host "  Warning: $($severityCounts['warning']) rules" -ForegroundColor Yellow
    Write-Host "  Suggestion: $($severityCounts['suggestion']) rules" -ForegroundColor Cyan
    Write-Host "  None: $($severityCounts['none']) rules" -ForegroundColor Gray
    Write-Host "  Ignored (IGNORE): $($ruleResult.IgnoredCount) rules" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Review .editorconfig: $editorConfigPath" -ForegroundColor Gray
    Write-Host "  2. Modify config: $ConfigPath" -ForegroundColor Gray
    Write-Host "  3. Test build: dotnet build" -ForegroundColor Gray
    Write-Host "  4. Run enforcement: .\enforce-quality.ps1 -Action enforce" -ForegroundColor Gray
}

    Write-Host ""
    Write-Host "$success $Action Phase Complete!" -ForegroundColor Green
    Write-Host ("=" * 50) -ForegroundColor Cyan
    exit 0

} catch {
    $errorEmoji = Get-StatusEmoji 'error'
    Write-Host ""
    Write-Host "$errorEmoji Script failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "For help, run: Get-Help .\enforce-quality.ps1 -Full" -ForegroundColor Yellow
    exit 1
}
finally {
    # Cleanup any remaining jobs
    Get-Job | Where-Object { $_.Name -like 'enforce-quality-build-*' } | Remove-Job -Force -ErrorAction SilentlyContinue
}

