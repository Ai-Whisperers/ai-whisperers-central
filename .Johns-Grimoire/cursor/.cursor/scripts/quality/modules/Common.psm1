#Requires -Version 7.2
#Requires -PSEdition Core

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Unicode {
    $psVersion = $PSVersionTable.PSVersion.Major
    $inAzure = $null -ne $env:AGENT_TEMPDIRECTORY
    $isUtf8Console = $false

    try {
        $isUtf8Console = [Console]::OutputEncoding.CodePage -eq 65001
    } catch {
        # Some hosts may not allow reading console encoding; treat as non-UTF8.
        $isUtf8Console = $false
    }

    return ($psVersion -ge 7) -or $inAzure -or $isUtf8Console
}

function Get-StatusEmoji {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('success', 'warning', 'error', 'info', 'step')]
        [string]$Status
    )

    if (-not (Test-Unicode)) {
        return @{
            success = '[OK]'
            warning = '[WARN]'
            error   = '[ERR]'
            info    = '[INFO]'
            step    = '[STEP]'
        }[$Status]
    }

    return @{
        success = '✅'
        warning = '⚠️'
        error   = '❌'
        info    = 'ℹ️'
        step    = '🔹'
    }[$Status]
}

function Write-Section {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('=' * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('=' * 80) -ForegroundColor Cyan
    Write-Host ''
}

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $step = Get-StatusEmoji -Status step
    Write-Host "`n$step $Message" -ForegroundColor Cyan
}

function Write-InfoMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $emoji = Get-StatusEmoji -Status info
    Write-Host "$emoji $Message" -ForegroundColor Gray
}

function Write-SuccessMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $emoji = Get-StatusEmoji -Status success
    Write-Host "$emoji $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $emoji = Get-StatusEmoji -Status warning
    Write-Host "$emoji $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $emoji = Get-StatusEmoji -Status error
    Write-Host "$emoji $Message" -ForegroundColor Red
}

function Get-RepoRoot {
    param(
        [Parameter(Mandatory = $false)]
        [string]$StartPath = (Get-Location).Path
    )

    $resolved = Resolve-Path -Path $StartPath -ErrorAction SilentlyContinue
    $cursor = if ($resolved) { $resolved.Path } else { $StartPath }

    # Prefer git if available (more reliable than directory heuristics).
    try {
        $gitRoot = (& git -C $cursor rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot) -and (Test-Path $gitRoot)) {
            return (Resolve-Path $gitRoot).Path
        }
    } catch {
        # Ignore, fall back to walking.
    }

    while ($cursor) {
        if (Test-Path (Join-Path $cursor '.git')) { return $cursor }
        if (Test-Path (Join-Path $cursor 'Directory.Build.props')) { return $cursor }
        if (Test-Path (Join-Path $cursor '*.sln')) { return $cursor }

        $parent = Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }

    return (Resolve-Path -Path (Get-Location).Path).Path
}

Export-ModuleMember -Function `
    Test-Unicode, `
    Get-StatusEmoji, `
    Write-Section, `
    Write-Step, `
    Write-InfoMessage, `
    Write-SuccessMessage, `
    Write-WarningMessage, `
    Write-ErrorMessage, `
    Get-RepoRoot


