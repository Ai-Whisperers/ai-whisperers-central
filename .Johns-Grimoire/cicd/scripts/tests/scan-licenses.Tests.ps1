<#
.SYNOPSIS
    Pester tests for scan-licenses.ps1

.DESCRIPTION
    Tests the license scanning script including:
    - Write-Log function behavior
    - Parallel processing logic
    - License classification
    - Parameter validation
#>

$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scan-licenses.ps1"

# Import shared logging module (tests now validate the shared module)
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Describe "scan-licenses.ps1 Tests" {
    
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
        
        It "Should have DisableParallel switch parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$DisableParallel'
        }
        
        It "Should have ThrottleLimit parameter with default from environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$ThrottleLimit = \$env:NUMBER_OF_PROCESSORS'
        }
        
        It "Should have OutputPath parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$OutputPath'
        }
    }
    
    Context "Parallel Processing Logic" {
        
        It "Should detect PowerShell version for parallel processing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'PSVersionTable\.PSVersion\.Major'
        }
        
        It "Should disable parallel on PowerShell < 7" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$PSVersionTable\.PSVersion\.Major -lt 7'
        }
        
        It "Should use ForEach-Object -Parallel for parallel processing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ForEach-Object -Parallel'
        }
        
        It "Should use ThrottleLimit parameter in parallel processing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '-ThrottleLimit \$ThrottleLimit'
        }
    }
    
    Context "License Classification" {
        
        It "Should define prohibited licenses list" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$prohibitedLicenses = @\('
        }
        
        It "Should include GPL in prohibited licenses" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"GPL"'
        }
        
        It "Should include AGPL in prohibited licenses" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"AGPL"'
        }
        
        It "Should define warning licenses list" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$warningLicenses = @\('
        }
        
        It "Should include MPL in warning licenses" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"MPL"'
        }
    }
    
    Context "Environment Detection" {
        
        It "Should detect Azure Pipelines environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$isAzurePipeline = \[bool\]\$env:BUILD_ARTIFACTSTAGINGDIRECTORY'
        }
        
        It "Should set output path based on environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$isAzurePipeline\)'
        }
    }
    
    Context "Exit Codes" {
        
        It "Should exit with code 1 on prohibited licenses" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Verify script contains exit 1 logic for prohibited licenses
            $scriptContent | Should -Match 'exit 1$'
            # Verify script checks for prohibited licenses before exiting
            $scriptContent | Should -Match 'Prohibited copyleft licenses found'
        }
        
        It "Should exit with code 0 when all licenses approved" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Verify script contains exit 0 for successful completion
            $scriptContent | Should -Match 'exit 0$'
            # Verify exit 0 comes after license checks
            $exitZeroPosition = $scriptContent.IndexOf('exit 0')
            $prohibitedCheckPosition = $scriptContent.IndexOf('Prohibited copyleft licenses')
            $exitZeroPosition | Should -BeGreaterThan $prohibitedCheckPosition
        }
    }
}

