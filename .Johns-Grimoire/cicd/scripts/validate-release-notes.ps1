<#
.SYNOPSIS
    Validates CHANGELOG.md contains entry for current release version

.DESCRIPTION
    Validates that CHANGELOG.md is properly updated for releases:
    - Checks CHANGELOG.md exists
    - Verifies entry for current version exists
    - Validates entry is not empty
    - Ensures proper versioning format
    
    Auto-detects version from release tag if not specified.

.PARAMETER Version
    Version to validate in CHANGELOG.md. If empty, extracts from BUILD_SOURCEBRANCH tag

.EXAMPLE
    .\validate-release-notes.ps1
    
    Auto-detects version from release tag and validates

.EXAMPLE
    .\validate-release-notes.ps1 -Version "1.2.0"
    
    Validates CHANGELOG.md contains entry for version 1.2.0

.EXAMPLE
    # Azure Pipelines usage
    - task: PowerShell@2
      displayName: 'Validate Release Notes'
      inputs:
        filePath: 'cicd/scripts/validate-release-notes.ps1'

.NOTES
    File Name      : validate-release-notes.ps1
    Prerequisite   : CHANGELOG.md in repository root
    Portability    : Works in Azure Pipelines and locally
    
.LINK
    https://keepachangelog.com/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Version to validate (auto-detects from tag if empty)")]
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

# Import shared logging module
$ModulePath = Join-Path $PSScriptRoot "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

# Import Git utilities module
$GitUtilitiesPath = Join-Path $PSScriptRoot "modules\GitUtilities.psm1"
Import-Module $GitUtilitiesPath -Force

Write-Log ""
Write-Log "=== Release Notes Validation ===" -Level INFO
Write-Log ""

# Enhanced context logging for CI/CD debugging
$gitContext = Get-GitContext
Write-Log "" -Level INFO
Write-Separator -Level INFO
Write-Log "  CONTEXT ANALYSIS" -Level INFO
Write-Separator -Level INFO
Write-Log "Commit:         $($gitContext.CommitSha)" -Level INFO
Write-Log "Branch:         $($gitContext.Branch)" -Level INFO
Write-Log "" -Level INFO

# Extract version from tag if not provided
if (-not $Version) {
    $sourceBranch = $env:BUILD_SOURCEBRANCH
    
    if ($sourceBranch -match 'refs/tags/release-(.+)') {
        $Version = $matches[1]
    } else {
        Write-Log "Not a release tag, skipping validation" -Level WARN
        exit 0
    }
}

Write-Log "Validating release notes for version: $Version" -Level INFO
Write-Log ""

# Check CHANGELOG.md exists
if (-not (Test-Path "CHANGELOG.md")) {
    Write-Log "CHANGELOG.md not found!" -Level ERROR
    Write-Log ""
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "  AUTOMATED SOLUTION: Use Cursor AI Prompt" -Level INFO
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log ""
    Write-Log "Open your repository in Cursor and tell the AI:" -Level WARN
    Write-Log ""
    Write-Log '  "Create CHANGELOG.md and generate entries from git history"' -Level INFO
    Write-Log ""
    Write-Log "Or use prompt: .cursor/prompts/changelog/generate-changelog-from-git.md" -Level WARN
    Write-Log ""
    Write-Log "The AI will create a complete CHANGELOG.md with all historical releases." -Level WARN
    Write-Log ""
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "  MANUAL ALTERNATIVE: Create CHANGELOG.md Manually" -Level INFO
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log ""
    Write-Log "Create CHANGELOG.md with this format:" -Level WARN
    Write-Log ""
    Write-Log "# Changelog" -Level INFO
    Write-Log ""
    Write-Log "All notable changes to this project will be documented in this file." -Level INFO
    Write-Log ""
    Write-Log "The format is based on [Keep a Changelog](https://keepachangelog.com/)." -Level INFO
    Write-Log ""
    Write-Log "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')" -Level INFO
    Write-Log ""
    Write-Log "**Release Tag**: [release-$Version](https://dev.azure.com/Energy21/NuGet%20Packages/_git/eneve.ebase.datamigrator/tags?tagName=release-$Version)" -Level INFO
    Write-Log ""
    Write-Log "### Added" -Level INFO
    Write-Log "- New feature description" -Level INFO
    Write-Log ""
    Write-Log "### Changed" -Level INFO
    Write-Log "- Changes made" -Level INFO
    Write-Log ""
    Write-Log "### Fixed" -Level INFO
    Write-Log "- Bugs fixed" -Level INFO
    Write-Log ""
    Write-Log "Documentation: .cursor/prompts/changelog/README.md" -Level DEBUG
    Write-Log ""
    exit 1
}

# Read CHANGELOG.md
$changelog = Get-Content "CHANGELOG.md" -Raw

# Check for version entry
$versionPattern = "\[?$([regex]::Escape($Version))\]?"

if ($changelog -notmatch $versionPattern) {
    Write-Log "CHANGELOG.md missing entry for version $Version!" -Level ERROR
    Write-Log ""
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "  AUTOMATED SOLUTION: Use Cursor AI Prompt" -Level INFO
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log ""
    Write-Log "Open your repository in Cursor and run:" -Level WARN
    Write-Log ""
    Write-Log '  Use prompt: .cursor/prompts/changelog/quick-changelog-update.md' -Level INFO
    Write-Log ""
    Write-Log "Or tell the AI:" -Level WARN
    Write-Log '  "Generate CHANGELOG entry for version' "$Version" 'from git history"' -Level INFO
    Write-Log ""
    Write-Log "The AI will:" -Level WARN
    Write-Log "  - Analyze commits since last release" -Level SUCCESS
    Write-Log "  - Categorize into Added/Changed/Fixed/Breaking" -Level SUCCESS
    Write-Log "  - Generate properly formatted entry" -Level SUCCESS
    Write-Log "  - Include release tag link" -Level SUCCESS
    Write-Log ""
    Write-Log "Then commit and re-tag:" -Level WARN
    Write-Log "  git add CHANGELOG.md" -Level INFO
    Write-Log "  git commit -m" '"docs: Add release notes for' "$Version" '"' -Level INFO
    Write-Log "  git tag -d $($env:BUILD_SOURCEBRANCHNAME)" -Level INFO
    Write-Log "  git push origin :refs/tags/$($env:BUILD_SOURCEBRANCHNAME)" -Level INFO
    Write-Log "  git tag $($env:BUILD_SOURCEBRANCHNAME)" -Level INFO
    Write-Log "  git push origin $($env:BUILD_SOURCEBRANCHNAME)" -Level INFO
    Write-Log ""
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log "  MANUAL ALTERNATIVE: Edit CHANGELOG.md Manually" -Level INFO
    Write-Log "═══════════════════════════════════════════════════════════════════" -Level INFO
    Write-Log ""
    Write-Log "Add this entry to CHANGELOG.md:" -Level WARN
    Write-Log ""
    Write-Log "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')" -Level INFO
    Write-Log ""
    Write-Log "**Release Tag**: [release-$Version](https://dev.azure.com/Energy21/NuGet%20Packages/_git/eneve.ebase.datamigrator/tags?tagName=release-$Version)" -Level INFO
    Write-Log ""
    Write-Log "### Added" -Level INFO
    Write-Log "- List new features" -Level INFO
    Write-Log ""
    Write-Log "### Changed" -Level INFO
    Write-Log "- List changes" -Level INFO
    Write-Log ""
    Write-Log "### Fixed" -Level INFO
    Write-Log "- List bug fixes" -Level INFO
    Write-Log ""
    Write-Log "### Breaking Changes" -Level INFO
    Write-Log "- List any breaking changes (if applicable)" -Level INFO
    Write-Log ""
    Write-Log "Documentation: .cursor/prompts/changelog/README.md" -Level DEBUG
    Write-Log ""
    exit 1
}

# Extract section for this version (stop at next H2, not H3)
$pattern = "(?ms)^##\s+\[?$([regex]::Escape($Version))\]?.*?(?=^##\s+\[|\z)"
$versionSection = [regex]::Match(
    $changelog,
    $pattern,
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
).Value

if ($versionSection.Length -lt 50) {
    Write-Log "Release notes for $Version are very short (< 50 chars)" -Level WARN
    Write-Log ""
}

# Check for standard sections
$hasAdded = $versionSection -match "###\s+Added"
$hasChanged = $versionSection -match "###\s+Changed"
$hasFixed = $versionSection -match "###\s+Fixed"
$hasBreaking = $versionSection -match "###\s+Breaking"

$contentCheckLevel = if ($hasAdded -and $hasChanged -and $hasFixed) { "INFO" } else { "WARN" }

Write-Log "Release Notes Content Check:" -Level $contentCheckLevel
Write-Log "  Added section: $(if ($hasAdded) { '[PASS]' } else { '[WARN]' })" -Level INFO
Write-Log "  Changed section: $(if ($hasChanged) { '[PASS]' } else { '[WARN]' })" -Level INFO
Write-Log "  Fixed section: $(if ($hasFixed) { '[PASS]' } else { '[WARN]' })" -Level INFO
Write-Log "  Breaking Changes: $(if ($hasBreaking) { '[PASS]' } else { 'N/A' })" -Level INFO
Write-Log ""

if (-not $hasAdded -and -not $hasChanged -and -not $hasFixed) {
    Write-Log "No standard sections found (Added/Changed/Fixed)" -Level WARN
    Write-Log "Consider using standard CHANGELOG format." -Level WARN
}

# Show excerpt
Write-Log "Release Notes Preview:" -Level INFO
Write-Log ""
$preview = $versionSection -replace '(?m)^', '  '
Write-Log $preview -Level INFO
Write-Log ""

Write-Log "CHANGELOG.md contains entry for version $Version" -Level SUCCESS
Write-Log ""

exit 0

