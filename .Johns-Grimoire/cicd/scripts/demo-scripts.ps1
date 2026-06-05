#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive demo of CI/CD scripts functionality
.DESCRIPTION
    Demonstrates each script with real examples
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Demo {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  DEMO: $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 80)`n" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "➜ " -ForegroundColor Yellow -NoNewline
    Write-Host $Text
}

try {
    Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           CI/CD Scripts Interactive Demo                     ║
║                                                               ║
║     This will demonstrate key scripts with real examples     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    $scriptRoot = $PSScriptRoot
    $repoRoot = Split-Path (Split-Path $scriptRoot -Parent) -Parent

    # Demo 1: Verify XML Files
    Write-Demo "verify-xml-files.ps1 - Check XML documentation files exist"
    Write-Step "This script ensures that .xml documentation files are generated during build"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\verify-xml-files.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\verify-xml-files.ps1' -ForegroundColor Yellow
    }

    # Demo 2: Validate Documentation
    Write-Demo "validate-documentation.ps1 - Check for missing XML comments"
    Write-Step "Scans C# code for public APIs without XML documentation"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\validate-documentation.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\validate-documentation.ps1' -ForegroundColor Yellow
    }

    # Demo 3: Validate Package Metadata
    Write-Demo "validate-package-metadata.ps1 - Ensure NuGet packages have complete metadata"
    Write-Step "Validates Authors, Description, License, and other required fields"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\validate-package-metadata.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\validate-package-metadata.ps1' -ForegroundColor Yellow
    }

    # Demo 4: Validate Tag Context
    Write-Demo "validate-tag-context.ps1 - Check release tags are on correct branches"
    Write-Step "Ensures tags follow branching strategy (main or release/* branches)"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\validate-tag-context.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\validate-tag-context.ps1' -ForegroundColor Yellow
    }

    # Demo 5: Validate Release Notes
    Write-Demo "validate-release-notes.ps1 - Check CHANGELOG has entry for version"
    Write-Step "Validates that CHANGELOG.md contains proper release notes"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\validate-release-notes.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\validate-release-notes.ps1 -Version "1.0.0"' -ForegroundColor Yellow
    }

    # Demo 6: Check Breaking Changes
    Write-Demo "check-breaking-changes.ps1 - API Compatibility Analysis"
    Write-Step "Compares current API against latest release to detect breaking changes"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\check-breaking-changes.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\check-breaking-changes.ps1 -OutputPath ".\local-reports\compat"' -ForegroundColor Yellow
    }

    # Demo 7: Scan Licenses
    Write-Demo "scan-licenses.ps1 - License Compliance Scanning"
    Write-Step "Scans all NuGet dependencies and generates license reports"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\scan-licenses.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\scan-licenses.ps1 -OutputPath ".\local-reports\licenses"' -ForegroundColor Yellow
    }

    # Demo 8: Calculate Code Metrics
    Write-Demo "calculate-code-metrics.ps1 - Maintainability and Complexity Analysis"
    Write-Step "Calculates Maintainability Index and Cyclomatic Complexity"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\calculate-code-metrics.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\calculate-code-metrics.ps1 -OutputPath ".\local-reports\metrics"' -ForegroundColor Yellow
    }

    # Demo 9: Enhanced Coverage Analysis
    Write-Demo "enhanced-coverage-analysis.ps1 - Advanced Test Coverage"
    Write-Step "Generates detailed coverage reports with history tracking"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\enhanced-coverage-analysis.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\enhanced-coverage-analysis.ps1 -CoberturaFile ".\coverage\coverage.cobertura.xml"' -ForegroundColor Yellow
    }

    # Demo 10: Run Benchmarks
    Write-Demo "run-benchmarks.ps1 - Performance Benchmark Runner"
    Write-Step "Runs BenchmarkDotNet performance tests"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\run-benchmarks.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\run-benchmarks.ps1 -Configuration Release' -ForegroundColor Yellow
    }

    # Demo 11: Run Mutation Tests
    Write-Demo "run-mutation-tests.ps1 - Mutation Testing with Stryker"
    Write-Step "Tests the quality of your tests by introducing mutations"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\run-mutation-tests.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\run-mutation-tests.ps1 -TestProject "tst\Eneve.Domain.Tests"' -ForegroundColor Yellow
    }

    # Demo 12: Install Tools
    Write-Demo "install-tools.ps1 - Install Required .NET Global Tools"
    Write-Step "Installs all required tools for the CI/CD pipeline"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\install-tools.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\install-tools.ps1' -ForegroundColor Yellow
    }

    # Demo 13: Generate Doc Report
    Write-Demo "generate-doc-report.ps1 - Documentation Coverage Report"
    Write-Step "Generates detailed report of XML documentation coverage"
    Write-Host ""
    
    if (Test-Path "$scriptRoot\generate-doc-report.ps1") {
        Write-Host "Script Status: " -NoNewline
        Write-Host "✓ Available" -ForegroundColor Green
        Write-Host "Usage: " -NoNewline
        Write-Host '.\generate-doc-report.ps1' -ForegroundColor Yellow
    }

    # Summary
    Write-Demo "Summary"
    
    $allScripts = @(
        "verify-xml-files.ps1",
        "validate-documentation.ps1",
        "validate-package-metadata.ps1",
        "validate-tag-context.ps1",
        "validate-release-notes.ps1",
        "check-breaking-changes.ps1",
        "scan-licenses.ps1",
        "calculate-code-metrics.ps1",
        "enhanced-coverage-analysis.ps1",
        "run-benchmarks.ps1",
        "run-mutation-tests.ps1",
        "install-tools.ps1",
        "generate-doc-report.ps1"
    )
    
    $available = $allScripts | Where-Object { Test-Path "$scriptRoot\$_" }
    $withTests = $allScripts | Where-Object { Test-Path "$scriptRoot\$($_.Replace('.ps1', '.Tests.ps1'))" }
    
    Write-Host "Scripts Available:  " -NoNewline
    Write-Host "$($available.Count)/$($allScripts.Count)" -ForegroundColor Green
    Write-Host "With Pester Tests:  " -NoNewline
    Write-Host "$($withTests.Count)/$($allScripts.Count)" -ForegroundColor Green
    
    $coverage = [math]::Round(($withTests.Count / $allScripts.Count) * 100, 1)
    Write-Host "Test Coverage:      " -NoNewline
    Write-Host "$coverage%" -ForegroundColor $(if ($coverage -ge 90) { "Green" } elseif ($coverage -ge 75) { "Yellow" } else { "Red" })
    
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "  To run all tests: .\quick-test-all.ps1" -ForegroundColor Yellow
    Write-Host "  For help on any script: Get-Help .\<script-name>.ps1 -Detailed" -ForegroundColor Yellow
    Write-Host ("=" * 80) + "`n" -ForegroundColor Cyan

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

