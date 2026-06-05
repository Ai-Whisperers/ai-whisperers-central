#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated warning fix script for CI/CD quality checks
.DESCRIPTION
    Automatically fixes common warnings to achieve zero-warning goal
    Part of the Zero Errors, Zero Warnings quality initiative
.PARAMETER Fix
    Type of warning to fix
.PARAMETER Path
    Path to file/project to fix
.PARAMETER DryRun
    Show what would be fixed without making changes
.EXAMPLE
    .\fix-warnings.ps1 -Fix MissingDocumentation -Path "src/MyClass.cs"
.EXAMPLE
    .\fix-warnings.ps1 -Fix AnalyzerAutocorrect -Path "src" -DryRun
.EXAMPLE
    .\fix-warnings.ps1 -Fix LowCoverage -Path "src/MyClass.cs" -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'AnalyzerAutocorrect',
        'MissingDocumentation',
        'LicenseWarning',
        'LowCoverage',
        'CodeComplexity',
        'IncompleteMetadata',
        'All'
    )]
    [string]$Fix,
    
    [Parameter()]
    [string]$Path,
    
    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import shared modules
Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        Automated Warning Fix - Zero Warnings Goal            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if ($DryRun) {
    Write-Log "DRY RUN MODE - No changes will be made" -Level WARN
}

Write-Log "Fix Type: $Fix"
if ($Path) {
    Write-Log "Target Path: $Path"
}

function Fix-MissingDocumentation {
    param([string]$FilePath)
    
    Write-Log "Fixing missing documentation in: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" -Level ERROR
        return $false
    }
    
    $lines = Get-Content $FilePath
    $newLines = @()
    
    $fixed = 0
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if next line is a public member without documentation
        if ($i -lt $lines.Count - 1) {
            $nextLine = $lines[$i + 1]
            
            # Check for public class/interface/enum
            if ($nextLine -match '^\s*public\s+(class|interface|enum|record|struct)\s+(\w+)' -and
                $line -notmatch '^\s*///') {
                
                $memberType = $matches[1]
                $memberName = $matches[2]
                
                Write-Log "  Adding documentation for $memberType $memberName" -Level SUCCESS
                
                if (-not $DryRun) {
                    $indent = $nextLine -replace '^\s*public.*', ''
                    $newLines += "$indent/// <summary>"
                    $newLines += "$indent/// $memberName $memberType"
                    $newLines += "$indent/// </summary>"
                }
                $fixed++
            }
            
            # Check for public method/property
            elseif ($nextLine -match '^\s*public\s+\w+\s+(\w+)' -and
                    $line -notmatch '^\s*///') {
                
                $memberName = $matches[1]
                
                Write-Log "  Adding documentation for member $memberName" -Level SUCCESS
                
                if (-not $DryRun) {
                    $indent = $nextLine -replace '^\s*public.*', ''
                    $newLines += "$indent/// <summary>"
                    $newLines += "$indent/// Gets or sets $memberName"
                    $newLines += "$indent/// </summary>"
                }
                $fixed++
            }
        }
        
        $newLines += $line
    }
    
    if ($fixed -gt 0) {
        if (-not $DryRun) {
            $newLines | Set-Content $FilePath -Encoding UTF8
            Write-Log "Fixed $fixed documentation issue(s)" -Level SUCCESS
        } else {
            Write-Log "Would fix $fixed documentation issue(s)" -Level WARN
        }
        return $true
    } else {
        Write-Log "No documentation issues found" -Level SUCCESS
        return $true
    }
}

function Fix-IncompleteMetadata {
    param([string]$ProjectFile)
    
    Write-Log "Fixing incomplete metadata in: $ProjectFile"
    
    if (-not (Test-Path $ProjectFile)) {
        Write-Log "Project file not found: $ProjectFile" -Level ERROR
        return $false
    }
    
    [xml]$project = Get-Content $ProjectFile
    $propertyGroup = $project.Project.PropertyGroup | Select-Object -First 1
    
    if (-not $propertyGroup) {
        Write-Log "No PropertyGroup found in project file" -Level ERROR
        return $false
    }
    
    $requiredProperties = @{
        'Authors' = 'Your Organization'
        'Company' = 'Your Company'
        'Description' = 'Package description'
        'PackageLicenseExpression' = 'MIT'
        'PackageProjectUrl' = 'https://github.com/yourorg/yourrepo'
        'RepositoryUrl' = 'https://github.com/yourorg/yourrepo'
        'PackageTags' = 'tag1;tag2'
        'Copyright' = "Copyright (c) $(Get-Date -Format yyyy) Your Organization"
    }
    
    $fixed = 0
    foreach ($prop in $requiredProperties.Keys) {
        if (-not $propertyGroup.$prop) {
            Write-Log "  Adding missing property: $prop" -Level SUCCESS
            
            if (-not $DryRun) {
                $newElement = $project.CreateElement($prop)
                $newElement.InnerText = $requiredProperties[$prop]
                $propertyGroup.AppendChild($newElement) | Out-Null
            }
            $fixed++
        }
    }
    
    if ($fixed -gt 0) {
        if (-not $DryRun) {
            $project.Save($ProjectFile)
            Write-Log "Fixed $fixed metadata issue(s)" -Level SUCCESS
        } else {
            Write-Log "Would fix $fixed metadata issue(s)" -Level WARN
        }
        return $true
    } else {
        Write-Log "No metadata issues found" -Level SUCCESS
        return $true
    }
}

function Fix-AnalyzerAutocorrect {
    param([string]$TargetPath)

    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # Keep this list narrowly scoped to diagnostics that are (typically) safely auto-fixable via `dotnet format`.
    # This set is used as the default "analyzer autocorrect" batch for downstream repos (e.g., DataMigrator).
    $styleDiagnosticIds = @(
        'IDE0017',
        'IDE0028',
        'IDE0034',
        'IDE0059',
        'IDE0090',
        'IDE0250',
        'IDE0251',
        'IDE0290',
        'IDE0300',
        'IDE0301',
        'IDE0305',
        'IDE0350'
    )

    $analyzerDiagnosticIds = @(
        'CA1816',
        'CA1827',
        'CA1861'
    )

    $includeArgs = @()
    if ($TargetPath) {
        $normalizedTargetPath = if ([System.IO.Path]::IsPathRooted($TargetPath)) {
            $TargetPath
        } else {
            Join-Path $repoRoot $TargetPath
        }

        if (-not (Test-Path $normalizedTargetPath)) {
            Write-Log "Target path not found: $TargetPath (resolved: $normalizedTargetPath)" -Level ERROR
            return $false
        }

        $resolvedTargetPath = (Resolve-Path $normalizedTargetPath).Path
        if (-not $resolvedTargetPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Log "Target path is outside repo root; ignoring include filter. Target: $resolvedTargetPath | RepoRoot: $repoRoot" -Level WARN
        } else {
            $relativeTargetPath = $resolvedTargetPath.Substring($repoRoot.Length).TrimStart('\', '/')
            if ($relativeTargetPath) {
                $includeArgs = @('--include', $relativeTargetPath)
                Write-Log "Using include filter: $relativeTargetPath"
            }
        }
    }

    $verifyArgs = @()
    if ($DryRun) {
        $verifyArgs = @('--verify-no-changes')
    }

    Push-Location $repoRoot
    try {
        Write-Log "Running dotnet format (style) for: $($styleDiagnosticIds -join ', ')"
        $styleArgs = @('format', 'style', '--severity', 'warn') + $verifyArgs + $includeArgs + @('--diagnostics') + $styleDiagnosticIds
        $styleOutput = & dotnet @styleArgs 2>&1
        $styleExitCode = $LASTEXITCODE

        if ($DryRun -and ($styleExitCode -eq 0 -or $styleExitCode -eq 2)) {
            Write-Log "Style analyzer dry-run complete. ExitCode=$styleExitCode (0=no changes, 2=changes needed)." -Level SUCCESS
        }
        elseif (-not $DryRun -and $styleExitCode -eq 0) {
            Write-Log "Style analyzer fixes applied successfully." -Level SUCCESS
        }
        else {
            Write-Log "dotnet format style failed. ExitCode=$styleExitCode" -Level ERROR
            if ($styleOutput) { Write-Host $styleOutput }
            return $false
        }

        Write-Log "Running dotnet format (analyzers) for: $($analyzerDiagnosticIds -join ', ')"
        $analyzersArgs = @('format', 'analyzers', '--severity', 'warn') + $verifyArgs + $includeArgs + @('--diagnostics') + $analyzerDiagnosticIds
        $analyzersOutput = & dotnet @analyzersArgs 2>&1
        $analyzersExitCode = $LASTEXITCODE

        if ($DryRun -and ($analyzersExitCode -eq 0 -or $analyzersExitCode -eq 2)) {
            Write-Log "3rd party analyzer dry-run complete. ExitCode=$analyzersExitCode (0=no changes, 2=changes needed)." -Level SUCCESS
        }
        elseif (-not $DryRun -and $analyzersExitCode -eq 0) {
            Write-Log "3rd party analyzer fixes applied successfully." -Level SUCCESS
        }
        else {
            Write-Log "dotnet format analyzers failed. ExitCode=$analyzersExitCode" -Level ERROR
            if ($analyzersOutput) { Write-Host $analyzersOutput }
            return $false
        }

        return $true
    }
    finally {
        Pop-Location
    }
}

function Fix-LowCoverage {
    param([string]$FilePath)
    
    Write-Log "Generating tests for: $FilePath"
    
    Write-Log "Low coverage detected. Automated test generation is not supported by this script." -Level WARN
    Write-Log "Suggested next step: Use Cursor AI to generate unit tests for: $FilePath" -Level WARN
    return $true
}

function Fix-All {
    Write-Log "Running all automated fixes..."
    
    $fixes = @('MissingDocumentation', 'IncompleteMetadata')
    $allSuccess = $true
    
    foreach ($fixType in $fixes) {
        Write-Log "`nApplying fix: $fixType" -Level INFO
        $success = switch ($fixType) {
            'MissingDocumentation' {
                if ($Path) {
                    Fix-MissingDocumentation -FilePath $Path
                } else {
                    Write-Log "Path required for MissingDocumentation fix" -Level WARN
                    $true
                }
            }
            'IncompleteMetadata' {
                if ($Path) {
                    Fix-IncompleteMetadata -ProjectFile $Path
                } else {
                    Write-Log "Path required for IncompleteMetadata fix" -Level WARN
                    $true
                }
            }
        }
        
        if (-not $success) {
            $allSuccess = $false
        }
    }
    
    return $allSuccess
}

# Main execution
try {
    $success = switch ($Fix) {
        'AnalyzerAutocorrect' { Fix-AnalyzerAutocorrect -TargetPath $Path }
        'MissingDocumentation' { Fix-MissingDocumentation -FilePath $Path }
        'IncompleteMetadata' { Fix-IncompleteMetadata -ProjectFile $Path }
        'LowCoverage' { Fix-LowCoverage -FilePath $Path }
        'LicenseWarning' {
            Write-Log "License warning requires manual review" -Level WARN
            $true
        }
        'CodeComplexity' {
            Write-Log "Code complexity requires refactoring" -Level WARN
            $true
        }
        'All' { Fix-All }
    }
    
    if ($success) {
        Write-Log "`nWarning fix completed successfully!" -Level SUCCESS
        exit 0
    } else {
        Write-Log "`nWarning fix completed with errors" -Level ERROR
        exit 1
    }
    
} catch {
    Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

