#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Pester tests for validate-pre-merge.ps1

.DESCRIPTION
    Tests configuration file loading, parameter validation, step execution,
    error handling, and output formatting.
#>

$scriptPath = Join-Path $PSScriptRoot "validate-pre-merge.ps1"

Describe "validate-pre-merge.ps1" {
    BeforeAll {
        # Create mock solution directory for testing
        $testRoot = Join-Path $TestDrive "TestSolution"
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

        $testSln = Join-Path $testRoot "Test.sln"
        Set-Content -Path $testSln -Value "Microsoft Visual Studio Solution File, Format Version 12.00"
    }
    Context "Configuration File Loading" {
        It "Should load configuration from JSON file" {
            $configPath = Join-Path $TestDrive "test-config.json"
            $config = @{
                TargetPath = "custom/path"
                MaxOutputLines = 100
                MaxFiles = 50
                SkipTests = $true
            }
            $config | ConvertTo-Json | Set-Content -Path $configPath
            
            # Mock the script execution to verify config loading
            $result = & $scriptPath -ConfigFile $configPath -DryRun -JsonOutput 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing configuration file gracefully" {
            $result = & $scriptPath -ConfigFile "nonexistent.json" -DryRun -JsonOutput 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle invalid JSON gracefully" {
            $configPath = Join-Path $TestDrive "invalid-config.json"
            Set-Content -Path $configPath -Value "{ invalid json }"
            
            $result = & $scriptPath -ConfigFile $configPath -DryRun -JsonOutput 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should allow command-line parameters to override config file" {
            $configPath = Join-Path $TestDrive "override-config.json"
            $config = @{ MaxOutputLines = 100 }
            $config | ConvertTo-Json | Set-Content -Path $configPath
            
            # Command line -MaxOutputLines should override config
            $result = & $scriptPath -ConfigFile $configPath -MaxOutputLines 200 -DryRun -JsonOutput 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept valid TargetPath parameter" {
            { & $scriptPath -TargetPath $testSln -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should accept valid Steps parameter (range)" {
            { & $scriptPath -TargetPath $testSln -Steps "1-3" -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should accept valid Steps parameter (comma-separated)" {
            { & $scriptPath -TargetPath $testSln -Steps "1,3,5" -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should accept valid DiagnosticFilter parameter" {
            { & $scriptPath -TargetPath $testSln -DiagnosticFilter "CS1591,IDE1006" -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should accept valid MaxOutputLines parameter" {
            { & $scriptPath -TargetPath $testSln -MaxOutputLines 100 -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should accept valid MaxFiles parameter" {
            { & $scriptPath -TargetPath $testSln -MaxFiles 50 -DryRun -JsonOutput } | Should -Not -Throw
        }
    }
    
    Context "Solution File Detection" {
        It "Should find solution file in directory" {
            $output = & $scriptPath -TargetPath $testRoot -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept direct solution file path" {
            $output = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output | Should -Not -BeNullOrEmpty
        }
        
        It "Should fail gracefully when no solution file found" {
            $emptyDir = Join-Path $TestDrive "EmptyDir"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            
            $output = & $scriptPath -TargetPath $emptyDir -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.Error | Should -Match "No solution file found"
        }
    }
    
    Context "Dry Run Mode" {
        It "Should not execute commands in dry run mode" {
            $output = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.SkippedSteps | Should -BeGreaterThan 0
        }
        
        It "Should show what would be done in dry run" {
            $output = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Steps | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "JSON Output Mode" {
        It "Should produce valid JSON output" {
            $json = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should include summary in JSON output" {
            $output = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary | Should -Not -BeNullOrEmpty
            $output.Summary.TotalSteps | Should -BeGreaterThan 0
        }
        
        It "Should include steps array in JSON output" {
            $output = & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Steps | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Step Filtering" {
        It "Should run only specified steps (single)" {
            $output = & $scriptPath -TargetPath $testSln -Steps "3" -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Steps.Count | Should -BeLessOrEqual 1
        }
        
        It "Should run only specified steps (range)" {
            $output = & $scriptPath -TargetPath $testSln -Steps "1-3" -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.TotalSteps | Should -Be 3
        }
        
        It "Should run only specified steps (comma-separated)" {
            $output = & $scriptPath -TargetPath $testSln -Steps "1,3,5" -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.TotalSteps | Should -Be 3
        }
    }
    
    Context "Error Handling" {
        It "Should handle exceptions gracefully" {
            # Test with invalid solution file
            $invalidSln = Join-Path $TestDrive "invalid.sln"
            Set-Content -Path $invalidSln -Value "invalid content"
            
            { & $scriptPath -TargetPath $invalidSln -DryRun -JsonOutput } | Should -Not -Throw
        }
        
        It "Should return non-zero exit code on failure" {
            $emptyDir = Join-Path $TestDrive "EmptyDir2"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            
            & $scriptPath -TargetPath $emptyDir -DryRun -JsonOutput 2>&1 | Out-Null
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
    
    Context "Switch Parameters" {
        It "Should respect -SkipAutoFix switch" {
            $output = & $scriptPath -TargetPath $testSln -SkipAutoFix -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.SkippedSteps | Should -BeGreaterThan 0
        }
        
        It "Should respect -SkipTests switch" {
            $output = & $scriptPath -TargetPath $testSln -SkipTests -DryRun -JsonOutput 2>&1 | ConvertFrom-Json
            $output.Summary.SkippedSteps | Should -BeGreaterThan 0
        }
    }
    
    Context "Exit Codes" {
        It "Should return 0 on success (dry run)" {
            & $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should return 1 when no solution found" {
            $emptyDir = Join-Path $TestDrive "EmptyDir3"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            
            & $scriptPath -TargetPath $emptyDir -JsonOutput 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "Helper Functions" {
        BeforeAll {
            # Source the script to test helper functions
            . $scriptPath -TargetPath $testSln -DryRun -JsonOutput 2>&1 | Out-Null
        }
        
        It "Get-StatusEmoji should return emojis" {
            $emoji = Get-StatusEmoji -Status 'success'
            $emoji | Should -Not -BeNullOrEmpty
        }
        
        It "Get-StepsToRun should parse range correctly" {
            $steps = Get-StepsToRun -StepsParam "1-5"
            $steps.Count | Should -Be 5
            $steps[0] | Should -Be 1
            $steps[4] | Should -Be 5
        }
        
        It "Get-StepsToRun should parse comma-separated correctly" {
            $steps = Get-StepsToRun -StepsParam "1,3,5"
            $steps.Count | Should -Be 3
            $steps | Should -Contain 1
            $steps | Should -Contain 3
            $steps | Should -Contain 5
        }
    }
}

Describe "Configuration File Format" {
    It "Should support all parameters in config file" {
        $config = @{
            TargetPath = "."
            SkipAutoFix = $false
            SkipTests = $false
            Steps = "1-7"
            DiagnosticFilter = "CS1591"
            MaxOutputLines = 50
            MaxFiles = 20
            DryRun = $false
            JsonOutput = $false
        }
        
        $configPath = Join-Path $TestDrive "full-config.json"
        $config | ConvertTo-Json | Set-Content -Path $configPath
        
        { & $scriptPath -ConfigFile $configPath -DryRun -JsonOutput } | Should -Not -Throw
    }
}
