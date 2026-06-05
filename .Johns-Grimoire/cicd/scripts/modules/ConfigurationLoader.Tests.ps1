<#
.SYNOPSIS
    Pester tests for ConfigurationLoader.psm1 module

.DESCRIPTION
    Tests all exported functions from ConfigurationLoader module:
    - Import-ScriptConfiguration
    - Get-ConfigValue
    - Merge-ConfigurationWithParameters
#>

Describe "ConfigurationLoader Module" {
    
    BeforeAll {
        $script:here = $PSScriptRoot
        $script:modulePath = Join-Path $script:here "ConfigurationLoader.psm1"

        Import-Module $script:modulePath -Force
        
        # Create temp directory for test config files
        $script:testDir = Join-Path $env:TEMP "ConfigLoaderTests_$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }
    
    AfterAll {
        Remove-Module ConfigurationLoader -Force -ErrorAction SilentlyContinue
        
        # Clean up test directory
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Module Structure" {
        It "Should import without errors" {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }
        
        It "Should export Import-ScriptConfiguration function" {
            $command = Get-Command Import-ScriptConfiguration -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ConfigurationLoader'
        }
        
        It "Should export Get-ConfigValue function" {
            $command = Get-Command Get-ConfigValue -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ConfigurationLoader'
        }
        
        It "Should export Merge-ConfigurationWithParameters function" {
            $command = Get-Command Merge-ConfigurationWithParameters -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ConfigurationLoader'
        }
    }
    
    Context "Import-ScriptConfiguration - Basic" {
        It "Should return null for nonexistent file" {
            $result = Import-ScriptConfiguration -ConfigFile "$script:testDir\nonexistent.json"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should load valid JSON file" {
            $configPath = Join-Path $script:testDir "valid.json"
            @{ MinThreshold = 80; OutputPath = "test" } | ConvertTo-Json | Set-Content $configPath
            
            $result = Import-ScriptConfiguration -ConfigFile $configPath
            ($null -ne $result) | Should -Be $true
            $result.MinThreshold | Should -Be 80
            $result.OutputPath | Should -Be "test"
        }
        
        It "Should return null for invalid JSON" {
            $configPath = Join-Path $script:testDir "invalid.json"
            "{ invalid json" | Set-Content $configPath
            
            $result = Import-ScriptConfiguration -ConfigFile $configPath
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle empty JSON file" {
            $configPath = Join-Path $script:testDir "empty.json"
            "{}" | Set-Content $configPath
            
            $result = Import-ScriptConfiguration -ConfigFile $configPath
            ($null -ne $result) | Should -Be $true
        }
    }
    
    Context "Get-ConfigValue - Simple Values" {
        BeforeAll {
            $script:testConfig = [pscustomobject]@{
                MinThreshold = 80
                OutputPath = "test-output"
                Configuration = "Release"
                EnableFeature = $true
            }
        }
        
        It "Should retrieve simple integer value" {
            $result = Get-ConfigValue -Config $script:testConfig -PropertyPath "MinThreshold"
            $result | Should -Be 80
        }
        
        It "Should retrieve simple string value" {
            $result = Get-ConfigValue -Config $script:testConfig -PropertyPath "OutputPath"
            $result | Should -Be "test-output"
        }
        
        It "Should retrieve boolean value" {
            $result = Get-ConfigValue -Config $script:testConfig -PropertyPath "EnableFeature"
            $result | Should -Be $true
        }
        
        It "Should return null for nonexistent path" {
            $result = Get-ConfigValue -Config $script:testConfig -PropertyPath "NonExistent"
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Get-ConfigValue - Nested Values" {
        BeforeAll {
            $script:nestedConfig = [pscustomobject]@{
                Coverage = [pscustomobject]@{
                    MinThreshold = 80
                    MaxThreshold = 95
                }
                Output = [pscustomobject]@{
                    Path = "reports"
                    Format = "html"
                }
            }
        }
        
        It "Should retrieve nested value with dot notation" {
            $result = Get-ConfigValue -Config $script:nestedConfig -PropertyPath "Coverage.MinThreshold"
            $result | Should -Be 80
        }
        
        It "Should retrieve deeply nested value" {
            $result = Get-ConfigValue -Config $script:nestedConfig -PropertyPath "Output.Path"
            $result | Should -Be "reports"
        }
        
        It "Should return null for invalid nested path" {
            $result = Get-ConfigValue -Config $script:nestedConfig -PropertyPath "Coverage.NonExistent"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle multiple levels of nesting" {
            $deepConfig = [pscustomobject]@{
                Level1 = [pscustomobject]@{
                    Level2 = [pscustomobject]@{
                        Level3 = "deep-value"
                    }
                }
            }
            
            $result = Get-ConfigValue -Config $deepConfig -PropertyPath "Level1.Level2.Level3"
            $result | Should -Be "deep-value"
        }
    }
    
    Context "Merge-ConfigurationWithParameters - CLI Precedence" {
        It "Should use CLI parameter when provided" {
            $config = [pscustomobject]@{ MinThreshold = 80 }
            $boundParams = @{ MinThreshold = 90 }
            $paramMap = @{ 'MinThreshold' = 'MinThreshold' }
            
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.ContainsKey('MinThreshold') | Should -Be $false
        }
        
        It "Should use config value when CLI not provided" {
            $config = [pscustomobject]@{ MinThreshold = 80 }
            $boundParams = @{}
            $paramMap = @{ 'MinThreshold' = 'MinThreshold' }
            
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.MinThreshold | Should -Be 80
        }
        
        It "Should handle multiple parameters" {
            $config = [pscustomobject]@{
                MinThreshold = 80
                OutputPath = "config-path"
                Configuration = "Release"
            }
            $boundParams = @{ MinThreshold = 90 }  # Only override MinThreshold
            $paramMap = @{
                'MinThreshold' = 'MinThreshold'
                'OutputPath' = 'OutputPath'
                'Configuration' = 'Configuration'
            }
            
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.ContainsKey('MinThreshold') | Should -Be $false
            $result.OutputPath | Should -Be "config-path"
            $result.Configuration | Should -Be "Release"
        }
    }
    
    Context "Merge-ConfigurationWithParameters - Nested Paths" {
        It "Should merge nested config value" {
            $config = [pscustomobject]@{
                Coverage = [pscustomobject]@{
                    MinThreshold = 80
                }
            }
            $boundParams = @{}
            $paramMap = @{ 'MinThreshold' = 'Coverage.MinThreshold' }
            
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.MinThreshold | Should -Be 80
        }
        
        It "Should prioritize CLI over nested config" {
            $config = [pscustomobject]@{
                Coverage = [pscustomobject]@{
                    MinThreshold = 80
                }
            }
            $boundParams = @{ MinThreshold = 90 }
            $paramMap = @{ 'MinThreshold' = 'Coverage.MinThreshold' }
            
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.ContainsKey('MinThreshold') | Should -Be $false
        }
    }
    
    Context "Integration - Full Workflow" {
        It "Should complete full config loading and merging workflow" {
            # Create test config file
            $configPath = Join-Path $script:testDir "workflow.json"
            @{
                MinThreshold = 75
                OutputPath = "config-output"
                Configuration = "Debug"
            } | ConvertTo-Json | Set-Content $configPath
            
            # Load config
            $config = Import-ScriptConfiguration -ConfigFile $configPath
            $config | Should -Not -BeNullOrEmpty
            
            # Simulate CLI parameters (override MinThreshold only)
            $boundParams = @{ MinThreshold = 85 }
            $paramMap = @{
                'MinThreshold' = 'MinThreshold'
                'OutputPath' = 'OutputPath'
                'Configuration' = 'Configuration'
            }
            
            # Merge
            $result = Merge-ConfigurationWithParameters -Config $config -BoundParameters $boundParams -ParameterMap $paramMap
            
            $result.ContainsKey('MinThreshold') | Should -Be $false
            $result.OutputPath | Should -Be "config-output"
            $result.Configuration | Should -Be "Debug"
        }
    }
}

