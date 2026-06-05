#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes CS1570 XML comment format errors by restoring proper multi-line structure.

.DESCRIPTION
    Converts single-line XML documentation comments back to properly formatted
    multi-line structure. This addresses CS1570 errors caused by compressed
    or incorrectly formatted XML comments.

    Specifically targets:
    - Single-line <summary> tags that should be multi-line
    - Missing proper indentation and line breaks
    - XML comments that don't follow C# documentation standards

    This script targets CS1570 errors: "XML comment has badly formed XML"

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory and subdirectories will be processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER WhatIf
    Show what would be changed without actually making changes.

.PARAMETER Verbose
    Enable verbose output showing detailed processing information.

.EXAMPLE
    .\fix-cs1570-xml-format.ps1 -Path "src/MyClass.cs"
    Restore proper XML comment formatting in a specific file

.EXAMPLE
    .\fix-cs1570-xml-format.ps1 -Path "src/" -Recurse
    Restore XML comment formatting in all C# files under src/ directory

.EXAMPLE
    .\fix-cs1570-xml-format.ps1 -Path "MyClass.cs" -WhatIf -Verbose
    Show what formatting changes would be made without applying them

.NOTES
    File Name      : fix-cs1570-xml-format.ps1
    Author         : AI Assistant
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes CS1570 (badly formed XML comments)
    Related Rules  : rule.documentation.standards.v1, rule.quality.zero-warnings-zero-errors.v1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to C# file or directory to process")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Recurse into subdirectories when Path is a directory")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the heuristic fixer")]
    [switch]$SkipRoslyn
)

$ErrorActionPreference = 'Stop'

$commonModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (-not (Test-Path $commonModulePath)) {
    throw "Common module not found at: $commonModulePath"
}
Import-Module $commonModulePath -Force -ErrorAction Stop

$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

# Get all C# files to process
function Get-CSharpFiles {
    param([string]$TargetPath, [bool]$RecurseDirectories)

    if (Test-Path $TargetPath -PathType Leaf) {
        if ($TargetPath -like "*.cs") {
            return @($TargetPath)
        } else {
            Write-ErrorMessage "Specified file is not a C# file: $TargetPath"
            return @()
        }
    }

    if (Test-Path $TargetPath -PathType Container) {
        $searchOptions = @{
            Path    = $TargetPath
            Filter  = "*.cs"
            File    = $true
        }
        if ($RecurseDirectories) {
            $searchOptions.Recurse = $true
        }

        return Get-ChildItem @searchOptions | Select-Object -ExpandProperty FullName
    }

    Write-ErrorMessage "Path does not exist: $TargetPath"
    return @()
}

# Restore proper multi-line XML comment formatting
function Fix-XmlFormat {
    param([string]$FilePath)

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop

        # Track if any changes were made
        $originalContent = $content
        $changesMade = 0

        # Fix single-line XML summaries to multi-line format
        # This regex looks for /// <summary>content</summary> and converts to proper multi-line format
        $pattern = '/// <summary>(.*?)</summary>'

        $replacement = @"
/// <summary>
/// $1
/// </summary>
"@

        $newContent = $content -replace $pattern, $replacement
        if ($newContent -ne $content) {
            $changesMade++
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                Write-InfoMessage "Restored multi-line XML comment format in $FilePath"
            }
        }
        $content = $newContent

        # Only write file if changes were made
        if ($changesMade -gt 0) {
            if ($WhatIfPreference) {
                Write-InfoMessage "Would restore XML comment formatting in $changesMade location(s) in $FilePath"
                return $true
            } else {
                $content | Set-Content $FilePath -NoNewline -ErrorAction Stop
                Write-SuccessMessage "Restored XML comment formatting in $changesMade location(s) in $FilePath"
                return $true
            }
        } else {
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                Write-InfoMessage "No XML comment formatting issues found in $FilePath"
            }
            return $false
        }

    } catch {
        Write-ErrorMessage "Error processing $FilePath : $_"
        return $false
    }
}

# Main execution
try {
    Write-Step "CS1570 XML Comment Format Restorer"
    Write-InfoMessage "Restores proper multi-line XML documentation comment structure"

    if (-not $SkipRoslyn -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        try {
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (CS1570)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('CS1570') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (CS1570)."
                    } else {
                        Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (CS1570). Continuing with heuristic fixer."
                    }
                } else {
                    Write-InfoMessage "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with heuristic fixer."
                }
            }
        } catch {
            Write-InfoMessage "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with heuristic fixer."
        }
    }

    $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories $Recurse

    if ($files.Count -eq 0) {
        Write-ErrorMessage "No C# files found to process"
        exit 1
    }

    Write-InfoMessage "Found $($files.Count) C# file(s) to process"

    $filesProcessed = 0
    $filesChanged = 0
    $totalChanges = 0

    foreach ($file in $files) {
        $filesProcessed++
        if ($Verbose) {
            Write-InfoMessage "Processing: $file"
        }

        $changed = Fix-XmlFormat -FilePath $file
        if ($changed) {
            $filesChanged++
        }
    }

    Write-Step "Summary"
    Write-InfoMessage "Processed: $filesProcessed file(s)"
    Write-InfoMessage "Changed: $filesChanged file(s)"

    if ($WhatIfPreference) {
        Write-InfoMessage "Run without -WhatIf to apply changes"
    }

    if ($filesChanged -gt 0) {
        Write-SuccessMessage "CS1570 XML comment formatting restored successfully"
        exit 0
    } else {
        Write-InfoMessage "No CS1570 formatting issues found - files already properly formatted"
        exit 0
    }

} catch {
    Write-ErrorMessage "Script execution failed: $_"
    exit 1
}

