<#
.SYNOPSIS
    Meta-tests for validate-documentation.Tests.ps1

.DESCRIPTION
    Tests that validate the test logic in validate-documentation.Tests.ps1:
    - Test coverage completeness
    - Test structure quality
    - Module imports
    - Test helper availability
#>

$ErrorActionPreference = "Stop"

# Get the test file we're meta-testing
$targetTestFile = Join-Path $PSScriptRoot "validate-documentation.Tests.ps1"

Describe "validate-documentation.Tests.ps1 Meta-Tests" {
    
    Context "Test File Exists and Is Valid" {
        
        It "Target test file should exist" {
            Test-Path $targetTestFile | Should -Be $true
        }
        
        It "Target test file should be syntactically valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $targetTestFile -Raw),
                [ref]$errors
            )
            
            $errors.Count | Should -Be 0
        }
        
        It "Target test file should import ScriptLogging module" {
            $content = Get-Content $targetTestFile -Raw
            $content | Should -Match 'ScriptLogging\.psm1'
        }
        
        It "Target test file should import ProjectUtilities module" {
            $content = Get-Content $targetTestFile -Raw
            $content | Should -Match 'ProjectUtilities\.psm1'
        }
    }
    
    Context "Test Coverage Analysis" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should test Write-Log function" {
            $content | Should -Match 'Write-Log Function'
        }
        
        It "Should test Azure Pipelines integration" {
            $content | Should -Match 'Azure Pipelines Integration'
        }
        
        It "Should test Get-TargetFramework function" {
            $content | Should -Match 'Get-TargetFramework Function'
        }
        
        It "Should test parameter validation" {
            $content | Should -Match 'Parameter Validation'
        }
        
        It "Should test exit codes" {
            $content | Should -Match 'Exit Codes'
        }
    }
    
    Context "Environment Simulation Tests" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should simulate Azure Pipelines environment" {
            # Tests should set AGENT_TEMPDIRECTORY to simulate CI
            $content | Should -Match 'AGENT_TEMPDIRECTORY'
        }
        
        It "Should save original environment state" {
            $content | Should -Match 'originalAgentTemp'
        }
    }
    
    Context "Test Data Validation" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should create temporary files for testing" {
            $content | Should -Match 'New-TemporaryFile'
        }
        
        It "Should clean up temporary files" {
            $content | Should -Match 'Remove-Item'
        }
        
        It "Should test with net9.0 TargetFramework" {
            $content | Should -Match 'net9\.0'
        }
    }
    
    Context "Test Assertion Quality" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should use Should -Be assertions" {
            $content | Should -Match 'Should -Be'
        }
        
        It "Should use Should -Match assertions" {
            $content | Should -Match 'Should -Match'
        }
        
        It "Should use Should -Exist assertions" {
            $content | Should -Match 'Should -Exist'
        }
        
        It "Should use Should -Not -Throw assertions" {
            $content | Should -Match 'Should -Not -Throw'
        }
        
        It "Should use Should -Throw assertions" {
            $content | Should -Match 'Should -Throw'
        }
    }
    
    Context "Module Import Validation" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should use PSScriptRoot for relative paths" {
            $content | Should -Match 'PSScriptRoot'
        }
        
        It "Should use Split-Path for parent directory" {
            $content | Should -Match 'Split-Path.*-Parent'
        }
        
        It "Should import modules with -Force flag" {
            $content | Should -Match 'Import-Module.*-Force'
        }
    }
}

Describe "validate-documentation.Tests.ps1 Test Execution" {
    
    Context "Test Helper Functions Work" {
        
        # Import the modules that the tests use
        $LoggingModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
        Import-Module $LoggingModulePath -Force
        
        $ProjectUtilitiesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ProjectUtilities.psm1"
        Import-Module $ProjectUtilitiesPath -Force
        
        It "Write-Log function should be available" {
            Get-Command Write-Log -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Get-TargetFramework function should be available" {
            Get-Command Get-TargetFramework -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Write-Log should handle INFO level" {
            { Write-Log "Test INFO" -Level INFO } | Should -Not -Throw
        }
        
        It "Write-Log should handle SUCCESS level" {
            { Write-Log "Test SUCCESS" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Write-Log should handle WARN level" {
            { Write-Log "Test WARN" -Level WARN } | Should -Not -Throw
        }
        
        It "Write-Log should handle ERROR level" {
            { Write-Log "Test ERROR" -Level ERROR } | Should -Not -Throw
        }
        
        It "Write-Log should handle DEBUG level" {
            { Write-Log "Test DEBUG" -Level DEBUG } | Should -Not -Throw
        }
    }
}

Describe "validate-documentation.Tests.ps1 Best Practices Compliance" {
    
    Context "Test Documentation" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should have file-level synopsis" {
            $content | Should -Match '\.SYNOPSIS'
        }
        
        It "Should have file-level description" {
            $content | Should -Match '\.DESCRIPTION'
        }
        
        It "Should document what is being tested" {
            $content | Should -Match 'Write-Log function'
        }
    }
    
    Context "Test Organization" {
        
        $content = Get-Content $targetTestFile -Raw
        
        It "Should have Describe blocks" {
            $content | Should -Match 'Describe'
        }
        
        It "Should have Context blocks" {
            $content | Should -Match 'Context'
        }
        
        It "Should have It blocks" {
            $content | Should -Match '^\s*It\s+'
        }
    }
}
