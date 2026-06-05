<#
.SYNOPSIS
    Pester tests for TestHelpers.psm1 module

.DESCRIPTION
    Test suite covering:
    - New-TestCsprojFile function
    - New-TestDirectoryBuildProps function
    - XML content generation
    - Property hashtable handling
    - File creation validation
#>

$ErrorActionPreference = "Stop"

# Import module under test
$ModulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "modules\TestHelpers.psm1"
Import-Module $ModulePath -Force

Describe "TestHelpers.psm1 Module Tests" {
    
    Context "New-TestCsprojFile - Basic Functionality" {
        
        It "Should create minimal .csproj file" {
            $testPath = Join-Path $TestDrive "test.csproj"
            
            New-TestCsprojFile -Path $testPath
            
            $testPath | Should -Exist
        }
        
        It "Should create valid XML" {
            $testPath = Join-Path $TestDrive "valid.csproj"
            
            New-TestCsprojFile -Path $testPath
            
            { [xml](Get-Content $testPath) } | Should -Not -Throw
        }
        
        It "Should include default TargetFramework net9.0" {
            $testPath = Join-Path $TestDrive "default-fw.csproj"
            
            New-TestCsprojFile -Path $testPath
            
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.TargetFramework | Should -Be "net9.0"
        }
    }
    
    Context "New-TestCsprojFile - Custom Properties" {
        
        It "Should include custom properties in PropertyGroup" {
            $testPath = Join-Path $TestDrive "custom.csproj"
            $props = @{
                PackageId = "Test.Package"
                Version = "1.2.3"
            }
            
            New-TestCsprojFile -Path $testPath -Properties $props
            
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.PackageId | Should -Be "Test.Package"
            $content.Project.PropertyGroup.Version | Should -Be "1.2.3"
        }
        
        It "Should handle multiple custom properties" {
            $testPath = Join-Path $TestDrive "multiple.csproj"
            $props = @{
                PackageId = "My.Test"
                Authors = "Test Author"
                Description = "Test Description"
                Copyright = "Copyright 2024"
            }
            
            New-TestCsprojFile -Path $testPath -Properties $props
            
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.PackageId | Should -Be "My.Test"
            $content.Project.PropertyGroup.Authors | Should -Be "Test Author"
            $content.Project.PropertyGroup.Description | Should -Be "Test Description"
            $content.Project.PropertyGroup.Copyright | Should -Be "Copyright 2024"
        }
        
        It "Should handle empty properties hashtable" {
            $testPath = Join-Path $TestDrive "empty-props.csproj"
            
            New-TestCsprojFile -Path $testPath -Properties @{}
            
            $testPath | Should -Exist
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.TargetFramework | Should -Be "net9.0"
        }
    }
    
    Context "New-TestDirectoryBuildProps - Basic Functionality" {
        
        It "Should create Directory.Build.props file" {
            $testPath = Join-Path $TestDrive "Directory.Build.props"
            
            New-TestDirectoryBuildProps -Path $testPath
            
            $testPath | Should -Exist
        }
        
        It "Should create valid XML" {
            $testPath = Join-Path $TestDrive "Directory.Build.props"
            
            New-TestDirectoryBuildProps -Path $testPath
            
            { [xml](Get-Content $testPath) } | Should -Not -Throw
        }
        
        It "Should have Project root element" {
            $testPath = Join-Path $TestDrive "Directory.Build.props"
            
            New-TestDirectoryBuildProps -Path $testPath
            
            [xml]$content = Get-Content $testPath
            $content.Project | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "New-TestDirectoryBuildProps - Custom Properties" {
        
        It "Should include custom properties" {
            $testPath = Join-Path $TestDrive "custom-props.xml"
            $props = @{
                Company = "Test Company"
                Copyright = "Copyright 2024"
            }
            
            New-TestDirectoryBuildProps -Path $testPath -Properties $props
            
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.Company | Should -Be "Test Company"
            $content.Project.PropertyGroup.Copyright | Should -Be "Copyright 2024"
        }
        
        It "Should handle multiple custom properties" {
            $testPath = Join-Path $TestDrive "multi-props.xml"
            $props = @{
                Company = "Acme Corp"
                Authors = "Development Team"
                PackageLicenseExpression = "MIT"
                RepositoryUrl = "https://github.com/test/repo"
            }
            
            New-TestDirectoryBuildProps -Path $testPath -Properties $props
            
            [xml]$content = Get-Content $testPath
            $content.Project.PropertyGroup.Company | Should -Be "Acme Corp"
            $content.Project.PropertyGroup.Authors | Should -Be "Development Team"
            $content.Project.PropertyGroup.PackageLicenseExpression | Should -Be "MIT"
            $content.Project.PropertyGroup.RepositoryUrl | Should -Be "https://github.com/test/repo"
        }
    }
    
    Context "Module Exports" {
        
        It "Should export New-TestCsprojFile function" {
            $exports = Get-Command -Module TestHelpers
            $exports.Name | Should Contain "New-TestCsprojFile"
        }
        
        It "Should export New-TestDirectoryBuildProps function" {
            $exports = Get-Command -Module TestHelpers
            $exports.Name | Should Contain "New-TestDirectoryBuildProps"
        }
        
        It "Should export exactly two functions" {
            $exports = Get-Command -Module TestHelpers
            $exports.Count | Should -Be 2
        }
    }
    
    Context "Parameter Validation" {
        
        It "New-TestCsprojFile should require Path parameter" {
            { New-TestCsprojFile } | Should -Throw
        }
        
        It "New-TestDirectoryBuildProps should require Path parameter" {
            { New-TestDirectoryBuildProps } | Should -Throw
        }
    }
}

