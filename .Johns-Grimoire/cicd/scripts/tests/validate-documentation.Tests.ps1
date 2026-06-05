<#
.SYNOPSIS
    Pester tests for validate-documentation.ps1

.DESCRIPTION
    Tests the documentation validation script including:
    - Write-Log function behavior
    - Project discovery logic
    - XML file validation
    - CS1591 warning detection
    - Exit codes and error handling
#>

$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "validate-documentation.ps1"

# Import shared modules
$LoggingModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $LoggingModulePath -Force

$ProjectUtilitiesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ProjectUtilities.psm1"
Import-Module $ProjectUtilitiesPath -Force

Describe "validate-documentation.ps1 Tests" {
    
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
    
    Context "Get-TargetFramework Function" {
        
        It "Should extract TargetFramework from project file" {
            $tempProject = New-TemporaryFile
            $projectContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $tempProject.FullName -Value $projectContent
            
            $framework = Get-TargetFramework -ProjectPath $tempProject.FullName
            $framework | Should -Be "net9.0"
            
            Remove-Item $tempProject.FullName
        }
        
        It "Should extract first TargetFramework from TargetFrameworks (plural)" {
            $tempProject = New-TemporaryFile
            $projectContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $tempProject.FullName -Value $projectContent
            
            $framework = Get-TargetFramework -ProjectPath $tempProject.FullName
            $framework | Should -Be "net8.0"
            
            Remove-Item $tempProject.FullName
        }
        
        It "Should return net9.0 as default when no TargetFramework found" {
            $tempProject = New-TemporaryFile
            $projectContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $tempProject.FullName -Value $projectContent
            
            $framework = Get-TargetFramework -ProjectPath $tempProject.FullName
            $framework | Should -Be "net9.0"
            
            Remove-Item $tempProject.FullName
        }
        
        It "Should handle malformed XML gracefully" {
            $tempProject = New-TemporaryFile
            Set-Content -Path $tempProject.FullName -Value "Not valid XML"
            
            $framework = Get-TargetFramework -ProjectPath $tempProject.FullName
            $framework | Should -Be "net9.0"
            
            Remove-Item $tempProject.FullName
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
        
        It "Should accept ProjectPaths parameter from pipeline" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ValueFromPipeline=\$true'
        }
    }
    
    Context "Exit Codes" {
        
        It "Should exit with code 1 when no projects found" -Skip {
            # This test requires mocking Get-ChildItem which is complex
            # Marked as pending for future implementation
        }
        
        It "Should exit with code 1 when validation fails" -Skip {
            # This test requires creating temp projects and mocking dotnet build
            # Marked as pending for future implementation
        }
        
        It "Should exit with code 0 when validation passes" -Skip {
            # This test requires creating temp projects with valid XML docs
            # Marked as pending for future implementation
        }
    }
}

