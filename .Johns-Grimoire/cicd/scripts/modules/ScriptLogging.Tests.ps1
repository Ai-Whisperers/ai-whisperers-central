<#
.SYNOPSIS
    Pester tests for ScriptLogging.psm1 module

.DESCRIPTION
    Tests all exported functions from ScriptLogging module:
    - Write-Log function with all severity levels
    - Azure Pipelines integration
    - Unicode detection and output
#>

Describe "ScriptLogging Module" {
    
    BeforeAll {
        $script:here = $PSScriptRoot
        $script:modulePath = Join-Path $script:here "ScriptLogging.psm1"

        Import-Module $script:modulePath -Force
    }
    
    AfterAll {
        Remove-Module ScriptLogging -Force -ErrorAction SilentlyContinue
    }
    
    Context "Module Structure" {
        It "Should import without errors" {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }
        
        It "Should export Write-Log function" {
            $command = Get-Command Write-Log -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ScriptLogging'
        }
    }
    
    Context "Write-Log Function - Basic" {
        It "Should accept Message parameter" {
            { Write-Log "Test message" } | Should -Not -Throw
        }
        
        It "Should accept Level parameter" {
            { Write-Log "Test" -Level INFO } | Should -Not -Throw
        }
        
        It "Should accept all valid levels" {
            { Write-Log "Test INFO" -Level INFO } | Should -Not -Throw
            { Write-Log "Test WARN" -Level WARN } | Should -Not -Throw
            { Write-Log "Test ERROR" -Level ERROR } | Should -Not -Throw
            { Write-Log "Test SUCCESS" -Level SUCCESS } | Should -Not -Throw
            { Write-Log "Test DEBUG" -Level DEBUG } | Should -Not -Throw
        }
        
        It "Should default to INFO level when not specified" {
            { Write-Log "Default level test" } | Should -Not -Throw
        }
        
        It "Should reject invalid level" {
            { Write-Log "Test" -Level "INVALID" } | Should -Throw
        }
    }
    
    Context "Write-Log Function - Output Format" {
        BeforeAll {
            $script:loggingModule = Get-Module ScriptLogging
            $script:originalSupportsUnicode = $script:loggingModule.SessionState.PSVariable.GetValue('SupportsUnicode')
        }

        BeforeEach {
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $false)
        }

        AfterAll {
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $script:originalSupportsUnicode)
        }

        It "Should output message with timestamp" {
            $output = Write-Log "Test" -Level INFO 6>&1
            $output | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'
        }
        
        It "Should output message with level indicator for INFO" {
            $output = Write-Log "Test" -Level INFO 6>&1
            $output | Should -Match '\[INFO\]'
        }
        
        It "Should output message with level indicator for SUCCESS" {
            $output = Write-Log "Test" -Level SUCCESS 6>&1
            $output | Should -Match '\[PASS\]'
        }
        
        It "Should output message with level indicator for WARN" {
            $output = Write-Log "Test" -Level WARN 6>&1
            $output | Should -Match '\[WARN\]'
        }
        
        It "Should output message with level indicator for ERROR" {
            $output = Write-Log "Test" -Level ERROR 6>&1
            $output | Should -Match '\[FAIL\]'
        }
        
        It "Should output message with level indicator for DEBUG" {
            $output = Write-Log "Test" -Level DEBUG 6>&1
            $output | Should -Match '\[DEBUG\]'
        }
        
        It "Should include the actual message text" {
            $output = Write-Log "Custom message here" -Level INFO 6>&1
            $output | Should -Match 'Custom message here'
        }
    }
    
    Context "Write-Log Function - Azure Pipelines Integration" {
        BeforeEach {
            # Save original environment
            $script:originalAgentDir = $env:AGENT_TEMPDIRECTORY
        }
        
        AfterEach {
            # Restore original environment
            $env:AGENT_TEMPDIRECTORY = $script:originalAgentDir
        }
        
        It "Should detect Azure Pipelines environment" {
            $env:AGENT_TEMPDIRECTORY = "C:\temp\agent"
            $output = Write-Log "Test" -Level ERROR *>&1 | Out-String
            $output | Should -Match '##vso\[task\.logissue type=error\]'
        }
        
        It "Should use Azure Pipelines error logging command for ERROR level" {
            $env:AGENT_TEMPDIRECTORY = "C:\temp\agent"
            $output = Write-Log "Error message" -Level ERROR *>&1 | Out-String
            $output | Should -Match '##vso\[task\.logissue type=error\]Error message'
        }
        
        It "Should use Azure Pipelines warning logging command for WARN level" {
            $env:AGENT_TEMPDIRECTORY = "C:\temp\agent"
            $output = Write-Log "Warning message" -Level WARN *>&1 | Out-String
            $output | Should -Match '##vso\[task\.logissue type=warning\]Warning message'
        }
        
        It "Should not use Azure Pipelines commands locally" {
            $env:AGENT_TEMPDIRECTORY = $null
            $output = Write-Log "Test" -Level ERROR *>&1 | Out-String
            $output | Should -Not -Match '##vso\['
        }
    }
    
    Context "Write-Log Function - Empty/Blank Messages" {
        It "Should handle empty string message" {
            { Write-Log "" -Level INFO } | Should -Not -Throw
        }
        
        It "Should handle whitespace-only message" {
            { Write-Log "   " -Level INFO } | Should -Not -Throw
        }
        
        It "Should output blank line for empty message" {
            $output = Write-Log "" -Level INFO 6>&1
            ($null -eq $output -or $output.ToString() -match '^\s*$') | Should -Be $true
        }
    }
    
    Context "Write-Log Function - Special Characters" {
        It "Should handle message with special characters" {
            { Write-Log "Test with 'quotes' and `"double`" quotes" -Level INFO } | Should -Not -Throw
        }
        
        It "Should handle message with line breaks" {
            { Write-Log "Line 1`nLine 2" -Level INFO } | Should -Not -Throw
        }
        
        It "Should handle message with Unicode characters" {
            { Write-Log "Test ✅ ❌ ⚠️" -Level INFO } | Should -Not -Throw
        }
    }
    
    Context "Write-Log Function - Color Output (Verification)" {
        # Note: Actual color output testing is complex in PowerShell
        # These tests verify the function runs without errors when outputting with colors
        
        It "Should output INFO level without errors" {
            { Write-Log "Info test" -Level INFO } | Should -Not -Throw
        }
        
        It "Should output SUCCESS level without errors" {
            { Write-Log "Success test" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should output WARN level without errors" {
            { Write-Log "Warning test" -Level WARN } | Should -Not -Throw
        }
        
        It "Should output ERROR level without errors" {
            { Write-Log "Error test" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should output DEBUG level without errors" {
            { Write-Log "Debug test" -Level DEBUG } | Should -Not -Throw
        }
    }
}

