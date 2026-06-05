<#
.SYNOPSIS
    Validates NuGet package metadata quality and completeness

.DESCRIPTION
    Validates that all source projects have complete and proper NuGet metadata:
    - Checks required fields (PackageId, Version, Authors, Description, etc.)
    - Validates recommended fields (Tags, ReleaseNotes, Icon)
    - Ensures proper licensing information
    - Checks repository and project URLs
    
    Helps ensure high-quality, discoverable NuGet packages.

.PARAMETER Configuration
    Build configuration to validate (Debug or Release). Default: Release

.EXAMPLE
    .\validate-package-metadata.ps1
    
    Validates package metadata for all source projects

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Validate Package Metadata'
      inputs:
        filePath: 'cicd/scripts/validate-package-metadata.ps1'

.NOTES
    File Name      : validate-package-metadata.ps1
    Prerequisite   : .NET SDK, source projects with .csproj files
    Portability    : Works in Azure Pipelines and locally
    
.LINK
    https://docs.microsoft.com/nuget/create-packages/package-authoring-best-practices
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
    $ErrorActionPreference = "Stop"

    # Import shared module for structured logging
    $ModulePath = Join-Path $PSScriptRoot "modules\ScriptLogging.psm1"
    Import-Module $ModulePath -Force
    
    # Import Git utilities module
    $GitUtilitiesPath = Join-Path $PSScriptRoot "modules\GitUtilities.psm1"
    Import-Module $GitUtilitiesPath -Force

    Write-Log "" -Level INFO
    Write-Log "=== Package Metadata Validation ===" -Level INFO
    Write-Log "" -Level INFO
    
    # Enhanced context logging for CI/CD debugging
    $gitContext = Get-GitContext
    Write-Log "" -Level INFO
    Write-Separator -Level INFO
    Write-Log "  CONTEXT ANALYSIS" -Level INFO
    Write-Separator -Level INFO
    Write-Log "Commit:         $($gitContext.CommitSha)" -Level INFO
    Write-Log "Branch:         $($gitContext.Branch)" -Level INFO
    Write-Log "" -Level INFO

    $projectsToProcess = @()
    $hasErrors = $false
    $hasWarnings = $false

    # Required metadata fields
    $requiredFields = @(
        "PackageId",
        "Version",
        "Authors",
        "Description",
        "PackageLicenseExpression",
        "PackageProjectUrl",
        "RepositoryUrl",
        "RepositoryType",
        "Copyright"
    )

    # Recommended fields
    $recommendedFields = @(
        "PackageTags",
        "PackageReleaseNotes",
        "PackageIcon",
        "PackageReadmeFile"
    )
}

process {
    if ($ProjectPaths) {
        $projectsToProcess += $ProjectPaths
    }
}

end {
    # Auto-discover if no input provided
    if ($projectsToProcess.Count -eq 0) {
        $projectsToProcess = Get-ChildItem -Path "src" -Recurse -Filter "*.csproj"
    }

    # Normalize to FileInfo objects
    $projectFiles = @()
    foreach ($p in $projectsToProcess) {
        if ($p -is [string]) {
            if (Test-Path $p) {
                $item = Get-Item $p
                if ($item.Extension -eq ".csproj") {
                    $projectFiles += $item
                }
            }
        } elseif ($p -is [System.IO.FileInfo]) {
            $projectFiles += $p
        }
    }

    if ($projectFiles.Count -eq 0) {
        Write-Log "No projects found" -Level INFO
        exit 0
    }

    Write-Log "Validating $($projectFiles.Count) project(s)..." -Level INFO
    Write-Log "" -Level INFO

    foreach ($project in $projectFiles) {
        $projectName = $project.BaseName
        $isValid = $true
        $errors = @()
        $warnings = @()
        
        Write-Log "Checking: $projectName" -Level INFO
        
        # Load project file
        [xml]$projectXml = Get-Content $project.FullName
        
        # Also check Directory.Build.props for inherited properties
        $dirBuildProps = Join-Path (Split-Path $project.FullName -Parent) "Directory.Build.props"
        $rootDirBuildProps = Join-Path (Get-Location) "Directory.Build.props"
        
        $allProperties = @{}
        
        # Read properties from Directory.Build.props (root)
        if (Test-Path $rootDirBuildProps) {
            [xml]$rootProps = Get-Content $rootDirBuildProps
            $rootProps.Project.PropertyGroup | ForEach-Object {
                $_.ChildNodes | ForEach-Object {
                    if ($_.NodeType -eq "Element") {
                        $allProperties[$_.Name] = $_.InnerText
                    }
                }
            }
        }
        
        # Read properties from project file (overrides)
        $projectXml.Project.PropertyGroup | ForEach-Object {
            $_.ChildNodes | ForEach-Object {
                if ($_.NodeType -eq "Element") {
                    $allProperties[$_.Name] = $_.InnerText
                }
            }
        }
        
        # Check required fields
        $missingRequired = @()
        $emptyRequired = @()
        
        foreach ($field in $requiredFields) {
            if (-not $allProperties.ContainsKey($field)) {
                $missingRequired += $field
            } elseif ([string]::IsNullOrWhiteSpace($allProperties[$field])) {
                $emptyRequired += $field
            } else {
                Write-Log "  $field : $($allProperties[$field])" -Level SUCCESS
            }
        }
        
        # Check recommended fields
        $missingRecommended = @()
        
        foreach ($field in $recommendedFields) {
            if (-not $allProperties.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($allProperties[$field])) {
                $missingRecommended += $field
            } else {
                Write-Log "  $field : $($allProperties[$field])" -Level SUCCESS
            }
        }
        
        # Validate specific fields
        if ($allProperties.ContainsKey("Description")) {
            $desc = $allProperties["Description"]
            if ($desc.Length -lt 20) {
                Write-Log "  Description too short (< 20 chars)" -Level WARN
                $hasWarnings = $true
                $warnings += "Description too short (< 20 chars)"
            }
        }
        
        if ($allProperties.ContainsKey("PackageLicenseExpression")) {
            $license = $allProperties["PackageLicenseExpression"]
            $validLicenses = @("MIT", "Apache-2.0", "BSD-3-Clause", "BSD-2-Clause", "GPL-3.0", "LGPL-3.0")
            
            if ($license -notin $validLicenses) {
                Write-Log "  Uncommon license: $license" -Level WARN
                $hasWarnings = $true
                $warnings += "Uncommon license: $license"
            }
        }
        
        if ($allProperties.ContainsKey("Version")) {
            $version = $allProperties["Version"]
            # MSBuild property variables like $(VersionPrefix) are valid and resolved at pack time
            $isMSBuildVariable = $version -match '^\$\('
            $isSemanticVersion = $version -match '^\d+\.\d+\.\d+'
            
            if (-not $isMSBuildVariable -and -not $isSemanticVersion) {
                Write-Log "  Version format may be invalid: $version" -Level WARN
                $hasWarnings = $true
                $warnings += "Version format may be invalid: $version"
            }
        }
        
        # Report errors
        if ($missingRequired.Count -gt 0 -or $emptyRequired.Count -gt 0) {
            Write-Log "" -Level INFO
            Write-Log "  REQUIRED FIELDS MISSING/EMPTY:" -Level ERROR
            
            foreach ($field in $missingRequired) {
                Write-Log "    - $field (missing)" -Level ERROR
                $errors += "$field (missing)"
            }
            
            foreach ($field in $emptyRequired) {
                Write-Log "    - $field (empty)" -Level ERROR
                $errors += "$field (empty)"
            }
            
            $hasErrors = $true
            $isValid = $false
        }
        
        # Report warnings
        if ($missingRecommended.Count -gt 0) {
            Write-Log "" -Level INFO
            Write-Log "  RECOMMENDED FIELDS MISSING:" -Level WARN
            
            foreach ($field in $missingRecommended) {
                Write-Log "    - $field" -Level WARN
                $warnings += "$field missing"
            }
            
            $hasWarnings = $true
        }
        
        Write-Log "" -Level INFO
        
        # Output object to pipeline
        [PSCustomObject]@{
            Project = $projectName
            Path = $project.FullName
            Valid = $isValid
            Errors = $errors
            Warnings = $warnings
        }
    }

    Write-Log "" -Level INFO
    Write-Log "Validation Summary:" -Level INFO

    if ($hasErrors) {
        Write-Log "  Errors: Required metadata missing" -Level ERROR
        Write-Log "" -Level INFO
        Write-Host "##vso[task.logissue type=error]Required package metadata is missing or empty!"
        Write-Log "" -Level INFO
        Write-Log "======================================================================" -Level INFO
        Write-Log "  AUTOMATED SOLUTION: Use Cursor AI" -Level INFO
        Write-Log "======================================================================" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Cursor AI can help generate complete package metadata:" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Use prompt:" -Level INFO
        Write-Log "  .cursor/prompts/package/generate-package-metadata.md" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Or tell the AI:" -Level INFO
        Write-Log '  "Add missing NuGet package metadata to Directory.Build.props"' -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Or:" -Level INFO
        Write-Log '  "Generate package metadata following NuGet best practices"' -Level INFO
        Write-Log "" -Level INFO
        Write-Log "The AI will:" -Level INFO
        Write-Log "  - Add all required metadata fields" -Level SUCCESS
        Write-Log "  - Generate meaningful descriptions" -Level SUCCESS
        Write-Log "  - Set appropriate license" -Level SUCCESS
        Write-Log "  - Add repository URLs" -Level SUCCESS
        Write-Log "  - Include recommended tags" -Level SUCCESS
        Write-Log "  - Follow NuGet packaging best practices" -Level SUCCESS
        Write-Log "" -Level INFO
        Write-Log "======================================================================" -Level INFO
        Write-Log "  MANUAL ALTERNATIVE: Add Metadata Manually" -Level INFO
        Write-Log "======================================================================" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Add to Directory.Build.props (project root) or .csproj:" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "<PropertyGroup>" -Level INFO
        Write-Log "  <PackageId>Your.Package.Name</PackageId>" -Level INFO
        Write-Log "  <Authors>Your Name or Company</Authors>" -Level INFO
        Write-Log "  <Description>Comprehensive package description</Description>" -Level INFO
        Write-Log "  <PackageLicenseExpression>MIT</PackageLicenseExpression>" -Level INFO
        Write-Log "  <PackageProjectUrl>https://github.com/org/repo</PackageProjectUrl>" -Level INFO
        Write-Log "  <RepositoryUrl>https://github.com/org/repo</RepositoryUrl>" -Level INFO
        Write-Log "  <RepositoryType>git</RepositoryType>" -Level INFO
        Write-Log "  <Copyright>Copyright Â© Company $(Get-Date -Format yyyy)</Copyright>" -Level INFO
        Write-Log "  " -Level INFO
        Write-Log "  <!-- Recommended -->" -Level INFO
        Write-Log "  <PackageTags>tag1;tag2;tag3</PackageTags>" -Level INFO
        Write-Log "  <PackageReadmeFile>README.md</PackageReadmeFile>" -Level INFO
        Write-Log "  <PackageIcon>icon.png</PackageIcon>" -Level INFO
        Write-Log "</PropertyGroup>" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Common License Options:" -Level INFO
        Write-Log "  - MIT (permissive, popular)" -Level INFO
        Write-Log "  - Apache-2.0 (permissive with patent grant)" -Level INFO
        Write-Log "  - BSD-3-Clause (permissive, simple)" -Level INFO
        Write-Log "  - See: https://choosealicense.com/" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Where to Add:" -Level INFO
        Write-Log "  Option 1: Directory.Build.props (shared across all projects)" -Level INFO
        Write-Log "  Option 2: Individual .csproj files (project-specific)" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Best Practices:" -Level INFO
        Write-Log "  - Description: 50+ characters, clear purpose" -Level INFO
        Write-Log "  - Tags: Relevant keywords for discoverability" -Level INFO
        Write-Log "  - Include README.md in package" -Level INFO
        Write-Log "  - Add package icon (64x64 PNG recommended)" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Documentation:" -Level INFO
        Write-Log "  Project setup: .cursor/rules/setup/project-setup-rule.mdc" -Level INFO
        Write-Log "  NuGet docs: https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices" -Level INFO
        Write-Log "" -Level INFO
        exit 1
    }

    if ($hasWarnings) {
        Write-Log "  Warnings: Some recommended metadata missing" -Level WARN
        Write-Log "" -Level INFO
        Write-Host "##vso[task.logissue type=warning]Consider adding recommended package metadata fields."
        Write-Log "" -Level INFO
        Write-Log "Improve package quality by adding:" -Level INFO
        Write-Log "  - PackageTags - Helps users find your package" -Level INFO
        Write-Log "  - PackageReadmeFile - Shows README on NuGet.org" -Level INFO
        Write-Log "  - PackageIcon - Professional appearance" -Level INFO
        Write-Log "  - PackageReleaseNotes - Link to CHANGELOG.md" -Level INFO
        Write-Log "" -Level INFO
        Write-Log "Ask Cursor AI: 'Add recommended NuGet package metadata'" -Level INFO
        Write-Log "" -Level INFO
    }

    if (-not $hasErrors -and -not $hasWarnings) {
        Write-Log "All metadata valid!" -Level SUCCESS
    }

    Write-Log "" -Level INFO
    
    exit 0
}
