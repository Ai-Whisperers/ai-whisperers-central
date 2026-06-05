#!/usr/bin/env pwsh
# Quick test runner for all CI/CD scripts

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "   CI/CD Scripts Test Suite" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$testFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" | Where-Object { $_.Name -notlike "*.tmp" } | Sort-Object Name

Write-Host "Found $($testFiles.Count) test files`n"

$results = @()

foreach ($testFile in $testFiles) {
    $name = $testFile.Name
    Write-Host "Testing: $name ... " -NoNewline
    
    try {
        $result = Invoke-Pester -Path $testFile.FullName -PassThru -Quiet 2>&1
        
        if ($result.FailedCount -eq 0) {
            Write-Host "[PASS]" -ForegroundColor Green -NoNewline
            Write-Host " ($($result.PassedCount)/$($result.TotalCount) tests)"
        } else {
            Write-Host "[FAIL]" -ForegroundColor Red -NoNewline
            Write-Host " ($($result.PassedCount)/$($result.TotalCount) tests, $($result.FailedCount) failed)"
        }
        
        $results += @{
            Name = $name.Replace('.Tests.ps1', '')
            Passed = $result.PassedCount
            Failed = $result.FailedCount
            Total = $result.TotalCount
            Success = $result.FailedCount -eq 0
        }
    } catch {
        Write-Host "[ERROR]" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
        $results += @{
            Name = $name.Replace('.Tests.ps1', '')
            Passed = 0
            Failed = 1
            Total = 1
            Success = $false
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "   Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$totalPassed = ($results | ForEach-Object { $_.Passed } | Measure-Object -Sum).Sum
$totalFailed = ($results | ForEach-Object { $_.Failed } | Measure-Object -Sum).Sum
$totalTests = ($results | ForEach-Object { $_.Total } | Measure-Object -Sum).Sum
$successCount = @($results | Where-Object { $_.Success }).Count

Write-Host "Total Scripts: $($results.Count)"
Write-Host "Successful:    " -NoNewline
Write-Host "$successCount" -ForegroundColor Green
Write-Host "Failed:        " -NoNewline
Write-Host "$($results.Count - $successCount)" -ForegroundColor $(if ($successCount -eq $results.Count) { "Green" } else { "Red" })
Write-Host ""
Write-Host "Total Tests:   $totalTests"
Write-Host "Passed:        " -NoNewline
Write-Host "$totalPassed" -ForegroundColor Green
Write-Host "Failed:        " -NoNewline
Write-Host "$totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })

if ($totalTests -gt 0) {
    $coverage = [math]::Round(($totalPassed / $totalTests) * 100, 1)
    Write-Host ""
    Write-Host "Coverage:      $coverage%"
}

$failedScripts = $results | Where-Object { -not $_.Success }
if ($failedScripts.Count -gt 0) {
    Write-Host "`n================================" -ForegroundColor Red
    Write-Host "   Failed Scripts" -ForegroundColor Red
    Write-Host "================================`n" -ForegroundColor Red
    foreach ($failed in $failedScripts) {
        Write-Host "[FAIL] $($failed.Name)" -ForegroundColor Red
    }
}

Write-Host ""

if ($totalFailed -eq 0) {
    Write-Host "[PASS] All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] Some tests failed" -ForegroundColor Red
    exit 1
}

