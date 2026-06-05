#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run all Pester tests for CI/CD scripts
.DESCRIPTION
    Runs all .Tests.ps1 files and generates a summary report
#>

param()

$ErrorActionPreference = 'Continue'
Write-Host "`n=== CI/CD Scripts - Comprehensive Test Suite ===`n" -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
$testsDir = Join-Path $scriptRoot "tests"
$modulesDir = Join-Path $scriptRoot "modules"

# Get tests from both tests/ and modules/ directories recursively
$testFiles = @()
if (Test-Path $testsDir) {
    $testFiles += Get-ChildItem -Path $testsDir -Filter "*.Tests.ps1" -Recurse
}
if (Test-Path $modulesDir) {
    $testFiles += Get-ChildItem -Path $modulesDir -Filter "*.Tests.ps1" -Recurse
}
$testFiles = $testFiles | Where-Object { $_.Name -notlike "*.tmp" } | Sort-Object FullName

Write-Host "Found $($testFiles.Count) test files`n"

$results = @()
$totalTests = 0
$totalPassed = 0
$totalFailed = 0
$totalSkipped = 0

foreach ($testFile in $testFiles) {
    $scriptName = $testFile.Name.Replace('.Tests.ps1', '')
    Write-Host "Testing: " -NoNewline
    Write-Host "$scriptName".PadRight(40) -ForegroundColor Yellow -NoNewline
    Write-Host " ... " -NoNewline
    
    try {
        $result = Invoke-Pester -Path $testFile.FullName -PassThru -Quiet 2>&1
        
        $totalTests += $result.TotalCount
        $totalPassed += $result.PassedCount
        $totalFailed += $result.FailedCount
        $totalSkipped += $result.SkippedCount
        
        $results += [PSCustomObject]@{
            Script = $scriptName
            Passed = $result.PassedCount
            Failed = $result.FailedCount
            Skipped = $result.SkippedCount
            Total = $result.TotalCount
            Success = $result.FailedCount -eq 0
        }
        
        if ($result.FailedCount -eq 0) {
            Write-Host "PASS" -ForegroundColor Green -NoNewline
            Write-Host " ($($result.PassedCount)/$($result.TotalCount))"
        } else {
            Write-Host "FAIL" -ForegroundColor Red -NoNewline
            Write-Host " ($($result.PassedCount)/$($result.TotalCount), $($result.FailedCount) failed)"
        }
    } catch {
        Write-Host "ERROR" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Script = $scriptName
            Passed = 0
            Failed = 1
            Skipped = 0
            Total = 1
            Success = $false
        }
        $totalFailed++
        $totalTests++
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Scripts Tested: $($testFiles.Count)"
Write-Host "Total Tests:    $totalTests"
Write-Host "Passed:         " -NoNewline -ForegroundColor Green
Write-Host $totalPassed
Write-Host "Failed:         " -NoNewline -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
Write-Host $totalFailed
Write-Host "Skipped:        $totalSkipped"

if ($totalTests -gt 0) {
    $passRate = [math]::Round(($totalPassed / $totalTests) * 100, 1)
    Write-Host "Pass Rate:      $passRate%"
}

$successCount = ($results | Where-Object { $_.Success }).Count
Write-Host "`nScripts Passing All Tests: $successCount/$($results.Count)"

if ($totalFailed -eq 0) {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed" -ForegroundColor Yellow
    $failedScripts = $results | Where-Object { -not $_.Success }
    Write-Host "`nFailed Scripts:" -ForegroundColor Red
    foreach ($failed in $failedScripts) {
        Write-Host "  - $($failed.Script)" -ForegroundColor Red
    }
    exit 1
}

