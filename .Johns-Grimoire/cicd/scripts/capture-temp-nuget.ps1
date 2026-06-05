[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$searchRoots = @(
    "D:\a\1\Nuget",
    $env:AGENT_TEMPDIRECTORY,
    "D:\a\1",
    "D:\a",
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp\NuGetScratch",
    "$env:LOCALAPPDATA\NuGet",
    "$env:USERPROFILE\.nuget",
    "$env:ProgramData\NuGet"
) | Where-Object { $_ } | Select-Object -Unique

$found = @()
foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    try {
        $found += Get-ChildItem -Path $root -Recurse -Filter "tempNuGet_*.config" -File -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Search skipped for $($root): $_"
    }
}

$found = $found | Sort-Object LastWriteTimeUtc -Descending
$diag = Join-Path $OutputPath "nuget-diagnostics.txt"

"NuGet diagnostics" | Out-File -FilePath $diag -Encoding utf8
"Search roots: $($searchRoots -join ', ')" | Out-File -FilePath $diag -Append
"" | Out-File -FilePath $diag -Append
"==== nuget locals all -list ====" | Out-File -FilePath $diag -Append
nuget locals all -list 2>&1 | Out-File -FilePath $diag -Append
"" | Out-File -FilePath $diag -Append

if (-not $found -or $found.Count -eq 0) {
    Write-Host "No temp config files found. Searched roots: $($searchRoots -join ', ')"
    "No temp configs found" | Out-File -FilePath $diag -Append
    return
}

"Found temp configs:" | Out-File -FilePath $diag -Append
$found | ForEach-Object { "  $($_.FullName)" | Out-File -FilePath $diag -Append }
"" | Out-File -FilePath $diag -Append

$found | Copy-Item -Destination $OutputPath -Force
Copy-Item "$(System.DefaultWorkingDirectory)\NuGet.config" -Destination "$OutputPath\root-NuGet.config" -ErrorAction SilentlyContinue
Copy-Item "$(System.DefaultWorkingDirectory)\Directory.Packages.props" -Destination "$OutputPath\Directory.Packages.props" -ErrorAction SilentlyContinue

$latest = Get-ChildItem $OutputPath -Filter "tempNuGet_*.config" -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1

"" | Out-File -FilePath $diag -Append
"NuGet diagnostics for $($latest.FullName)" | Out-File -FilePath $diag -Append
"" | Out-File -FilePath $diag -Append
"==== nuget config -list ====" | Out-File -FilePath $diag -Append
nuget config -list -configfile $latest.FullName 2>&1 | Out-File -FilePath $diag -Append
"" | Out-File -FilePath $diag -Append
"==== dotnet nuget list source ====" | Out-File -FilePath $diag -Append
dotnet nuget list source --configfile $latest.FullName 2>&1 | Out-File -FilePath $diag -Append

try {
    [xml]$xml = Get-Content $latest.FullName
    $psm = $xml.configuration.packageSourceMapping.packageSource
    if ($psm) {
        "" | Out-File -FilePath $diag -Append
        "==== packageSourceMapping entries ====" | Out-File -FilePath $diag -Append
        foreach ($node in $psm.ChildNodes) {
            "Source: $($node.Name) -> Patterns: $($node.Add | ForEach-Object { $_.key } -join ', ')" | Out-File -FilePath $diag -Append
        }
    }
} catch {
    "Failed to parse packageSourceMapping: $_" | Out-File -FilePath $diag -Append
}

