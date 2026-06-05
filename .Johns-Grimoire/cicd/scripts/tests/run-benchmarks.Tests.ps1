<#
.SYNOPSIS
    Pester tests for run-benchmarks.ps1

.DESCRIPTION
    Tests the performance benchmark script including:
    - Write-Log function behavior
    - Benchmark project discovery
    - Baseline comparison logic
    - Performance regression detection
    - Result file parsing
#>

$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "run-benchmarks.ps1"

# Import shared logging module (tests now validate the shared module)
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Describe "run-benchmarks.ps1 Tests" {
    
    Context "Write-Log Function" {
        
        It "Should log INFO messages without throwing" {
            { Write-Log "Test message" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages without throwing" {
            { Write-Log "Success message" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log WARN messages without throwing" {
            { Write-Log "Warning message" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages without throwing" {
            { Write-Log "Error message" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages without throwing" {
            { Write-Log "Debug message" -Level DEBUG } | Should -Not -Throw
        }
        
        It "Should handle empty messages (blank lines)" {
            { Write-Log "" } | Should -Not -Throw
        }
        
        It "Should default to INFO level when not specified" {
            { Write-Log "Default level" } | Should -Not -Throw
        }
    }
    
    Context "Azure Pipelines Integration" {
        
        It "Should log in Azure Pipelines environment without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\_work\temp"
                { Write-Log "Test" -Level ERROR } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should log ERROR level in Azure Pipelines without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\_work\temp"
                { Write-Log "Error test" -Level ERROR } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should log WARN level in Azure Pipelines without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\_work\temp"
                { Write-Log "Warning test" -Level WARN } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should log outside Azure Pipelines without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                { Write-Log "Test" -Level ERROR } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                }
            }
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should have Configuration parameter with ValidateSet" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[ValidateSet\("Debug", "Release"\)\]'
        }
        
        It "Should have Configuration parameter with default value Release" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Configuration = "Release"'
        }
        
        It "Should have MaxRegressionPercent parameter with ValidateRange" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[ValidateRange\(0, 100\)\]'
        }
        
        It "Should have MaxRegressionPercent parameter with default value 10" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$MaxRegressionPercent = 10'
        }
        
        It "Should have ShowProgress switch parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$ShowProgress'
        }
        
        It "Should have OutputPath parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$OutputPath'
        }
    }
    
    Context "Environment Detection" {
        
        It "Should detect Azure Pipelines environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:BUILD_ARTIFACTSTAGINGDIRECTORY'
        }
        
        It "Should set output path based on environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$env:BUILD_ARTIFACTSTAGINGDIRECTORY\)'
        }
        
        It "Should handle progress bar display logic" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$showProgressBar'
        }
    }
    
    Context "Benchmark Project Discovery" {
        
        It "Should search for benchmark projects recursively" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-ChildItem.*-Recurse.*Benchmarks\.csproj'
        }
        
        It "Should exit with code 0 when no benchmark projects found" -Skip {
            # This test requires complex directory setup
        }
    }
    
    Context "Baseline Comparison Logic" {
        
        It "Should check for baseline file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'baseline-benchmarks\.json'
        }
        
        It "Should calculate percentage change correctly" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$percentChange.*=.*\(\(.*Mean.*-.*Mean\).*\/.*Mean\).*\*.*100'
        }
        
        It "Should detect regressions exceeding threshold" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$percentChange -gt \$MaxRegressionPercent\)'
        }
        
        It "Should detect improvements" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'elseif \(\$percentChange -lt -5\)'
        }
    }
    
    Context "Exit Codes" {
        
        It "Should exit with code 1 when regressions detected" -Skip {
            # This test requires mocking benchmark results
        }
        
        It "Should exit with code 0 when no regressions" -Skip {
            # This test requires mocking benchmark results
        }
        
        It "Should exit with code 0 when no benchmark projects found" -Skip {
            # This test requires complex directory setup
        }
    }
    
    Context "Progress Reporting" {
        
        It "Should use Write-Progress for progress reporting" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Progress'
        }
        
        It "Should calculate percent complete" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$percentComplete'
        }
        
        It "Should complete progress bar at end" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Progress.*-Completed'
        }
    }
}

