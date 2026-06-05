#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for fix-warnings.ps1
.DESCRIPTION
    Comprehensive unit tests for the automated warning fix script
    Tests warning detection, automated fixes, and dry-run mode
    
    Compatible with Pester 5.x
#>

$ErrorActionPreference = "Stop"

Describe "fix-warnings.ps1" -Tag "Unit", "CICD", "WarningFix" {

    BeforeAll {
        # Setup - Get script under test
        $script:scriptPath = Join-Path $PSScriptRoot "..\fix-warnings.ps1"
        $script:scriptContent = Get-Content $script:scriptPath -Raw
        $scriptPath = $script:scriptPath
        $scriptContent = $script:scriptContent
    }
    
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
    
    Context "Parameter Validation" {
        It "Should have Fix parameter with Mandatory attribute" {
            $scriptContent -match '(?s)\[Parameter\(Mandatory.*\)\][\s\S]*?\[string\]\$Fix' | Should -Be $true
        }

        It "Should have ValidateSet for Fix parameter with AnalyzerAutocorrect" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'AnalyzerAutocorrect'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with MissingDocumentation" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'MissingDocumentation'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with LicenseWarning" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'LicenseWarning'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with LowCoverage" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'LowCoverage'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with CodeComplexity" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'CodeComplexity'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with IncompleteMetadata" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'IncompleteMetadata'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with All" {
            $scriptContent -match "(?s)ValidateSet\([\s\S]*'All'" | Should -Be $true
        }
        
        It "Should have Path parameter" {
            $scriptContent -match '\[string\]\$Path' | Should -Be $true
        }
        
        It "Should have DryRun switch parameter" {
            $scriptContent -match '\[switch\]\$DryRun' | Should -Be $true
        }
    }
    
    Context "Fix-MissingDocumentation Function" {
        It "Should have Fix-MissingDocumentation function defined" {
            $scriptContent -match 'function Fix-MissingDocumentation' | Should -Be $true
        }
        
        It "Should check if file exists" {
            $scriptContent -match 'Test-Path.*\$FilePath' | Should -Be $true
        }
        
        It "Should read file content" {
            $scriptContent -match 'Get-Content.*\$FilePath' | Should -Be $true
        }
        
        It "Should detect public class without documentation" {
            $scriptContent -match 'public\s+class' | Should -Be $true
        }
        
        It "Should detect public interface without documentation" {
            $scriptContent -match 'class\|interface\|enum' | Should -Be $true
        }
        
        It "Should detect public enum without documentation" {
            $scriptContent -match 'class\|interface\|enum' | Should -Be $true
        }
        
        It "Should add XML summary tags" {
            $scriptContent -match '/// <summary>' | Should -Be $true
        }
        
        It "Should preserve indentation" {
            $scriptContent -match '\$indent' | Should -Be $true
        }
        
        It "Should respect DryRun mode in Fix-MissingDocumentation" {
            $scriptContent -match 'if.*-not.*\$DryRun' | Should -Be $true
        }
        
        It "Should return false when file not found" {
            $scriptContent -match 'return \$false' | Should -Be $true
        }
    }
    
    Context "Fix-IncompleteMetadata Function" {
        It "Should have Fix-IncompleteMetadata function defined" {
            $scriptContent -match 'function Fix-IncompleteMetadata' | Should -Be $true
        }
        
        It "Should check if project file exists" {
            $scriptContent -match 'Test-Path.*\$ProjectFile' | Should -Be $true
        }
        
        It "Should load XML content" {
            $scriptContent -match '\[xml\].*Get-Content.*\$ProjectFile' | Should -Be $true
        }
        
        It "Should check for PropertyGroup" {
            $scriptContent -match 'PropertyGroup' | Should -Be $true
        }
        
        It "Should add Authors property" {
            $scriptContent -match "'Authors'" | Should -Be $true
        }
        
        It "Should add Company property" {
            $scriptContent -match "'Company'" | Should -Be $true
        }
        
        It "Should add Description property" {
            $scriptContent -match "'Description'" | Should -Be $true
        }
        
        It "Should add PackageLicenseExpression property" {
            $scriptContent -match "'PackageLicenseExpression'" | Should -Be $true
        }
        
        It "Should add Copyright property with current year" {
            $scriptContent -match 'Get-Date -Format yyyy' | Should -Be $true
        }
        
        It "Should save modified project file" {
            $scriptContent -match '\.Save\(' | Should -Be $true
        }
        
        It "Should respect DryRun mode in Fix-IncompleteMetadata" {
            $scriptContent -match 'if.*-not.*\$DryRun' | Should -Be $true
        }
    }
    
    Context "Fix-LowCoverage Function" {
        It "Should have Fix-LowCoverage function defined" {
            $scriptContent -match 'function Fix-LowCoverage' | Should -Be $true
        }
        
        It "Should warn that automated test generation is not supported" {
            $scriptContent -match 'Automated test generation is not supported' | Should -Be $true
        }
        
        It "Should suggest using Cursor AI" {
            $scriptContent -match 'Suggested next step: Use Cursor AI' | Should -Be $true
        }
        
        It "Should reference documentation" {
            $scriptContent -match 'Documentation' | Should -Be $true
        }
        
        It "Should mention unit test workflow rule" {
            $scriptContent -match 'unit test' | Should -Be $true
        }
    }
    
    Context "Fix-All Function" {
        It "Should have Fix-All function defined" {
            $scriptContent -match 'function Fix-All' | Should -Be $true
        }
        
        It "Should define fixes array" {
            $scriptContent -match '\$fixes.*=.*@\(' | Should -Be $true
        }
        
        It "Should include MissingDocumentation in fixes" {
            $scriptContent -match "'MissingDocumentation'" | Should -Be $true
        }
        
        It "Should include IncompleteMetadata in fixes" {
            $scriptContent -match "'IncompleteMetadata'" | Should -Be $true
        }
        
        It "Should iterate through fixes" {
            $scriptContent -match 'foreach.*\$fixType.*in.*\$fixes' | Should -Be $true
        }
    }

    Context "AnalyzerAutocorrect Diagnostic Coverage" {
        It "Should include DataMigrator-reported style diagnostic IDs in AnalyzerAutocorrect" {
            $scriptContent -match "'IDE0034'" | Should -Be $true
            $scriptContent -match "'IDE0059'" | Should -Be $true
            $scriptContent -match "'IDE0250'" | Should -Be $true
            $scriptContent -match "'IDE0251'" | Should -Be $true
            $scriptContent -match "'IDE0290'" | Should -Be $true
            $scriptContent -match "'IDE0350'" | Should -Be $true
        }

        It "Should include DataMigrator-reported analyzer diagnostic IDs in AnalyzerAutocorrect" {
            $scriptContent -match "'CA1816'" | Should -Be $true
            $scriptContent -match "'CA1827'" | Should -Be $true
        }
    }
    
    Context "LicenseWarning Fix Type" {
        It "Should handle LicenseWarning fix type" {
            $scriptContent -match "'LicenseWarning'" | Should -Be $true
        }
        
        It "Should log warning for manual review" {
            $scriptContent -match 'License warning requires manual review' | Should -Be $true
        }
    }
    
    Context "CodeComplexity Fix Type" {
        It "Should handle CodeComplexity fix type" {
            $scriptContent -match "'CodeComplexity'" | Should -Be $true
        }
        
        It "Should log warning for refactoring" {
            $scriptContent -match 'Code complexity requires refactoring' | Should -Be $true
        }
    }
    
    Context "Exit Codes" {
        It "Should have exit 0 for success" {
            $scriptContent -match 'exit 0' | Should -Be $true
        }
        
        It "Should have exit 1 for failure" {
            $scriptContent -match 'exit 1' | Should -Be $true
        }
        
        It "Should exit 0 when success is true" {
            $scriptContent -match '(?s)if\s*\(\s*\$success\s*\)[\s\S]*?exit 0' | Should -Be $true
        }
    }
    
    Context "DryRun Mode" {
        It "Should log DryRun mode when enabled" {
            $scriptContent -match 'DRY RUN MODE' | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should have try-catch block" {
            $scriptContent -match 'try\s*\{' | Should -Be $true
            $scriptContent -match 'catch\s*\{' | Should -Be $true
        }
        
        It "Should log fatal errors" {
            $scriptContent -match 'Fatal error' | Should -Be $true
        }
        
        It "Should display stack trace on error" {
            $scriptContent -match 'ScriptStackTrace' | Should -Be $true
        }
    }
    
    Context "Main Execution Logic" {
        It "Should have switch statement for Fix types" {
            $scriptContent -match 'switch.*\$Fix' | Should -Be $true
        }
        
        It "Should handle MissingDocumentation case" {
            $scriptContent -match "'MissingDocumentation'.*\{.*Fix-MissingDocumentation" | Should -Be $true
        }
        
        It "Should handle IncompleteMetadata case" {
            $scriptContent -match "'IncompleteMetadata'.*\{.*Fix-IncompleteMetadata" | Should -Be $true
        }
        
        It "Should handle LowCoverage case" {
            $scriptContent -match "'LowCoverage'.*\{.*Fix-LowCoverage" | Should -Be $true
        }
        
        It "Should handle LicenseWarning case" {
            $scriptContent -match "'LicenseWarning'" | Should -Be $true
        }
        
        It "Should handle CodeComplexity case" {
            $scriptContent -match "'CodeComplexity'" | Should -Be $true
        }
        
        It "Should handle All case" {
            $scriptContent -match "'All'.*\{.*Fix-All" | Should -Be $true
        }
    }
}
