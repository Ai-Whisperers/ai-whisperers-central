#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
Find templars/exemplars with no consumers and missing metadata.

.DESCRIPTION
Scans templars and exemplars under a prompts root, checks frontmatter fields,
and searches consumer roots for references. Reports dead candidates (no
references and missing consumed-by/illustrates) plus metadata gaps.

.PARAMETER PromptsRoot
Root folder containing prompts/templars/exemplars. Default: repo/.cursor/prompts

.PARAMETER SearchRoots
Folders to scan for references (Select-String). Default: repo root (.)

.PARAMETER Json
Output report as JSON (progress suppressed).

.PARAMETER PassThru
Return report object instead of console summary.

.EXAMPLE
.\find-dead-templars-exemplars.ps1
Console summary for .cursor/prompts using repo root as search scope.

.EXAMPLE
.\find-dead-templars-exemplars.ps1 -PromptsRoot ".cursor/prompts" -SearchRoots "."
Scan default prompts root and repo for references.

.EXAMPLE
.\find-dead-templars-exemplars.ps1 -Json
Emit JSON for automation.
#>
[CmdletBinding()]
param(
    [Parameter()][ValidateScript({ Test-Path $_ })][string]$PromptsRoot = $(if ($PSScriptRoot) { Join-Path $PSScriptRoot "..\\.cursor\\prompts" } else { Join-Path (Get-Location).Path ".cursor\\prompts" }),
    [Parameter()][ValidateScript({ ($_ | ForEach-Object { Test-Path $_ }) -notcontains $false })][string[]]$SearchRoots = @("."),
    [Parameter()][switch]$Json,
    [Parameter()][switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($Json) { $ProgressPreference = 'SilentlyContinue' }

# Import shared utilities
$ModulePath = Join-Path $PSScriptRoot "..\\modules\\Common.psm1"
Import-Module $ModulePath -Force

function Load-Frontmatter {
    param([string]$FilePath)
    $data = @{
        Implements   = @()
        Illustrates  = @()
        ConsumedBy   = @()
        ExtractedFrom= @()
    }
    $lines = Get-Content -Path $FilePath -TotalCount 120 -ErrorAction Stop
    $inHeader = $false
    $activeListKey = $null
    foreach ($line in $lines) {
        if ($line -match '^---\s*$') {
            $inHeader = -not $inHeader
            if (-not $inHeader) { break }
            continue
        }
        if ($inHeader) {
            # Support both scalar and YAML list forms:
            #   consumed-by: some/path
            #   consumed-by:
            #     - some/path
            if ($line -match '^\s*(implements|illustrates|consumed-by|extracted-from):\s*(.*)$') {
                $key = $Matches[1].Trim().ToLowerInvariant()
                $value = $Matches[2].Trim()

                if ($value) {
                    switch ($key) {
                        'implements'      { $data.Implements += $value }
                        'illustrates'     { $data.Illustrates += $value }
                        'consumed-by'     { $data.ConsumedBy += $value }
                        'extracted-from'  { $data.ExtractedFrom += $value }
                    }
                    $activeListKey = $null
                }
                else {
                    $activeListKey = $key
                }

                continue
            }

            if ($activeListKey -and $line -match '^\s*-\s*(.+)$') {
                $value = $Matches[1].Trim()
                if ($value) {
                    switch ($activeListKey) {
                        'implements'      { $data.Implements += $value }
                        'illustrates'     { $data.Illustrates += $value }
                        'consumed-by'     { $data.ConsumedBy += $value }
                        'extracted-from'  { $data.ExtractedFrom += $value }
                    }
                }
                continue
            }
        }
    }
    return $data
}

function Get-SearchPatterns {
    param(
        [Parameter(Mandatory)][string]$ItemPath,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][hashtable]$Meta
    )

    $patterns = @()

    # Prefer matching concrete file paths over basenames to avoid false positives
    # (e.g., "README" matches everywhere but is not a meaningful consumer reference).
    $patterns += $ItemPath
    $patterns += ".cursor/prompts/$ItemPath"
    $patterns += ($ItemPath -replace '/','\\')
    $patterns += (".cursor\\prompts\\" + ($ItemPath -replace '/','\\'))

    $basename = [IO.Path]::GetFileNameWithoutExtension($ItemPath)
    if ($basename -and $basename -notin @('README')) {
        $patterns += $basename
    }

    if ($Kind -eq 'templar' -and $Meta.ContainsKey('Implements') -and $Meta.Implements) {
        $patterns += @($Meta.Implements)
    }
    if ($Kind -eq 'exemplar' -and $Meta.ContainsKey('Illustrates') -and $Meta.Illustrates) {
        $patterns += @($Meta.Illustrates)
    }

    return ($patterns | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -Unique)
}

function Is-MeaningfulReference {
    param(
        [Parameter(Mandatory)][string]$MatchPath
    )

    # Avoid treating ticket/conversation docs as "real consumers" of templars/exemplars.
    # Those files can mention artifacts for housekeeping work, but they don't represent
    # prompt/rule usage in the active library.
    $p = Normalize($MatchPath)
    if ($p -match '(^|/)(tickets|conversations|archive)/') { return $false }
    return $true
}

try {
    $root = Resolve-Path -Path $PromptsRoot -ErrorAction Stop
    $templars =
        Get-ChildItem -Path (Join-Path $root.Path "templars") -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' }

    $exemplars =
        Get-ChildItem -Path (Join-Path $root.Path "exemplars") -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' }

    $searchFileCache = @{}
    function Get-SearchFiles {
        param([Parameter(Mandatory)][string]$RootPath)

        if ($searchFileCache.ContainsKey($RootPath)) { return $searchFileCache[$RootPath] }

        # When scanning from repo root ("."), limit to .cursor/ to keep the scan
        # focused on real prompt/rule consumers and to avoid unnecessary work.
        $scanRoot = $RootPath
        $cursorRoot = Join-Path $RootPath ".cursor"
        if (Test-Path -Path $cursorRoot) { $scanRoot = $cursorRoot }

        $files =
            Get-ChildItem -Path $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $p = Normalize($_.FullName)
                if ($p -match '(^|/)\.git(/|$)') { return $false }
                if ($p -match '(^|/)(out|local-reports)(/|$)') { return $false }
                if ($p -match '(^|/)(coverage-final|coverage-final-report|coverage-precheck|coverage-report|coverage-report2|coverage-results|coverage-temp|coverage-temp2)(/|$)') { return $false }

                # Likely consumer file types
                if ($_.Name -like '*.prompt.md') { return $true }
                return $_.Extension -in @('.md', '.mdc', '.ps1', '.yml', '.yaml', '.cs', '.json')
            } |
            Select-Object -ExpandProperty FullName

        $searchFileCache[$RootPath] = $files
        return $files
    }

    $items = @()
    foreach ($f in $templars) {
        $meta = Load-Frontmatter -FilePath $f.FullName
        $items += [pscustomobject]@{
            Path          = Normalize($f.FullName.Substring($root.Path.Length + 1))
            Kind          = 'templar'
            Meta          = $meta
        }
    }
    foreach ($f in $exemplars) {
        $meta = Load-Frontmatter -FilePath $f.FullName
        $items += [pscustomobject]@{
            Path          = Normalize($f.FullName.Substring($root.Path.Length + 1))
            Kind          = 'exemplar'
            Meta          = $meta
        }
    }

    $results = @()
    foreach ($item in $items) {
        $needFields = @()
        if ($item.Kind -eq 'templar' -and ($item.Meta.ConsumedBy.Count -eq 0)) { $needFields += 'consumed-by' }
        if ($item.Kind -eq 'exemplar' -and ($item.Meta.Illustrates.Count -eq 0)) { $needFields += 'illustrates' }
        if ($item.Meta.Implements.Count -eq 0 -and $item.Kind -eq 'templar') { $needFields += 'implements' }
        if ($item.Meta.ExtractedFrom.Count -eq 0 -and $item.Kind -eq 'exemplar') { $needFields += 'extracted-from' }

        $matches = @()
        $patterns = Get-SearchPatterns -ItemPath $item.Path -Kind $item.Kind -Meta $item.Meta
        foreach ($sr in $SearchRoots) {
            $scope = Resolve-Path -Path $sr -ErrorAction Stop
            $searchFiles = Get-SearchFiles -RootPath $scope.Path
            foreach ($pat in $patterns) {
                $matches += Select-String -Path $searchFiles -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue
            }
        }

        $selfPath = Normalize((Join-Path $root.Path $item.Path))
        $meaningfulMatches =
            @($matches) |
            Where-Object { $_.Path } |
            Where-Object { (Normalize($_.Path)) -ne $selfPath } |
            Where-Object { Is-MeaningfulReference -MatchPath $_.Path }

        $refCount = @($meaningfulMatches).Count
        $isDead = $false
        if ($refCount -eq 0) {
            if ($item.Kind -eq 'templar' -and ($item.Meta.ConsumedBy.Count -eq 0)) { $isDead = $true }
            if ($item.Kind -eq 'exemplar' -and ($item.Meta.Illustrates.Count -eq 0)) { $isDead = $true }
        }

        $results += [pscustomobject]@{
            Path            = $item.Path
            Kind            = $item.Kind
            References      = $refCount
            MissingMetadata = $needFields
            DeadCandidate   = $isDead
        }
    }

    $dead = $results | Where-Object { $_.DeadCandidate }
    $missingMeta = $results | Where-Object { $_.MissingMetadata.Count -gt 0 }

    $report = [pscustomobject]@{
        PromptsRoot    = $root.Path
        TotalTemplars  = @($templars).Count
        TotalExemplars = @($exemplars).Count
        DeadCount      = @($dead).Count
        MissingMeta    = $missingMeta
        Dead           = $dead
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 5
        if (($dead.Count -gt 0) -or ($missingMeta.Count -gt 0)) { exit 1 } else { exit 0 }
    }

    Write-Host "Prompts root: $($root.Path)" -ForegroundColor Gray
    Write-Host "Templars: $(@($templars).Count)  Exemplars: $(@($exemplars).Count)" -ForegroundColor Gray
    if ($dead.Count -gt 0) {
        Write-Host "$(Get-StatusGlyph 'error') Dead candidates: $($dead.Count)" -ForegroundColor Red
        $dead | ForEach-Object { Write-Host " - $($_.Path) (refs=$($_.References))" -ForegroundColor Red }
    } else {
        Write-Host "$(Get-StatusGlyph 'success') No dead templars/exemplars detected." -ForegroundColor Green
    }
    if ($missingMeta.Count -gt 0) {
        Write-Host "$(Get-StatusGlyph 'warning') Missing metadata: $($missingMeta.Count)" -ForegroundColor Yellow
        $missingMeta | ForEach-Object { Write-Host " - $($_.Path): $(@($_.MissingMetadata) -join ', ')" -ForegroundColor Yellow }
    } else {
        Write-Host "$(Get-StatusGlyph 'success') Metadata present for all checked fields." -ForegroundColor Green
    }

    if ($PassThru) { $report }

    if (($dead.Count -gt 0) -or ($missingMeta.Count -gt 0)) { exit 1 } else { exit 0 }
}
catch {
    Write-Host "$(Get-StatusGlyph 'error') Failure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}


