<#
.SYNOPSIS
    Project utility functions for .NET project analysis

.DESCRIPTION
    Shared module providing utility functions for analyzing .NET project files,
    including target framework detection and project property extraction.

.NOTES
    File Name   : ProjectUtilities.psm1
    Location    : cicd/scripts/modules/
#>

# --- Public Functions ---

function Get-TargetFramework {
    <#
    .SYNOPSIS
        Extracts the target framework from a .NET project file
    
    .DESCRIPTION
        Reads a .csproj file and extracts the TargetFramework or TargetFrameworks property.
        If multiple target frameworks are specified (TargetFrameworks), returns the first one.
        Falls back to "net9.0" if no target framework is found.
    
    .PARAMETER ProjectPath
        Path to the .csproj file to analyze
    
    .OUTPUTS
        [string] Target framework identifier (e.g., "net9.0", "net8.0", "net6.0")
    
    .EXAMPLE
        $framework = Get-TargetFramework -ProjectPath "src/MyProject/MyProject.csproj"
        Write-Host "Project targets: $framework"
        # Output: Project targets: net9.0
    
    .EXAMPLE
        $projectFiles = Get-ChildItem -Recurse -Filter "*.csproj"
        foreach ($project in $projectFiles) {
            $framework = Get-TargetFramework -ProjectPath $project.FullName
            Write-Host "$($project.Name): $framework"
        }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ProjectPath
    )
    
    try {
        [xml]$projectXml = Get-Content $ProjectPath
        $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
        
        if ([string]::IsNullOrEmpty($targetFramework)) {
            # Try TargetFrameworks (plural) and take the first one
            $targetFrameworks = $projectXml.Project.PropertyGroup.TargetFrameworks | Select-Object -First 1
            if (-not [string]::IsNullOrEmpty($targetFrameworks)) {
                $targetFramework = $targetFrameworks.Split(';')[0]
            }
        }
        
        if ([string]::IsNullOrEmpty($targetFramework)) {
            return "net9.0"
        }
        
        return $targetFramework
    }
    catch {
        return "net9.0"
    }
}

# --- Export Public Functions ---
Export-ModuleMember -Function Get-TargetFramework

