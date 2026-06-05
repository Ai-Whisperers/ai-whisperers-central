#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Applies or validates the repository "Quality Dial" (analyzer severity phases).

.DESCRIPTION
    This repository enforces TreatWarningsAsErrors centrally, so changing analyzer severities
    in `.editorconfig` is effectively how we "turn the dial":

    - suggestion -> warning  == becomes build-breaking (because warnings are treated as errors)
    - temporary relaxations  == allowed only with explicit expiry + ticket id

    This script manages a dedicated block in `.editorconfig` between markers:
      - "# BEGIN QUALITY DIAL (managed by cicd/scripts/quality-dial.ps1)"
      - "# END QUALITY DIAL (managed by cicd/scripts/quality-dial.ps1)"

.PARAMETER Mode
    Validate (default) checks:
      - no expired temporary relaxations
      - `.editorconfig` contains the managed markers

    Apply writes the configured phase into the managed block (idempotent).

.PARAMETER Phase
    Phase name from the config file (e.g. baseline, tighten-1, tighten-2).
    If omitted, uses defaultPhase from config.

.PARAMETER ConfigPath
    Path to the quality dial config json.

.PARAMETER EditorConfigPath
    Path to `.editorconfig` to update/validate.

.PARAMETER DryRun
    When Mode=Apply, shows what would change without writing.

.EXAMPLE
    # Validate current config (default phase only influences output formatting)
    .\quality-dial.ps1 -Mode Validate

.EXAMPLE
    # Apply tighten-1 phase (dry-run)
    .\quality-dial.ps1 -Mode Apply -Phase tighten-1 -DryRun

.EXAMPLE
    # Apply tighten-2 phase (write)
    .\quality-dial.ps1 -Mode Apply -Phase tighten-2
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Validate', 'Apply')]
    [string]$Mode = 'Validate',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Phase,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config\quality-dial.config.json'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$EditorConfigPath,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "modules\ScriptLogging.psm1") -Force

function Resolve-RepoRoot {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    return $repoRoot
}

function Read-JsonFile {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content $Path -Raw
    return ($raw | ConvertFrom-Json -Depth 32)
}

function Get-EditorConfigPath {
    param([Parameter(Mandatory)] [string]$RepoRoot)

    if ($EditorConfigPath) {
        return $EditorConfigPath
    }

    return (Join-Path $RepoRoot '.editorconfig')
}

function Get-PhaseName {
    param(
        [Parameter(Mandatory)] $ConfigObject,
        [string]$RequestedPhase
    )

    $phaseToUse = if ($RequestedPhase) { $RequestedPhase } else { $ConfigObject.defaultPhase }
    if (-not $phaseToUse) {
        throw "No phase provided and config.defaultPhase is empty."
    }

    if (-not $ConfigObject.phases.PSObject.Properties.Name -contains $phaseToUse) {
        $available = ($ConfigObject.phases.PSObject.Properties.Name | Sort-Object) -join ', '
        throw "Unknown phase '$phaseToUse'. Available phases: $available"
    }

    return $phaseToUse
}

function Test-TemporaryRelaxations {
    param([Parameter(Mandatory)] $ConfigObject)

    $today = (Get-Date).Date
    $expired = @()

    foreach ($relaxation in ($ConfigObject.temporaryRelaxations | ForEach-Object { $_ })) {
        if (-not $relaxation) { continue }

        $expiresOnRaw = $relaxation.expiresOn
        if (-not $expiresOnRaw) {
            $expired += $relaxation
            continue
        }

        $expiresOn = [DateTime]::ParseExact($expiresOnRaw, 'yyyy-MM-dd', $null).Date
        if ($expiresOn -lt $today) {
            $expired += $relaxation
        }
    }

    if ($expired.Count -gt 0) {
        Write-Log "" -Level ERROR
        Write-Log "❌ ERROR: Expired temporary relaxations found in quality dial config" -Level ERROR
        Write-Log "" -Level ERROR
        Write-Log "Explanation: Temporary relaxations are allowed only as a controlled, time-boxed escape hatch. Expired relaxations must be removed or explicitly extended to avoid permanent 'temporary' policy." -Level WARN
        Write-Log "" -Level ERROR
        Write-Log "Solution:" -Level INFO
        Write-Log "  1. Edit: $ConfigPath" -Level INFO
        Write-Log "  2. Remove the expired relaxation(s), or extend expiresOn with an explicit decision." -Level INFO
        Write-Log "  3. Re-run: .\\quality-dial.ps1 -Mode Validate" -Level INFO
        Write-Log "" -Level ERROR
        Write-Log "Expired items:" -Level ERROR
        foreach ($item in $expired) {
            $ticket = if ($item.ticketId) { $item.ticketId } else { 'n/a' }
            $id = if ($item.diagnosticId) { $item.diagnosticId } else { 'n/a' }
            $sev = if ($item.severity) { $item.severity } else { 'n/a' }
            $exp = if ($item.expiresOn) { $item.expiresOn } else { 'missing' }
            Write-Log "  - diagnosticId=$id severity=$sev expiresOn=$exp ticketId=$ticket" -Level ERROR
        }

        return $false
    }

    return $true
}

function New-ManagedBlockText {
    param(
        [Parameter(Mandatory)] $ConfigObject,
        [Parameter(Mandatory)] [string]$PhaseName
    )

    $beginMarker = $ConfigObject.managedBlock.beginMarker
    $endMarker = $ConfigObject.managedBlock.endMarker
    if (-not $beginMarker -or -not $endMarker) {
        throw "Config.managedBlock is missing beginMarker/endMarker."
    }

    $phase = $ConfigObject.phases.$PhaseName
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($beginMarker)
    $lines.Add("# Managed by: cicd/scripts/quality-dial.ps1")
    $lines.Add("# Config:      cicd/scripts/config/quality-dial.config.json")
    $lines.Add("# Phase:       $PhaseName")
    $lines.Add("#")
    $lines.Add("# IMPORTANT:")
    $lines.Add("# - TreatWarningsAsErrors is enforced centrally in build settings.")
    $lines.Add("# - Moving a diagnostic from 'suggestion' -> 'warning' effectively makes it a build breaker.")
    $lines.Add("# - Temporary relaxations MUST have an explicit expiry and ticket link.")
    $lines.Add("#")

    $diagnostics = @($ConfigObject.diagnostics | ForEach-Object { $_ })
    foreach ($diag in ($diagnostics | Sort-Object -Property id)) {
        $id = $diag.id
        $desc = $diag.description
        $severity = $phase.severities.$id
        if (-not $severity) {
            throw "Phase '$PhaseName' has no severity for diagnostic '$id'."
        }

        $lines.Add("# ${id}: $desc")
        $lines.Add("dotnet_diagnostic.$id.severity = $severity")
        $lines.Add("#")
    }

    $relaxations = @($ConfigObject.temporaryRelaxations | ForEach-Object { $_ })
    if ($relaxations.Count -gt 0) {
        $lines.Add("# Temporary relaxations (time-boxed):")
        foreach ($r in $relaxations) {
            if (-not $r) { continue }
            $ticketId = if ($r.ticketId) { $r.ticketId } else { 'n/a' }
            $expiresOn = if ($r.expiresOn) { $r.expiresOn } else { 'missing' }
            $reason = if ($r.reason) { $r.reason } else { 'n/a' }
            $lines.Add("# - $($r.diagnosticId) => $($r.severity) (expiresOn=$expiresOn, ticketId=$ticketId) - $reason")
        }
        $lines.Add("#")
    }

    $lines.Add($endMarker)
    return ($lines -join "`n")
}

function Update-EditorConfigManagedBlock {
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string]$NewBlockText,
        [Parameter(Mandatory)] [string]$BeginMarker,
        [Parameter(Mandatory)] [string]$EndMarker,
        [switch]$WriteChanges
    )

    if (-not (Test-Path $FilePath)) {
        throw ".editorconfig not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw

    $beginIndex = $content.IndexOf($BeginMarker, [System.StringComparison]::Ordinal)
    $endIndex = $content.IndexOf($EndMarker, [System.StringComparison]::Ordinal)
    if ($beginIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -lt $beginIndex) {
        throw "Managed markers not found (or invalid order) in: $FilePath"
    }

    $endIndexAfter = $endIndex + $EndMarker.Length
    $currentBlock = $content.Substring($beginIndex, $endIndexAfter - $beginIndex)

    if ($currentBlock -eq $NewBlockText) {
        Write-Log "Quality dial block already up-to-date." -Level SUCCESS
        return $false
    }

    Write-Log "Quality dial block differs from desired phase output." -Level WARN
    if (-not $WriteChanges) {
        Write-Log "DRY RUN: no changes written." -Level WARN
        return $true
    }

    $updated = $content.Substring(0, $beginIndex) + $NewBlockText + $content.Substring($endIndexAfter)
    $updated | Set-Content -Path $FilePath -Encoding UTF8
    Write-Log "Updated quality dial block in: $FilePath" -Level SUCCESS
    return $true
}

$repoRoot = Resolve-RepoRoot
$editorConfigFile = Get-EditorConfigPath -RepoRoot $repoRoot

Write-Log "Mode: $Mode"
Write-Log "Config: $ConfigPath"
Write-Log "EditorConfig: $editorConfigFile"

$config = Read-JsonFile -Path $ConfigPath
$phaseName = Get-PhaseName -ConfigObject $config -RequestedPhase $Phase
Write-Log "Phase: $phaseName"

if (-not (Test-TemporaryRelaxations -ConfigObject $config)) {
    exit 1
}

$beginMarker = $config.managedBlock.beginMarker
$endMarker = $config.managedBlock.endMarker

switch ($Mode) {
    'Validate' {
        $null = Update-EditorConfigManagedBlock `
            -FilePath $editorConfigFile `
            -NewBlockText (New-ManagedBlockText -ConfigObject $config -PhaseName $phaseName) `
            -BeginMarker $beginMarker `
            -EndMarker $endMarker `
            -WriteChanges:$false

        Write-Log "Quality dial validation complete." -Level SUCCESS
        exit 0
    }
    'Apply' {
        $changed = Update-EditorConfigManagedBlock `
            -FilePath $editorConfigFile `
            -NewBlockText (New-ManagedBlockText -ConfigObject $config -PhaseName $phaseName) `
            -BeginMarker $beginMarker `
            -EndMarker $endMarker `
            -WriteChanges:(!$DryRun)

        if ($changed -and $DryRun) {
            Write-Log "Dry-run indicates changes would be applied. Re-run without -DryRun to write." -Level WARN
        }

        Write-Log "Quality dial apply complete." -Level SUCCESS
        exit 0
    }
}


