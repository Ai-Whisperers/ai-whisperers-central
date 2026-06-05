#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
Scan markdown-like artifacts for broken internal links and missing targets.

.DESCRIPTION
Parses links in markdown/prompt/rule files and checks that referenced local
paths exist. Reports broken internal links and emits JSON when requested.

.PARAMETER Folder
Folder to scan (default: repo root).

.PARAMETER Json
Output report as JSON (suppresses progress/console summary).

.PARAMETER PassThru
Return report object.

.EXAMPLE
.\update-cross-references.ps1
Scan repo root for broken links.

.EXAMPLE
.\update-cross-references.ps1 -Folder ".cursor/rules" -Json
Emit JSON for rules folder.
#>
[CmdletBinding()]
param(
    [Parameter()][ValidateScript({ Test-Path $_ })][string]$Folder = $(Get-Location).Path,
    [Parameter()][switch]$Json,
    [Parameter()][switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($Json) { $ProgressPreference = 'SilentlyContinue' }

# Import shared utilities
$ModulePath = Join-Path $PSScriptRoot "..\\modules\\Common.psm1"
Import-Module $ModulePath -Force

try {
    $root = Resolve-Path -Path $Folder -ErrorAction Stop
    $files = Get-ChildItem -Path $root.Path -Recurse -File -Include *.md,*.mdc,*.prompt.md
    if ((Split-Path -Path $root.Path -Leaf) -eq '.cursor') {
        # In this repo, .cursor/rules are treated as authored artifacts and may contain illustrative links
        # that aren't intended to resolve locally. Keep .cursor link validation focused on actionable
        # maintenance surfaces (prompts, scripts, exemplars, etc.).
        $files = $files | Where-Object { $_.FullName -notmatch '\\\.cursor\\rules\\' }
    }

    $broken = @()
    foreach ($f in $files) {
        $content = Get-Content -Raw -Path $f.FullName
        # Ignore links inside fenced code blocks (typically illustrative examples).
        $contentWithoutFencedCode = [regex]::Replace($content, '(?s)```.*?```', '')
        $matches = [regex]::Matches($contentWithoutFencedCode, '\[[^\]]+\]\(([^)]+)\)')
        foreach ($m in $matches) {
            $link = $m.Groups[1].Value.Trim()
            if ($link -match '^(http|https|mailto):') { continue }
            if ($link -match '^#') { continue }
            if ($link -match '^@') { continue }
            $parts = $link -split '#'
            $pathPart = $parts[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            if ($pathPart -match '\{\{[^}]+\}\}') { continue } # placeholder token (e.g. {{TOKEN}})
            if ($pathPart -match '\[[^\]]+\]') { continue }    # placeholder token (e.g. [TICKET_ID])
            $leafName = Split-Path -Path $pathPart -Leaf
            if ($leafName -match '(-specification-file|-file)\.md$') { continue } # example placeholder files
            if ($pathPart -match '(^|/|\\)other-domain(/|\\)') { continue }        # example placeholder paths
            if ($leafName -in @(
                'domain-database-schema.md',
                'domain-business-rules.md',
                'implementation-guide.md',
                'integration-points.md',
                'formula-type-enum.md',
                'enum-name-enum.md',
                'specification.md'
            )) { continue } # example placeholder files
            if ($pathPart -match '(^|/|\\)(technical|implementation)(/|\\)domain(/|\\)') { continue } # example placeholder folders
            $candidate = if ($pathPart.StartsWith('/')) {
                Join-Path $root.Path $pathPart.TrimStart('/')
            } else {
                Join-Path $f.DirectoryName $pathPart
            }
            if (-not (Test-Path -Path $candidate)) {
                $resolvedBase = Resolve-Path -LiteralPath (Split-Path -Path $candidate -Parent) -ErrorAction SilentlyContinue
                $resolvedPath = $null
                if ($resolvedBase) {
                    $resolvedPath = Normalize((Join-Path $resolvedBase.Path (Split-Path -Leaf $candidate)))
                }

                $broken += [pscustomobject]@{
                    File    = Normalize($f.FullName.Substring($root.Path.Length + 1))
                    Link    = $link
                    Resolved= $resolvedPath
                }
            }
        }
    }

    $report = [pscustomobject]@{
        Folder    = $root.Path
        Scanned   = @($files).Count
        Broken    = $broken
        BrokenCount = @($broken).Count
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 5
        if ($broken.Count -gt 0) { exit 1 } else { exit 0 }
    }

    Write-Host "Folder: $($root.Path)" -ForegroundColor Gray
    Write-Host "Files scanned: $(@($files).Count)" -ForegroundColor Gray
    if ($broken.Count -gt 0) {
        Write-Host "$(Get-StatusGlyph 'error') Broken links: $($broken.Count)" -ForegroundColor Red
        $broken | Select-Object -First 50 | ForEach-Object { Write-Host " - $($_.File) -> $($_.Link)" -ForegroundColor Red }
        if ($broken.Count -gt 50) { Write-Host " ... truncated ..." -ForegroundColor Red }
    } else {
        Write-Host "$(Get-StatusGlyph 'success') No broken internal links detected." -ForegroundColor Green
    }

    if ($PassThru) { $report }
    if ($broken.Count -gt 0) { exit 1 } else { exit 0 }
}
catch {
    Write-Host "$(Get-StatusGlyph 'error') Failure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}


