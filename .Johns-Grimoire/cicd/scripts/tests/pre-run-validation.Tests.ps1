#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for pre-run-validation.ps1
.DESCRIPTION
    Comprehensive unit tests for the pre-run validation script
    Tests validation orchestration, auto-fix integration, and reporting
    
    Compatible with Pester 3.x
#>

$ErrorActionPreference = "Stop"

# Setup - Get script under test
$scriptPath = Join-Path $PSScriptRoot "..\pre-run-validation.ps1"
$scriptContent = Get-Content $scriptPath -Raw

Describe "pre-run-validation.ps1" -Tag "Unit", "CICD", "Validation" {
    
    Context "Script Initialization" {
        It "Should exist at expected path" {
            Test-Path $scriptPath | Should -Be $true
        }
        
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$errors)
            $errors.Count | Should -Be 0
        }
        
        It "Should have proper shebang" {
            $firstLine = Get-Content $scriptPath -First 1
            $firstLine | Should -Match '^#!/usr/bin/env pwsh'
        }
    }
    
    Context "Script Content Validation" {
        It "Should have Run-Validation function definition" {
            $scriptContent -match 'function Run-Validation' | Should -Be $true
        }
        
        It "Should reference validate-documentation.ps1" {
            $scriptContent -match 'validate-documentation\.ps1' | Should -Be $true
        }
        
        It "Should reference validate-package-metadata.ps1" {
            $scriptContent -match 'validate-package-metadata\.ps1' | Should -Be $true
        }
        
        It "Should reference verify-xml-files.ps1" {
            $scriptContent -match 'verify-xml-files\.ps1' | Should -Be $true
        }
        
        It "Should reference scan-licenses.ps1" {
            $scriptContent -match 'scan-licenses\.ps1' | Should -Be $true
        }
        
        It "Should reference calculate-code-metrics.ps1" {
            $scriptContent -match 'calculate-code-metrics\.ps1' | Should -Be $true
        }
        
        It "Should have AutoFix parameter" {
            $scriptContent -match '\[switch\]\$AutoFix' | Should -Be $true
        }
        
        It "Should have SkipTests parameter" {
            $scriptContent -match '\[switch\]\$SkipTests' | Should -Be $true
        }
        
        It "Should have Configuration parameter" {
            $scriptContent -match '\[string\]\$Configuration' | Should -Be $true
        }
        
        It "Should have Configuration ValidateSet" {
            $scriptContent -match "ValidateSet\('Debug', 'Release'\)" | Should -Be $true
        }
    }
    
    Context "Validation Orchestration Logic" {
        It "Should check for AutoFix flag in validation logic" {
            $scriptContent -match 'if.*\$AutoFix' | Should -Be $true
        }
        
        It "Should check for SkipTests flag" {
            $scriptContent -match 'if.*-not.*\$SkipTests' | Should -Be $true
        }
        
        It "Should have validation results hashtable" {
            $scriptContent -match '\$validationResults.*=.*@\{' | Should -Be $true
        }
        
        It "Should track Errors in results" {
            $scriptContent -match "Errors.*=.*@\(\)" | Should -Be $true
        }
        
        It "Should track Warnings in results" {
            $scriptContent -match "Warnings.*=.*@\(\)" | Should -Be $true
        }
        
        It "Should track Passed validations" {
            $scriptContent -match "Passed.*=.*@\(\)" | Should -Be $true
        }
    }
    
    Context "Exit Code Behavior" {
        It "Should have exit 0 for success" {
            $scriptContent -match 'exit 0' | Should -Be $true
        }
        
        It "Should have exit 1 for failure" {
            $scriptContent -match 'exit 1' | Should -Be $true
        }
        
        It "Should exit 0 when no errors or warnings" {
            $scriptContent -match 'if.*Errors\.Count.*-eq 0.*-and.*Warnings\.Count.*-eq 0' | Should -Be $true
        }
        
        It "Should exit 1 when errors found" {
            $scriptContent -match 'if.*Errors\.Count.*-gt 0' | Should -Be $true
        }
    }
    
    Context "Summary Reporting" {
        It "Should display passed count" {
            $scriptContent -match 'Passed:' | Should -Be $true
        }
        
        It "Should display warnings count" {
            $scriptContent -match 'Warnings:' | Should -Be $true
        }
        
        It "Should display errors count" {
            $scriptContent -match 'Errors:' | Should -Be $true
        }
        
        It "Should show success message for zero errors and warnings" {
            $scriptContent -match 'ZERO ERRORS, ZERO WARNINGS' | Should -Be $true
        }
        
        It "Should show warnings message when warnings found" {
            $scriptContent -match 'WARNINGS FOUND' | Should -Be $true
        }
        
        It "Should show errors message when errors found" {
            $scriptContent -match 'ERRORS FOUND' | Should -Be $true
        }
        
        It "Should suggest AutoFix when issues found" {
            $scriptContent -match 'Run with -AutoFix' | Should -Be $true
        }
    }
    
    Context "Configuration Propagation" {
        It "Should pass Configuration to validate-documentation" {
            $scriptContent -match 'validate-documentation\.ps1.*-Configuration' | Should -Be $true
        }
        
        It "Should pass Configuration to scan-licenses" {
            $scriptContent -match 'scan-licenses\.ps1.*-Configuration' | Should -Be $true
        }
        
        It "Should pass Configuration to calculate-code-metrics" {
            $scriptContent -match 'calculate-code-metrics\.ps1.*-Configuration' | Should -Be $true
        }
    }
}
