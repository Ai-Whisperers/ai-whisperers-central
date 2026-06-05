<#
.SYNOPSIS
    Pester tests for ProjectUtilities.psm1 module

.DESCRIPTION
    Test suite covering:
    - Get-TargetFramework function
    - Single TargetFramework extraction
    - Multiple TargetFrameworks (plural) handling
    - Default fallback behavior
    - Error handling for malformed XML
#>

$ErrorActionPreference = "Stop"

# Import module under test
$ModulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "modules\ProjectUtilities.psm1"
Import-Module $ModulePath -Force

Describe "ProjectUtilities.psm1 Module Tests" {
    
    Context "Get-TargetFramework - Single TargetFramework" {
        
        It "Should extract TargetFramework from project file" {
            $testCsproj = Join-Path $TestDrive "single.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
        
        It "Should extract net8.0 framework" {
            $testCsproj = Join-Path $TestDrive "net8.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net8.0"
        }
    }
    
    Context "Get-TargetFramework - Multiple TargetFrameworks" {
        
        It "Should extract first framework from TargetFrameworks (plural)" {
            $testCsproj = Join-Path $TestDrive "multi.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net8.0;net6.0;net48</TargetFrameworks>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net8.0"
        }
        
        It "Should handle single framework in TargetFrameworks element" {
            $testCsproj = Join-Path $TestDrive "single-in-plural.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net9.0</TargetFrameworks>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
    }
    
    Context "Get-TargetFramework - Default Behavior" {
        
        It "Should return net9.0 when no TargetFramework found" {
            $testCsproj = Join-Path $TestDrive "empty.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
        
        It "Should handle malformed XML gracefully" {
            $testCsproj = Join-Path $TestDrive "malformed.csproj"
            $xml = "Not valid XML at all"
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
        
        It "Should handle missing PropertyGroup element" {
            $testCsproj = Join-Path $TestDrive "no-propgroup.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
    }
    
    Context "Get-TargetFramework - Parameter Validation" {
        
        It "Should require ProjectPath parameter" {
            { Get-TargetFramework } | Should -Throw
        }
        
        It "Should validate that file exists" {
            { Get-TargetFramework -ProjectPath "C:\NonExistent\File.csproj" } | Should -Throw
        }
    }
    
    Context "Module Exports" {
        
        It "Should export Get-TargetFramework function" {
            $exports = Get-Command -Module ProjectUtilities
            ($exports.Name -contains "Get-TargetFramework") | Should -Be $true
        }
        
        It "Should export exactly one function" {
            $exports = Get-Command -Module ProjectUtilities
            $exports.Count | Should -Be 1
        }
    }
}

