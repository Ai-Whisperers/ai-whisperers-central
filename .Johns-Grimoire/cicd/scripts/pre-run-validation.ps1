#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-run validation with automated fixes - Zero Errors, Zero Warnings
.DESCRIPTION
    Comprehensive validation suite that runs all checks and offers automated fixes
    Goal: Achieve zero errors and zero warnings before committing/releasing
.PARAMETER AutoFix
    Automatically fix warnings and errors where possible
.PARAMETER SkipTests
    Skip running Pester tests for the scripts themselves
.PARAMETER Configuration
    Build configuration (Debug/Release)
.EXAMPLE
    .\pre-run-validation.ps1
.EXAMPLE
    .\pre-run-validation.ps1 -AutoFix
.EXAMPLE
    .\pre-run-validation.ps1 -AutoFix -Configuration Release
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$AutoFix,
    
    [Parameter()]
    [switch]$SkipTests,
    
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║      Pre-Run Validation - Zero Errors, Zero Warnings         ║
║                                                               ║
║  Comprehensive quality checks with automated fixes           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Log "Configuration: $Configuration"
Write-Log "AutoFix: $($AutoFix.IsPresent)"
Write-Log "Skip Tests: $($SkipTests.IsPresent)"
Write-Host ""

$validationResults = @{
    Errors = @()
    Warnings = @()
    Passed = @()
}

function Run-Validation {
    param(
        [string]$Name,
        [scriptblock]$Script,
        [hashtable]$AutoFixInfo = @{}
    )
    
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  Validation: $Name" -ForegroundColor Cyan
    Write-Host $('=' * 80) -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $result = & $Script
        
        if ($result.Success) {
            Write-Log "✓ $Name - PASSED" -Level SUCCESS
            $validationResults.Passed += $Name
        } elseif ($result.HasWarnings) {
            Write-Log "⚠ $Name - WARNINGS FOUND" -Level WARN
            $validationResults.Warnings += @{
                Name = $Name
                Issues = $result.Issues
                AutoFix = $AutoFixInfo
            }
            
            if ($AutoFix -and $AutoFixInfo.Command) {
                Write-Log "Attempting automated fix..." -Level INFO
                & $AutoFixInfo.Command
            }
        } else {
            Write-Log "✗ $Name - ERRORS FOUND" -Level ERROR
            $validationResults.Errors += @{
                Name = $Name
                Issues = $result.Issues
                AutoFix = $AutoFixInfo
            }
            
            if ($AutoFix -and $AutoFixInfo.Command) {
                Write-Log "Attempting automated fix..." -Level INFO
                & $AutoFixInfo.Command
            }
        }
        
        return $result
    } catch {
        Write-Log "✗ $Name - FAILED: $($_.Exception.Message)" -Level ERROR
        $validationResults.Errors += @{
            Name = $Name
            Issues = @($_.Exception.Message)
        }
        return @{ Success = $false; Issues = @($_.Exception.Message) }
    }
}

# Validation 1: Documentation
$docResult = Run-Validation -Name "XML Documentation" -Script {
    $output = & "$PSScriptRoot\validate-documentation.ps1" -Configuration $Configuration 2>&1
    $success = $LASTEXITCODE -eq 0
    
    @{
        Success = $success
        HasWarnings = $output -match 'missing documentation'
        Issues = @($output | Where-Object { $_ -match 'missing|warning' })
    }
} -AutoFixInfo @{
    Command = { & "$PSScriptRoot\fix-warnings.ps1" -Fix MissingDocumentation }
}

# Validation 2: Package Metadata
$metadataResult = Run-Validation -Name "Package Metadata" -Script {
    $output = & "$PSScriptRoot\validate-package-metadata.ps1" 2>&1
    $success = $LASTEXITCODE -eq 0
    
    @{
        Success = $success
        HasWarnings = $output -match 'incomplete|missing'
        Issues = @($output | Where-Object { $_ -match 'incomplete|missing|warning' })
    }
} -AutoFixInfo @{
    Command = { & "$PSScriptRoot\fix-warnings.ps1" -Fix IncompleteMetadata }
}

# Validation 3: XML Files Exist
$xmlFilesResult = Run-Validation -Name "XML Files Exist" -Script {
    $output = & "$PSScriptRoot\verify-xml-files.ps1" 2>&1
    $success = $LASTEXITCODE -eq 0
    
    @{
        Success = $success
        HasWarnings = $false
        Issues = @($output | Where-Object { $_ -match 'not found|missing' })
    }
} -AutoFixInfo @{
    Command = { & "$PSScriptRoot\fix-errors.ps1" -Fix MissingXmlFiles }
}

# Validation 4: License Compliance
$licenseResult = Run-Validation -Name "License Compliance" -Script {
    $reportsDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "local-reports\licenses"
    $output = & "$PSScriptRoot\scan-licenses.ps1" -OutputPath $reportsDir -Configuration $Configuration 2>&1
    $success = $LASTEXITCODE -eq 0
    
    @{
        Success = $success
        HasWarnings = $output -match 'warning'
        Issues = @($output | Where-Object { $_ -match 'warning|prohibited' })
    }
}

# Validation 5: Code Metrics
$metricsResult = Run-Validation -Name "Code Metrics" -Script {
    $reportsDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "local-reports\metrics"
    $output = & "$PSScriptRoot\calculate-code-metrics.ps1" -OutputPath $reportsDir -Configuration $Configuration 2>&1
    $success = $LASTEXITCODE -eq 0
    
    $warnings = $output | Where-Object { $_ -match 'low maintainability|high complexity' }
    
    @{
        Success = $success
        HasWarnings = $warnings.Count -gt 0
        Issues = @($warnings)
    }
} -AutoFixInfo @{
    Command = { Write-Log "Code complexity requires manual refactoring" -Level WARN }
}

# Validation 6: Code Formatting (dotnet format)
$formatResult = Run-Validation -Name "Code Formatting" -Script {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Push-Location $repoRoot
    try {
        $output = & dotnet format --verify-no-changes --severity warn 2>&1
        $exitCode = $LASTEXITCODE

        @{
            Success = $exitCode -eq 0
            HasWarnings = $false
            Issues = @(
                "dotnet format exit code: $exitCode",
                $output
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
    }
    finally {
        Pop-Location
    }
} -AutoFixInfo @{
    Command = { & "$PSScriptRoot\fix-warnings.ps1" -Fix AnalyzerAutocorrect -Path "src" }
}

# Validation 7: Script Tests (if not skipped)
if (-not $SkipTests) {
    $testsResult = Run-Validation -Name "CI/CD Script Tests" -Script {
        $output = & "$PSScriptRoot\run-all-tests.ps1" 2>&1
        $success = $LASTEXITCODE -eq 0
        
        @{
            Success = $success
            HasWarnings = $false
            Issues = @($output | Where-Object { $_ -match 'failed' })
        }
    }
}

# Summary Report
Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host $('=' * 80) -ForegroundColor Cyan
Write-Host ""

Write-Host "Passed:   " -NoNewline -ForegroundColor Green
Write-Host $validationResults.Passed.Count -ForegroundColor Green
Write-Host "Warnings: " -NoNewline -ForegroundColor Yellow
Write-Host $validationResults.Warnings.Count -ForegroundColor $(if ($validationResults.Warnings.Count -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "Errors:   " -NoNewline -ForegroundColor Red
Write-Host $validationResults.Errors.Count -ForegroundColor $(if ($validationResults.Errors.Count -eq 0) { 'Green' } else { 'Red' })

# Show warnings
if ($validationResults.Warnings.Count -gt 0) {
    Write-Host "`n$('=' * 80)" -ForegroundColor Yellow
    Write-Host "  WARNINGS FOUND" -ForegroundColor Yellow
    Write-Host $('=' * 80) -ForegroundColor Yellow
    
    foreach ($warningItem in $validationResults.Warnings) {
        Write-Host "`n⚠ $($warningItem.Name):" -ForegroundColor Yellow
        foreach ($issue in $warningItem.Issues) {
            Write-Host "  - $issue" -ForegroundColor DarkYellow
        }
        
        $warningAutoFixCommand = $null
        if ($warningItem -is [hashtable] -and $warningItem.ContainsKey('AutoFix')) {
            $warningAutoFixCommand = $warningItem.AutoFix.Command
        }

        if (-not $AutoFix -and $warningAutoFixCommand) {
            Write-Host "`n  Run with -AutoFix to attempt automated repair" -ForegroundColor Cyan
        }
    }
}

# Show errors
if ($validationResults.Errors.Count -gt 0) {
    Write-Host "`n$('=' * 80)" -ForegroundColor Red
    Write-Host "  ERRORS FOUND" -ForegroundColor Red
    Write-Host $('=' * 80) -ForegroundColor Red
    
    foreach ($errorItem in $validationResults.Errors) {
        Write-Host "`n✗ $($errorItem.Name):" -ForegroundColor Red
        foreach ($issue in $errorItem.Issues) {
            Write-Host "  - $issue" -ForegroundColor DarkRed
        }
        
        $errorAutoFixCommand = $null
        if ($errorItem -is [hashtable] -and $errorItem.ContainsKey('AutoFix')) {
            $errorAutoFixCommand = $errorItem.AutoFix.Command
        }

        if (-not $AutoFix -and $errorAutoFixCommand) {
            Write-Host "`n  Run with -AutoFix to attempt automated repair" -ForegroundColor Cyan
        }
    }
}

# Final status
Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
if ($validationResults.Errors.Count -eq 0 -and $validationResults.Warnings.Count -eq 0) {
    Write-Host "  ✓ ZERO ERRORS, ZERO WARNINGS - READY TO COMMIT!" -ForegroundColor Green
    Write-Host $('=' * 80) -ForegroundColor Green
    exit 0
} elseif ($validationResults.Errors.Count -eq 0) {
    Write-Host "  ⚠ WARNINGS FOUND - PLEASE REVIEW" -ForegroundColor Yellow
    Write-Host $('=' * 80) -ForegroundColor Yellow
    Write-Host "`nRun with -AutoFix to attempt automated fixes" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "  ✗ ERRORS FOUND - MUST FIX BEFORE COMMIT" -ForegroundColor Red
    Write-Host $('=' * 80) -ForegroundColor Red
    Write-Host "`nRun with -AutoFix to attempt automated fixes" -ForegroundColor Cyan
    exit 1
}

