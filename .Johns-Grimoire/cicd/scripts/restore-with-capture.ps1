[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [string]$PackagesPath,
    [string[]]$AdditionalArgs
)

# Preferred over the stock DotNetCoreCLI restore: the built-in task can emit
# MSB1001 ("Unknown switch") when restore arguments are concatenated and
# wrapped into MSBuild response files, and it tends to clean up the temp
# NuGet config before we can capture it. This script runs dotnet restore
# directly with discrete args and captures the temp config immediately after.
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$argsList = @(
    "restore",
    $SolutionPath,
    "--configfile", $ConfigPath,
    "--use-lock-file",
    "--force-evaluate"
)

if ($PackagesPath) {
    $argsList += @("--packages", $PackagesPath)
}

if ($AdditionalArgs) {
    $argsList += $AdditionalArgs
}

dotnet @argsList
$restoreExit = $LASTEXITCODE

# Immediately capture any temp config before clean-up
& "$PSScriptRoot\capture-temp-nuget.ps1" -OutputPath $OutputPath

if ($restoreExit -ne 0) {
    throw "dotnet restore exited with code $restoreExit"
}

