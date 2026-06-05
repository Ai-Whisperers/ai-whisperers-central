#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Pre-merge quality validation script - ensures code is ready to merge

.DESCRIPTION
    Automates the complete test-and-validate workflow before merging:
    1. Auto-fix formatting and analyzer issues (70-80% resolution)
    2. Fix specific diagnostic types (CS1591, IDE1006 naming violations)
    3. Build solution with warnings-as-errors
    4. Run all tests to ensure no functionality broke
    5. Validate formatting is clean
    6. Final quality check
    
    This script enforces zero-warnings, zero-errors discipline and ensures
    all tests pass before code can be merged.

.PARAMETER ConfigFile
    Path to configuration file (JSON) with default parameter values. Command-line parameters override config file.

.PARAMETER TargetPath
    Path to the directory or solution file to validate. Default: current directory

.PARAMETER SkipAutoFix
    Skip automatic fixes (dotnet format). Use if you want to see issues first.

.PARAMETER SkipTests
    Skip running tests. Not recommended - tests ensure fixes didn't break functionality.

.PARAMETER Verbose
    Show detailed output from all commands

.EXAMPLE
    .\validate-pre-merge.ps1
    Run complete pre-merge validation with auto-fixes

.EXAMPLE
    .\validate-pre-merge.ps1 -SkipAutoFix
    Check quality without applying auto-fixes (dry-run mode)

.EXAMPLE
    .\validate-pre-merge.ps1 -TargetPath "src/MyProject" -Verbose
    Validate specific project with detailed output

.EXAMPLE
    .\validate-pre-merge.ps1 -EnableAnalyzer CA1062 -TrackProgress
    Enable CA1062 analyzer, validate, and track progress

.EXAMPLE
    .\validate-pre-merge.ps1 -EnableAnalyzer CS1591 -AnalyzerSeverity error
    Enable CS1591 as an error-level analyzer and validate

.EXAMPLE
    .\validate-pre-merge.ps1 -ShowProgress
    Display analyzer enablement progress report

.NOTES
    Result Codes:
    - 0: Success - code is ready to merge
    - 1: Build failed or warnings/errors found
    - 2: Tests failed - functionality broken
    - 3: Format validation failed
    
    Integrated Scripts:
    - enable-analyzer.ps1: Enables specific analyzers by modifying configuration
    - track-analyzer-progress.ps1: Tracks analyzer enablement progress
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Configuration file path (JSON) - command-line params override config")]
    [string]$ConfigFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Target directory or solution file")]
    [string]$TargetPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Skip automatic fixes")]
    [switch]$SkipAutoFix,

    [Parameter(Mandatory = $false, HelpMessage = "Skip running tests (not recommended)")]
    [switch]$SkipTests,

    [Parameter(Mandatory = $false, HelpMessage = "Run specific steps only (e.g., '1,3,5' or '1-3')")]
    [string]$Steps = "1-7",

    [Parameter(Mandatory = $false, HelpMessage = "Filter diagnostics by code (e.g., 'CS1591,IDE1006') - IDE1006 = naming violations")]
    [string]$DiagnosticFilter = "",

    [Parameter(Mandatory = $false, HelpMessage = "Maximum lines of output per section (for AI context limits)")]
    [int]$MaxOutputLines = 50,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum files to report issues for (batch processing)")]
    [int]$MaxFiles = 20,

    [Parameter(Mandatory = $false, HelpMessage = "Dry run - show what would be done without doing it")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Output results in JSON format for AI parsing")]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false, HelpMessage = "Analyzer ID to enable before validation (e.g., CA1062, CS1591)")]
    [ValidatePattern('^[A-Z]{2,4}\d{4}$')]
    [string]$EnableAnalyzer,

    [Parameter(Mandatory = $false, HelpMessage = "Severity level for enabled analyzer: error, warning, suggestion")]
    [ValidateSet('error', 'warning', 'suggestion')]
    [string]$AnalyzerSeverity = 'warning',

    [Parameter(Mandatory = $false, HelpMessage = "Track analyzer progress after validation")]
    [switch]$TrackProgress,

    [Parameter(Mandatory = $false, HelpMessage = "Show analyzer progress report and exit")]
    [switch]$ShowProgress
)

$ErrorActionPreference = 'Continue'
$script:FailureCount = 0
$script:StartTime = Get-Date
$scriptDir = Split-Path $PSCommandPath -Parent

# Import shared helpers (optional but preferred)
$commonModulePath = Join-Path $scriptDir 'modules\Common.psm1'
if (Test-Path $commonModulePath) {
    try {
        Import-Module $commonModulePath -Force -ErrorAction Stop
    } catch {
        # Continue without shared module; this script has local fallbacks.
    }
}

# Handle ShowProgress early - display report and exit
if ($ShowProgress) {
    $trackScript = Join-Path $PSScriptRoot "track-analyzer-progress.ps1"
    if (Test-Path $trackScript) {
        & $trackScript -Report -ReportFormat 'console'
        exit 0
    } else {
        Write-Error "track-analyzer-progress.ps1 not found at: $trackScript"
        exit 1
    }
}

# Load configuration file if specified
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    try {
        $config = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        
        # Apply config values only if parameter was not explicitly provided
        $boundParams = $PSCmdlet.MyInvocation.BoundParameters
        
        if (-not $boundParams.ContainsKey('TargetPath') -and $config.TargetPath) {
            $TargetPath = $config.TargetPath
        }
        if (-not $boundParams.ContainsKey('SkipAutoFix') -and $config.SkipAutoFix) {
            $SkipAutoFix = $config.SkipAutoFix
        }
        if (-not $boundParams.ContainsKey('SkipTests') -and $config.SkipTests) {
            $SkipTests = $config.SkipTests
        }
        if (-not $boundParams.ContainsKey('Steps') -and $config.Steps) {
            $Steps = $config.Steps
        }
        if (-not $boundParams.ContainsKey('DiagnosticFilter') -and $config.DiagnosticFilter) {
            $DiagnosticFilter = $config.DiagnosticFilter
        }
        if (-not $boundParams.ContainsKey('MaxOutputLines') -and $config.MaxOutputLines) {
            $MaxOutputLines = $config.MaxOutputLines
        }
        if (-not $boundParams.ContainsKey('MaxFiles') -and $config.MaxFiles) {
            $MaxFiles = $config.MaxFiles
        }
        if (-not $boundParams.ContainsKey('DryRun') -and $config.DryRun) {
            $DryRun = $config.DryRun
        }
        if (-not $boundParams.ContainsKey('JsonOutput') -and $config.JsonOutput) {
            $JsonOutput = $config.JsonOutput
        }
        
        if (-not $JsonOutput) {
            Write-Host "✅ Configuration loaded from: $ConfigFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to load configuration file '$ConfigFile': $_"
        Write-Warning "Continuing with command-line parameters only"
    }
}
elseif ($ConfigFile) {
    Write-Warning "Configuration file not found: $ConfigFile"
    Write-Warning "Continuing with command-line parameters only"
}

# Emoji helpers
function Get-StatusEmoji {
    param([string]$Status)
    if ($env:CI -eq 'true') {
        return @{
            'success' = '[SUCCESS]'
            'error'   = '[ERROR]'
            'warning' = '[WARN]'
            'info'    = '[INFO]'
            'step'    = '[STEP]'
        }[$Status]
    }
    @{
        'success' = '✅'
        'error'   = '❌'
        'warning' = '⚠️'
        'info'    = 'ℹ️'
        'step'    = '🔹'
    }[$Status]
}

function Write-Step {
    param([string]$Message)
    $step = Get-StatusEmoji 'step'
    Write-Host "`n$step $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'success'
    Write-Host "$emoji $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'error'
    Write-Host "$emoji $Message" -ForegroundColor Red
    $script:FailureCount++
}

function Write-InfoMessage {
    param([string]$Message)
    $emoji = Get-StatusEmoji 'info'
    Write-Host "$emoji $Message" -ForegroundColor Gray
}

# Parse steps parameter (e.g., "1,3,5" or "1-3" or "1-7")
function Get-StepsToRun {
    param([string]$StepsParam)
    
    $steps = @()
    
    # Handle range (e.g., "1-7")
    if ($StepsParam -match '^(\d+)-(\d+)$') {
        $start = [int]$Matches[1]
        $end = [int]$Matches[2]
        $steps = $start..$end
    }
    # Handle comma-separated (e.g., "1,3,5")
    elseif ($StepsParam -match ',') {
        $steps = $StepsParam.Split(',') | ForEach-Object { [int]$_.Trim() }
    }
    # Handle single step (e.g., "3")
    elseif ($StepsParam -match '^\d+$') {
        $steps = @([int]$StepsParam)
    }
    else {
        $steps = 1..7  # Default to all steps
    }
    
    return $steps
}

# Filter build output by diagnostic codes
function Get-FilteredDiagnostics {
    param(
        [string]$BuildOutput,
        [string]$Filter,
        [int]$MaxLines
    )
    
    if ([string]::IsNullOrWhiteSpace($Filter)) {
        # No filter - return first N lines
        $lines = $BuildOutput -split "`n"
        if ($lines.Count -gt $MaxLines) {
            $truncated = $lines[0..($MaxLines-1)] -join "`n"
            return "$truncated`n`n... (truncated, showing first $MaxLines of $($lines.Count) lines)"
        }
        return $BuildOutput
    }
    
    # Filter by diagnostic codes
    $filterCodes = $Filter -split ',' | ForEach-Object { $_.Trim() }
    $pattern = ($filterCodes | ForEach-Object { [regex]::Escape($_) }) -join '|'
    
    $matchedLines = $BuildOutput -split "`n" | Where-Object { $_ -match $pattern }
    
    if ($matchedLines.Count -gt $MaxLines) {
        $truncated = $matchedLines[0..($MaxLines-1)] -join "`n"
        return "$truncated`n`n... (filtered to $Filter, showing first $MaxLines of $($matchedLines.Count) matches)"
    }
    
    return $matchedLines -join "`n"
}

# Truncate file list for batch processing
function Get-TruncatedFileList {
    param(
        [string]$Output,
        [int]$MaxFiles
    )
    
    # Extract file paths from build output
    $filePattern = '(?m)^(.+?\.(cs|csproj|props))(?:\(\d+,\d+\))?:'
    $matches = [regex]::Matches($Output, $filePattern)
    
    $uniqueFiles = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    
    if ($uniqueFiles.Count -le $MaxFiles) {
        return @{
            Output = $Output
            HasMore = $false
            TotalFiles = $uniqueFiles.Count
        }
    }
    
    # Truncate to first MaxFiles
    $filesToShow = $uniqueFiles[0..($MaxFiles-1)]
    $pattern = ($filesToShow | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $filteredLines = $Output -split "`n" | Where-Object { $_ -match $pattern }
    
    return @{
        Output = ($filteredLines -join "`n") + "`n`n... (showing issues in first $MaxFiles of $($uniqueFiles.Count) files)"
        HasMore = $true
        TotalFiles = $uniqueFiles.Count
        RemainingFiles = $uniqueFiles.Count - $MaxFiles
    }
}

# Find solution file
function Get-SolutionFile {
    param([string]$Path)
    
    if (Test-Path $Path -PathType Leaf) {
        if ($Path -like "*.sln") {
            return $Path
        }
        Write-Failure "Specified file is not a solution file"
        return $null
    }
    
    $slnFiles = Get-ChildItem -Path $Path -Filter "*.sln" -File
    if ($slnFiles.Count -eq 0) {
        Write-Failure "No solution file found in $Path"
        return $null
    }
    
    if ($slnFiles.Count -gt 1) {
        Write-InfoMessage "Multiple solution files found, using first: $($slnFiles[0].Name)"
    }
    
    return $slnFiles[0].FullName
}

# Main workflow
$stepsToRun = Get-StepsToRun -StepsParam $Steps
$results = @{
    Steps = @()
    Summary = @{
        TotalSteps = $stepsToRun.Count
        SuccessfulSteps = 0
        FailedSteps = 0
        SkippedSteps = 0
    }
    BuildErrors = @()
    TestResults = $null
    HasMoreFiles = $false
}

if (-not $JsonOutput) {
    Write-Host "`n================================================" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  PRE-MERGE QUALITY VALIDATION (DRY RUN)" -ForegroundColor Yellow
    } else {
        Write-Host "  PRE-MERGE QUALITY VALIDATION" -ForegroundColor Cyan
    }
    Write-Host "================================================`n" -ForegroundColor Cyan
}

$solutionFile = Get-SolutionFile -Path $TargetPath
if (-not $solutionFile) {
    if ($JsonOutput) {
        $results.Summary.Error = "No solution file found"
        Write-Output ($results | ConvertTo-Json -Depth 10)
    }
    exit 1
}

$solutionDir = Split-Path $solutionFile -Parent

if (-not $JsonOutput) {
    Write-InfoMessage "Solution: $solutionFile"
    Write-InfoMessage "Directory: $solutionDir"
    if ($DiagnosticFilter) {
        Write-InfoMessage "Filtering diagnostics: $DiagnosticFilter"
    }
    if ($MaxFiles -lt 999) {
        Write-InfoMessage "Max files to report: $MaxFiles"
    }
    Write-Host ""
}

# Step 0: Enable analyzer if requested (before main workflow)
if ($EnableAnalyzer) {
    if (-not $JsonOutput) {
        Write-Step "Step 0: Enabling analyzer $EnableAnalyzer"
    }
    
    $enableScript = Join-Path $scriptDir "enable-analyzer.ps1"
    if (Test-Path $enableScript) {
        try {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would enable: $EnableAnalyzer (severity: $AnalyzerSeverity)"
                }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: enable-analyzer.ps1..." -ForegroundColor Gray
                }
                & $enableScript -AnalyzerId $EnableAnalyzer -Severity $AnalyzerSeverity -ErrorAction Continue
                
                if ($LASTEXITCODE -eq 0) {
                    if (-not $JsonOutput) {
                        Write-Success "Analyzer $EnableAnalyzer enabled successfully"
                    }
                } else {
                    if (-not $JsonOutput) {
                        Write-Failure "Failed to enable analyzer $EnableAnalyzer"
                    }
                }
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Enable analyzer threw exception: $_"
            }
        }
    } else {
        if (-not $JsonOutput) {
            Write-Failure "enable-analyzer.ps1 not found at: $enableScript"
        }
    }
    
    if (-not $JsonOutput) {
        Write-Host ""
    }
}

# Step 1: Auto-fix formatting and analyzer issues
if ($stepsToRun -contains 1 -and -not $SkipAutoFix -and -not $DryRun) {
    if (-not $JsonOutput) {
        Write-Step "Step 1/7: Auto-fixing formatting and analyzer issues"
    }
    
    $stepResult = @{
        Step = 1
        Name = "AutoFix"
        Status = "Running"
        Actions = @()
    }
    
    if (-not $JsonOutput) {
        Write-Host "  Running: dotnet format..." -ForegroundColor Gray
    }
    try {
        $formatResult = dotnet format $solutionFile 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            if (-not $JsonOutput) {
                Write-Success "Code formatting auto-fixed"
            }
            $stepResult.Actions += @{ Action = "dotnet format"; Status = "Success" }
        } else {
            if (-not $JsonOutput) {
                Write-Failure "Format command failed"
            }
            $stepResult.Actions += @{ Action = "dotnet format"; Status = "Failed"; Error = $formatResult }
        }
    }
    catch {
        if (-not $JsonOutput) {
            Write-Failure "Format command threw exception: $_"
        }
        $stepResult.Actions += @{ Action = "dotnet format"; Status = "Exception"; Error = $_.Exception.Message }
    }
    
    if (-not $JsonOutput) {
        Write-Host "  Running: dotnet format analyzers..." -ForegroundColor Gray
    }
    try {
        $analyzerResult = dotnet format analyzers $solutionFile 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            if (-not $JsonOutput) {
                Write-Success "Analyzer issues auto-fixed"
            }
            $stepResult.Actions += @{ Action = "dotnet format analyzers"; Status = "Success" }
            $stepResult.Status = "Success"
            $results.Summary.SuccessfulSteps++
        } else {
            if (-not $JsonOutput) {
                Write-Failure "Analyzer format failed"
            }
            $stepResult.Actions += @{ Action = "dotnet format analyzers"; Status = "Failed"; Error = $analyzerResult }
            $stepResult.Status = "Failed"
            $results.Summary.FailedSteps++
        }
    }
    catch {
        if (-not $JsonOutput) {
            Write-Failure "Analyzer format threw exception: $_"
        }
        $stepResult.Actions += @{ Action = "dotnet format analyzers"; Status = "Exception"; Error = $_.Exception.Message }
        $stepResult.Status = "Failed"
        $results.Summary.FailedSteps++
    }
    
    $results.Steps += $stepResult
} elseif ($stepsToRun -contains 1 -and $DryRun) {
    if (-not $JsonOutput) {
        Write-Step "Step 1/7: Auto-fix (DRY RUN)"
        Write-InfoMessage "Would run: dotnet format + dotnet format analyzers"
    }
    $results.Summary.SkippedSteps++
} elseif ($SkipAutoFix) {
    if (-not $JsonOutput) {
        Write-Step "Step 1/7: Auto-fix skipped (-SkipAutoFix)"
    }
    $results.Summary.SkippedSteps++
} elseif (-not ($stepsToRun -contains 1)) {
    if (-not $JsonOutput) {
        Write-Step "Step 1/7: Auto-fix (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 2: Fix specific diagnostic types

if ($stepsToRun -contains 2) {
    if (-not $JsonOutput) {
        Write-Step "Step 2/7: Fixing specific diagnostic types"
    }
    
    $stepResult = @{
        Step = 2
        Name = "FixDiagnostics"
        Status = "Running"
        Actions = @()
    }
    
    # Determine which fixes to run based on DiagnosticFilter
    $runCS1591 = [string]::IsNullOrWhiteSpace($DiagnosticFilter) -or $DiagnosticFilter -match 'CS1591'
    $runCS1570 = [string]::IsNullOrWhiteSpace($DiagnosticFilter) -or $DiagnosticFilter -match 'CS1570'
    $runIDE1006 = [string]::IsNullOrWhiteSpace($DiagnosticFilter) -or $DiagnosticFilter -match 'IDE1006'
    $runIDE0028 = [string]::IsNullOrWhiteSpace($DiagnosticFilter) -or $DiagnosticFilter -match 'IDE0028'
    $runCA1825 = [string]::IsNullOrWhiteSpace($DiagnosticFilter) -or $DiagnosticFilter -match 'CA1825'
    
    # Fix CS1591 (missing XML documentation)
    if ($runCS1591) {
        $cs1591Script = Join-Path $scriptDir "fix-cs1591-documentation.ps1"
        if (Test-Path $cs1591Script) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-cs1591-documentation.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-cs1591-documentation.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-cs1591-documentation.ps1..." -ForegroundColor Gray
                }
                & $cs1591Script -Path $solutionDir -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "CS1591 fixes applied"
                }
                $stepResult.Actions += @{ Action = "fix-cs1591-documentation.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "CS1591 fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-cs1591-documentation.ps1"; Status = "NotFound" }
        }
    }
    
    # Fix IDE1006 (naming rule violations - missing underscore prefix)
    if ($runIDE1006) {
        $ide1006Script = Join-Path $scriptDir "fix-ide1006-naming-violations.ps1"
        if (Test-Path $ide1006Script) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-ide1006-naming-violations.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-naming-violations.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-ide1006-naming-violations.ps1..." -ForegroundColor Gray
                }
                & $ide1006Script -Path $solutionDir -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "IDE1006 naming violations fixed"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-naming-violations.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "IDE1006 naming violations fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-ide1006-naming-violations.ps1"; Status = "NotFound" }
        }
    }

    # Fix IDE1006 (private field casing - ensure lower-case after underscore)
    if ($runIDE1006) {
        $ide1006FieldCasingScript = Join-Path $scriptDir "fix-ide1006-private-field-casing.ps1"
        if (Test-Path $ide1006FieldCasingScript) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-ide1006-private-field-casing.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-private-field-casing.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-ide1006-private-field-casing.ps1..." -ForegroundColor Gray
                }
                & $ide1006FieldCasingScript -Path $solutionDir -ErrorAction Continue
                if ($LASTEXITCODE -eq 0 -and -not $JsonOutput) {
                    Write-Success "IDE1006 private field casing fixed"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-private-field-casing.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "IDE1006 private field casing fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-ide1006-private-field-casing.ps1"; Status = "NotFound" }
        }
    }

    # Fix IDE1006 (async method naming - ensure Async suffix)
    if ($runIDE1006) {
        $ide1006AsyncScript = Join-Path $scriptDir "fix-ide1006-async-method-naming.ps1"
        if (Test-Path $ide1006AsyncScript) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-ide1006-async-method-naming.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-async-method-naming.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-ide1006-async-method-naming.ps1..." -ForegroundColor Gray
                }
                & $ide1006AsyncScript -Path $solutionDir -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "IDE1006 async method naming fixed"
                }
                $stepResult.Actions += @{ Action = "fix-ide1006-async-method-naming.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "IDE1006 async method naming fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-ide1006-async-method-naming.ps1"; Status = "NotFound" }
        }
    }

    # Fix CS1570 (badly formed XML comments)
    if ($runCS1570) {
        $cs1570Script = Join-Path $scriptDir "fix-cs1570-xml-comments.ps1"
        if (Test-Path $cs1570Script) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-cs1570-xml-comments.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-cs1570-xml-comments.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-cs1570-xml-comments.ps1..." -ForegroundColor Gray
                }
                & $cs1570Script -Path $solutionDir -Recurse -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "CS1570 XML comment fixes applied"
                }
                $stepResult.Actions += @{ Action = "fix-cs1570-xml-comments.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "CS1570 fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-cs1570-xml-comments.ps1"; Status = "NotFound" }
        }
    }

    # Fix CS1570 (restore XML format) - optional second pass for formatting regressions
    if ($runCS1570) {
        $cs1570FormatScript = Join-Path $scriptDir "fix-cs1570-xml-format.ps1"
        if (Test-Path $cs1570FormatScript) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-cs1570-xml-format.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-cs1570-xml-format.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-cs1570-xml-format.ps1..." -ForegroundColor Gray
                }
                & $cs1570FormatScript -Path $solutionDir -Recurse -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "CS1570 XML format fixes applied"
                }
                $stepResult.Actions += @{ Action = "fix-cs1570-xml-format.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "CS1570 XML format fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-cs1570-xml-format.ps1"; Status = "NotFound" }
        }
    }

    # Fix IDE0028 (simplify collection initialization)
    if ($runIDE0028) {
        $ide0028Script = Join-Path $scriptDir "fix-ide0028-collection-initialization.ps1"
        if (Test-Path $ide0028Script) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-ide0028-collection-initialization.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-ide0028-collection-initialization.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-ide0028-collection-initialization.ps1..." -ForegroundColor Gray
                }
                & $ide0028Script -Path $solutionDir -Recurse -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "IDE0028 collection initialization fixes applied"
                }
                $stepResult.Actions += @{ Action = "fix-ide0028-collection-initialization.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "IDE0028 fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-ide0028-collection-initialization.ps1"; Status = "NotFound" }
        }
    }

    # Fix CA1825 (static readonly arrays)
    if ($runCA1825) {
        $ca1825Script = Join-Path $scriptDir "fix-ca1825-static-readonly-arrays.ps1"
        if (Test-Path $ca1825Script) {
            if ($DryRun) {
                if (-not $JsonOutput) {
                    Write-InfoMessage "Would run: fix-ca1825-static-readonly-arrays.ps1"
                }
                $stepResult.Actions += @{ Action = "fix-ca1825-static-readonly-arrays.ps1"; Status = "DryRun" }
            } else {
                if (-not $JsonOutput) {
                    Write-Host "  Running: fix-ca1825-static-readonly-arrays.ps1..." -ForegroundColor Gray
                }
                & $ca1825Script -Path $solutionDir -Recurse -ErrorAction Continue
                if (-not $JsonOutput) {
                    Write-Success "CA1825 static readonly array fixes applied"
                }
                $stepResult.Actions += @{ Action = "fix-ca1825-static-readonly-arrays.ps1"; Status = "Success" }
            }
        } else {
            if (-not $JsonOutput) {
                Write-InfoMessage "CA1825 fix script not found, skipping"
            }
            $stepResult.Actions += @{ Action = "fix-ca1825-static-readonly-arrays.ps1"; Status = "NotFound" }
        }
    }

    $postFixFormatFailed = $false
    if (-not $DryRun -and -not $SkipAutoFix) {
        if (-not $JsonOutput) {
            Write-Host "  Running: dotnet format (post-fix)..." -ForegroundColor Gray
        }
        dotnet format | Out-Null
        $formatExitCode = $LASTEXITCODE
        $stepResult.Actions += @{
            Action = "dotnet format (post-fix)"
            Status = if ($formatExitCode -eq 0) { "Success" } else { "Failed" }
        }

        if (-not $JsonOutput) {
            Write-Host "  Running: dotnet format analyzers (post-fix)..." -ForegroundColor Gray
        }
        dotnet format analyzers | Out-Null
        $analyzerFormatExitCode = $LASTEXITCODE
        $stepResult.Actions += @{
            Action = "dotnet format analyzers (post-fix)"
            Status = if ($analyzerFormatExitCode -eq 0) { "Success" } else { "Failed" }
        }

        if ($formatExitCode -ne 0 -or $analyzerFormatExitCode -ne 0) {
            $postFixFormatFailed = $true
        }
    }

    $stepResult.Status = if ($DryRun) { "DryRun" } elseif ($postFixFormatFailed) { "Failed" } else { "Success" }
    if ($stepResult.Status -eq "Failed") {
        $results.Summary.FailedSteps++
    } else {
        $results.Summary.SuccessfulSteps++
    }
    $results.Steps += $stepResult
} else {
    if (-not $JsonOutput) {
        Write-Step "Step 2/7: Fix diagnostics (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 3: Build solution with warnings-as-errors
if ($stepsToRun -contains 3) {
    if (-not $JsonOutput) {
        Write-Step "Step 3/7: Building solution (warnings-as-errors enabled)"
    }
    
    $stepResult = @{
        Step = 3
        Name = "Build"
        Status = "Running"
        Output = ""
    }
    
    if ($DryRun) {
        if (-not $JsonOutput) {
            Write-InfoMessage "Would run: dotnet build $solutionFile --no-restore"
        }
        $stepResult.Status = "DryRun"
        $stepResult.Output = "Dry run - build not executed"
    } else {
        if (-not $JsonOutput) {
            Write-Host "  Running: dotnet build..." -ForegroundColor Gray
        }
        try {
            $buildOutput = dotnet build $solutionFile --no-restore 2>&1 | Out-String
            $buildExitCode = $LASTEXITCODE
            
            if ($buildExitCode -eq 0) {
                if (-not $JsonOutput) {
                    Write-Success "Build succeeded with zero warnings/errors"
                }
                $stepResult.Status = "Success"
                $stepResult.Output = "Build succeeded"
                $results.Summary.SuccessfulSteps++
            } else {
                if (-not $JsonOutput) {
                    Write-Failure "Build failed with warnings or errors"
                }
                $stepResult.Status = "Failed"
                
                # Apply filtering and truncation
                $filteredOutput = Get-FilteredDiagnostics -BuildOutput $buildOutput -Filter $DiagnosticFilter -MaxLines $MaxOutputLines
                $truncatedResult = Get-TruncatedFileList -Output $filteredOutput -MaxFiles $MaxFiles
                
                $stepResult.Output = $truncatedResult.Output
                $stepResult.TotalFiles = $truncatedResult.TotalFiles
                $stepResult.HasMore = $truncatedResult.HasMore
                
                if ($truncatedResult.HasMore) {
                    $results.HasMoreFiles = $true
                }
                
                if (-not $JsonOutput) {
                    Write-Host "`nBuild Output (filtered):" -ForegroundColor Yellow
                    Write-Host $stepResult.Output
                    if ($truncatedResult.HasMore) {
                        Write-Host "`n💡 TIP: Fix these $MaxFiles files first, then re-run to see remaining $($truncatedResult.RemainingFiles) files" -ForegroundColor Cyan
                    }
                    Write-Host "`n⚠️  Fix warnings/errors before proceeding" -ForegroundColor Yellow
                }
                
                $results.Summary.FailedSteps++
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Build threw exception: $_"
            }
            $stepResult.Status = "Failed"
            $stepResult.Output = "Build exception: $($_.Exception.Message)"
            $results.Summary.FailedSteps++
        }
    }
    
    $results.Steps += $stepResult
} else {
    if (-not $JsonOutput) {
        Write-Step "Step 3/7: Build (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 4: Run tests (CONDITIONAL - only if build succeeded)
$buildSucceeded = ($results.Steps | Where-Object { $_.Step -eq 3 -and $_.Status -eq "Success" }) -ne $null
$shouldRunTests = ($stepsToRun -contains 4) -and -not $SkipTests

if ($shouldRunTests) {
    if (-not $JsonOutput) {
        Write-Step "Step 4/7: Running all tests"
    }
    
    $stepResult = @{
        Step = 4
        Name = "Tests"
        Status = "Running"
        Output = ""
    }
    
    # Check if build succeeded first
    if (-not $buildSucceeded -and ($stepsToRun -contains 3)) {
        if (-not $JsonOutput) {
            Write-Host "  ⚠️  Skipping tests - build failed in Step 3" -ForegroundColor Yellow
        }
        $stepResult.Status = "Skipped"
        $stepResult.Reason = "Build failed"
        $results.Summary.SkippedSteps++
    } elseif ($DryRun) {
        if (-not $JsonOutput) {
            Write-InfoMessage "Would run: dotnet test $solutionFile --no-build --verbosity normal"
        }
        $stepResult.Status = "DryRun"
        $stepResult.Output = "Dry run - tests not executed"
        $results.Summary.SkippedSteps++
    } else {
        if (-not $JsonOutput) {
            Write-Host "  Running: dotnet test..." -ForegroundColor Gray
        }
        try {
            $testOutput = dotnet test $solutionFile --no-build --verbosity normal 2>&1 | Out-String
            $testExitCode = $LASTEXITCODE
            
            # Extract test summary
            $testSummary = $testOutput | Select-String "Total tests:|Failed:|Passed:" | Out-String
            
            if ($testExitCode -eq 0) {
                if (-not $JsonOutput) {
                    Write-Success "All tests passed"
                }
                $stepResult.Status = "Success"
                $stepResult.Output = $testSummary
                $results.Summary.SuccessfulSteps++
            } else {
                if (-not $JsonOutput) {
                    Write-Failure "Tests failed - functionality may be broken"
                }
                $stepResult.Status = "Failed"
                
                # Truncate test output for AI context
                $truncatedOutput = Get-FilteredDiagnostics -BuildOutput $testOutput -Filter "" -MaxLines $MaxOutputLines
                $stepResult.Output = $truncatedOutput
                
                if (-not $JsonOutput) {
                    Write-Host "`nTest Output (truncated):" -ForegroundColor Yellow
                    Write-Host $stepResult.Output
                    Write-Host "`n⚠️  Fix failing tests before merging" -ForegroundColor Yellow
                }
                
                $results.Summary.FailedSteps++
            }
            
            $results.TestResults = $stepResult
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Test execution threw exception: $_"
            }
            $stepResult.Status = "Failed"
            $stepResult.Output = "Test exception: $($_.Exception.Message)"
            $results.Summary.FailedSteps++
        }
    }
    
    $results.Steps += $stepResult
} elseif ($SkipTests) {
    if (-not $JsonOutput) {
        Write-Step "Step 4/7: Tests skipped (-SkipTests)"
        Write-Host "  ⚠️  Running tests is highly recommended to ensure fixes didn't break functionality" -ForegroundColor Yellow
    }
    $results.Summary.SkippedSteps++
} elseif (-not ($stepsToRun -contains 4)) {
    if (-not $JsonOutput) {
        Write-Step "Step 4/7: Tests (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 5: Validate formatting is clean
if ($stepsToRun -contains 5) {
    if (-not $JsonOutput) {
        Write-Step "Step 5/7: Validating formatting is clean"
    }
    
    $stepResult = @{
        Step = 5
        Name = "FormatValidation"
        Status = "Running"
        Checks = @()
    }
    
    if ($DryRun) {
        if (-not $JsonOutput) {
            Write-InfoMessage "Would run: dotnet format --verify-no-changes"
            Write-InfoMessage "Would run: dotnet format analyzers --verify-no-changes"
        }
        $stepResult.Status = "DryRun"
        $results.Summary.SkippedSteps++
    } else {
        try {
            if (-not $JsonOutput) {
                Write-Host "  Running: dotnet format --verify-no-changes..." -ForegroundColor Gray
            }
            $formatVerifyResult = dotnet format $solutionFile --verify-no-changes 2>&1 | Out-String
            $formatVerifyExitCode = $LASTEXITCODE
            
            if ($formatVerifyExitCode -eq 0) {
                if (-not $JsonOutput) {
                    Write-Success "Code formatting validated"
                }
                $stepResult.Checks += @{ Check = "dotnet format"; Status = "Success" }
            } else {
                if (-not $JsonOutput) {
                    Write-Failure "Formatting verification failed"
                }
                $stepResult.Checks += @{ Check = "dotnet format"; Status = "Failed"; Output = $formatVerifyResult }
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Format verification threw exception: $_"
            }
            $stepResult.Checks += @{ Check = "dotnet format"; Status = "Exception"; Output = $_.Exception.Message }
            $formatVerifyExitCode = 1
        }
        
        try {
            if (-not $JsonOutput) {
                Write-Host "  Running: dotnet format analyzers --verify-no-changes..." -ForegroundColor Gray
            }
            $analyzerVerifyResult = dotnet format analyzers $solutionFile --verify-no-changes 2>&1 | Out-String
            $analyzerVerifyExitCode = $LASTEXITCODE
            
            if ($analyzerVerifyExitCode -eq 0) {
                if (-not $JsonOutput) {
                    Write-Success "Analyzer formatting validated"
                }
                $stepResult.Checks += @{ Check = "dotnet format analyzers"; Status = "Success" }
            } else {
                if (-not $JsonOutput) {
                    Write-Failure "Analyzer formatting verification failed"
                }
                $stepResult.Checks += @{ Check = "dotnet format analyzers"; Status = "Failed"; Output = $analyzerVerifyResult }
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Analyzer verification threw exception: $_"
            }
            $stepResult.Checks += @{ Check = "dotnet format analyzers"; Status = "Exception"; Output = $_.Exception.Message }
            $analyzerVerifyExitCode = 1
        }
        
        $stepResult.Status = if ($formatVerifyExitCode -eq 0 -and $analyzerVerifyExitCode -eq 0) { "Success" } else { "Failed" }
        
        if ($stepResult.Status -eq "Success") {
            $results.Summary.SuccessfulSteps++
        } else {
            $results.Summary.FailedSteps++
        }
    }
    
    $results.Steps += $stepResult
} else {
    if (-not $JsonOutput) {
        Write-Step "Step 5/7: Format validation (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 6: Final quality check
if ($stepsToRun -contains 6) {
    if (-not $JsonOutput) {
        Write-Step "Step 6/7: Final quality check"
    }
    
    $stepResult = @{
        Step = 6
        Name = "FinalCheck"
        Status = "Running"
        Output = ""
    }
    
    if ($DryRun) {
        if (-not $JsonOutput) {
            Write-InfoMessage "Would run: build-and-find-errors.ps1 or dotnet build"
        }
        $stepResult.Status = "DryRun"
        $results.Summary.SkippedSteps++
    } else {
        try {
            $buildCheckScript = Join-Path $scriptDir "build-and-find-errors.ps1"
            if (Test-Path $buildCheckScript) {
                if (-not $JsonOutput) {
                    Write-Host "  Running: build-and-find-errors.ps1..." -ForegroundColor Gray
                }
                $checkOutput = & $buildCheckScript -SolutionPath $solutionFile -ErrorAction Continue | Out-String
                $checkExitCode = $LASTEXITCODE
                
                if ($checkExitCode -eq 0 -or $checkOutput -match "Build succeeded with (no|0) errors") {
                    if (-not $JsonOutput) {
                        Write-Success "Quality check passed"
                    }
                    $stepResult.Status = "Success"
                    $stepResult.Output = "Zero errors found"
                    $results.Summary.SuccessfulSteps++
                } else {
                    if (-not $JsonOutput) {
                        Write-Failure "Quality check found issues"
                    }
                    $stepResult.Status = "Failed"
                    $stepResult.Output = Get-FilteredDiagnostics -BuildOutput $checkOutput -Filter "" -MaxLines ($MaxOutputLines * 2)
                    $results.Summary.FailedSteps++
                }
            } else {
                if (-not $JsonOutput) {
                    Write-InfoMessage "build-and-find-errors.ps1 not found, running basic build check"
                }
                dotnet build $solutionFile --no-restore > $null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    if (-not $JsonOutput) {
                        Write-Success "Basic build check passed"
                    }
                    $stepResult.Status = "Success"
                    $stepResult.Output = "Build succeeded"
                    $results.Summary.SuccessfulSteps++
                } else {
                    if (-not $JsonOutput) {
                        Write-Failure "Basic build check failed"
                    }
                    $stepResult.Status = "Failed"
                    $stepResult.Output = "Build failed"
                    $results.Summary.FailedSteps++
                }
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Failure "Final check threw exception: $_"
            }
            $stepResult.Status = "Failed"
            $stepResult.Output = "Exception during final check: $($_.Exception.Message)"
            $results.Summary.FailedSteps++
        }
    }
    
    $results.Steps += $stepResult
} else {
    if (-not $JsonOutput) {
        Write-Step "Step 6/7: Final check (skipped by -Steps parameter)"
    }
    $results.Summary.SkippedSteps++
}

# Step 7: Summary
$elapsed = (Get-Date) - $script:StartTime
$elapsedFormatted = "{0:mm}m {0:ss}s" -f $elapsed

$results.Summary.ElapsedTime = $elapsedFormatted
$results.Summary.ReadyToMerge = ($results.Summary.FailedSteps -eq 0 -and $script:FailureCount -eq 0)

# JSON Output Mode (for AI consumption)
if ($JsonOutput) {
    Write-Output ($results | ConvertTo-Json -Depth 10)
    if ($results.Summary.ReadyToMerge) { exit 0 }
    exit 1
}

# Human-readable output
if (-not $JsonOutput) {
    Write-Step "Step 7/7: Validation Summary"
}

# Track analyzer progress if requested
if ($TrackProgress -and $EnableAnalyzer) {
    $trackScript = Join-Path $scriptDir "track-analyzer-progress.ps1"
    if (Test-Path $trackScript) {
        try {
            if (-not $JsonOutput) {
                Write-Host "`n📊 Tracking analyzer progress..." -ForegroundColor Cyan
            }
            
            $status = if ($results.Summary.ReadyToMerge) { 'completed' } else { 'in-progress' }
            $errorsFixed = if ($results.Analysis.ErrorsCount) { $results.Analysis.ErrorsCount } else { 0 }
            $notes = "Validation $(if ($results.Summary.ReadyToMerge) { 'passed' } else { 'in progress' }) - $errorsFixed issues addressed"
            
            & $trackScript -AnalyzerId $EnableAnalyzer -Status $status -ErrorsFixed $errorsFixed -Notes $notes -ErrorAction Continue
            
            if ($LASTEXITCODE -eq 0 -and -not $JsonOutput) {
                Write-Host "  ✅ Progress tracked for $EnableAnalyzer" -ForegroundColor Green
            }
        }
        catch {
            if (-not $JsonOutput) {
                Write-Warning "  ⚠️ Failed to track progress: $_"
            }
        }
    } else {
        if (-not $JsonOutput) {
            Write-Warning "  ⚠️ track-analyzer-progress.ps1 not found at: $trackScript"
        }
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
if ($results.Summary.ReadyToMerge) {
    $emoji = Get-StatusEmoji 'success'
    Write-Host "$emoji CODE IS READY TO MERGE!" -ForegroundColor Green
    Write-Host "================================================`n" -ForegroundColor Cyan
    Write-Host "✅ Zero warnings" -ForegroundColor Green
    Write-Host "✅ Zero errors" -ForegroundColor Green
    if (-not $SkipTests -and ($stepsToRun -contains 4)) {
        Write-Host "✅ All tests passing" -ForegroundColor Green
    }
    if ($stepsToRun -contains 5) {
        Write-Host "✅ Formatting validated" -ForegroundColor Green
    }
    Write-Host "`nSteps: $($results.Summary.SuccessfulSteps) successful, $($results.Summary.FailedSteps) failed, $($results.Summary.SkippedSteps) skipped" -ForegroundColor Gray
    Write-Host "Time elapsed: $elapsedFormatted" -ForegroundColor Gray
    
    if ($EnableAnalyzer) {
        Write-Host "`n✅ Analyzer $EnableAnalyzer successfully enabled and validated" -ForegroundColor Green
        if ($TrackProgress) {
            Write-Host "   Progress tracked: completed" -ForegroundColor Gray
            Write-Host "   View all progress: " -NoNewline -ForegroundColor Gray
            Write-Host ".\validate-pre-merge.ps1 -ShowProgress" -ForegroundColor White
        }
    }
    
    if (-not $DryRun) {
        Write-Host "`nReady to commit:" -ForegroundColor Cyan
        Write-Host "  git add ." -ForegroundColor Gray
        Write-Host "  git commit -m `"chore: enforce code quality standards`"" -ForegroundColor Gray
    }
    
    if (-not $EnableAnalyzer -and -not $ShowProgress) {
        Write-Host "`n💡 TIP: Gradually enable more analyzers:" -ForegroundColor Cyan
        Write-Host "   .\validate-pre-merge.ps1 -EnableAnalyzer CA1062 -TrackProgress" -ForegroundColor Gray
        Write-Host "   .\validate-pre-merge.ps1 -ShowProgress  # View progress" -ForegroundColor Gray
    }
    exit 0
} else {
    $emoji = Get-StatusEmoji 'error'
    Write-Host "$emoji VALIDATION FAILED - DO NOT MERGE" -ForegroundColor Red
    Write-Host "================================================`n" -ForegroundColor Cyan
    Write-Host "Failures: $($results.Summary.FailedSteps) steps failed" -ForegroundColor Red
    Write-Host "Steps: $($results.Summary.SuccessfulSteps) successful, $($results.Summary.FailedSteps) failed, $($results.Summary.SkippedSteps) skipped" -ForegroundColor Gray
    
    if ($EnableAnalyzer) {
        Write-Host "`n⚠️ Analyzer $EnableAnalyzer enabled but validation incomplete" -ForegroundColor Yellow
        if ($TrackProgress) {
            Write-Host "   Progress tracked: in-progress" -ForegroundColor Gray
        }
        Write-Host "   Fix issues above, then re-run to complete" -ForegroundColor Yellow
    }
    
    if ($results.HasMoreFiles) {
        Write-Host "`n💡 TIP: This is a batch run showing first $MaxFiles files." -ForegroundColor Cyan
        Write-Host "   Fix these files, then re-run to see next batch." -ForegroundColor Cyan
    }
    
    Write-Host "`nFix the issues above and re-run:" -ForegroundColor Yellow
    Write-Host "  .\validate-pre-merge.ps1" -ForegroundColor Gray
    
    if ($DiagnosticFilter) {
        Write-Host "`nOr focus on specific diagnostics:" -ForegroundColor Yellow
        Write-Host "  .\validate-pre-merge.ps1 -DiagnosticFilter `"CS1591,IDE1006`"" -ForegroundColor Gray
    }
    
    if ($EnableAnalyzer) {
        Write-Host "`nContinue working on ${EnableAnalyzer}:" -ForegroundColor Yellow
        Write-Host "  .\validate-pre-merge.ps1 -EnableAnalyzer $EnableAnalyzer -TrackProgress" -ForegroundColor Gray
    }
    
    Write-Host "`nTime elapsed: $elapsedFormatted" -ForegroundColor Gray
    
    # Determine exit code based on which step failed
    $testsFailed = ($results.Steps | Where-Object { $_.Step -eq 4 -and $_.Status -eq "Failed" }) -ne $null
    $formatFailed = ($results.Steps | Where-Object { $_.Step -eq 5 -and $_.Status -eq "Failed" }) -ne $null
    
    if ($testsFailed) {
        exit 2  # Tests failed
    } elseif ($formatFailed) {
        exit 3  # Format validation failed
    } else {
        exit 1  # Build failed or errors found
    }
}
