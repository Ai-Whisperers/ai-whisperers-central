<#
.SYNOPSIS
    Validates XML documentation completeness for all source projects

.DESCRIPTION
    Validates that all public APIs have proper XML documentation by:
    - Checking XML documentation files exist
    - Verifying XML files are not empty
    - Detecting CS1591 warnings (missing XML comments)
    - Providing actionable guidance for fixing documentation issues
    
    Supports both Azure Pipelines and local execution.

.PARAMETER Configuration
    Build configuration to validate (Debug or Release). Default: Release

.EXAMPLE
    .\validate-documentation.ps1
    
    Validates documentation with default Release configuration

.EXAMPLE
    .\validate-documentation.ps1 -Configuration Debug
    
    Validates documentation for Debug build

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Validate Documentation'
      inputs:
        filePath: 'cicd/scripts/validate-documentation.ps1'
        arguments: '-Configuration $(buildConfiguration)'

.NOTES
    File Name      : validate-documentation.ps1
    Prerequisite   : .NET SDK, source projects must be built
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

#region Import Shared Modules
# Import shared logging module
$LoggingModulePath = Join-Path $PSScriptRoot "modules\ScriptLogging.psm1"
Import-Module $LoggingModulePath -Force

# Import project utilities module
$ProjectUtilitiesPath = Join-Path $PSScriptRoot "modules\ProjectUtilities.psm1"
Import-Module $ProjectUtilitiesPath -Force

# Import Git utilities module
$GitUtilitiesPath = Join-Path $PSScriptRoot "modules\GitUtilities.psm1"
Import-Module $GitUtilitiesPath -Force
#endregion

# Initialize script
Write-Log "========================================"
Write-Log "Validating Documentation Completeness"
Write-Log "Configuration: $Configuration"
Write-Log "========================================"
Write-Log

# Enhanced context logging for CI/CD debugging
$gitContext = Get-GitContext
Write-Log
Write-Separator -Level INFO
Write-Log "  CONTEXT ANALYSIS" -Level INFO
Write-Separator -Level INFO
Write-Log "Commit:         $($gitContext.CommitSha)" -Level INFO
Write-Log "Branch:         $($gitContext.Branch)" -Level INFO
Write-Log

$ErrorCount = 0
$WarningCount = 0
$SuccessCount = 0

# Handle pipeline input or auto-discover projects
if ($ProjectPaths) {
    $projectsToProcess = $ProjectPaths
} else {
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

    Write-Log "Found $($sourceProjects.Count) source project(s) to validate"
    Write-Log

    foreach ($Project in $sourceProjects) {
        $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($Project.Name)
        $ProjectPath = $Project.FullName
        
        Write-Log "Validating project: $ProjectName"
        Write-Log "  Path: $ProjectPath" -Level DEBUG
        
        # Check if XML file exists
        $ProjectDir = $Project.DirectoryName
        $TargetFramework = Get-TargetFramework -ProjectPath $ProjectPath
        $XmlPath = Join-Path $ProjectDir "bin\$Configuration\$TargetFramework\$ProjectName.xml"
        
        $isValid = $false
        $errors = @()
        $warnings = @()

        if (-not (Test-Path $XmlPath)) {
            Write-Log "  XML documentation file not found!" -Level ERROR
            Write-Log "     Expected: $XmlPath" -Level WARN
            $errors += "XML documentation file not found"
            $ErrorCount++
            Write-Log
        }
        else {
            # Check if XML file has content
            $XmlFileSize = (Get-Item $XmlPath).Length
            if ($XmlFileSize -eq 0) {
                Write-Log "  XML documentation file is EMPTY!" -Level ERROR
                $errors += "XML documentation file is EMPTY"
                $ErrorCount++
                Write-Log
            }
            else {
                $FileSizeKB = [math]::Round($XmlFileSize / 1024, 2)
                Write-Log "  XML file exists ($FileSizeKB KB)"
                
                # Build the project and capture warnings
                Write-Log "  Checking for documentation warnings (CS1591)..."
                
                $BuildOutput = dotnet build $ProjectPath --configuration $Configuration --no-restore 2>&1 | Out-String
                
                # Check for CS1591 warnings (missing XML documentation)
                $CS1591Warnings = $BuildOutput | Select-String -Pattern "warning CS1591:" -AllMatches
                
                if ($CS1591Warnings) {
                    $WarningLines = $CS1591Warnings.Matches.Count
                    Write-Log "  Found $WarningLines documentation warning(s)" -Level WARN
                    
                    # Extract and display specific warnings
                    $BuildOutput -split "`n" | Where-Object { $_ -match "warning CS1591:" } | ForEach-Object {
                        Write-Log "     $_" -Level WARN
                        $warnings += $_.Trim()
                    }
                    
                    $WarningCount += $WarningLines
                    $ErrorCount++
                    $errors += "Found $WarningLines documentation warning(s)"
                } else {
                    Write-Log "  No documentation warnings found" -Level SUCCESS
                    $SuccessCount++
                    $isValid = $true
                }
            }
        }
        
        # Output object to pipeline
        [PSCustomObject]@{
            Project = $ProjectName
            Path = $ProjectPath
            Valid = $isValid
            Errors = $errors
            Warnings = $warnings
        }
        
        Write-Log
    }

    # Summary
    Write-Log "========================================"
    Write-Log "Validation Summary"
    Write-Log "========================================"
    Write-Log "Fully Documented: $SuccessCount project(s)" -Level $(if ($SuccessCount -gt 0) { "SUCCESS" } else { "INFO" })
    Write-Log "Issues Found:     $ErrorCount project(s)" -Level $(if ($ErrorCount -gt 0) { "ERROR" } else { "SUCCESS" })
    Write-Log "Total Warnings:   $WarningCount warning(s)" -Level $(if ($WarningCount -gt 0) { "WARN" } else { "SUCCESS" })
    Write-Log

    if ($ErrorCount -gt 0) {
        Write-Log "Documentation validation FAILED" -Level ERROR
        Write-Log
        Write-Log "Missing XML documentation comments!" -Level ERROR
        Write-Log
        Write-Log "======================================================================"
        Write-Log "  AUTOMATED SOLUTION: Use Cursor AI to Generate Documentation"
        Write-Log "======================================================================"
        Write-Log
        Write-Log "Cursor AI can automatically generate missing XML documentation:" -Level WARN
        Write-Log
        Write-Log "Use prompt:"
        Write-Log "  .cursor/prompts/documentation/generate-missing-docs.md" -Level DEBUG
        Write-Log
        Write-Log "Or tell the AI:"
        Write-Log '  "Generate missing XML documentation for all public APIs"' -Level DEBUG
        Write-Log
        Write-Log "Or be specific:"
        Write-Log '  "Add XML docs to MyClass following our standards"' -Level DEBUG
        Write-Log
        Write-Log "The AI will:" -Level WARN
        Write-Log "  [OK] Analyze your code structure" -Level SUCCESS
        Write-Log "  [OK] Generate comprehensive ``<summary>`` tags" -Level SUCCESS
        Write-Log "  [OK] Document parameters with ``<param>`` tags" -Level SUCCESS
        Write-Log "  [OK] Document return values with ``<returns>`` tags" -Level SUCCESS
        Write-Log "  [OK] Add ``<exception>`` tags for thrown exceptions" -Level SUCCESS
        Write-Log "  [OK] Follow project documentation standards" -Level SUCCESS
        Write-Log
        Write-Log "Documentation Standards:" -Level WARN
        Write-Log "  .cursor/rules/documentation/documentation-standards-rule.mdc"
        Write-Log
        Write-Log "======================================================================"
        Write-Log "  MANUAL ALTERNATIVE: Add Documentation Manually"
        Write-Log "======================================================================"
        Write-Log
        Write-Log "XML Documentation Format:" -Level WARN
        Write-Log
        Write-Log "  /// ``<summary>``" -Level DEBUG
        Write-Log "  /// Brief description of what this does" -Level DEBUG
        Write-Log "  /// ``</summary>``" -Level DEBUG
        Write-Log "  /// ``<param name='paramName'>``Description of parameter``</param>``" -Level DEBUG
        Write-Log "  /// ``<returns>``Description of return value``</returns>``" -Level DEBUG
        Write-Log "  public ReturnType MethodName(ParamType paramName)" -Level DEBUG
        Write-Log
        Write-Log "Quick Steps:" -Level WARN
        Write-Log "  1. Add triple-slash comments (///) above public members"
        Write-Log "  2. Use ``<summary>``, ``<param>``, ``<returns>`` tags"
        Write-Log "  3. Run 'dotnet build' to verify"
        Write-Log "  4. Re-run pipeline to validate"
        Write-Log
        Write-Log "See full documentation standards:" -Level WARN
        Write-Log "  docs/DOCUMENTATION-STANDARDS.md"
        Write-Log
        exit 1
    } else {
        Write-Log "All projects have complete documentation!" -Level SUCCESS
        exit 0
    }

