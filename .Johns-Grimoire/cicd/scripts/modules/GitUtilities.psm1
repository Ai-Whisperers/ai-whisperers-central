<#
.SYNOPSIS
    Shared Git utility functions for CI/CD scripts

.DESCRIPTION
    Provides consistent, safe Git operations with proper error handling for:
    - Branch detection (handles detached HEAD)
    - Commit SHA retrieval
    - Remote fetching with error suppression
    - Git context gathering

.NOTES
    Version: 1.0.0
    Created: 2025-12-07
    Ticket: CICD-004
#>

#region Public Functions

<#
.SYNOPSIS
    Gets current Git branch name with detached HEAD handling

.DESCRIPTION
    Safely retrieves current branch name. Returns "detached HEAD" when HEAD
    is detached (e.g., during CI builds from tags or specific commits).

.EXAMPLE
    $branch = Get-GitBranch
    # Returns: "develop" or "detached HEAD"

.OUTPUTS
    String - Branch name or "detached HEAD"
#>
function Get-GitBranch {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $branch = git branch --show-current 2>$null
        
        if ([string]::IsNullOrWhiteSpace($branch)) {
            return "detached HEAD"
        }
        
        return $branch.Trim()
    }
    catch {
        Write-Warning "Failed to get Git branch: $_"
        return "unknown"
    }
}

<#
.SYNOPSIS
    Gets current commit SHA

.DESCRIPTION
    Retrieves the current commit SHA with options for full or short hash.

.PARAMETER Short
    If specified, returns 7-character short hash. Otherwise returns full hash.

.EXAMPLE
    $commitHash = Get-GitCommitSha
    # Returns: "a1b2c3d4e5f6..."

.EXAMPLE
    $shortHash = Get-GitCommitSha -Short
    # Returns: "a1b2c3d"

.OUTPUTS
    String - Commit SHA (full or short)
#>
function Get-GitCommitSha {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [switch]$Short
    )

    try {
        if ($Short) {
            $sha = git rev-parse --short HEAD 2>$null
        } else {
            $sha = git rev-parse HEAD 2>$null
        }
        
        if ([string]::IsNullOrWhiteSpace($sha)) {
            Write-Warning "Failed to get commit SHA"
            return "unknown"
        }
        
        return $sha.Trim()
    }
    catch {
        Write-Warning "Failed to get Git commit SHA: $_"
        return "unknown"
    }
}

<#
.SYNOPSIS
    Fetches from Git remote with error suppression

.DESCRIPTION
    Safely fetches from origin with stderr suppression to prevent auth prompts
    and noise in CI/CD pipelines. Returns $true on success, $false on failure.

.PARAMETER Prune
    If specified, prunes deleted remote branches. Default: $true

.PARAMETER Quiet
    If specified, suppresses output. Default: $true

.EXAMPLE
    $success = Invoke-GitFetch
    if (-not $success) {
        Write-Warning "Git fetch failed"
    }

.OUTPUTS
    Boolean - $true if fetch succeeded, $false otherwise
#>
function Invoke-GitFetch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$Prune = $true,
        
        [Parameter()]
        [switch]$Quiet = $true
    )

    try {
        $fetchArgs = @('fetch', 'origin')
        
        if ($Prune) {
            $fetchArgs += '--prune'
        }
        
        if ($Quiet) {
            $fetchArgs += '--quiet'
        }
        
        # Suppress stderr to prevent auth prompts and noise in CI/CD
        git @fetchArgs 2>&1 | Out-Null
        
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-Warning "Git fetch failed: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Gets comprehensive Git context information

.DESCRIPTION
    Gathers current Git state including branch, commit SHA, and optional
    remote information. Returns a hashtable with all Git context.

.PARAMETER IncludeRemote
    If specified, includes remote branch information. Default: $false

.EXAMPLE
    $context = Get-GitContext
    Write-Host "Branch: $($context.Branch)"
    Write-Host "Commit: $($context.CommitSha)"

.EXAMPLE
    $context = Get-GitContext -IncludeRemote
    # Includes remote branches in $context.RemoteBranches

.OUTPUTS
    Hashtable with keys:
    - Branch: Current branch name or "detached HEAD"
    - CommitSha: Full commit hash
    - ShortSha: 7-character short hash
    - RemoteBranches: (optional) Array of remote branches
    - IsDetached: Boolean indicating if HEAD is detached
#>
function Get-GitContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [switch]$IncludeRemote
    )

    $branch = Get-GitBranch
    $commitSha = Get-GitCommitSha
    $shortSha = Get-GitCommitSha -Short
    $isDetached = $branch -eq "detached HEAD"
    
    $context = @{
        Branch      = $branch
        CommitSha   = $commitSha
        ShortSha    = $shortSha
        IsDetached  = $isDetached
    }
    
    if ($IncludeRemote) {
        try {
            $remoteBranches = git branch -r 2>$null | 
                ForEach-Object { $_.Trim() } | 
                Where-Object { $_ -notmatch 'HEAD' }
            
            $context.RemoteBranches = $remoteBranches
        }
        catch {
            Write-Warning "Failed to get remote branches: $_"
            $context.RemoteBranches = @()
        }
    }
    
    return $context
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Get-GitBranch',
    'Get-GitCommitSha',
    'Invoke-GitFetch',
    'Get-GitContext'
)

#endregion

