<#
.SYNOPSIS
    Detects breaking API changes between current code and baseline version

.DESCRIPTION
    Compares public API surface between current assemblies and a baseline version:
    - Detects added, removed, or changed public members
    - Analyzes method signature changes
    - Identifies breaking vs non-breaking changes
    - Generates compatibility report
    
    Uses last release tag as baseline if not specified.
    
    Supports JSON configuration file for managing multiple parameters.
    Parameter precedence: CLI > Config File > Defaults

.PARAMETER ConfigFile
    Path to JSON configuration file. Default: check-breaking-changes.config.json
    Config file can specify: Configuration, BaselineTag, OutputPath, DisableParallel, ThrottleLimit

.PARAMETER Configuration
    Build configuration to analyze (Debug or Release). Default: Release

.PARAMETER BaselineTag
    Git tag to use as baseline for comparison. If empty, uses last release-* tag

.PARAMETER OutputPath
    Directory to write compatibility reports.
    Default: Azure Pipelines staging directory or local directory

.PARAMETER DisableParallel
    Disable parallel processing (forces sequential analysis)

.PARAMETER ThrottleLimit
    Maximum concurrent threads for parallel processing. Default: NUMBER_OF_PROCESSORS

.EXAMPLE
    .\check-breaking-changes.ps1
    
    Compares current code against last release tag with default config

.EXAMPLE
    .\check-breaking-changes.ps1 -BaselineTag "release-1.2.0"
    
    Compares current code against specific version

.EXAMPLE
    .\check-breaking-changes.ps1 -ConfigFile "custom-config.json"
    
    Uses custom configuration file for all parameters

.EXAMPLE
    .\check-breaking-changes.ps1 -ConfigFile "my-config.json" -Configuration "Debug"
    
    Uses config file but overrides Configuration parameter with CLI value

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Check Breaking Changes'
      inputs:
        filePath: 'cicd/scripts/check-breaking-changes.ps1'

.NOTES
    File Name      : check-breaking-changes.ps1
    Prerequisite   : .NET SDK, git, Microsoft.DotNet.ApiCompat
    Portability    : Works in Azure Pipelines and locally
    Quality Level  : Standard (config file, structured logging, unit tests)
    
.LINK
    https://docs.microsoft.com/dotnet/core/compatibility/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Path to JSON configuration file")]
    [string]$ConfigFile,
    
    [Parameter(Mandatory=$false, HelpMessage="Build configuration (Debug or Release)")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "",
    
    [Parameter(Mandatory=$false, HelpMessage="Baseline git tag for comparison")]
    [string]$BaselineTag = "",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for compatibility reports")]
    [string]$OutputPath = "",

    [Parameter(Mandatory=$false, HelpMessage="Disable parallel processing")]
    [switch]$DisableParallel,

    [Parameter(Mandatory=$false, HelpMessage="Maximum number of concurrent threads")]
    [int]$ThrottleLimit = 0
)

$ErrorActionPreference = "Stop"

# Determine config file path with CI/CD and local support
if (-not $ConfigFile) {
    if ($env:BUILD_SOURCESDIRECTORY) {
        # Running in Azure Pipelines - use BUILD_SOURCESDIRECTORY
        $ConfigFile = Join-Path $env:BUILD_SOURCESDIRECTORY "cicd/scripts/check-breaking-changes.config.json"
    } else {
        # Running locally - use script-relative path
        $ConfigFile = Join-Path $PSScriptRoot "check-breaking-changes.config.json"
    }
}

# Import shared modules
Import-Module "$PSScriptRoot/modules/ScriptLogging.psm1" -Force
Import-Module "$PSScriptRoot/modules/ConfigurationLoader.psm1" -Force
Import-Module "$PSScriptRoot/modules/EnvironmentDetection.psm1" -Force

#region Load Configuration File
$config = Import-ScriptConfiguration -ConfigFile $ConfigFile

if ($config) {
    Write-Log "Loaded configuration from: $ConfigFile" -Level SUCCESS
    
    # Define parameter mapping
    $paramMap = @{
        'Configuration' = 'Configuration'
        'BaselineTag' = 'BaselineTag'
        'OutputPath' = 'OutputPath'
        'DisableParallel' = 'DisableParallel'
        'ThrottleLimit' = 'ThrottleLimit'
    }
    
    # Merge configuration with CLI parameters (CLI takes precedence)
    $appliedValues = Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParameters -ParameterMap $paramMap
    foreach ($entry in $appliedValues.GetEnumerator()) {
        Set-Variable -Name $entry.Key -Value $entry.Value -Scope Script
    }
}

# Apply final defaults if still not set
if ([string]::IsNullOrEmpty($Configuration)) {
    $Configuration = "Release"
}

if ($ThrottleLimit -eq 0) {
    $ThrottleLimit = if ($env:NUMBER_OF_PROCESSORS) { [int]$env:NUMBER_OF_PROCESSORS } else { 4 }
}
#endregion

# Auto-disable parallel on PowerShell < 7
if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $DisableParallel) {
    Write-Log "PowerShell < 7 detected. Disabling parallel processing." -Level INFO
    $DisableParallel = $true
}

# Set default OutputPath if not provided (using shared module)
if ([string]::IsNullOrEmpty($OutputPath)) {
    if (Test-AzurePipelines) {
        $OutputPath = Get-DefaultOutputPath -SubPath "api-compat"
    } else {
        $OutputPath = Join-Path $PWD "api-compat"
    }
}

Write-Log ""
Write-Log "=== Breaking Change Detection ===" -Level INFO
Write-Log ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

# Find all library projects (exclude test projects)
$projectFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.csproj"

if ($projectFiles.Count -eq 0) {
    Write-Log "No projects found in src/ directory" -Level INFO
    exit 0
}

Write-Log "Found $($projectFiles.Count) project(s) to analyze" -Level INFO
Write-Log ""

# Get baseline tag if not provided
if (-not $BaselineTag) {
    Write-Log "Finding last release tag..." -Level INFO
    $tags = git tag -l "release-*" --sort=-version:refname
    
    if (-not $tags -or $tags.Length -eq 0) {
        Write-Log "No baseline release tag found. Skipping breaking change detection." -Level WARN
        Write-Log "   This is expected for first release." -Level INFO
        Write-Log ""
        exit 0
    }
    
    # Get first tag (most recent)
    if ($tags -is [array]) {
        $BaselineTag = $tags[0]
    } else {
        $BaselineTag = $tags
    }
    
    # Validate tag format
    if ($BaselineTag -notmatch '^release-\d+\.\d+\.\d+') {
        Write-Log "Invalid baseline tag format: $BaselineTag" -Level ERROR
        Write-Log "Expected format: release-X.Y.Z or release-X.Y.Z-rcN" -Level WARN
        Write-Log ""
        Write-Log "Available tags:" -Level WARN
        $tags | ForEach-Object { Write-Log "  $_" -Level INFO }
        exit 1
    }
    
    Write-Log "Using baseline: $BaselineTag" -Level INFO
    Write-Log ""
}

# Create temporary directory for baseline
$tempDir = Join-Path $env:TEMP "api-baseline-$(Get-Random)"

try {
    # Use git worktree to checkout baseline tag (works in CI/CD and locally)
    Write-Log "Checking out baseline: $BaselineTag..." -Level INFO
    
    # Temporarily allow git stderr output (informational messages)
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    git worktree add $tempDir $BaselineTag 2>&1 | Out-Null
    $worktreeExitCode = $LASTEXITCODE
    
    $ErrorActionPreference = $previousErrorAction
    
    if ($worktreeExitCode -ne 0) {
        Write-Log "Failed to checkout baseline tag: $BaselineTag" -Level ERROR
        Write-Log "Available release tags:" -Level WARN
        git tag -l "release-*" --sort=-version:refname | ForEach-Object { Write-Log "  $_" -Level INFO }
        exit 1
    }
    
    # Build baseline assemblies
    Write-Log "Building baseline assemblies..." -Level INFO
    Push-Location $tempDir
    
    # Temporarily allow build output redirection
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    dotnet build --configuration $Configuration --verbosity quiet 2>&1 | Out-Null
    $buildExitCode = $LASTEXITCODE
    
    $ErrorActionPreference = $previousErrorAction
    Pop-Location
    
    if ($buildExitCode -ne 0) {
        Write-Log "Failed to build baseline assemblies" -Level ERROR
        exit 1
    }
    
    # Install API comparison tool
    Write-Log "Installing API compatibility tool..." -Level INFO
    
    # Temporarily allow tool install output redirection
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    # Use central tool installer if available
    $installScript = Join-Path $PSScriptRoot "install-tools.ps1"
    if (Test-Path $installScript) {
        Write-Log "Installing tool via central installer..." -Level INFO
        & $installScript -Tools "Microsoft.DotNet.ApiCompat.Tool"
    } else {
        Write-Log "Installing tool (fallback)..." -Level INFO
        # Install latest version (removes version constraint to support latest SDKs)
        $installOutput = dotnet tool install --global Microsoft.DotNet.ApiCompat.Tool 2>&1
        $toolInstallExitCode = $LASTEXITCODE
        
        if ($toolInstallExitCode -ne 0) {
            # Check if it failed because it's already installed or generic error 1
            $outputString = $installOutput | Out-String
            if ($outputString -match "is already installed" -or $toolInstallExitCode -eq 1) {
                Write-Log "Tool installation returned code $toolInstallExitCode. Proceeding..." -Level WARN
                if (-not [string]::IsNullOrWhiteSpace($outputString)) {
                    Write-Log $outputString -Level INFO
                }
            } else {
                $ErrorActionPreference = $previousErrorAction
                Write-Log "Failed to install API compatibility tool" -Level ERROR
                Write-Log $outputString -Level ERROR
                exit 1
            }
        }
    }
    
    $ErrorActionPreference = $previousErrorAction
    
    # Ensure global tools directory is in PATH
    $globalToolsPath = if ($IsWindows -or $env:OS -match "Windows") {
        Join-Path $env:USERPROFILE ".dotnet\tools"
    } else {
        Join-Path $env:HOME ".dotnet/tools"
    }
    
    if (-not ($env:PATH -split [System.IO.Path]::PathSeparator -contains $globalToolsPath)) {
        Write-Log "Adding global tools directory to PATH: $globalToolsPath" -Level INFO
        $env:PATH = "$globalToolsPath$([System.IO.Path]::PathSeparator)$env:PATH"
    }
    
    # Verify tool is accessible
    $apiCompatPath = Get-Command "apicompat" -ErrorAction SilentlyContinue
    if (-not $apiCompatPath) {
        Write-Log "API compatibility tool not found after installation" -Level ERROR
        Write-Log "Global tools path: $globalToolsPath" -Level WARN
        Write-Log "PATH: $env:PATH" -Level WARN
        Write-Log "" -Level INFO
        Write-Log "Attempting to list installed tools:" -Level WARN
        dotnet tool list --global
        exit 1
    }
    
    Write-Log ""
    Write-Log "Analyzing API compatibility..." -Level INFO
    Write-Log ""
    
    $breakingChanges = @()
    $compatibleChanges = 0
    
    if ($DisableParallel -or $projectFiles.Count -le 1) {
        Write-Log "Processing $($projectFiles.Count) projects sequentially..." -Level INFO
        
        $results = $projectFiles | ForEach-Object {
            $project = $_
            $projectName = $project.BaseName
            $projectDir = $project.Directory.FullName
            
            # Calculate relative path from repo root
            $currentDir = Get-Location
            $relativePath = $projectDir.Substring($currentDir.Path.Length + 1)
            
            # Find current assembly
            $currentAssembly = Get-ChildItem -Path "$relativePath/bin/$Configuration" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } | 
                Select-Object -First 1
            
            if (-not $currentAssembly) {
                # Try finding it without config path
                $currentAssembly = Get-ChildItem -Path "$relativePath/bin" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1
            }

            if (-not $currentAssembly) {
                Write-Log "  $projectName - Assembly not found in $relativePath/bin" -Level WARN
                return $null
            }
            
            # Find baseline assembly
            $baselineAssembly = Get-ChildItem -Path "$tempDir/$relativePath/bin/$Configuration" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1

            if (-not $baselineAssembly) {
                 $baselineAssembly = Get-ChildItem -Path "$tempDir/$relativePath/bin" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                 Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                 Select-Object -First 1
            }
            
            if (-not $baselineAssembly) {
                Write-Log "  $projectName - New project, no baseline" -Level INFO
                return $null
            }
            
            # Run API compatibility check
            Write-Log "  Checking: $projectName..." -Level INFO
            
            # Temporarily allow stderr output
            $previousErrorAction = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            
            # Use 'apicompat' directly and -l/-r syntax
            $output = apicompat -l $baselineAssembly.FullName -r $currentAssembly.FullName 2>&1
            $exitCode = $LASTEXITCODE
            
            $ErrorActionPreference = $previousErrorAction
            
            if ($exitCode -ne 0) {
                Write-Log "    Breaking changes detected" -Level ERROR
                return @{
                    Project = $projectName
                    Status = "Fail"
                    Details = $output
                }
            } else {
                Write-Log "    Compatible" -Level SUCCESS
                return @{
                    Project = $projectName
                    Status = "Success"
                }
            }
        }
    } else {
        Write-Log "Processing $($projectFiles.Count) projects in parallel (Throttle: $ThrottleLimit)..." -Level INFO
        
        # Thread-safe progress tracking
        $progress = [Hashtable]::Synchronized(@{ Completed = 0 })
        $total = $projectFiles.Count
        
        $results = $projectFiles | ForEach-Object -Parallel {
            $project = $_
            $projectName = $project.BaseName
            $config = $using:Configuration
            $temp = $using:tempDir
            $syncProgress = $using:progress
            $syncTotal = $using:total
            $projectDir = $project.Directory.FullName
            
            # Calculate relative path
            $workingDir = $using:PWD
            $relativePath = $projectDir.Substring($workingDir.Path.Length + 1)
            
            # Find current assembly
            $currentAssembly = Get-ChildItem -Path "$relativePath/bin/$config" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1
            
            if (-not $currentAssembly) {
                $currentAssembly = Get-ChildItem -Path "$relativePath/bin" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1
            }
            
            if (-not $currentAssembly) {
                # Note: Can't use Write-Log in parallel block, use Write-Host with formatted output
                Write-Host "[WARN] $projectName - Assembly not found in $relativePath/bin"
                return $null
            }
            
            # Find baseline assembly
            $baselineAssembly = Get-ChildItem -Path "$temp/$relativePath/bin/$config" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1
            
            if (-not $baselineAssembly) {
                 $baselineAssembly = Get-ChildItem -Path "$temp/$relativePath/bin" -Recurse -Filter "$projectName.dll" -ErrorAction SilentlyContinue | 
                Where-Object { $_.FullName -notmatch "ref" -and $_.FullName -notmatch "refint" } |
                Select-Object -First 1
            }
            
            if (-not $baselineAssembly) {
                Write-Host "[INFO] $projectName - New project, no baseline"
                return $null
            }
            
            # Run API compatibility check
            $output = apicompat -l $baselineAssembly.FullName -r $currentAssembly.FullName 2>&1
            $exitCode = $LASTEXITCODE
            
            # Update progress
            $syncProgress.Completed++
            $percent = [math]::Round(($syncProgress.Completed / $syncTotal) * 100)
            Write-Host "[INFO] [$($syncProgress.Completed)/$syncTotal] Processed $projectName - $percent%"
            
            if ($exitCode -ne 0) {
                return @{
                    Project = $projectName
                    Status = "Fail"
                    Details = $output
                }
            } else {
                return @{
                    Project = $projectName
                    Status = "Success"
                }
            }
        } -ThrottleLimit $ThrottleLimit
    }
    
    # Aggregate results
    foreach ($res in $results) {
        if ($null -ne $res) {
            if ($res.Status -eq "Fail") {
                $breakingChanges += @{
                    Project = $res.Project
                    Details = $res.Details
                }
                # Re-print failure to ensure visibility in main log
                Write-Log "    $($res.Project) - Breaking changes detected" -Level ERROR
            } elseif ($res.Status -eq "Success") {
                $compatibleChanges++
            }
        }
    }
    
    Write-Log ""
    $resultsLevel = if ($breakingChanges.Count -gt 0) { "WARN" } else { "INFO" }
    $breakingLevel = if ($breakingChanges.Count -gt 0) { "ERROR" } else { "INFO" }
    Write-Log "API Compatibility Results:" -Level $resultsLevel
    Write-Log "  [OK] Compatible: $compatibleChanges" -Level INFO
    Write-Log "  [FAIL] Breaking: $($breakingChanges.Count)" -Level $breakingLevel
    Write-Log ""
    
    # Generate report
    $report = @{
        Baseline = $BaselineTag
        Current = $env:BUILD_SOURCEBRANCHNAME
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Compatible = $compatibleChanges
        Breaking = $breakingChanges.Count
        Details = $breakingChanges
    }
    
    $reportFile = Join-Path $OutputPath "api-compat-report.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content $reportFile
    
    # Show breaking changes
    if ($breakingChanges.Count -gt 0) {
        Write-Log "BREAKING CHANGES DETECTED:" -Level ERROR
        Write-Log ""
        
        foreach ($change in $breakingChanges) {
            Write-Log "Project: $($change.Project)" -Level WARN
            Write-Log $change.Details -Level INFO
            Write-Log ""
        }
        
        Write-Log ""
        Write-Separator -Level INFO
        Write-Log "  REQUIRED ACTIONS: Document Breaking Changes" -Level INFO
        Write-Separator -Level INFO
        Write-Log ""
        Write-Log "Breaking changes MUST be properly documented before release." -Level WARN
        Write-Log ""
        Write-Log "Option 1: Use Cursor AI (Recommended)" -Level WARN
        Write-Log ""
        Write-Log "Use prompt:" -Level INFO
        Write-Log "  .cursor/prompts/breaking-changes/document-breaking-changes.md" -Level DEBUG
        Write-Log ""
        Write-Log "Or tell the AI:" -Level INFO
        Write-Log '  "Document these breaking changes in CHANGELOG.md with migration guide"' -Level DEBUG
        Write-Log ""
        Write-Log "The AI will:" -Level WARN
        Write-Log "  - Analyze the breaking changes" -Level SUCCESS
        Write-Log "  - Add 'Breaking Changes' section to CHANGELOG" -Level SUCCESS
        Write-Log "  - Explain what changed and why" -Level SUCCESS
        Write-Log "  - Provide before/after code examples" -Level SUCCESS
        Write-Log "  - Include migration steps for consumers" -Level SUCCESS
        Write-Log ""
        Write-Log "Option 2: Manual Documentation" -Level WARN
        Write-Log ""
        Write-Log "Add to CHANGELOG.md:" -Level INFO
        Write-Log ""
        Write-Log "  ### Breaking Changes" -Level DEBUG
        Write-Log "  - **API Change Description**: What changed and why" -Level DEBUG
        Write-Log "    - **Before**: ``OldAPI(param)``" -Level DEBUG
        Write-Log "    - **After**: ``NewAPI(param, newParam)``" -Level DEBUG
        Write-Log "    - **Migration**: Step-by-step upgrade guide" -Level DEBUG
        Write-Log "    - **Reason**: Why this change was necessary" -Level DEBUG
        Write-Log ""
        Write-Log "Required Steps:" -Level WARN
        Write-Log "  1. Document breaking changes in CHANGELOG.md" -Level INFO
        Write-Log "  2. Increment MAJOR version (X.0.0)" -Level INFO
        Write-Log "  3. Add migration guide for consumers" -Level INFO
        Write-Log "  4. Update README with upgrade instructions" -Level INFO
        Write-Log "  5. Consider: deprecation period before removal" -Level INFO
        Write-Log ""
        Write-Log "Version Impact:" -Level WARN
        Write-Log "  Current baseline: $BaselineTag" -Level INFO
        Write-Log "  Required action: Increment MAJOR version" -Level INFO
        Write-Log "    Example: 1.5.2 → 2.0.0" -Level DEBUG
        Write-Log ""
        Write-Log "Documentation:" -Level WARN
        Write-Log "  CHANGELOG prompt: .cursor/prompts/changelog/quick-changelog-update.md" -Level INFO
        Write-Log "  Versioning rules: .cursor/rules/cicd/tag-based-versioning-rule.mdc" -Level INFO
        Write-Log ""
        Write-Log "If changes are unintentional:" -Level WARN
        Write-Log "  - Review and revert the breaking changes" -Level INFO
        Write-Log "  - Use [Obsolete] attribute for deprecation instead" -Level INFO
        Write-Log "  - Consider additive changes that maintain compatibility" -Level INFO
        Write-Log ""
        
        exit 1
    } else {
        Write-Log "NO BREAKING CHANGES!" -Level SUCCESS
        Write-Log ""
    }
    
} finally {
    # Cleanup worktree
    if (Test-Path $tempDir) {
        Write-Log "Cleaning up worktree..." -Level INFO
        
        # Temporarily allow git stderr output (informational messages)
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        
        git worktree remove $tempDir --force 2>&1 | Out-Null
        
        $ErrorActionPreference = $previousErrorAction
        
        # Fallback: Remove directory if worktree removal fails
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Log "Report: $reportFile" -Level INFO
Write-Log ""

exit 0