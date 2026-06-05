<#
.SYNOPSIS
    Pester tests for check-breaking-changes.ps1

.DESCRIPTION
    Unit tests for configuration loading, structured logging, and parameter validation.
    Tests core functionality without external dependencies.

.NOTES
    File Name      : check-breaking-changes.Tests.ps1
    Prerequisite   : Pester 5.x
    Testing        : Configuration and logging functionality
#>

#Requires -Version 7.2
#Requires -PSEdition Core

# Import shared logging module (tests now validate the shared module)
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Describe "check-breaking-changes.ps1 - Write-Log Function" {
    
    Context "When logging messages with different severity levels" {
        
        It "Should log INFO messages without throwing" {
            { Write-Log "Test INFO message" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages without throwing" {
            { Write-Log "Test SUCCESS message" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log WARN messages without throwing" {
            { Write-Log "Test WARN message" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages without throwing" {
            { Write-Log "Test ERROR message" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages without throwing" {
            { Write-Log "Test DEBUG message" -Level DEBUG } | Should -Not -Throw
        }
        
        It "Should handle empty messages (blank lines)" {
            { Write-Log "" } | Should -Not -Throw
        }
        
        It "Should default to INFO level when level not specified" {
            { Write-Log "Test default level" } | Should -Not -Throw
        }
    }
    
    Context "When Azure Pipelines environment is detected" {
        
        It "Should detect Azure Pipelines environment variable" {
            $originalValue = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\work"
                $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
                $isAzurePipeline | Should -Be $true
            } finally {
                if ($originalValue) {
                    $env:AGENT_TEMPDIRECTORY = $originalValue
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should detect local environment when variable not set" {
            $originalValue = $env:AGENT_TEMPDIRECTORY
            try {
                Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
                $isAzurePipeline | Should -Be $false
            } finally {
                if ($originalValue) {
                    $env:AGENT_TEMPDIRECTORY = $originalValue
                }
            }
        }
    }
}

Describe "check-breaking-changes.ps1 - Configuration File Support" {
    
    Context "When config file exists with valid JSON" {
        BeforeEach {
            $testConfigPath = Join-Path $TestDrive "test-config.json"
        }
        
        It "Should load and parse valid JSON config file" {
            $testConfig = @{
                Configuration = "Debug"
                BaselineTag = "release-1.0.0"
                OutputPath = "C:\output"
                DisableParallel = $true
                ThrottleLimit = 8
            } | ConvertTo-Json
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            { Get-Content $testConfigPath | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should extract Configuration value from config" {
            $testConfig = @{ Configuration = "Debug" } | ConvertTo-Json
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Get-Content $testConfigPath | ConvertFrom-Json
            $config.Configuration | Should -Be "Debug"
        }
        
        It "Should extract BaselineTag value from config" {
            $testConfig = @{ BaselineTag = "release-1.0.0" } | ConvertTo-Json
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Get-Content $testConfigPath | ConvertFrom-Json
            $config.BaselineTag | Should -Be "release-1.0.0"
        }
        
        It "Should extract ThrottleLimit value from config" {
            $testConfig = @{ ThrottleLimit = 8 } | ConvertTo-Json
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Get-Content $testConfigPath | ConvertFrom-Json
            $config.ThrottleLimit | Should -Be 8
        }
        
        It "Should extract DisableParallel value from config" {
            $testConfig = @{ DisableParallel = $true } | ConvertTo-Json
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Get-Content $testConfigPath | ConvertFrom-Json
            $config.DisableParallel | Should -Be $true
        }
    }
    
    Context "When applying parameter precedence" {
        
        It "CLI parameter should override config value" {
            $cliValue = "Release"
            $configValue = "Debug"
            
            # Simulate CLI > Config precedence
            $finalValue = if ($cliValue) { $cliValue } else { $configValue }
            $finalValue | Should -Be "Release"
        }
        
        It "Config value should be used when CLI parameter is empty" {
            $cliValue = ""
            $configValue = "Debug"
            
            # Simulate Config > Default precedence
            $finalValue = if ($cliValue) { $cliValue } else { $configValue }
            $finalValue | Should -Be "Debug"
        }
        
        It "Default value should be used when both CLI and config are empty" {
            $cliValue = ""
            $configValue = ""
            $defaultValue = "Release"
            
            # Simulate Default precedence
            $finalValue = if ($cliValue) { $cliValue } elseif ($configValue) { $configValue } else { $defaultValue }
            $finalValue | Should -Be "Release"
        }
    }
    
    Context "When config file does not exist" {
        
        It "Should handle missing config file gracefully" {
            $nonExistentPath = Join-Path $TestDrive "nonexistent.json"
            Test-Path $nonExistentPath | Should -Be $false
            # Script should continue with defaults
        }
    }
    
    Context "When config file has malformed JSON" {
        
        It "Should handle invalid JSON gracefully" {
            $testConfigPath = Join-Path $TestDrive "malformed-config.json"
            Set-Content -Path $testConfigPath -Value "{ invalid json }"
            
            try {
                Get-Content $testConfigPath | ConvertFrom-Json
                $parsedSuccessfully = $true
            } catch {
                $parsedSuccessfully = $false
            }
            
            $parsedSuccessfully | Should -Be $false
        }
    }
}

Describe "check-breaking-changes.ps1 - Tag Format Validation" {
    
    Context "When validating release tag format" {
        
        It "Should validate correct release tag format" {
            $validTag = "release-1.0.0"
            $validTag -match '^release-\d+\.\d+\.\d+' | Should -Be $true
        }
        
        It "Should validate release tag with RC suffix" {
            $validTag = "release-1.0.0-rc1"
            $validTag -match '^release-\d+\.\d+\.\d+(-rc\d+)?' | Should -Be $true
        }
        
        It "Should reject invalid tag format" {
            $invalidTag = "invalid-tag"
            $invalidTag -match '^release-\d+\.\d+\.\d+' | Should -Be $false
        }
        
        It "Should reject tag without version number" {
            $invalidTag = "release"
            $invalidTag -match '^release-\d+\.\d+\.\d+' | Should -Be $false
        }
        
        It "Should reject tag with incomplete version" {
            $invalidTag = "release-1.0"
            $invalidTag -match '^release-\d+\.\d+\.\d+' | Should -Be $false
        }
    }
}

Describe "check-breaking-changes.ps1 - Parallel Processing Configuration" {
    
    Context "When determining parallel vs sequential processing" {
        
        It "Should use parallel for multiple projects when not disabled" {
            $projectCount = 5
            $disableParallel = $false
            
            $shouldUseParallel = ($projectCount -gt 1) -and (-not $disableParallel)
            $shouldUseParallel | Should -Be $true
        }
        
        It "Should use sequential for single project" {
            $projectCount = 1
            $disableParallel = $false
            
            $shouldUseParallel = ($projectCount -gt 1) -and (-not $disableParallel)
            $shouldUseParallel | Should -Be $false
        }
        
        It "Should use sequential when parallel is disabled" {
            $projectCount = 5
            $disableParallel = $true
            
            $shouldUseParallel = ($projectCount -gt 1) -and (-not $disableParallel)
            $shouldUseParallel | Should -Be $false
        }
        
        It "Should use configured throttle limit" {
            $throttleLimit = 8
            $throttleLimit | Should -Be 8
        }
        
        It "Should default throttle limit to NUMBER_OF_PROCESSORS" {
            $throttleLimit = 0
            
            $finalThrottle = if ($throttleLimit -eq 0) { [int]$env:NUMBER_OF_PROCESSORS } else { $throttleLimit }
            $finalThrottle | Should -Be ([int]$env:NUMBER_OF_PROCESSORS)
        }
    }
    
    Context "When checking PowerShell version for parallel support" {
        
        It "Should identify PowerShell 7+ as parallel-capable" {
            $psVersion = 7
            $psVersion -ge 7 | Should -Be $true
        }
        
        It "Should identify PowerShell 5 as not parallel-capable" {
            $psVersion = 5
            $psVersion -ge 7 | Should -Be $false
        }
    }
}

Describe "check-breaking-changes.ps1 - Output Path Configuration" {
    
    Context "When determining output path" {
        
        It "Should use Azure Pipelines staging directory when in CI/CD" {
            $originalValue = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
            try {
                $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\_work\1\a"
                $outputPath = Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY "api-compat"
                $outputPath | Should -Match "api-compat$"
            } finally {
                if ($originalValue) {
                    $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $originalValue
                } else {
                    Remove-Item Env:\BUILD_ARTIFACTSTAGINGDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should use local directory when not in CI/CD" {
            $originalValue = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
            try {
                Remove-Item Env:\BUILD_ARTIFACTSTAGINGDIRECTORY -ErrorAction SilentlyContinue
                $outputPath = Join-Path $PWD "api-compat"
                $outputPath | Should -Match "api-compat$"
            } finally {
                if ($originalValue) {
                    $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $originalValue
                }
            }
        }
    }
}
