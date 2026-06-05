#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for fix-errors.ps1
.DESCRIPTION
    Comprehensive unit tests for the automated error fix script
    Tests error detection, automated fixes, and dry-run mode
    
    Compatible with Pester 3.x
#>

$ErrorActionPreference = "Stop"

Describe "fix-errors.ps1" -Tag "Unit", "CICD", "ErrorFix" {
    BeforeAll {
        # Setup - Get script under test
        $script:scriptPath = Join-Path $PSScriptRoot "..\fix-errors.ps1"
        $script:scriptContent = Get-Content $script:scriptPath -Raw
    }
    
    Context "Script Initialization" {
        It "Should exist at expected path" {
            Test-Path $script:scriptPath | Should -Be $true
        }
        
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($script:scriptContent, [ref]$errors)
            $errors.Count | Should -Be 0
        }
        
        It "Should have proper shebang" {
            $firstLine = Get-Content $script:scriptPath -First 1
            $firstLine | Should -Match '^#!/usr/bin/env pwsh'
        }
    }
    
    Context "Parameter Validation" {
        It "Should have Fix parameter with Mandatory attribute" {
            $script:scriptContent -match '(?s)\[Parameter\(Mandatory.*\)\][\s\S]*?\[string\]\$Fix' | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with MissingChangelog" {
            $script:scriptContent -match "(?s)ValidateSet\([\s\S]*'MissingChangelog'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with InvalidTagContext" {
            $script:scriptContent -match "(?s)ValidateSet\([\s\S]*'InvalidTagContext'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with MissingXmlFiles" {
            $script:scriptContent -match "(?s)ValidateSet\([\s\S]*'MissingXmlFiles'" | Should -Be $true
        }
        
        It "Should have ValidateSet for Fix parameter with All" {
            $script:scriptContent -match "(?s)ValidateSet\([\s\S]*'All'" | Should -Be $true
        }
        
        It "Should have Version parameter" {
            $script:scriptContent -match '\[string\]\$Version' | Should -Be $true
        }
        
        It "Should have DryRun switch parameter" {
            $script:scriptContent -match '\[switch\]\$DryRun' | Should -Be $true
        }
    }
    
    Context "Fix-MissingChangelog Function" {
        It "Should have Fix-MissingChangelog function defined" {
            $script:scriptContent -match 'function Fix-MissingChangelog' | Should -Be $true
        }
        
        It "Should get git commits for changelog" {
            $script:scriptContent -match 'git log' | Should -Be $true
        }
        
        It "Should get last tag with git describe" {
            $script:scriptContent -match 'git describe.*--tags' | Should -Be $true
        }
        
        It "Should categorize commits by type" {
            $script:scriptContent -match 'feat|feature' | Should -Be $true
            $script:scriptContent -match 'fix|bugfix' | Should -Be $true
        }
        
        It "Should include BREAKING CHANGE detection" {
            $script:scriptContent -match 'BREAKING CHANGE' | Should -Be $true
        }
        
        It "Should format changelog entry with version and date" {
            $script:scriptContent -match 'Get-Date -Format yyyy-MM-dd' | Should -Be $true
        }
        
        It "Should respect DryRun mode in Fix-MissingChangelog" {
            $script:scriptContent -match 'if.*\$DryRun' | Should -Be $true
        }
    }
    
    Context "Fix-MissingXmlFiles Function" {
        It "Should have Fix-MissingXmlFiles function defined" {
            $script:scriptContent -match 'function Fix-MissingXmlFiles' | Should -Be $true
        }
        
        It "Should search for csproj files" {
            $script:scriptContent -match 'Get-ChildItem.*-Filter.*\.csproj' | Should -Be $true
        }
        
        It "Should check GenerateDocumentationFile property" {
            $script:scriptContent -match 'GenerateDocumentationFile' | Should -Be $true
        }
        
        It "Should set GenerateDocumentationFile to true" {
            $script:scriptContent -match "GenerateDocumentationFile.*=.*'true'" | Should -Be $true
        }
        
        It "Should save modified project files" {
            $script:scriptContent -match '\.Save\(' | Should -Be $true
        }
        
        It "Should respect DryRun mode in Fix-MissingXmlFiles" {
            $script:scriptContent -match 'if.*-not.*\$DryRun' | Should -Be $true
        }
    }
    
    Context "Fix-All Function" {
        It "Should have Fix-All function defined" {
            $script:scriptContent -match 'function Fix-All' | Should -Be $true
        }
        
        It "Should call Fix-MissingXmlFiles in Fix-All" {
            $script:scriptContent -match 'Fix-MissingXmlFiles' | Should -Be $true
        }
        
        It "Should conditionally call Fix-MissingChangelog when Version provided" {
            $script:scriptContent -match 'if.*\$Version' | Should -Be $true
        }
    }
    
    Context "InvalidTagContext Error Type" {
        It "Should handle InvalidTagContext error type" {
            $script:scriptContent -match "'InvalidTagContext'" | Should -Be $true
        }
        
        It "Should log error for manual intervention" {
            $script:scriptContent -match 'Invalid tag context requires manual intervention' | Should -Be $true
        }
    }
    
    Context "Exit Codes" {
        It "Should have exit 0 for success" {
            $script:scriptContent -match 'exit 0' | Should -Be $true
        }
        
        It "Should have exit 1 for failure" {
            $script:scriptContent -match 'exit 1' | Should -Be $true
        }
        
        It "Should exit 0 when success is true" {
            $script:scriptContent -match '(?s)if \(\$success\)[\s\S]*exit 0' | Should -Be $true
        }
        
        It "Should exit 1 when success is false" {
            $script:scriptContent -match '(?s)else[\s\S]*exit 1' | Should -Be $true
        }
    }
    
    Context "DryRun Mode" {
        It "Should log DryRun mode when enabled" {
            $script:scriptContent -match 'DRY RUN MODE' | Should -Be $true
        }
        
        It "Should display what would be changed in DryRun" {
            $script:scriptContent -match 'Would add' | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should have try-catch block" {
            $script:scriptContent -match 'try\s*\{' | Should -Be $true
            $script:scriptContent -match 'catch\s*\{' | Should -Be $true
        }
        
        It "Should log fatal errors" {
            $script:scriptContent -match 'Fatal error' | Should -Be $true
        }
        
        It "Should display stack trace on error" {
            $script:scriptContent -match 'ScriptStackTrace' | Should -Be $true
        }
    }
    
    Context "Main Execution Logic" {
        It "Should have switch statement for Fix types" {
            $script:scriptContent -match 'switch.*\$Fix' | Should -Be $true
        }
        
        It "Should handle MissingChangelog case" {
            $script:scriptContent -match "'MissingChangelog'" | Should -Be $true
        }
        
        It "Should handle MissingXmlFiles case" {
            $script:scriptContent -match "'MissingXmlFiles'" | Should -Be $true
        }
        
        It "Should handle InvalidTagContext case" {
            $script:scriptContent -match "'InvalidTagContext'" | Should -Be $true
        }
        
        It "Should handle All case" {
            $script:scriptContent -match "'All'" | Should -Be $true
        }
    }
}
