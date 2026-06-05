<#
.SYNOPSIS
    Enable gradual code quality enforcement in phases

.DESCRIPTION
    Systematically tightens analyzer severity levels across 4 phases:
    - Phase 1: Safety-Critical Rules (culture, strings)
    - Phase 2: Null Safety Rules (parameter validation)
    - Phase 3: Code Quality Rules (maintainability)
    - Phase 4: Full Strict Enforcement (zero-tolerance)

.PARAMETER Phase
    The enforcement phase to enable (phase1, phase2, phase3, phase4)

.PARAMETER Validate
    Run validation after applying phase configuration (default: true)

.PARAMETER DryRun
    Show what would be changed without modifying files

.EXAMPLE
    .\enable-gradual-enforcement.ps1 -Phase phase1
    
    Enables Phase 1 (Safety-Critical Rules) and runs validation

.EXAMPLE
    .\enable-gradual-enforcement.ps1 -Phase phase2 -DryRun
    
    Shows what Phase 2 would change without modifying files

.NOTES
    Author: Cursor Agent
    Date: 2026-01-13
    Follows: rule.quality.code-quality-enforcement.v1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('phase1','phase2','phase3','phase4')]
    [string]$Phase,

    [Parameter(Mandatory=$false)]
    [switch]$Validate = $true,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$editorConfigPath = Join-Path $repoRoot ".editorconfig"

# Phase definitions
$phaseConfig = @{
    'phase1' = @{
        Name = "Safety-Critical Rules"
        Description = "Elevate culture/string safety rules to error level"
        Rules = @(
            @{ Rule = 'CA1304'; From = 'suggestion'; To = 'error'; Description = 'Specify CultureInfo' }
            @{ Rule = 'CA1305'; From = 'suggestion'; To = 'error'; Description = 'Specify IFormatProvider' }
            @{ Rule = 'CA1307'; From = 'suggestion'; To = 'error'; Description = 'Specify StringComparison' }
            @{ Rule = 'CA1310'; From = 'warning'; To = 'error'; Description = 'StringComparison for correctness' }
        )
        EstimatedViolations = "0-5 (auto-fix available)"
        Duration = "Week 1-2"
    }
    'phase2' = @{
        Name = "Null Safety Rules"
        Description = "Elevate parameter validation rules to warning level"
        Rules = @(
            @{ Rule = 'CA1062'; From = 'suggestion'; To = 'warning'; Description = 'Validate public method arguments' }
        )
        EstimatedViolations = "10-20 (manual fixes needed)"
        Duration = "Week 3-4"
    }
    'phase3' = @{
        Name = "Code Quality Rules"
        Description = "Elevate maintainability rules to warning level"
        Rules = @(
            @{ Rule = 'CA1716'; From = 'suggestion'; To = 'warning'; Description = 'Avoid keyword conflicts' }
            @{ Rule = 'CA1812'; From = 'suggestion'; To = 'warning'; Description = 'Avoid uninstantiated internal classes' }
            @{ Rule = 'CA1848'; From = 'suggestion'; To = 'warning'; Description = 'Use LoggerMessage delegates' }
        )
        NamingRules = @(
            @{ Rule = 'async_methods_should_end_with_async'; From = 'suggestion'; To = 'warning'; Description = 'Async method naming' }
        )
        EstimatedViolations = "5-15 (mostly naming)"
        Duration = "Week 5-6"
    }
    'phase4' = @{
        Name = "Full Strict Enforcement"
        Description = "Promote all warnings to errors (zero-tolerance)"
        Rules = @(
            @{ Rule = 'CA1062'; From = 'warning'; To = 'error'; Description = 'Validate public method arguments' }
            @{ Rule = 'CA1716'; From = 'warning'; To = 'error'; Description = 'Avoid keyword conflicts' }
            @{ Rule = 'CA1812'; From = 'warning'; To = 'error'; Description = 'Avoid uninstantiated internal classes' }
            @{ Rule = 'CA1848'; From = 'warning'; To = 'error'; Description = 'Use LoggerMessage delegates' }
        )
        NamingRules = @(
            @{ Rule = 'async_methods_should_end_with_async'; From = 'warning'; To = 'error'; Description = 'Async method naming' }
        )
        EstimatedViolations = "0 (all previous phases must be clean)"
        Duration = "Week 7+"
    }
}

function Write-PhaseInfo {
    param($Config)
    
    Write-Host "`n" ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $($Config.Name)" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "`nDescription: $($Config.Description)" -ForegroundColor Yellow
    Write-Host "Duration: $($Config.Duration)" -ForegroundColor Gray
    Write-Host "Estimated Violations: $($Config.EstimatedViolations)" -ForegroundColor Gray
    
    Write-Host "`nRules to Update:" -ForegroundColor Yellow
    foreach ($rule in $Config.Rules) {
        Write-Host "  • $($rule.Rule): $($rule.From) → $($rule.To)" -ForegroundColor White
        Write-Host "    $($rule.Description)" -ForegroundColor Gray
    }
    
    if ($Config.NamingRules) {
        Write-Host "`nNaming Rules to Update:" -ForegroundColor Yellow
        foreach ($rule in $Config.NamingRules) {
            Write-Host "  • $($rule.Rule): $($rule.From) → $($rule.To)" -ForegroundColor White
            Write-Host "    $($rule.Description)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

function Update-EditorConfig {
    param(
        [string]$Path,
        [array]$Rules,
        [array]$NamingRules,
        [switch]$DryRun
    )
    
    if (-not (Test-Path $Path)) {
        throw "EditorConfig file not found: $Path"
    }
    
    # Backup current config
    if (-not $DryRun) {
        $backupPath = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $Path $backupPath
        Write-Host "✓ Backup created: $backupPath" -ForegroundColor Green
    }
    
    # Read content
    $content = Get-Content $Path -Raw
    $originalContent = $content
    $changesApplied = 0
    
    # Update diagnostic rules
    foreach ($rule in $Rules) {
        $pattern = "dotnet_diagnostic\.$($rule.Rule)\.severity = $($rule.From)"
        $replacement = "dotnet_diagnostic.$($rule.Rule).severity = $($rule.To)"
        
        if ($content -match [regex]::Escape($pattern)) {
            Write-Host "  ✓ Updating $($rule.Rule): $($rule.From) → $($rule.To)" -ForegroundColor Green
            $content = $content -replace [regex]::Escape($pattern), $replacement
            $changesApplied++
        } else {
            Write-Host "  ⚠ Pattern not found for $($rule.Rule) (may already be updated)" -ForegroundColor Yellow
        }
    }
    
    # Update naming rules
    foreach ($rule in $NamingRules) {
        $pattern = "dotnet_naming_rule\.$($rule.Rule)\.severity = $($rule.From)"
        $replacement = "dotnet_naming_rule.$($rule.Rule).severity = $($rule.To)"
        
        if ($content -match [regex]::Escape($pattern)) {
            Write-Host "  ✓ Updating naming rule $($rule.Rule): $($rule.From) → $($rule.To)" -ForegroundColor Green
            $content = $content -replace [regex]::Escape($pattern), $replacement
            $changesApplied++
        } else {
            Write-Host "  ⚠ Pattern not found for naming rule $($rule.Rule) (may already be updated)" -ForegroundColor Yellow
        }
    }
    
    # Apply changes
    if ($changesApplied -gt 0 -and -not $DryRun) {
        Set-Content $Path $content -NoNewline
        Write-Host "`n✓ Applied $changesApplied change(s) to .editorconfig" -ForegroundColor Green
    } elseif ($changesApplied -gt 0 -and $DryRun) {
        Write-Host "`n[DRY RUN] Would apply $changesApplied change(s) to .editorconfig" -ForegroundColor Cyan
    } else {
        Write-Host "`n⚠ No changes applied (rules may already be configured)" -ForegroundColor Yellow
    }
    
    return $changesApplied
}

# Main execution
try {
    $config = $phaseConfig[$Phase]
    
    Write-PhaseInfo -Config $config
    
    if ($DryRun) {
        Write-Host "[DRY RUN MODE] No files will be modified`n" -ForegroundColor Cyan
    }
    
    Write-Host "Updating .editorconfig..." -ForegroundColor Yellow
    
    $changesApplied = Update-EditorConfig `
        -Path $editorConfigPath `
        -Rules $config.Rules `
        -NamingRules $config.NamingRules `
        -DryRun:$DryRun
    
    if ($changesApplied -eq 0) {
        Write-Host "`n⚠ No changes applied. Phase may already be enabled." -ForegroundColor Yellow
        Write-Host "  Run with -Validate to verify current state" -ForegroundColor Gray
        exit 0
    }
    
    if ($Validate -and -not $DryRun) {
        Write-Host "`nRunning validation..." -ForegroundColor Yellow
        
        $validationScript = Join-Path $PSScriptRoot "quality\validate-pre-merge.ps1"
        
        if (Test-Path $validationScript) {
            & $validationScript
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n✓ $($config.Name) enabled successfully!" -ForegroundColor Green
            } else {
                Write-Host "`n⚠ Validation found issues. Review output above." -ForegroundColor Yellow
                Write-Host "  Some violations may need manual fixes" -ForegroundColor Gray
            }
        } else {
            Write-Host "`n⚠ Validation script not found: $validationScript" -ForegroundColor Yellow
            Write-Host "  Please run validation manually" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n" ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $($config.Name) - Complete" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    if (-not $DryRun) {
        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "  1. Review validation results above" -ForegroundColor White
        Write-Host "  2. Address any violations found" -ForegroundColor White
        Write-Host "  3. Commit changes:" -ForegroundColor White
        Write-Host "     git add .editorconfig" -ForegroundColor Gray
        Write-Host "     git commit -m `"chore(quality): enable $($config.Name.ToLower()) ($Phase)`"" -ForegroundColor Gray
        
        if ($Phase -ne 'phase4') {
            $nextPhase = "phase$([int]$Phase.Substring(5) + 1)"
            Write-Host "`n  Next Phase: $nextPhase - $($phaseConfig[$nextPhase].Name)" -ForegroundColor Cyan
            Write-Host "  Run: .\enable-gradual-enforcement.ps1 -Phase $nextPhase" -ForegroundColor Gray
        } else {
            Write-Host "`n  ✓ All phases complete! Repository is in strict enforcement mode." -ForegroundColor Green
        }
    }
    
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
