#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Catalog a tab-delimited diagnostics export into per-code extracts (optionally into ticket subfolders).

.DESCRIPTION
    Parses a tab-delimited diagnostics export (e.g., Visual Studio Error List "Copy" output saved as TSV)
    containing at least columns: Severity, Code, Description, Project, File, Line.

    Produces:
    - A code counts report (console + optional JSON/TSV)
    - Per-code TSV extracts
    - Optional ticket-style folder creation for triage workflows

    This script is intentionally build-free: it does NOT build and does NOT run tests.

.PARAMETER ConfigFile
    Optional JSON config file. Values are used only when the corresponding parameter was not provided explicitly.

.PARAMETER InputPath
    Path to the tab-delimited diagnostics export (TSV). Must exist.

.PARAMETER RunId
    Run identifier used in output paths and filenames (e.g., "run1").

.PARAMETER OutputRoot
    Root folder for outputs when not writing into ticket folders. Default: directory containing InputPath.

.PARAMETER SummaryOnly
    If set, only prints the code counts summary and writes no per-code extracts.

.PARAMETER CreateTicketFolders
    If set, creates ticket-style subfolders under TicketRoot and writes per-code extracts into each folder.

.PARAMETER TicketRoot
    Required when -CreateTicketFolders is set. Example:
    tickets/EPP-192/EPP-192-CODEQUALITY

.PARAMETER TicketPrefix
    Used when creating ticket-style subfolders. Example: "EPP-192-CODEQUALITY".
    Subfolders will be created like:
      <TicketPrefix>-01-<CODE>-<SLUG>/

.PARAMETER OverwriteExisting
    If set, overwrites existing per-code extract files.

.PARAMETER JsonSummaryPath
    Optional file path to write the code counts summary as JSON.

.EXAMPLE
    .\catalog-diagnostics.ps1 -InputPath tickets\EPP-192\EPP-192-CODEQUALITY\data\run1\output.log -SummaryOnly
    Prints code counts only.

.EXAMPLE
    .\catalog-diagnostics.ps1 -InputPath tickets\EPP-192\EPP-192-CODEQUALITY\data\run1\output.log `
        -CreateTicketFolders -TicketRoot tickets\EPP-192\EPP-192-CODEQUALITY -TicketPrefix EPP-192-CODEQUALITY -RunId run1
    Creates one subfolder per diagnostic code and writes TSV extracts into each ticket's data/run1 folder.

.NOTES
    Exit codes:
      0 = success
      2 = invalid configuration / invalid input file format
      5 = runtime failure
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Optional JSON config file; CLI params override config")]
    [string]$ConfigFile = "",

    [Parameter(Mandatory, HelpMessage = "Path to the tab-delimited diagnostics export (TSV)")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Run identifier used in output paths/filenames")]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,30}$')]
    [string]$RunId = "run1",

    [Parameter(Mandatory = $false, HelpMessage = "Root folder for outputs when not creating ticket folders")]
    [string]$OutputRoot = "",

    [Parameter(Mandatory = $false, HelpMessage = "Only print counts; do not write extracts")]
    [switch]$SummaryOnly,

    [Parameter(Mandatory = $false, HelpMessage = "Create ticket-style subfolders under TicketRoot")]
    [switch]$CreateTicketFolders,

    [Parameter(Mandatory = $false, HelpMessage = "When creating ticket folders, prefer existing per-code folders under TicketRoot (stable numbering across reruns)")]
    [switch]$PreferExistingTicketFolders,

    [Parameter(Mandatory = $false, HelpMessage = "Ticket folder root (required with -CreateTicketFolders)")]
    [string]$TicketRoot = "",

    [Parameter(Mandatory = $false, HelpMessage = "Ticket prefix (required with -CreateTicketFolders), e.g. EPP-192-CODEQUALITY")]
    [ValidatePattern('^[A-Z]{2,10}-\d{1,6}(?:-[A-Z0-9-]{1,40})?$')]
    [string]$TicketPrefix = "",

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite existing extracts")]
    [switch]$OverwriteExisting,

    [Parameter(Mandatory = $false, HelpMessage = "Optional JSON output path for code-count summary")]
    [string]$JsonSummaryPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path $PSCommandPath -Parent

# Shared helpers
$commonModule = Join-Path $scriptDir 'modules\Common.psm1'
if (Test-Path $commonModule) { Import-Module $commonModule -Force }

function Write-InfoSafe([string]$Message) {
    if (Get-Command Write-InfoMessage -ErrorAction SilentlyContinue) { Write-InfoMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Gray
}
function Write-ErrorSafe([string]$Message) {
    if (Get-Command Write-ErrorMessage -ErrorAction SilentlyContinue) { Write-ErrorMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Red
}
function Write-SuccessSafe([string]$Message) {
    if (Get-Command Write-SuccessMessage -ErrorAction SilentlyContinue) { Write-SuccessMessage -Message $Message; return }
    Write-Host $Message -ForegroundColor Green
}

function Convert-ToSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateRange(5, 40)]
        [int]$MaxLength = 28
    )

    $upper = $Text.ToUpperInvariant()
    $upper = $upper -replace '[^A-Z0-9]+', '-'
    $upper = $upper.Trim('-')
    if ($upper.Length -gt $MaxLength) { $upper = $upper.Substring(0, $MaxLength).Trim('-') }
    if ([string]::IsNullOrWhiteSpace($upper)) { return 'UNCLASSIFIED' }
    return $upper
}

function Read-ConfigIfPresent {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }

    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    } catch {
        throw "Invalid JSON in config file '$Path'. Fix the JSON (or omit -ConfigFile)."
    }
}

# Apply config (CLI overrides config)
try {
    $config = Read-ConfigIfPresent -Path $ConfigFile
    if ($null -ne $config) {
        $bound = $PSCmdlet.MyInvocation.BoundParameters

        if (-not $bound.ContainsKey('RunId') -and $config.RunId) { $RunId = [string]$config.RunId }
        if (-not $bound.ContainsKey('OutputRoot') -and $config.OutputRoot) { $OutputRoot = [string]$config.OutputRoot }
        if (-not $bound.ContainsKey('SummaryOnly') -and $config.SummaryOnly) { $SummaryOnly = [bool]$config.SummaryOnly }
        if (-not $bound.ContainsKey('CreateTicketFolders') -and $config.CreateTicketFolders) { $CreateTicketFolders = [bool]$config.CreateTicketFolders }
        if (-not $bound.ContainsKey('TicketRoot') -and $config.TicketRoot) { $TicketRoot = [string]$config.TicketRoot }
        if (-not $bound.ContainsKey('TicketPrefix') -and $config.TicketPrefix) { $TicketPrefix = [string]$config.TicketPrefix }
        if (-not $bound.ContainsKey('OverwriteExisting') -and $config.OverwriteExisting) { $OverwriteExisting = [bool]$config.OverwriteExisting }
        if (-not $bound.ContainsKey('JsonSummaryPath') -and $config.JsonSummaryPath) { $JsonSummaryPath = [string]$config.JsonSummaryPath }
    }
} catch {
    Write-ErrorSafe "❌ ERROR: Failed to load config file.`n`nExplanation: $($_.Exception.Message)`n`nSolution: Fix the JSON, or omit -ConfigFile."
    exit 2
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Split-Path (Resolve-Path -LiteralPath $InputPath) -Parent
}

if ($CreateTicketFolders) {
    if ([string]::IsNullOrWhiteSpace($TicketRoot) -or -not (Test-Path $TicketRoot -PathType Container)) {
        Write-ErrorSafe "❌ ERROR: -CreateTicketFolders requires -TicketRoot to be an existing directory.`n`nSolution: Provide -TicketRoot (e.g., tickets\\EPP-192\\EPP-192-CODEQUALITY)."
        exit 2
    }
    if ([string]::IsNullOrWhiteSpace($TicketPrefix)) {
        Write-ErrorSafe "❌ ERROR: -CreateTicketFolders requires -TicketPrefix (e.g., EPP-192-CODEQUALITY)."
        exit 2
    }
}

try {
    Write-InfoSafe "Input: $InputPath"
    Write-InfoSafe "RunId: $RunId"

    $records = Import-Csv -LiteralPath $InputPath -Delimiter ([char]9)
    if ($records.Count -eq 0) {
        Write-ErrorSafe "❌ ERROR: No diagnostics found in input file.`n`nExplanation: The TSV contains no rows.`nSolution: Verify the export contains diagnostics and is tab-delimited."
        exit 2
    }

    foreach ($col in @('Code', 'Description', 'File', 'Line')) {
        if (-not ($records[0].PSObject.Properties.Name -contains $col)) {
            Write-ErrorSafe "❌ ERROR: Missing required column '$col' in TSV.`n`nExplanation: The catalog workflow depends on stable column names.`nSolution: Re-export diagnostics with a header row including: Severity, Code, Description, Project, File, Line."
            exit 2
        }
    }

    $counts = $records |
        Group-Object Code |
        Sort-Object Count -Descending |
        ForEach-Object { [pscustomobject]@{ Code = $_.Name; Count = $_.Count } }

    Write-Host ""
    $counts | Format-Table -AutoSize | Out-String | Write-Host

    if (-not [string]::IsNullOrWhiteSpace($JsonSummaryPath)) {
        $jsonOut = Resolve-Path -LiteralPath (Split-Path $JsonSummaryPath -Parent) -ErrorAction SilentlyContinue
        if ($PSCmdlet.ShouldProcess($JsonSummaryPath, "Write JSON summary")) {
            New-Item -ItemType Directory -Path (Split-Path $JsonSummaryPath -Parent) -Force | Out-Null
            $counts | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonSummaryPath -Encoding UTF8
        }
    }

    if ($SummaryOnly) {
        Write-SuccessSafe "Completed summary-only run."
        exit 0
    }

    if ($CreateTicketFolders) {
        $existingByCode = @{}
        $maxExistingIndex = 0

        if ($PreferExistingTicketFolders) {
            $prefixEscaped = [regex]::Escape($TicketPrefix)
            $pattern = "^$prefixEscaped-(\d{2})-([A-Za-z0-9]+)-"

            Get-ChildItem -LiteralPath $TicketRoot -Directory | ForEach-Object {
                $m = [regex]::Match($_.Name, $pattern)
                if (-not $m.Success) { return }

                $idx = [int]$m.Groups[1].Value
                $code = [string]$m.Groups[2].Value

                if (-not $existingByCode.ContainsKey($code)) { $existingByCode[$code] = $_.FullName }
                if ($idx -gt $maxExistingIndex) { $maxExistingIndex = $idx }
            }
        }

        $i = 0
        $nextNewIndex = $maxExistingIndex + 1
        foreach ($c in $counts) {
            $i++
            $code = [string]$c.Code
            $first = $records | Where-Object { $_.Code -eq $code } | Select-Object -First 1
            $slug = Convert-ToSlug -Text ([string]$first.Description)

            $ticketFolder = $null
            if ($PreferExistingTicketFolders -and $existingByCode.ContainsKey($code)) {
                $ticketFolder = [string]$existingByCode[$code]
            } else {
                $folderIndex = $i
                if ($PreferExistingTicketFolders) {
                    $folderIndex = $nextNewIndex
                    $nextNewIndex++
                }

                $folderName = ('{0}-{1:D2}-{2}-{3}' -f $TicketPrefix, $folderIndex, $code, $slug)
                $ticketFolder = Join-Path $TicketRoot $folderName
            }

            $ticketDataDir = Join-Path $ticketFolder (Join-Path 'data' $RunId)
            $ticketOutFile = Join-Path $ticketDataDir ("diagnostics.{0}.{1}.tsv" -f $code, $RunId)

            if ($PSCmdlet.ShouldProcess($ticketFolder, "Create ticket folder and write $code extract")) {
                New-Item -ItemType Directory -Path $ticketDataDir -Force | Out-Null

                if ((-not $OverwriteExisting) -and (Test-Path $ticketOutFile -PathType Leaf)) {
                    Write-InfoSafe "Skipping existing extract (use -OverwriteExisting): $ticketOutFile"
                } else {
                    $records | Where-Object { $_.Code -eq $code } |
                        Export-Csv -LiteralPath $ticketOutFile -Delimiter ([char]9) -NoTypeInformation
                }

                $planPath = Join-Path $ticketFolder 'plan.md'
                if (-not (Test-Path $planPath -PathType Leaf)) {
                    $plan = @(
                        "## Plan: $code — $($first.Description) (RunId: $RunId; Count: $($c.Count))"
                        ""
                        "### Objective"
                        "Create a **targeted, location-aware** fixer script for $code using the TSV extract in this folder."
                        ""
                        "### Constraints"
                        "- **Do not build**"
                        "- **Do not run tests**"
                        ""
                        "### Input data"
                        "- data/$RunId/diagnostics.$code.$RunId.tsv"
                        ""
                        "### Deliverables"
                        "- New script under: eneve.ebase.foundation/.cursor/scripts/quality/"
                        "- Script output report: file/line touched + applied vs skipped (TSV/JSON)"
                        ""
                        "### Fix strategy (location-aware)"
                        "- Parse TSV → group by `File` → apply edits anchored on the reported `Line`."
                        "- Prefer idempotent transformations; if a case cannot be proven safe via line-context, **skip and report**."
                    ) -join "`n"
                    Set-Content -LiteralPath $planPath -Value $plan -Encoding UTF8
                }
            }
        }
    } else {
        $outDir = Join-Path $OutputRoot (Join-Path 'by-code' $RunId)
        if ($PSCmdlet.ShouldProcess($outDir, "Write per-code extracts")) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        foreach ($c in $counts) {
            $code = [string]$c.Code
            $outFile = Join-Path $outDir ("diagnostics.{0}.{1}.tsv" -f $code, $RunId)

            if ((-not $OverwriteExisting) -and (Test-Path $outFile -PathType Leaf)) {
                Write-InfoSafe "Skipping existing extract (use -OverwriteExisting): $outFile"
                continue
            }

            if ($PSCmdlet.ShouldProcess($outFile, "Write $code extract")) {
                $records | Where-Object { $_.Code -eq $code } |
                    Export-Csv -LiteralPath $outFile -Delimiter ([char]9) -NoTypeInformation
            }
        }
    }

    Write-SuccessSafe "Catalog complete."
    exit 0
} catch {
    Write-ErrorSafe "❌ ERROR: Catalog failed.`n`nExplanation: $($_.Exception.Message)`n`nSolution: Re-run with -Verbose and check the input TSV format (tab-delimited + required columns)."
    exit 5
}


