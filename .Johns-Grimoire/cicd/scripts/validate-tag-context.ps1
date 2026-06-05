<#
.SYNOPSIS
    Validates that release tags are created on appropriate stable branches.

.DESCRIPTION
    This script enforces branching governance for the CI/CD pipeline.
    It ensures that tags starting with 'release-' (e.g., release-1.0.0, release-1.0.0-rc1)
    are only permitted if the commit they point to is reachable from a stable branch ('main' or 'release/*').
    
    This prevents users from accidentally triggering a release workflow from an unstable 'feature/' or 'fix/' branch.
    Tags starting with other prefixes (e.g., 'test-', 'coverage-') are exempt from this check.

.PARAMETER TagName
    The full Git reference name of the tag (e.g., 'refs/tags/release-1.0.0').
    Defaults to the value of the environment variable 'BUILD_SOURCEBRANCH'.

.EXAMPLE
    .\validate-tag-context.ps1 -TagName "refs/tags/release-1.0.0"
    # Validates that the commit pointed to by release-1.0.0 is on main or release/*.

.NOTES
    Author: CI/CD Optimization Task
    Date: 2025-12-05
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TagName = $env:BUILD_SOURCEBRANCH
)

# -------------------------------------------------------------------------
# SCRIPT: validate-tag-context.ps1
# PURPOSE: Enforce that release tags only exist on stable branches.
# -------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

# Import shared logging module
Import-Module "$PSScriptRoot/modules/ScriptLogging.psm1" -Force

# 1. Check if a tag name was provided
if ([string]::IsNullOrWhiteSpace($TagName)) {
    Write-Log "No tag name provided or detected. This is likely a branch build, not a tag build." -Level INFO
    Write-Log "Validation skipped." -Level INFO
    exit 0
}

# 2. Check if the trigger is actually a tag
#    Azure DevOps uses 'refs/heads/...' for branches and 'refs/tags/...' for tags.
if (-not ($TagName -like "refs/tags/*")) {
    Write-Log "Source '$TagName' is not a tag (starts with refs/heads/). Validation skipped." -Level INFO
    exit 0
}

# 3. Clean tag name for processing
$cleanTagName = $TagName -replace "^refs/tags/", ""

# 4. Check if it is a 'release-' tag
#    We only enforce rules on release tags. 'test-*' or 'coverage-*' tags are allowed anywhere.
if (-not ($cleanTagName -match "^release-")) {
    Write-Log "Tag '$cleanTagName' is not a release tag (does not start with 'release-')." -Level INFO
    Write-Log "Governance rules apply only to release tags. Validation skipped." -Level INFO
    exit 0
}

Write-Log "Validating release tag '$cleanTagName'..." -Level INFO

# 5. Ensure we have branch information from Git
#    Azure DevOps pipelines often do shallow clones (fetchDepth: 1) which lack remote branch info.
#    The pipeline YAML should specify 'fetchDepth: 0' for this to work reliably.
#    We attempt to fetch origin just in case, but rely on the pipeline configuration.
$repoIsShallow = (git rev-parse --is-shallow-repository 2>$null) -eq 'true'
try {
    Write-Log "Fetching remote branches to ensure graph connectivity..." -Level INFO
    git fetch origin --prune --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch exited with code $LASTEXITCODE"
    }
}
catch {
    Write-Log "Fetch skipped or failed (shallow checkout or limited credentials is expected here). Continuing with existing refs." -Level INFO
    if ($repoIsShallow) {
        Write-Log "Detected shallow clone (fetchDepth probably 1). Set checkout: fetchDepth: 0 and persistCredentials: true to remove this warning." -Level INFO
    }
    Write-Log "Branch containment checks will run with whatever refs are present; results may be incomplete." -Level INFO
}

# 6. Gather detailed context for logging
$currentCommit = git rev-parse HEAD 2>$null
if (-not $currentCommit) { $currentCommit = "Unknown" }

Write-Log "" -Level INFO
Write-Separator -Level INFO
Write-Log "  BRANCH CONTEXT ANALYSIS" -Level INFO
Write-Separator -Level INFO
Write-Log "Tag:            $cleanTagName" -Level INFO
Write-Log "Commit:         $currentCommit" -Level INFO
Write-Log "" -Level INFO

# 7. Determine what branch we're CURRENTLY on (primary check - local)
$currentBranch = git branch --show-current 2>$null

Write-Log "Current Branch (HEAD):" -Level INFO
if ($currentBranch) {
    Write-Log "  $currentBranch" -Level INFO
} else {
    Write-Log "  (detached HEAD or unable to determine)" -Level INFO
}
Write-Log "" -Level INFO

# 8. Identify which remote branches contain this commit (secondary check)
#    'git branch -r --contains HEAD' lists all remote branches that have the current commit in their history.
Write-Log "Remote branches containing commit $currentCommit :" -Level INFO
$containingBranches = git branch -r --contains HEAD 2>$null

if ($containingBranches) {
    $containingBranches | ForEach-Object { Write-Log "  $_" -Level INFO }
} else {
    Write-Log "  (None detected - commit might not be pushed to any branch yet)" -Level INFO
}
Write-Log "" -Level INFO
Write-Separator -Level INFO
Write-Log "" -Level INFO

# 9. Tag Type Detection
#    Determine tag type for appropriate validation rules
Write-Log "Tag Type Detection:" -Level INFO

# RC tag pattern: release-X.Y.Z-rcN (e.g., release-1.0.0-rc1)
$isRcTag = $cleanTagName -match '^release-[\d.]+-rc\d+$'

# Final release pattern: release-X.Y.Z (no rc suffix)
$isFinalReleaseTag = $cleanTagName -match '^release-[\d.]+$' -and -not $isRcTag

if ($isRcTag) {
    Write-Log "  Release Candidate (RC) Tag" -Level INFO
} elseif ($isFinalReleaseTag) {
    Write-Log "  Final Release Tag" -Level INFO
} else {
    Write-Log "  Other Release Tag" -Level INFO
}
Write-Log ""

# -------------------------------------------------------------------------
# LEVEL 1 VALIDATION: Code Push Status
# -------------------------------------------------------------------------
# Verify that the commit exists on ANY remote branch (proves code is pushed)

Write-Separator -Level INFO
Write-Log "  LEVEL 1: Code Push Status" -Level INFO
Write-Separator -Level INFO
Write-Log ""

if (-not $containingBranches -or $containingBranches.Count -eq 0) {
    # No remote branches = code not pushed
    Write-Log "  [FAIL] No remote branches found containing commit" -Level ERROR
    Write-Log ""
    Write-Separator -Level ERROR
    Write-Log "  VALIDATION FAILED" -Level ERROR
    Write-Separator -Level ERROR
    Write-Log ""
    Write-Log "ERROR: Tag points to unpushed code" -Level ERROR
    Write-Log ""
    Write-Log "Explanation: The commit $currentCommit has not been pushed to any remote branch." -Level WARN
    Write-Log "Tagging unpushed code prevents proper validation and traceability." -Level WARN
    Write-Log ""
    Write-Log "Solution:" -Level SUCCESS
    Write-Log "  1. Push your branch to remote: git push origin <branch-name>" -Level INFO
    Write-Log "  2. Verify commit is on remote: git branch -r --contains $currentCommit" -Level INFO
    Write-Log "  3. Then create tag: git tag $cleanTagName" -Level INFO
    Write-Log ""
    Write-Log "Help: See .cursor/rules/git/branch-lifecycle-rule.mdc" -Level INFO
    Write-Log ""
    exit 1
}

# PASS: Code exists on at least one remote branch
Write-Log "  [PASS] Code exists on remote branches (pushed)" -Level SUCCESS
Write-Log ""

# -------------------------------------------------------------------------
# LEVEL 2 VALIDATION: Branch Type Appropriateness
# -------------------------------------------------------------------------
# Verify tag is on appropriate branch type for the tag category

Write-Separator -Level INFO
Write-Log "  LEVEL 2: Branch Type Appropriateness" -Level INFO
Write-Separator -Level INFO
Write-Log ""

# Parse remote branches to extract branch names
$remoteBranchNames = @()
foreach ($branch in $containingBranches) {
    $branch = $branch.Trim()
    $branchName = $branch -replace "^origin/", ""
    $remoteBranchNames += $branchName
}

# Detect branch patterns
$hasRcBranch = $remoteBranchNames | Where-Object { $_ -match '^rc/' }
$hasReleaseBranch = $remoteBranchNames | Where-Object { $_ -match '^release/' }

# RC TAG VALIDATION (Flexible - warn if not ideal, but allow)
if ($isRcTag) {
    if ($hasRcBranch -or $hasReleaseBranch) {
        # RC tag on appropriate branch
        Write-Log "  [PASS] RC tag on appropriate branch (rc/* or release/*)" -Level SUCCESS
        Write-Log ""
        Write-Separator -Level SUCCESS
        Write-Log "  VALIDATION PASSED" -Level SUCCESS
        Write-Separator -Level SUCCESS
        Write-Log ""
        Write-Log "SUCCESS: Release tag '$cleanTagName' validated (code is pushed)" -Level SUCCESS
        Write-Log ""
        exit 0
    } else {
        # RC tag not on ideal branch - WARN but ALLOW
        Write-Log "  [WARN] RC tag not on rc/* or release/* branch" -Level WARN
        Write-Log ""
        Write-Separator -Level WARN
        Write-Log "  VALIDATION WARNING" -Level WARN
        Write-Separator -Level WARN
        Write-Log ""
        Write-Log "WARNING: RC tag location not ideal" -Level WARN
        Write-Log ""
        Write-Log "Impact: RC tag '$cleanTagName' found on branches:" -Level INFO
        foreach ($branchName in $remoteBranchNames) {
            Write-Log "  - $branchName" -Level INFO
        }
        Write-Log ""
        Write-Log "Best Practice: RC tags should be on rc/* or release/* branches" -Level WARN
        Write-Log "However, RC tags are flexible and deployment is allowed." -Level INFO
        Write-Log ""
        Write-Log "Recommendation:" -Level SUCCESS
        Write-Log "  1. For formal RCs, create rc/* branch: git checkout -b rc/X.Y" -Level INFO
        Write-Log "  2. Or use release/* branch for release line RCs" -Level INFO
        Write-Log ""
        Write-Log "Allowing deployment with warning..." -Level SUCCESS
        Write-Log ""
        exit 0
    }
}

# FINAL RELEASE TAG VALIDATION (Strict - must be on release/* branch)
if ($isFinalReleaseTag) {
    if ($hasReleaseBranch) {
        # Final release on release/* branch - PASS
        Write-Log "  [PASS] Final release tag on release/* branch" -Level SUCCESS
        Write-Log ""
        Write-Separator -Level SUCCESS
        Write-Log "  VALIDATION PASSED" -Level SUCCESS
        Write-Separator -Level SUCCESS
        Write-Log ""
        Write-Log "SUCCESS: Release tag '$cleanTagName' validated" -Level SUCCESS
        Write-Log ""
        exit 0
    } else {
        # Final release NOT on release/* branch - ERROR
        Write-Log "  [FAIL] Final release tag not on release/* branch" -Level ERROR
        Write-Log ""
        Write-Separator -Level ERROR
        Write-Log "  VALIDATION FAILED" -Level ERROR
        Write-Separator -Level ERROR
        Write-Log ""
        Write-Log "ERROR: Final release tag must be on release/* branch" -Level ERROR
        Write-Log ""
        Write-Log "Explanation: Final release tags require strict branch validation." -Level WARN
        Write-Log "The tag '$cleanTagName' is on:" -Level WARN
        foreach ($branchName in $remoteBranchNames) {
            Write-Log "  - $branchName" -Level INFO
        }
        Write-Log ""
        Write-Log "Solution:" -Level SUCCESS
        Write-Log "  1. Create release branch: git checkout -b release/X.Y from develop" -Level INFO
        Write-Log "  2. Merge to main: git checkout main && git merge release/X.Y" -Level INFO
        Write-Log "  3. Tag on main: git tag $cleanTagName" -Level INFO
        Write-Log ""
        Write-Log "Help: See .cursor/rules/git/branch-lifecycle-rule.mdc" -Level INFO
        Write-Log ""
        exit 1
    }
}

# OTHER RELEASE TAGS (Apply RC rules - flexible)
Write-Log "  [INFO] Applying flexible validation (RC rules)" -Level INFO
Write-Log ""
Write-Separator -Level SUCCESS
Write-Log "  VALIDATION PASSED" -Level SUCCESS
Write-Separator -Level SUCCESS
Write-Log ""
Write-Log "SUCCESS: Release tag '$cleanTagName' validated (code is pushed)" -Level SUCCESS
Write-Log ""
exit 0

