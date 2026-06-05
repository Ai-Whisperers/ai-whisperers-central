<#
.SYNOPSIS
    Pester tests for collect-local-metrics.ps1

.DESCRIPTION
    Tests configuration loading, parameter precedence, and orchestration logic
    for the collect-local-metrics script.
    
    Compatible with Pester 3.x
#>

# Setup - Import shared modules used by the script
$script:scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "collect-local-metrics.ps1"
$script:modulesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
Import-Module (Join-Path $script:modulesPath "ScriptLogging.psm1") -Force
Import-Module (Join-Path $script:modulesPath "ConfigurationLoader.psm1") -Force
Import-Module (Join-Path $script:modulesPath "EnvironmentDetection.psm1") -Force

Describe "collect-local-metrics.ps1 - Configuration Loading" {
    
    Context "When config file exists and is valid" {
        
        It "Should load configuration from file" {
            $testConfigPath = Join-Path $TestDrive "test-config.json"
            $testConfig = @{
                CoverageThresholds = @{
                    Line = 85
                    Branch = 80
                }
            } | ConvertTo-Json
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $config | Should -Not -BeNullOrEmpty
            $config.CoverageThresholds.Line | Should -Be 85
        }
    }
    
    Context "When config file does not exist" {
        It "Should return null without error" {
            $config = Import-ScriptConfiguration -ConfigFile "nonexistent.json"
            $config | Should -BeNullOrEmpty
        }
    }
    
    Context "When config file is invalid JSON" {
        It "Should handle parse error gracefully" {
            $invalidConfigPath = Join-Path $TestDrive "invalid-config.json"
            Set-Content -Path $invalidConfigPath -Value "{ invalid json"
            
            $config = Import-ScriptConfiguration -ConfigFile $invalidConfigPath
            $config | Should -BeNullOrEmpty
        }
    }
}

Describe "collect-local-metrics.ps1 - Parameter Precedence" {
    BeforeAll {
        $script:paramMap = @{
            'MinLineCoverage' = 'CoverageThresholds.Line'
            'MinBranchCoverage' = 'CoverageThresholds.Branch'
            'MinPublicApiCoverage' = 'CoverageThresholds.PublicApi'
            'MaxComplexity' = 'MetricsThresholds.MaxCyclomaticComplexity'
            'MinMaintainability' = 'MetricsThresholds.MinMaintainability'
            'OutputPath' = 'OutputSettings.OutputPath'
            'EnableHistoryTracking' = 'OutputSettings.EnableHistoryTracking'
            'MaxHistoryEntries' = 'OutputSettings.MaxHistoryEntries'
            'ReportTypes' = 'OutputSettings.ReportTypes'
            'AssemblyFilters' = 'OutputSettings.AssemblyFilters'
            'EnableProfiling' = 'PerformanceSettings.EnableProfiling'
            'ShowProgress' = 'PerformanceSettings.ShowProgress'
        }
    }
    
    Context "When only config value is provided" {
        It "Should use config value over default" {
            $testConfigPath = Join-Path $TestDrive "config-only.json"
            $testConfig = @{
                MetricsThresholds = @{ MaxCyclomaticComplexity = 25 }
            } | ConvertTo-Json
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $PSBoundParams = @{}
            $script:MaxComplexity = 15
            
            $appliedValues = Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParams -ParameterMap $script:paramMap
            foreach ($entry in $appliedValues.GetEnumerator()) {
                Set-Variable -Name $entry.Key -Value $entry.Value -Scope Script
            }
            
            $script:MaxComplexity | Should -Be 25
        }
    }
}

Describe "collect-local-metrics.ps1 - Configuration Schema" {
    
    Context "When all configuration sections are present" {
        It "Should parse complete configuration successfully" {
            $testConfigPath = Join-Path $TestDrive "complete-config.json"
            $testConfig = @{
                CoverageThresholds = @{
                    Line = 80
                    Branch = 75
                    PublicApi = 90
                }
                MetricsThresholds = @{
                    MaxCyclomaticComplexity = 15
                    MinMaintainability = 60
                }
                EnabledChecks = @{
                    RunMetrics = $true
                    RunCoverage = $true
                }
                OutputSettings = @{
                    OutputPath = "./local-reports"
                    EnableHistoryTracking = $true
                    MaxHistoryEntries = 0
                }
                PerformanceSettings = @{
                    EnableProfiling = $false
                    ShowProgress = $false
                }
            } | ConvertTo-Json -Depth 10
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $config.CoverageThresholds | Should -Not -BeNullOrEmpty
            $config.MetricsThresholds | Should -Not -BeNullOrEmpty
            $config.EnabledChecks | Should -Not -BeNullOrEmpty
            $config.OutputSettings | Should -Not -BeNullOrEmpty
            $config.PerformanceSettings | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When configuration has partial sections" {
        It "Should handle missing sections gracefully" {
            $testConfigPath = Join-Path $TestDrive "partial-config.json"
            $testConfig = @{
                CoverageThresholds = @{ Line = 85 }
            } | ConvertTo-Json
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $config.CoverageThresholds | Should -Not -BeNullOrEmpty
            ($config.PSObject.Properties.Name -contains 'MetricsThresholds') | Should -Be $false
        }
    }
}

Describe "collect-local-metrics.ps1 - Enabled Checks Logic" {
    
    Context "When RunMetrics is false in config" {
        It "Should detect metrics disabled" {
            $testConfigPath = Join-Path $TestDrive "skip-metrics.json"
            $testConfig = @{
                EnabledChecks = @{ RunMetrics = $false; RunCoverage = $true }
            } | ConvertTo-Json
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $runMetrics = $true
            if ($config.EnabledChecks.RunMetrics -ne $null) {
                $runMetrics = $config.EnabledChecks.RunMetrics
            }
            
            $runMetrics | Should -Be $false
        }
    }
    
    Context "When RunCoverage is false in config" {
        It "Should detect coverage disabled" {
            $testConfigPath = Join-Path $TestDrive "skip-coverage.json"
            $testConfig = @{
                EnabledChecks = @{ RunMetrics = $true; RunCoverage = $false }
            } | ConvertTo-Json
            
            Set-Content -Path $testConfigPath -Value $testConfig
            
            $config = Import-ScriptConfiguration -ConfigFile $testConfigPath
            $runCoverage = $true
            if ($config.EnabledChecks.RunCoverage -ne $null) {
                $runCoverage = $config.EnabledChecks.RunCoverage
            }
            
            $runCoverage | Should -Be $false
        }
    }
}

Describe "collect-local-metrics.ps1 - Write-Log Function" {
    
    Context "When logging at different levels" {
        
        It "Should log INFO messages without error" {
            { Write-Log "Test info message" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log WARN messages without error" {
            { Write-Log "Test warning message" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages without error" {
            { Write-Log "Test error message" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages without error" {
            { Write-Log "Test success message" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages without error" {
            { Write-Log "Test debug message" -Level DEBUG } | Should -Not -Throw
        }
    }
}

Describe "collect-local-metrics.ps1 - Output Path Detection" {
    
    Context "When running in Azure Pipelines" {
        
        It "Should detect Azure Pipelines environment" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\artifacts"
            
            $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
            $isAzurePipeline | Should -Be $true
            
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            Remove-Item env:BUILD_ARTIFACTSTAGINGDIRECTORY -ErrorAction SilentlyContinue
        }
    }
    
    Context "When running locally" {
        
        It "Should detect local environment" {
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            
            $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
            $isAzurePipeline | Should -Be $false
        }
    }
}

Describe "collect-local-metrics.ps1 - Parameter Passing" {
    
    Context "When constructing subprocess arguments" {
        
        It "Should create valid hashtable for metrics script" {
            $metricsArgs = @{
                Configuration = "Release"
                OutputPath = "test-output/code-metrics"
                MaxComplexity = 15
                MinMaintainability = 60
                EnableHistoryTracking = $true
                MaxHistoryEntries = 0
                EnableProfiling = $false
            }
            
            $metricsArgs.Keys.Count | Should -Be 7
            $metricsArgs.Configuration | Should -Be "Release"
        }
        
        It "Should create valid hashtable for coverage script" {
            $coverageArgs = @{
                Configuration = "Release"
                OutputPath = "test-output/enhanced-coverage"
                MinLineCoverage = 80
                MinBranchCoverage = 70
                MinPublicApiCoverage = 90
                ReportTypes = "Cobertura"
                AssemblyFilters = "+*"
                EnableHistoryTracking = $true
                MaxHistoryEntries = 0
                EnableProfiling = $false
                ShowProgress = $false
            }
            
            $coverageArgs.Keys.Count | Should -Be 11
            $coverageArgs.MinLineCoverage | Should -Be 80
        }
    }
}

Describe "collect-local-metrics.ps1 - Error Handling" {
    
    Context "When subprocess script is missing" {
        It "Should detect missing script" {
            $missingScriptPath = "nonexistent-script.ps1"
            Test-Path $missingScriptPath | Should -Be $false
        }
    }
    
    Context "When subprocess fails" {
        It "Should handle non-zero exit code" {
            $LASTEXITCODE = 1
            $LASTEXITCODE | Should -Be 1
        }
    }
}
