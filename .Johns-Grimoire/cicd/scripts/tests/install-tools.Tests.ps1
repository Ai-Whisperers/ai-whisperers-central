<#
.SYNOPSIS
    Pester tests for install-tools.ps1

.DESCRIPTION
    Unit tests validating the .NET tool installer script including
    logging functionality, config file loading, and tool installation logic

.NOTES
    File Name      : install-tools.Tests.ps1
    Prerequisite   : Pester 5.x (compatible with Pester 3.x)
    Test Framework : Pester
#>

Describe "install-tools.ps1" -Tag "Unit" {
    
    BeforeEach {
        # Import the script
        $script:scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "install-tools.ps1"
        
        # Create test directory structure
        $script:testRoot = Join-Path $TestDrive "TestRepo"
        $script:configDir = Join-Path $script:testRoot "cicd"
        
        if (-not (Test-Path $script:configDir)) {
            New-Item -Path $script:configDir -ItemType Directory -Force | Out-Null
        }
        
        # Create test config file
        $script:testConfigPath = Join-Path $script:configDir "tool-versions.json"
    }
    
    Context "Write-Log Function" {
        
        BeforeEach {
            $script:loggingModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
            Import-Module $script:loggingModulePath -Force
            $script:loggingModule = Get-Module ScriptLogging
            $script:originalSupportsUnicode = $script:loggingModule.SessionState.PSVariable.GetValue('SupportsUnicode')
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $false)
        }

        AfterEach {
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $script:originalSupportsUnicode)
        }
        
        It "Should log INFO messages with correct prefix" {
            $output = Write-Log "Test message" -Level INFO 6>&1 | Out-String
            $output | Should -Match "\[INFO\]"
            $output | Should -Match "Test message"
        }
        
        It "Should log SUCCESS messages with correct prefix" {
            $output = Write-Log "Test success" -Level SUCCESS 6>&1 | Out-String
            $output | Should -Match "\[PASS\]"
            $output | Should -Match "Test success"
        }
        
        It "Should log WARN messages with correct prefix" {
            $output = Write-Log "Test warning" -Level WARN 6>&1 | Out-String
            $output | Should -Match "\[WARN\]"
            $output | Should -Match "Test warning"
        }
        
        It "Should log ERROR messages with correct prefix" {
            $output = Write-Log "Test error" -Level ERROR 6>&1 | Out-String
            $output | Should -Match "\[FAIL\]"
            $output | Should -Match "Test error"
        }
        
        It "Should include timestamp in log output" {
            $output = Write-Log "Test timestamp" -Level INFO 6>&1 | Out-String
            $output | Should -Match "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        }
        
        It "Should default to INFO level when not specified" {
            $output = Write-Log "Default level" 6>&1 | Out-String
            $output | Should -Match "\[INFO\]"
        }
        
        It "Should validate Level parameter with ValidateSet" {
            { Write-Log "Test" -Level "INVALID" } | Should -Throw
        }
    }
    
    Context "Azure Pipelines Integration" {
        
        BeforeEach {
            # Mock Azure Pipelines environment
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            
            $script:loggingModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
            Import-Module $script:loggingModulePath -Force
            $script:loggingModule = Get-Module ScriptLogging
            $script:originalSupportsUnicode = $script:loggingModule.SessionState.PSVariable.GetValue('SupportsUnicode')
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $false)
        }
        
        AfterEach {
            Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            $script:loggingModule.SessionState.PSVariable.Set('SupportsUnicode', $script:originalSupportsUnicode)
        }
        
        It "Should detect Azure Pipelines environment" {
            $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
            $isAzurePipeline | Should -Be $true
        }
        
        It "Should output Azure Pipelines error logging command" {
            $output = Write-Log "Pipeline error" -Level ERROR 6>&1 | Out-String
            $output | Should -Match "##vso\[task\.logissue type=error\]Pipeline error"
        }
        
        It "Should output Azure Pipelines warning logging command" {
            $output = Write-Log "Pipeline warning" -Level WARN 6>&1 | Out-String
            $output | Should -Match "##vso\[task\.logissue type=warning\]Pipeline warning"
        }
    }
    
    Context "Configuration File Loading" {
        
        It "Should fail when config file does not exist" {
            $nonExistentConfig = Join-Path $script:testRoot "nonexistent.json"
            
            & $script:scriptPath -ConfigFile $nonExistentConfig 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should fail when config file has invalid JSON" {
            $invalidJson = "{ invalid json }"
            Set-Content -Path $script:testConfigPath -Value $invalidJson
            
            { & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 } | Should -Throw
        }
        
        It "Should fail when config file is missing tools property" {
            $invalidConfig = '{ "version": "1.0" }'
            Set-Content -Path $script:testConfigPath -Value $invalidConfig
            
            & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should load valid config file successfully" {
            $validConfig = @'
{
    "tools": {
        "docfx": "2.78.4",
        "dotnet-stryker": "4.3.0"
    }
}
'@
            Set-Content -Path $script:testConfigPath -Value $validConfig
            
            # Mock dotnet tool commands
            Mock dotnet { } -Verifiable
            
            { & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null } | Should -Not -Throw
        }
    }
    
    Context "Tool Selection" {
        
        BeforeEach {
            $validConfig = @'
{
    "tools": {
        "docfx": "2.78.4",
        "dotnet-stryker": "4.3.0",
        "reportgenerator": "5.4.1"
    }
}
'@
            Set-Content -Path $script:testConfigPath -Value $validConfig
        }
        
        It "Should process all tools when no specific tools requested" -Pending {
            # This test requires complex mocking of dotnet tool commands
        }
        
        It "Should process only specified tools when Tools parameter provided" -Pending {
            # This test requires complex mocking of dotnet tool commands
        }
        
        It "Should warn when requested tool not found in config" {
            $output = & $script:scriptPath -ConfigFile $script:testConfigPath -Tools "nonexistent-tool" *>&1 | Out-String
            $output | Should -Match "not found"
        }
        
        It "Should exit with 0 when no tools to process" {
            $emptyConfig = '{ "tools": {} }'
            Set-Content -Path $script:testConfigPath -Value $emptyConfig
            
            & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "Tool Installation Logic" {
        
        BeforeEach {
            $validConfig = @'
{
    "tools": {
        "docfx": "2.78.4"
    }
}
'@
            Set-Content -Path $script:testConfigPath -Value $validConfig
        }
        
        It "Should use pinned version by default" -Pending {
            # Requires mocking dotnet tool install with version parameter
        }
        
        It "Should use latest version when Latest switch provided" -Pending {
            # Requires mocking dotnet tool update without version parameter
        }
        
        It "Should handle tool installation failure gracefully" -Pending {
            # Requires mocking dotnet tool install to throw error
        }
        
        It "Should continue processing after tool installation failure" -Pending {
            # Requires mocking multiple tool installations with one failure
        }
    }
    
    Context "Exit Codes" {
        
        It "Should exit with 0 when successful" {
            $validConfig = '{ "tools": {} }'
            Set-Content -Path $script:testConfigPath -Value $validConfig
            
            & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should exit with 1 when config file not found" {
            $nonExistentConfig = Join-Path $script:testRoot "nonexistent.json"
            
            & $script:scriptPath -ConfigFile $nonExistentConfig 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should exit with 1 when config file is invalid" {
            $invalidConfig = '{ "version": "1.0" }'
            Set-Content -Path $script:testConfigPath -Value $invalidConfig
            
            & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should accept valid Tools parameter as string array" {
            $validConfig = '{ "tools": { "docfx": "2.78.4" } }'
            Set-Content -Path $script:testConfigPath -Value $validConfig
            
            { & $script:scriptPath -ConfigFile $script:testConfigPath -Tools "docfx" 2>&1 | Out-Null } | Should -Not -Throw
        }
        
        It "Should accept Latest switch parameter" {
            $validConfig = '{ "tools": { "docfx": "2.78.4" } }'
            Set-Content -Path $script:testConfigPath -Value $validConfig
            
            { & $script:scriptPath -ConfigFile $script:testConfigPath -Latest 2>&1 | Out-Null } | Should -Not -Throw
        }
        
        It "Should accept ConfigFile parameter" {
            $validConfig = '{ "tools": {} }'
            Set-Content -Path $script:testConfigPath -Value $validConfig
            
            { & $script:scriptPath -ConfigFile $script:testConfigPath 2>&1 | Out-Null } | Should -Not -Throw
        }
        
        It "Should default to tool-versions.json in parent directory" -Pending {
            # This test requires setting up specific directory structure
        }
    }
}

