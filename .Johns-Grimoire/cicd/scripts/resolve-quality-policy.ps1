#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
    Resolves the CI/CD quality policy for the current build context.
.DESCRIPTION
    Loads the default policy and optional override policy, selects the best matching
    context for the current branch/tag/reason, and emits:
      - A JSON policy report
      - A markdown summary (uploaded to pipeline summary when supported)
      - Pipeline variables for gate enablement and severity
.PARAMETER DefaultPolicyPath
    Path to the default policy JSON.
.PARAMETER OverridePolicyPath
    Path to the optional override policy JSON.
.PARAMETER OutputPath
    Directory for policy report artifacts.
.PARAMETER SourceBranch
    Build.SourceBranch override (for local testing).
.PARAMETER BuildReason
    Build.Reason override (for local testing).
.PARAMETER SetPipelineVariables
    Emit pipeline variables (##vso[task.setvariable]) if running in Azure DevOps.
.PARAMETER OutputVariables
    Mark pipeline variables as output variables (for stage/job dependencies).
.EXAMPLE
    .\resolve-quality-policy.ps1 -OutputPath .\out\policy
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DefaultPolicyPath = (Join-Path $PSScriptRoot '..\config\quality-policy.default.json'),

    [Parameter()]
    [string]$OverridePolicyPath = (Join-Path $PSScriptRoot '..\config\quality-policy.override.json'),

    [Parameter()]
    [string]$OutputPath = (Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY 'policy-report'),

    [Parameter()]
    [string]$SourceBranch,

    [Parameter()]
    [string]$BuildReason,

    [Parameter()]
    [bool]$SetPipelineVariables = $true,

    [Parameter()]
    [bool]$OutputVariables = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\ScriptLogging.psm1') -Force

function Write-PolicyError {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [Parameter(Mandatory)] [string]$Explanation,
        [Parameter(Mandatory)] [string]$Solution,
        [Parameter(Mandatory)] [string]$Location
    )

    Write-Log "" -Level ERROR
    Write-Log "❌ ERROR: $Message" -Level ERROR
    Write-Log "" -Level ERROR
    Write-Log "Explanation: $Explanation" -Level WARN
    Write-Log "" -Level ERROR
    Write-Log "Solution: $Solution" -Level INFO
    Write-Log "Location: $Location" -Level INFO
    Write-Log "" -Level ERROR
}

function Read-JsonFile {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path $Path)) {
        Write-PolicyError `
            -Message "Quality policy file not found" `
            -Explanation "The policy resolver requires a default policy file to determine which gates to run." `
            -Solution "Create the policy file or update the path. Example: cicd/config/quality-policy.default.json" `
            -Location $Path
        throw "Missing policy file: $Path"
    }

    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json -Depth 32)
    } catch {
        Write-PolicyError `
            -Message "Quality policy file is invalid JSON" `
            -Explanation "Policy parsing failed, so gate resolution cannot proceed." `
            -Solution "Fix the JSON syntax and re-run the policy resolver." `
            -Location $Path
        throw
    }
}

function Convert-ToHashtable {
    param([Parameter(Mandatory)] $InputObject)

    if ($InputObject -is [hashtable]) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) { return @{} + $InputObject }
    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += (Convert-ToHashtable -InputObject $item)
        }
        return $items
    }

    if ($InputObject -is [psobject]) {
        $hash = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = Convert-ToHashtable -InputObject $prop.Value
        }
        return $hash
    }

    return $InputObject
}

function Merge-PolicyObject {
    param(
        [Parameter(Mandatory)] $Base,
        [Parameter()] $Override
    )

    if ($null -eq $Override) { return $Base }
    if ($null -eq $Base) { return $Override }

    if ($Base -is [System.Collections.IDictionary] -and $Override -is [System.Collections.IDictionary]) {
        $merged = @{} + $Base
        foreach ($key in $Override.Keys) {
            if ($merged.ContainsKey($key)) {
                $merged[$key] = Merge-PolicyObject -Base $merged[$key] -Override $Override[$key]
            } else {
                $merged[$key] = $Override[$key]
            }
        }
        return $merged
    }

    if ($Base -is [System.Collections.IEnumerable] -and $Override -is [System.Collections.IEnumerable] -and
        -not ($Base -is [string]) -and -not ($Override -is [string])) {

        $baseList = @($Base)
        $overrideList = @($Override)

        $byName = @{}
        foreach ($item in $baseList) {
            if ($item -is [System.Collections.IDictionary] -and $item.Contains('name')) {
                $byName[$item.name] = $item
            }
        }

        foreach ($item in $overrideList) {
            if ($item -is [System.Collections.IDictionary] -and $item.Contains('name')) {
                if ($byName.ContainsKey($item.name)) {
                    $byName[$item.name] = Merge-PolicyObject -Base $byName[$item.name] -Override $item
                } else {
                    $byName[$item.name] = $item
                }
            } else {
                $baseList += $item
            }
        }

        return @($byName.Values) + ($baseList | Where-Object { $_ -isnot [System.Collections.IDictionary] -or -not $_.Contains('name') })
    }

    return $Override
}

function Test-PolicyMatch {
    param(
        [Parameter(Mandatory)] [hashtable]$Match,
        [Parameter(Mandatory)] [string]$SourceBranch,
        [Parameter(Mandatory)] [string]$BuildReason,
        [Parameter()] [string]$TagName = ''
    )

    if ($Match.ContainsKey('reason') -and $Match.reason) {
        if ($BuildReason -ne $Match.reason) { return $false }
    }

    if ($Match.ContainsKey('branch') -and $Match.branch) {
        if ($SourceBranch -ne $Match.branch) { return $false }
    }

    if ($Match.ContainsKey('branchPrefix') -and $Match.branchPrefix) {
        if (-not $SourceBranch.StartsWith($Match.branchPrefix)) { return $false }
    }

    if ($Match.ContainsKey('branchRegex') -and $Match.branchRegex) {
        if ($SourceBranch -notmatch $Match.branchRegex) { return $false }
    }

    if ($Match.ContainsKey('tagPrefix') -and $Match.tagPrefix) {
        if (-not $TagName) { return $false }
        if (-not $TagName.StartsWith($Match.tagPrefix)) { return $false }
    }

    if ($Match.ContainsKey('tagRegex') -and $Match.tagRegex) {
        if (-not $TagName) { return $false }
        if ($TagName -notmatch $Match.tagRegex) { return $false }
    }

    return $true
}

function Get-ResolvedPolicy {
    param(
        [Parameter(Mandatory)] [hashtable]$Policy,
        [Parameter(Mandatory)] [string]$SourceBranch,
        [Parameter(Mandatory)] [string]$BuildReason,
        [Parameter()] [string]$TagName = ''
    )

    $contexts = @($Policy.contexts | ForEach-Object { $_ })
    $selectedContext = $null

    foreach ($context in $contexts) {
        $match = @{}
        if ($context.match) { $match = $context.match }

        if (Test-PolicyMatch -Match $match -SourceBranch $SourceBranch -BuildReason $BuildReason -TagName $TagName) {
            $selectedContext = $context
            break
        }
    }

    if (-not $selectedContext -and $Policy.defaultContext) {
        $selectedContext = $contexts | Where-Object { $_.name -eq $Policy.defaultContext } | Select-Object -First 1
    }

    $defaults = $Policy.defaults
    $resolved = $defaults

    if ($selectedContext -and $selectedContext.overrides) {
        $resolved = Merge-PolicyObject -Base $defaults -Override $selectedContext.overrides
    }

    return @{
        Context = $selectedContext
        Resolved = $resolved
    }
}

function ConvertTo-PolicyGateName {
    param([Parameter(Mandatory)] [string]$Name)
    return ($Name -replace '[^A-Za-z0-9]', '_')
}

function Set-PolicyVariable {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Value,
        [switch]$AsOutput
    )

    $outputFlag = if ($AsOutput) { ';isOutput=true' } else { '' }
    Write-Host "##vso[task.setvariable variable=$Name$outputFlag]$Value"
}

function Test-PolicyDefinition {
    param([Parameter(Mandatory)] [hashtable]$Policy, [Parameter(Mandatory)] [string]$PolicyPath)

    if (-not $Policy.ContainsKey('defaults')) {
        Write-PolicyError `
            -Message "Policy defaults missing" `
            -Explanation "The policy must define default gates to ensure predictable behavior." `
            -Solution "Add a 'defaults.gates' section to the policy JSON." `
            -Location $PolicyPath
        throw "Policy defaults missing"
    }

    $gates = $Policy.defaults.gates
    if (-not $gates) {
        Write-PolicyError `
            -Message "Policy gates missing" `
            -Explanation "No gate settings were found, so the resolver cannot determine which checks to run." `
            -Solution "Define gates under defaults.gates in the policy JSON." `
            -Location $PolicyPath
        throw "Policy gates missing"
    }

    $validSeverities = @('info', 'warning', 'error')
    foreach ($gateName in $gates.Keys) {
        $gate = $gates[$gateName]
        if (-not $gate.ContainsKey('severity') -or -not $gate.severity) {
            Write-PolicyError `
                -Message "Gate severity missing for '$gateName'" `
                -Explanation "Severity is required to map gate outcomes to info/warn/error." `
                -Solution "Set severity to one of: info, warning, error." `
                -Location $PolicyPath
            throw "Gate severity missing: $gateName"
        }

        if ($validSeverities -notcontains $gate.severity) {
            Write-PolicyError `
                -Message "Invalid severity '$($gate.severity)' for gate '$gateName'" `
                -Explanation "Severity must be info, warning, or error to map to pipeline outcomes." `
                -Solution "Update the gate severity to one of: info, warning, error." `
                -Location $PolicyPath
            throw "Invalid severity for gate: $gateName"
        }
    }
}

$defaultPolicy = Convert-ToHashtable (Read-JsonFile -Path $DefaultPolicyPath)
$overridePolicy = if (Test-Path $OverridePolicyPath) { Convert-ToHashtable (Read-JsonFile -Path $OverridePolicyPath) } else { $null }

$policy = if ($null -ne $overridePolicy) {
    Merge-PolicyObject -Base $defaultPolicy -Override $overridePolicy
} else {
    $defaultPolicy
}

Test-PolicyDefinition -Policy $policy -PolicyPath $DefaultPolicyPath

$sourceBranch = if ($SourceBranch) { $SourceBranch } elseif ($env:BUILD_SOURCEBRANCH) { $env:BUILD_SOURCEBRANCH } else { '' }
$buildReason = if ($BuildReason) { $BuildReason } elseif ($env:BUILD_REASON) { $env:BUILD_REASON } else { '' }
$tagName = ''
if ($sourceBranch -like 'refs/tags/*') {
    $tagName = if ($env:BUILD_SOURCEBRANCHNAME) { $env:BUILD_SOURCEBRANCHNAME } else { $sourceBranch.Replace('refs/tags/', '') }
}

$resolvedPolicy = Get-ResolvedPolicy -Policy $policy -SourceBranch $sourceBranch -BuildReason $buildReason -TagName $tagName
$context = $resolvedPolicy.Context
$resolved = $resolvedPolicy.Resolved

$contextName = if ($context) { $context.name } else { 'default' }
$contextDescription = if ($context -and $context.description) { $context.description } else { 'Default policy context selected.' }

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
}

$report = [ordered]@{
    schemaVersion = $policy.schemaVersion
    selectedContext = $contextName
    contextDescription = $contextDescription
    sourceBranch = $sourceBranch
    buildReason = $buildReason
    tagName = $tagName
    resolvedGates = $resolved.gates
}

$reportJsonPath = Join-Path $OutputPath 'policy-report.json'
$report | ConvertTo-Json -Depth 32 | Out-File -FilePath $reportJsonPath -Encoding UTF8

$reportMdPath = Join-Path $OutputPath 'policy-report.md'
$gateLines = $resolved.gates.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $enabled = if ($_.Value.enabled) { '✅' } else { '⛔' }
    $severity = if ($_.Value.severity) { $_.Value.severity } else { 'n/a' }
    $autoFix = if ($_.Value.autoFix) { $_.Value.autoFix } else { 'n/a' }
    "- $enabled **$($_.Key)** (severity: $severity, autoFix: $autoFix)"
}

@"
# CI/CD Quality Policy Report

**Context**: $contextName  
**Reason**: $contextDescription  
**Source Branch**: $sourceBranch  
**Build Reason**: $buildReason  
**Tag**: $tagName  

## Resolved Gates
$($gateLines -join "`n")
"@ | Out-File -FilePath $reportMdPath -Encoding UTF8

if ($SetPipelineVariables) {
    Set-PolicyVariable -Name 'QualityPolicy_Context' -Value $contextName -AsOutput:$OutputVariables
    Set-PolicyVariable -Name 'QualityPolicy_Reason' -Value $contextDescription -AsOutput:$OutputVariables

    foreach ($gateName in $resolved.gates.Keys) {
        $gate = $resolved.gates[$gateName]
        $safeName = ConvertTo-PolicyGateName -Name $gateName
        $enabledValue = if ($gate.enabled) { 'true' } else { 'false' }
        $severityValue = if ($gate.severity) { $gate.severity } else { 'error' }
        $autoFixValue = if ($gate.autoFix) { $gate.autoFix } else { 'none' }

        Set-PolicyVariable -Name "QualityGate_${safeName}_Enabled" -Value $enabledValue -AsOutput:$OutputVariables
        Set-PolicyVariable -Name "QualityGate_${safeName}_Severity" -Value $severityValue -AsOutput:$OutputVariables
        Set-PolicyVariable -Name "QualityGate_${safeName}_AutoFix" -Value $autoFixValue -AsOutput:$OutputVariables
    }
}

Write-Host "##vso[task.uploadsummary]$reportMdPath"
Write-Log "Resolved policy context: $contextName"
Write-Log "Policy report written to: $OutputPath"
