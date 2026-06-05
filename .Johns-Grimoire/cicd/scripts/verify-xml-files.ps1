<#
.SYNOPSIS
    Verifies XML documentation files exist for all source projects

.DESCRIPTION
    Verifies that XML documentation files were generated successfully by:
    - Checking XML files exist in bin output directories
    - Verifying XML files are not empty
    - Providing guidance for fixing generation issues
    
    This is a quick verification step run after build to ensure documentation
    generation is working before detailed validation.

.PARAMETER Configuration
    Build configuration to check (Debug or Release). Default: Release

.EXAMPLE
    .\verify-xml-files.ps1
    
    Verifies XML files exist for Release configuration

.EXAMPLE
    .\verify-xml-files.ps1 -Configuration Debug
    
    Verifies XML files exist for Debug configuration

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Verify XML Files Generated'
      inputs:
        filePath: 'cicd/scripts/verify-xml-files.ps1'
        arguments: '-Configuration $(buildConfiguration)'

.NOTES
    File Name      : verify-xml-files.ps1
    Prerequisite   : .NET SDK, projects must be built first
    Portability    : Works in Azure Pipelines and locally
    
.LINK
    docs/DOCUMENTATION-STANDARDS.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string[]]$ProjectPaths
)

begin {
    # Import shared modules
    $LoggingModulePath = Join-Path $PSScriptRoot "modules\ScriptLogging.psm1"
    Import-Module $LoggingModulePath -Force
    
    $ProjectUtilitiesPath = Join-Path $PSScriptRoot "modules\ProjectUtilities.psm1"
    Import-Module $ProjectUtilitiesPath -Force

    Write-Log "========================================" -Level INFO
    Write-Log "Verifying XML Documentation Files" -Level INFO
    Write-Log "Configuration: $Configuration" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "" -Level INFO

    $projectsToProcess = @()
    $ErrorCount = 0
    $SuccessCount = 0
}

process {
    if ($ProjectPaths) {
        $projectsToProcess += $ProjectPaths
    }
}

end {
    # Get-TargetFramework function now provided by ProjectUtilities module

    # Auto-discover if no input provided
    if ($projectsToProcess.Count -eq 0) {
        $projectsToProcess = Get-ChildItem -Path "src" -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
    }

    # Normalize to FileInfo objects
    $sourceProjects = @()
    foreach ($p in $projectsToProcess) {
        if ($p -is [string]) {
            if (Test-Path $p) {
                $item = Get-Item $p
                if ($item.Extension -eq ".csproj") {
                    $sourceProjects += $item
                }
            }
        } elseif ($p -is [System.IO.FileInfo]) {
            $sourceProjects += $p
        }
    }

    if ($sourceProjects.Count -eq 0) {
        Write-Log "No source projects found" -Level ERROR
        exit 1
    }

    Write-Log "Found $($sourceProjects.Count) source project(s) to verify" -Level INFO
    Write-Log "" -Level INFO

    foreach ($Project in $sourceProjects) {
        $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($Project.Name)
        $ProjectDir = $Project.DirectoryName
        $ProjectPath = $Project.FullName
        
        Write-Log "Checking project: $ProjectName" -Level INFO
        
        # Check for XML file in the bin folder
        $TargetFramework = Get-TargetFramework -ProjectPath $ProjectPath
        $XmlPath = Join-Path $ProjectDir "bin\$Configuration\$TargetFramework\$ProjectName.xml"
        
        $isValid = $false
        $errorMsg = ""
        $fileSizeKB = 0

        if (Test-Path $XmlPath) {
            $FileSize = (Get-Item $XmlPath).Length
            $fileSizeKB = [math]::Round($FileSize / 1024, 2)
            
            if ($FileSize -gt 0) {
                Write-Log "  [PASS] XML file found: $fileSizeKB KB" -Level SUCCESS
                $SuccessCount++
                $isValid = $true
            } else {
                Write-Log "  [FAIL] XML file is EMPTY (0 bytes)" -Level ERROR
                Write-Log "     Path: $XmlPath" -Level WARN
                $ErrorCount++
                $errorMsg = "XML file is EMPTY (0 bytes)"
            }
        } else {
            Write-Log "  [FAIL] XML file NOT FOUND" -Level ERROR
            Write-Log "     Expected path: $XmlPath" -Level WARN
            Write-Log "     Ensure <GenerateDocumentationFile>true</GenerateDocumentationFile> is in the .csproj file" -Level WARN
            $ErrorCount++
            $errorMsg = "XML file NOT FOUND"
        }
        
        # Output object to pipeline
        [PSCustomObject]@{
            Project = $ProjectName
            Path = $ProjectPath
            XmlGenerated = $isValid
            XmlPath = $XmlPath
            XmlSizeKB = $fileSizeKB
            Error = $errorMsg
        }
        
        Write-Log "" -Level INFO
    }

    # Summary
    Write-Log "========================================" -Level INFO
    Write-Log "Verification Summary" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "[PASS] Success: $SuccessCount project(s)" -Level SUCCESS
    
    if ($ErrorCount -gt 0) {
        Write-Log "[FAIL] Errors:  $ErrorCount project(s)" -Level ERROR
    } else {
        Write-Log "[FAIL] Errors:  $ErrorCount project(s)" -Level SUCCESS
    }
    
    Write-Log "" -Level INFO

    if ($ErrorCount -gt 0) {
        Write-Log "[FAIL] XML file verification FAILED" -Level ERROR
        Write-Log "Please ensure all source projects have <GenerateDocumentationFile>true</GenerateDocumentationFile>" -Level WARN
        exit 1
    } else {
        Write-Log "[PASS] All XML documentation files verified successfully!" -Level SUCCESS
        exit 0
    }
}

