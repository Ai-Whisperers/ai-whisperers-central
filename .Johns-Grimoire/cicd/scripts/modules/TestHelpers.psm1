<#
.SYNOPSIS
    Test helper functions for unit testing CI/CD scripts

.DESCRIPTION
    Shared module providing test utility functions for creating test files,
    mock data, and common test scenarios used in Pester tests.

.NOTES
    File Name   : TestHelpers.psm1
    Location    : cicd/scripts/modules/
#>

# --- Public Functions ---

function New-TestCsprojFile {
    <#
    .SYNOPSIS
        Creates a test .csproj file for unit testing
    
    .DESCRIPTION
        Generates a minimal .csproj file with specified properties for testing purposes.
        Useful for creating mock project files in Pester tests without needing real projects.
    
    .PARAMETER Path
        Path where the .csproj file should be created
    
    .PARAMETER Properties
        Hashtable of MSBuild properties to include in the PropertyGroup
        (e.g., @{ PackageId = "Test.Package"; Version = "1.0.0" })
    
    .OUTPUTS
        None. Creates a file at the specified path.
    
    .EXAMPLE
        New-TestCsprojFile -Path "$TestDrive/Test.csproj"
        # Creates minimal .csproj targeting net9.0
    
    .EXAMPLE
        $props = @{
            PackageId = "My.Test.Package"
            Version = "1.2.3"
            Authors = "Test Author"
        }
        New-TestCsprojFile -Path "$TestDrive/Test.csproj" -Properties $props
        # Creates .csproj with custom properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{}
    )
    
    $xmlContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
$(foreach ($key in $Properties.Keys) { "    <$key>$($Properties[$key])</$key>`n" })
  </PropertyGroup>
</Project>
"@
    
    Set-Content -Path $Path -Value $xmlContent -Force
}

function New-TestDirectoryBuildProps {
    <#
    .SYNOPSIS
        Creates a test Directory.Build.props file for unit testing
    
    .DESCRIPTION
        Generates a Directory.Build.props file with specified properties for testing purposes.
        Useful for testing MSBuild property inheritance and centralized project configuration.
    
    .PARAMETER Path
        Path where the Directory.Build.props file should be created
    
    .PARAMETER Properties
        Hashtable of MSBuild properties to include in the PropertyGroup
        (e.g., @{ Company = "Test Company"; Copyright = "2024" })
    
    .OUTPUTS
        None. Creates a file at the specified path.
    
    .EXAMPLE
        New-TestDirectoryBuildProps -Path "$TestDrive/Directory.Build.props"
        # Creates minimal Directory.Build.props
    
    .EXAMPLE
        $props = @{
            Company = "Acme Corp"
            Copyright = "Copyright © 2024"
            PackageLicenseExpression = "MIT"
        }
        New-TestDirectoryBuildProps -Path "$TestDrive/Directory.Build.props" -Properties $props
        # Creates Directory.Build.props with shared properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{}
    )
    
    $xmlContent = @"
<Project>
  <PropertyGroup>
$(foreach ($key in $Properties.Keys) { "    <$key>$($Properties[$key])</$key>`n" })
  </PropertyGroup>
</Project>
"@
    
    Set-Content -Path $Path -Value $xmlContent -Force
}

# --- Export Public Functions ---
Export-ModuleMember -Function New-TestCsprojFile, New-TestDirectoryBuildProps

