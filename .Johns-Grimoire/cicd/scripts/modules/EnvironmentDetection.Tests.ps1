<#
.SYNOPSIS
    Pester tests for EnvironmentDetection.psm1 module

.DESCRIPTION
    Tests all exported functions from EnvironmentDetection module:
    - Test-AzurePipelines
    - Get-DefaultOutputPath
    - Test-PowerShellVersion
    - Get-BuildContext
#>

Describe "EnvironmentDetection Module" {
    
    BeforeAll {
        $script:here = $PSScriptRoot
        $script:modulePath = Join-Path $script:here "EnvironmentDetection.psm1"

        Import-Module $script:modulePath -Force
    }
    
    AfterAll {
        Remove-Module EnvironmentDetection -Force -ErrorAction SilentlyContinue
    }
    
    Context "Module Structure" {
        It "Should import without errors" {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }
        
        It "Should export Test-AzurePipelines function" {
            $command = Get-Command Test-AzurePipelines -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'EnvironmentDetection'
        }
        
        It "Should export Get-DefaultOutputPath function" {
            $command = Get-Command Get-DefaultOutputPath -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'EnvironmentDetection'
        }
        
        It "Should export Test-PowerShellVersion function" {
            $command = Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'EnvironmentDetection'
        }
        
        It "Should export Get-BuildContext function" {
            $command = Get-Command Get-BuildContext -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'EnvironmentDetection'
        }
    }
    
    Context "Test-AzurePipelines Function - Local Environment" {
        BeforeAll {
            # Save original environment
            $script:originalAgentDir = $env:AGENT_TEMPDIRECTORY
            # Clear to simulate local
            $env:AGENT_TEMPDIRECTORY = $null
        }
        
        AfterAll {
            # Restore original environment
            $env:AGENT_TEMPDIRECTORY = $script:originalAgentDir
        }
        
        It "Should return boolean" {
            $result = Test-AzurePipelines
            $result | Should -BeOfType [bool]
        }
        
        It "Should return false when not in Azure Pipelines" {
            $result = Test-AzurePipelines
            $result | Should -Be $false
        }
    }
    
    Context "Test-AzurePipelines Function - CI Environment" {
        BeforeEach {
            # Save original
            $script:originalAgentDir = $env:AGENT_TEMPDIRECTORY
        }
        
        AfterEach {
            # Restore original
            $env:AGENT_TEMPDIRECTORY = $script:originalAgentDir
        }
        
        It "Should return true when AGENT_TEMPDIRECTORY is set" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $result = Test-AzurePipelines
            $result | Should -Be $true
        }
        
        It "Should return true for any non-null AGENT_TEMPDIRECTORY" {
            $env:AGENT_TEMPDIRECTORY = "test"
            $result = Test-AzurePipelines
            $result | Should -Be $true
        }
    }
    
    Context "Get-DefaultOutputPath Function - Local Environment" {
        BeforeAll {
            # Save and clear for local simulation
            $script:originalAgentDir = $env:AGENT_TEMPDIRECTORY
            $script:originalStagingDir = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
            $env:AGENT_TEMPDIRECTORY = $null
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $null
        }
        
        AfterAll {
            # Restore
            $env:AGENT_TEMPDIRECTORY = $script:originalAgentDir
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $script:originalStagingDir
        }
        
        It "Should return a valid path" {
            $result = Get-DefaultOutputPath
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return path that exists or can be created" {
            $result = Get-DefaultOutputPath -SubPath "test"
            Test-Path -IsValid $result | Should -Be $true
        }
        
        It "Should use TEMP directory locally" {
            $result = Get-DefaultOutputPath
            $result | Should -Match ($env:TEMP -replace '\\', '\\')
        }
        
        It "Should append SubPath when provided" {
            $result = Get-DefaultOutputPath -SubPath "my-reports"
            $result | Should -Match "my-reports"
        }
    }
    
    Context "Get-DefaultOutputPath Function - CI Environment" {
        BeforeEach {
            # Save original
            $script:originalAgentDir = $env:AGENT_TEMPDIRECTORY
            $script:originalStagingDir = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
        }
        
        AfterEach {
            # Restore
            $env:AGENT_TEMPDIRECTORY = $script:originalAgentDir
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $script:originalStagingDir
        }
        
        It "Should use BUILD_ARTIFACTSTAGINGDIRECTORY in CI" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\staging"
            
            $result = Get-DefaultOutputPath
            $result | Should -Match "C:\\agent\\staging"
        }
        
        It "Should append SubPath in CI" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\staging"
            
            $result = Get-DefaultOutputPath -SubPath "coverage"
            $result | Should -Match "coverage"
        }
    }
    
    Context "Test-PowerShellVersion Function" {
        It "Should return boolean" {
            $result = Test-PowerShellVersion -MinVersion "5.1"
            $result | Should -BeOfType [bool]
        }
        
        It "Should validate current version against 5.1" {
            $result = Test-PowerShellVersion -MinVersion "5.1"
            # Current PowerShell should be >= 5.1
            $result | Should -Be $true
        }
        
        It "Should return false for impossibly high version" {
            $result = Test-PowerShellVersion -MinVersion "99.0"
            $result | Should -Be $false
        }
        
        It "Should handle version with major only" {
            { Test-PowerShellVersion -MinVersion "5" } | Should -Not -Throw
        }
        
        It "Should handle version with major.minor" {
            { Test-PowerShellVersion -MinVersion "5.1" } | Should -Not -Throw
        }
        
        It "Should handle version with major.minor.patch" {
            { Test-PowerShellVersion -MinVersion "5.1.0" } | Should -Not -Throw
        }
    }
    
    Context "Get-BuildContext Function - Local Environment" {
        BeforeAll {
            # Save and clear for local simulation
            $script:originalEnv = @{
                AGENT_TEMPDIRECTORY = $env:AGENT_TEMPDIRECTORY
                BUILD_BUILDNUMBER = $env:BUILD_BUILDNUMBER
                BUILD_SOURCEBRANCH = $env:BUILD_SOURCEBRANCH
                BUILD_SOURCEVERSION = $env:BUILD_SOURCEVERSION
            }
            
            $env:AGENT_TEMPDIRECTORY = $null
            $env:BUILD_BUILDNUMBER = $null
            $env:BUILD_SOURCEBRANCH = $null
            $env:BUILD_SOURCEVERSION = $null
        }
        
        AfterAll {
            # Restore
            $env:AGENT_TEMPDIRECTORY = $script:originalEnv.AGENT_TEMPDIRECTORY
            $env:BUILD_BUILDNUMBER = $script:originalEnv.BUILD_BUILDNUMBER
            $env:BUILD_SOURCEBRANCH = $script:originalEnv.BUILD_SOURCEBRANCH
            $env:BUILD_SOURCEVERSION = $script:originalEnv.BUILD_SOURCEVERSION
        }
        
        It "Should return hashtable" {
            $result = Get-BuildContext
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should include IsCI property" {
            $result = Get-BuildContext
            $result.ContainsKey('IsCI') | Should -Be $true
        }
        
        It "Should set IsCI to false locally" {
            $result = Get-BuildContext
            $result.IsCI | Should -Be $false
        }
        
        It "Should include BuildNumber property" {
            $result = Get-BuildContext
            $result.ContainsKey('BuildNumber') | Should -Be $true
        }
        
        It "Should include Branch property" {
            $result = Get-BuildContext
            $result.ContainsKey('Branch') | Should -Be $true
        }
        
        It "Should include Commit property" {
            $result = Get-BuildContext
            $result.ContainsKey('Commit') | Should -Be $true
        }
        
        It "Should use git fallback for Branch locally" {
            $result = Get-BuildContext
            # Should have some value (either git branch or fallback)
            $result.Branch | Should -Not -BeNullOrEmpty
        }
        
        It "Should use git fallback for Commit locally" {
            $result = Get-BuildContext
            # Should have some value (either git commit or fallback)
            $result.Commit | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-BuildContext Function - CI Environment" {
        BeforeEach {
            # Save original
            $script:originalEnv = @{
                AGENT_TEMPDIRECTORY = $env:AGENT_TEMPDIRECTORY
                BUILD_BUILDNUMBER = $env:BUILD_BUILDNUMBER
                BUILD_SOURCEBRANCH = $env:BUILD_SOURCEBRANCH
                BUILD_SOURCEVERSION = $env:BUILD_SOURCEVERSION
            }
            
            # Set CI environment
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_BUILDNUMBER = "20251207.1"
            $env:BUILD_SOURCEBRANCH = "refs/heads/main"
            $env:BUILD_SOURCEVERSION = "abc123def456"
        }
        
        AfterEach {
            # Restore
            $env:AGENT_TEMPDIRECTORY = $script:originalEnv.AGENT_TEMPDIRECTORY
            $env:BUILD_BUILDNUMBER = $script:originalEnv.BUILD_BUILDNUMBER
            $env:BUILD_SOURCEBRANCH = $script:originalEnv.BUILD_SOURCEBRANCH
            $env:BUILD_SOURCEVERSION = $script:originalEnv.BUILD_SOURCEVERSION
        }
        
        It "Should set IsCI to true in CI" {
            $result = Get-BuildContext
            $result.IsCI | Should -Be $true
        }
        
        It "Should use BUILD_BUILDNUMBER in CI" {
            $result = Get-BuildContext
            $result.BuildNumber | Should -Be "20251207.1"
        }
        
        It "Should use BUILD_SOURCEBRANCH in CI" {
            $result = Get-BuildContext
            $result.Branch | Should -Be "refs/heads/main"
        }
        
        It "Should use BUILD_SOURCEVERSION in CI" {
            $result = Get-BuildContext
            $result.Commit | Should -Be "abc123def456"
        }
    }
    
    Context "Integration - Environment Detection Flow" {
        It "Should detect local environment correctly" {
            # Clear CI variables
            $originalAgent = $env:AGENT_TEMPDIRECTORY
            $env:AGENT_TEMPDIRECTORY = $null
            
            $isCI = Test-AzurePipelines
            $context = Get-BuildContext
            $path = Get-DefaultOutputPath
            
            $isCI | Should -Be $false
            $context.IsCI | Should -Be $false
            $path | Should -Not -BeNullOrEmpty
            
            # Restore
            $env:AGENT_TEMPDIRECTORY = $originalAgent
        }
        
        It "Should detect CI environment correctly" {
            # Set CI variables
            $originalAgent = $env:AGENT_TEMPDIRECTORY
            $originalStaging = $env:BUILD_ARTIFACTSTAGINGDIRECTORY
            
            $env:AGENT_TEMPDIRECTORY = "C:\agent"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\staging"
            
            $isCI = Test-AzurePipelines
            $context = Get-BuildContext
            $path = Get-DefaultOutputPath
            
            $isCI | Should -Be $true
            $context.IsCI | Should -Be $true
            $path | Should -Match "C:\\staging"
            
            # Restore
            $env:AGENT_TEMPDIRECTORY = $originalAgent
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = $originalStaging
        }
    }
}

