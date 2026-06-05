#Requires -Version 7.2
#Requires -PSEdition Core

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RoslynRepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StartPath
    )

    if (Get-Command -Name Get-RepoRoot -ErrorAction SilentlyContinue) {
        return Get-RepoRoot -StartPath $StartPath
    }

    $resolved = Resolve-Path -Path $StartPath -ErrorAction SilentlyContinue
    $cursor = if ($resolved) { $resolved.Path } else { $StartPath }

    if (Test-Path $cursor -PathType Leaf) {
        $cursor = Split-Path $cursor -Parent
    }

    while ($cursor) {
        if (Test-Path (Join-Path $cursor '.git')) { return $cursor }
        $parent = Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }

    return (Resolve-Path -Path (Get-Location).Path).Path
}

function Resolve-RoslynSolutionPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,
        [Parameter(Mandatory = $false)]
        [string]$SolutionPath
    )

    if (-not [string]::IsNullOrWhiteSpace($SolutionPath)) {
        $rp = Resolve-Path -Path $SolutionPath -ErrorAction SilentlyContinue
        if (-not $rp) { return $null }
        if ($rp.Path -notlike '*.sln') { return $null }
        return $rp.Path
    }

    $slnFiles = @(Get-ChildItem -Path $RepoRoot -Filter '*.sln' -File -ErrorAction SilentlyContinue)
    if ($slnFiles.Count -ne 1) {
        return $null
    }
    return $slnFiles[0].FullName
}

function Invoke-RoslynFormatFix {
    <#
    .SYNOPSIS
        Attempts to apply Roslyn code fixes via dotnet format for specific diagnostics.

    .DESCRIPTION
        Runs `dotnet format` using `--diagnostics <ID>` for each provided diagnostic ID.
        This is intended as a "first pass" fixer before falling back to heuristic/regex scripts.

        This function is intentionally non-throwing for non-zero dotnet exit codes; callers can
        choose to treat failures as warnings and continue with fallback logic.

    .PARAMETER StartPath
        A file or directory path used to resolve repository root and default include scope.

    .PARAMETER Diagnostics
        One or more diagnostic IDs (e.g., IDE0009, IDE0300, CA1861).

    .PARAMETER Severity
        The minimum diagnostic severity to include (info, warn, error). Default: info.

    .PARAMETER SolutionPath
        Optional explicit .sln path. If omitted, this function will look for a single .sln in RepoRoot.

    .PARAMETER RepoRoot
        Optional explicit repo root. If omitted, the function will infer it from StartPath.

    .PARAMETER Include
        Optional paths to pass to `dotnet format --include` to narrow changes.

    .OUTPUTS
        PSCustomObject with:
          - Attempted (bool)
          - Applied (bool)
          - RepoRoot (string)
          - SolutionPath (string)
          - Runs (array of { Diagnostic, ExitCode, Output })
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StartPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Diagnostics,
        [Parameter(Mandatory = $false)]
        [ValidateSet('info', 'warn', 'error')]
        [string]$Severity = 'info',
        [Parameter(Mandatory = $false)]
        [string]$SolutionPath,
        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $false)]
        [string[]]$Include
    )

    $root = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Resolve-RoslynRepoRoot -StartPath $StartPath } else { $RepoRoot }
    if (-not (Test-Path $root -PathType Container)) {
        return [pscustomobject]@{ Attempted = $false; Applied = $false; RepoRoot = $root; SolutionPath = $null; Runs = @() }
    }

    $sln = Resolve-RoslynSolutionPath -RepoRoot $root -SolutionPath $SolutionPath
    if ([string]::IsNullOrWhiteSpace($sln)) {
        return [pscustomobject]@{ Attempted = $false; Applied = $false; RepoRoot = $root; SolutionPath = $null; Runs = @() }
    }

    $includeResolved = @()
    if ($Include -and $Include.Count -gt 0) {
        foreach ($p in $Include) {
            if ([string]::IsNullOrWhiteSpace($p)) { continue }
            $rp = Resolve-Path -Path $p -ErrorAction SilentlyContinue
            if ($rp) {
                $includeResolved += $rp.Path
            } else {
                $includeResolved += $p
            }
        }
        $includeResolved = @($includeResolved | Sort-Object -Unique)
    }

    $runs = New-Object System.Collections.Generic.List[object]
    $anySucceeded = $false

    Push-Location $root
    try {
        foreach ($diag in $Diagnostics) {
            $args = @('format', $sln, '--diagnostics', $diag, '--severity', $Severity)
            foreach ($inc in $includeResolved) { $args += @('--include', $inc) }

            $output = & dotnet @args 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            [void]$runs.Add([pscustomobject]@{
                Diagnostic = $diag
                ExitCode   = $exitCode
                Output     = $output
            })

            if ($exitCode -eq 0) { $anySucceeded = $true }
        }
    } finally {
        Pop-Location
    }

    # NOTE: PowerShell's enumerable binder can throw "Argument types do not match" when
    # returning a generic list directly in some environments. Materialize to a plain array.
    return [pscustomobject]@{
        Attempted    = $true
        Applied      = $anySucceeded
        RepoRoot     = $root
        SolutionPath = $sln
        Runs         = $runs.ToArray()
    }
}

Export-ModuleMember -Function Resolve-RoslynRepoRoot, Resolve-RoslynSolutionPath, Invoke-RoslynFormatFix


