#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Builds the solution and finds the first 10 errors of a specific type

.DESCRIPTION
    This script runs dotnet build and parses the output to find compilation errors,
    then filters for specific error types and displays the first 10 matches in a
    formatted way for easy fixing.

.PARAMETER SolutionPath
    Path to the solution file. If not specified, auto-detects the single .sln file in current directory.

.PARAMETER ErrorType
    The error type to filter for (e.g., CS1591 for missing XML documentation).
    If not specified, shows all errors.

.PARAMETER MaxErrors
    Maximum number of errors to display. Default: 10

.PARAMETER Configuration
    Build configuration to use. Default: Release

.PARAMETER TimeoutSeconds
    Timeout for build operation in seconds. Default: 180 (3 minutes)

.EXAMPLE
    .\build-and-find-errors.ps1 -ErrorType CS1591
    Builds and shows first 10 CS1591 (missing XML docs) errors

.EXAMPLE
    .\build-and-find-errors.ps1 -ErrorType CS0246 -MaxErrors 5
    Builds and shows first 5 CS0246 (namespace not found) errors

.EXAMPLE
    .\build-and-find-errors.ps1 -TimeoutSeconds 300
    Builds with 5-minute timeout

.NOTES
    File Name      : build-and-find-errors.ps1
    Prerequisite   : .NET SDK 9.x, PowerShell 7.2+
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Solution file path (auto-detects if not specified)")]
    [string]$SolutionPath,

    [Parameter(Mandatory = $false, HelpMessage = "Error type to filter for (e.g., CS1591)")]
    [string]$ErrorType,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of errors to display")]
    [ValidateRange(1, 50)]
    [int]$MaxErrors = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Build configuration")]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds")]
    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

function Test-Unicode {
    <#
    .SYNOPSIS
        Detects if the environment supports Unicode output.
    #>
    $psVersion = $PSVersionTable.PSVersion.Major
    $inAzure = $null -ne $env:AGENT_TEMPDIRECTORY
    $isUtf8Console = [Console]::OutputEncoding.CodePage -eq 65001

    return ($psVersion -ge 7) -or $inAzure -or $isUtf8Console
}

function Get-StatusEmoji {
    param([string]$Status)

    if (Test-Unicode) {
        return @{
            'success' = '✅'
            'warning' = '⚠️'
            'error'   = '❌'
            'info'    = 'ℹ️'
        }[$Status]
    } else {
        return @{
            'success' = '[OK]'
            'warning' = '[WARN]'
            'error'   = '[ERR]'
            'info'    = '[INFO]'
        }[$Status]
    }
}

try {
    $info = Get-StatusEmoji 'info'
    $errorEmoji = Get-StatusEmoji 'error'
    $success = Get-StatusEmoji 'success'

    Write-Host "$info Building solution in $Configuration mode..." -ForegroundColor Cyan

    # Auto-detect solution file if not specified
    if (-not $SolutionPath) {
        Write-Host "  Auto-detecting solution file..." -ForegroundColor Gray
        $solutionFiles = @(Get-ChildItem -Filter *.sln | Select-Object -ExpandProperty Name)
        Write-Host "  Found $($solutionFiles.Count) solution file(s): $($solutionFiles -join ', ')" -ForegroundColor Gray
        if ($solutionFiles.Count -eq 1) {
            $SolutionPath = $solutionFiles[0]
            Write-Host "  Using solution: $SolutionPath" -ForegroundColor Gray
        } elseif ($solutionFiles.Count -gt 1) {
            Write-Host "$errorEmoji Multiple solution files found. Please specify -SolutionPath:" -ForegroundColor Red
            $solutionFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            exit 1
        } else {
            Write-Host "$errorEmoji No solution file found in current directory" -ForegroundColor Red
            Write-Host "  Current directory: $(Get-Location)" -ForegroundColor Gray
            exit 1
        }
    }

    Write-Host "🔍 Starting build process..." -ForegroundColor Cyan
    Write-Host "  Solution: $SolutionPath" -ForegroundColor Gray
    Write-Host "  Configuration: $Configuration" -ForegroundColor Gray
    Write-Host "  Timeout: $TimeoutSeconds seconds" -ForegroundColor Gray
    Write-Host "  Note: Build may take longer due to 'warnings as errors' setting" -ForegroundColor Yellow

    $startTime = Get-Date
    Write-Host "  Build started at: $($startTime.ToString('HH:mm:ss'))" -ForegroundColor Gray

    # Run build in background job with timeout
    $job = Start-Job -ScriptBlock {
        param($sln, $config)
        $output = dotnet build $sln --configuration $config --verbosity quiet 2>&1 | Out-String
        return @{
            Output = $output
            ExitCode = $LASTEXITCODE
        }
    } -ArgumentList $SolutionPath, $Configuration -Name "build-and-find-errors-$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Wait for job with timeout
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds

    $endTime = Get-Date
    $totalDuration = $endTime - $startTime

    if ($null -eq $completed) {
        # Timeout occurred
        Write-Host "`n$errorEmoji Build timed out after $TimeoutSeconds seconds!" -ForegroundColor Red
        Write-Host "  Stopping build process..." -ForegroundColor Yellow
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Write-Host "`nConsider:" -ForegroundColor Cyan
        Write-Host "  - Increasing timeout: -TimeoutSeconds 300" -ForegroundColor Gray
        Write-Host "  - Building in Debug mode: -Configuration Debug" -ForegroundColor Gray
        Write-Host "  - Checking for hung processes or locks" -ForegroundColor Gray
        exit 1
    }

    Write-Host "  Build completed in $($totalDuration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green

    # Get build output and exit code
    $buildResult = Receive-Job -Job $job
    $buildFailed = $job.State -ne 'Completed' -or $buildResult.ExitCode -ne 0
    
    # Clean up job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

    if ($buildFailed) {
        Write-Host "$errorEmoji Build failed. Analyzing errors..." -ForegroundColor Red

        # Parse build output for errors - split output into lines
        $buildOutputLines = $buildResult.Output -split "`n"
        $errorLines = $buildOutputLines | Where-Object {
            $_ -match '\.cs\(\d+,\d+\): error (CS|CA|IDE)\d+:'
        }

        if ($errorLines.Count -eq 0) {
            Write-Host "No compilation errors found in build output." -ForegroundColor Yellow
            Write-Host "Build output sample:" -ForegroundColor Gray
            ($buildOutputLines | Select-Object -First 10) | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            exit 1
        }

        # Filter by error type if specified
        if ($ErrorType) {
            $filteredErrors = $errorLines | Where-Object { $_ -match ": error ${ErrorType}:" }
            Write-Host "`nFound $($filteredErrors.Count) $ErrorType errors. Showing first $MaxErrors..." -ForegroundColor Yellow
        } else {
            $filteredErrors = $errorLines
            Write-Host "`nFound $($filteredErrors.Count) total errors. Showing first $MaxErrors..." -ForegroundColor Yellow
        }

        # Display first N errors with formatting
        $errorsToShow = $filteredErrors | Select-Object -First $MaxErrors

        for ($i = 0; $i -lt $errorsToShow.Count; $i++) {
            $errorLine = $errorsToShow[$i]
            $errorNumber = $i + 1

            # Parse single-line error format: path(line,col): error CS1591: message [project]
            # Updated regex to handle Windows paths with backslashes and multiple error code prefixes
            if ($errorLine -match '(.+\.cs)\((\d+),(\d+)\): error ((CS|CA|IDE)\d+): (.+?) \[.+\]$') {
                $filePath = $Matches[1]
                $lineNum = $Matches[2]
                $colNum = $Matches[3]
                $errorCode = $Matches[4]
                $message = $Matches[6]

                Write-Host "`n$errorEmoji $errorNumber. $errorCode Error" -ForegroundColor Red
                Write-Host "   File: $filePath" -ForegroundColor Gray
                Write-Host "   Location: Line $lineNum, Column $colNum" -ForegroundColor Gray
                Write-Host "   Message: $message" -ForegroundColor White

                # Provide specific fix guidance based on error type
                switch ($errorCode) {
                    "CS1591" {
                        Write-Host "   Fix: Add XML documentation comment above the method" -ForegroundColor Cyan
                        Write-Host "   Example: /// `<summary`>Adds two numbers`</summary`>" -ForegroundColor Gray
                    }
                    "CS1570" {
                        Write-Host "   Fix: XML comment has malformed XML - check for unmatched tags" -ForegroundColor Cyan
                        Write-Host "   Common issues: Missing closing tags, unescaped `< or `> characters" -ForegroundColor Gray
                    }
                    "CS0246" {
                        Write-Host "   Fix: Add missing using directive or check namespace" -ForegroundColor Cyan
                    }
                    "CS1061" {
                        Write-Host "   Fix: Check method name spelling or add missing method" -ForegroundColor Cyan
                    }
                    default {
                        Write-Host "   Fix: Review error details and fix the compilation issue" -ForegroundColor Cyan
                    }
                }
            } else {
                # Fallback for lines that don't match expected pattern
                Write-Host "`n$errorEmoji $errorNumber. Unparsed Error:" -ForegroundColor Red
                Write-Host "   Raw: $errorLine" -ForegroundColor White
            }
        }

        if ($filteredErrors.Count -gt $MaxErrors) {
            $remaining = $filteredErrors.Count - $MaxErrors
            Write-Host "`n... and $remaining more errors. Use -MaxErrors to see more." -ForegroundColor Yellow
        }

        Write-Host "`n$errorEmoji Build failed with errors. Fix the issues above and re-run." -ForegroundColor Red
        exit 1

    } else {
        Write-Host "$success Build succeeded with no errors!" -ForegroundColor Green
        exit 0
    }

}
catch {
    $errorEmoji = Get-StatusEmoji 'error'
    Write-Host "$errorEmoji Script failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
finally {
    # Cleanup any remaining jobs
    Get-Job | Where-Object { $_.Name -like 'build-and-find-errors-*' } | Remove-Job -ErrorAction SilentlyContinue
}
