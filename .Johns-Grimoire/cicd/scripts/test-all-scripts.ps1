#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
    Comprehensive test runner for all CI/CD scripts
.DESCRIPTION
    Runs Pester tests for all scripts in the cicd/scripts directory and provides a summary report
.PARAMETER Filter
    Optional filter to run specific test files (e.g., "*validate*")
.PARAMETER Detailed
    Show detailed test output instead of summary
.EXAMPLE
    .\test-all-scripts.ps1
.EXAMPLE
    .\test-all-scripts.ps1 -Filter "*validate*" -Detailed
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Filter = "*.Tests.ps1",
    
    [Parameter()]
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Color output helpers
function Write-Header {
    param([string]$Text)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$('=' * 80)`n" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$ScriptName,
        [int]$Passed,
        [int]$Failed,
        [int]$Total,
        [double]$Duration
    )
    
    $status = if ($Failed -eq 0) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Failed -eq 0) { "Green" } else { "Red" }
    $coverage = if ($Total -gt 0) { [math]::Round(($Passed / $Total) * 100, 1) } else { 0 }
    
    Write-Host "$status " -ForegroundColor $color -NoNewline
    Write-Host "$ScriptName".PadRight(45) -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Passed: $Passed".PadRight(12) -ForegroundColor Green -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Failed: $Failed".PadRight(12) -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" }) -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Total: $Total".PadRight(10) -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Coverage: $coverage%".PadRight(15) -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "$([math]::Round($Duration, 2))s" -ForegroundColor DarkGray
}

try {
    Write-Header "CI/CD Scripts Test Suite"
    
    $scriptRoot = $PSScriptRoot
    Write-Host "Script Directory: " -NoNewline
    Write-Host $scriptRoot -ForegroundColor Yellow
    Write-Host ""
    
    # Find all test files recursively (root, tests/, modules/, tests/modules/)
    $testFiles = @(Get-ChildItem -Path $scriptRoot -Filter $Filter -Recurse |
        Where-Object { $_.Name -notlike "*.tmp" } |
        Sort-Object FullName)
    
    if ($testFiles.Count -eq 0) {
        Write-Warning "No test files found matching filter: $Filter"
        exit 1
    }
    
    Write-Host "Found $($testFiles.Count) test file(s) to run`n" -ForegroundColor Yellow
    
    # Results tracking
    $results = @()
    $totalPassed = 0
    $totalFailed = 0
    $totalTests = 0
    $startTime = Get-Date
    
    $pesterModule = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
    $pesterVersion = if ($pesterModule) { $pesterModule.Version } else { $null }

    if (-not $pesterVersion -or $pesterVersion.Major -lt 5) {
        Write-Host ""
        Write-Host "❌ ERROR: Pester 5.x is required to run these tests" -ForegroundColor Red
        Write-Host ""
        Write-Host "Explanation: The CI/CD script tests use Pester 5 assertion syntax (e.g., 'Should -Be')." -ForegroundColor Yellow
        Write-Host "Legacy Pester 3 syntax will not execute these tests correctly." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Solution:" -ForegroundColor Green
        Write-Host "  1. Install Pester 5.x (side-by-side is supported)." -ForegroundColor Green
        Write-Host "  2. Re-run: .\\cicd\\scripts\\test-all-scripts.ps1" -ForegroundColor Green
        Write-Host ""
        exit 1
    }

    Import-Module $pesterModule -Force

    # Run each test file
    foreach ($testFile in $testFiles) {
        $testName = $testFile.Name.Replace('.Tests.ps1', '')
        
        Write-Host "Running: " -NoNewline
        Write-Host $testFile.Name -ForegroundColor Cyan
        
        try {
            $testStart = Get-Date
            
            if ($Detailed) {
                $result = Invoke-Pester -Path $testFile.FullName -PassThru -Output Detailed -ErrorAction Stop
            } else {
                $result = Invoke-Pester -Path $testFile.FullName -PassThru -Output Normal -ErrorAction Stop
            }
            
            $testEnd = Get-Date
            $duration = ($testEnd - $testStart).TotalSeconds
            
            $results += [PSCustomObject]@{
                Script = $testName
                Passed = $result.PassedCount
                Failed = $result.FailedCount
                Total = $result.TotalCount
                Duration = $duration
                Success = $result.FailedCount -eq 0
            }
            
            $totalPassed += $result.PassedCount
            $totalFailed += $result.FailedCount
            $totalTests += $result.TotalCount
            
            if (-not $Detailed) {
                Write-TestResult -ScriptName $testName -Passed $result.PassedCount -Failed $result.FailedCount -Total $result.TotalCount -Duration $duration
            }
            
        } catch {
            Write-Host "✗ " -ForegroundColor Red -NoNewline
            Write-Host "$testName - ERROR: $($_.Exception.Message)" -ForegroundColor Red
            
            $results += [PSCustomObject]@{
                Script = $testName
                Passed = 0
                Failed = 1
                Total = 1
                Duration = 0
                Success = $false
                Error = $_.Exception.Message
            }
            
            $totalFailed += 1
            $totalTests += 1
        }
        
        Write-Host ""
    }
    
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds
    
    # Summary Report
    Write-Header "Test Summary"
    
    Write-Host "Total Tests Run: " -NoNewline
    Write-Host $totalTests -ForegroundColor Yellow
    Write-Host "Total Passed:    " -NoNewline
    Write-Host $totalPassed -ForegroundColor Green
    Write-Host "Total Failed:    " -NoNewline
    Write-Host $totalFailed -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
    Write-Host "Total Duration:  " -NoNewline
    Write-Host "$([math]::Round($totalDuration, 2))s" -ForegroundColor Yellow
    
    if ($totalTests -gt 0) {
        $overallCoverage = [math]::Round(($totalPassed / $totalTests) * 100, 2)
        Write-Host "Overall Success: " -NoNewline
        Write-Host "$overallCoverage%" -ForegroundColor $(if ($overallCoverage -eq 100) { "Green" } else { "Yellow" })
    }
    
    # Failed tests detail
    $failedTests = @($results | Where-Object { -not $_.Success })
    if ($failedTests.Count -gt 0) {
        Write-Header "Failed Tests Details"
        foreach ($failed in $failedTests) {
            Write-Host "✗ " -ForegroundColor Red -NoNewline
            Write-Host $failed.Script -ForegroundColor Red
            if ($failed.PSObject.Properties.Name -contains 'Error' -and $failed.Error) {
                Write-Host "  Error: $($failed.Error)" -ForegroundColor DarkRed
            }
        }
        Write-Host ""
    }
    
    # Top performers
    Write-Header "Top Performing Scripts"
    $topScripts = $results | 
        Where-Object { $_.Success } | 
        Sort-Object -Property @{Expression={$_.Passed}; Descending=$true}, Duration |
        Select-Object -First 5
    
    foreach ($script in $topScripts) {
        Write-Host "[PASS] " -ForegroundColor Green -NoNewline
        Write-Host "$($script.Script)".PadRight(45) -NoNewline
        Write-Host " - $($script.Passed) tests in $([math]::Round($script.Duration, 2))s" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    
    # Exit with appropriate code
    if ($totalFailed -eq 0) {
        Write-Host "[PASS] All tests passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "✗ Some tests failed. Review the details above." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`n✗ Fatal Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}

