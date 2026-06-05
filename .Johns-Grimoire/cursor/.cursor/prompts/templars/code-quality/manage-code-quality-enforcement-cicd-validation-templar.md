---
type: templar
artifact-type: prompt
applies-to: code-quality, enforcement, ci-cd
pattern-name: code-quality-enforcement-cicd-validation
version: 1.0.0
implements: code-quality.manage-code-quality-enforcement.cicd-validation
consumed-by:
  - .cursor/prompts/code-quality/manage-code-quality-enforcement.prompt.md
---

# Manage Code Quality Enforcement - CI/CD Validation Templar

This templar captures a fuller (script-based) CI/CD example. In this repository, prefer the orchestrator (`validate-pre-merge.ps1`) for alignment between local and CI runs; use this as reference only.

### Phase 5: CI/CD Integration (Reference)

#### Generate CI/CD Validation Script

```powershell
# validate-code-quality.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('baseline','enforce','suppress','gradual','strict')]
    [string]$Phase,

    [Parameter(Mandatory=$false)]
    [int]$ToleranceLevel = 0
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Code Quality Enforcement: $Phase Phase ===" -ForegroundColor Cyan

# Phase-specific validation logic
switch ($Phase) {
    'auto-fix' {
        # Run automated fix scripts first
        Write-Host "Running automated fix scripts..." -ForegroundColor Yellow

        $successfulFixes = 0
        $failedFixes = 0

        # Parse and execute fix scripts
        if ($FixScripts) {
            $scripts = $FixScripts | ConvertFrom-Json

            foreach ($script in $scripts) {
                Write-Host "  Executing: $($script.description)" -ForegroundColor Gray

                try {
                    & $script.scriptPath -Path $TargetPath -DryRun:$WhatIfMode

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ Success" -ForegroundColor Green
                        $successfulFixes++
                    } else {
                        Write-Host "  ❌ Failed" -ForegroundColor Red
                        $failedFixes++
                    }
                }
                catch {
                    Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                    $failedFixes++
                }
            }

            # Store successful scripts for reuse
            if ($StoreSuccessfulScripts -and $successfulFixes -gt 0) {
                $registryPath = Join-Path $TargetPath ".cursor\scripts\quality\script-registry.json"

                $registry = if (Test-Path $registryPath) {
                    Get-Content $registryPath | ConvertFrom-Json
                } else {
                    @{ scripts = @(); lastUpdated = Get-Date -Format "yyyy-MM-dd" }
                }

                foreach ($script in $scripts) {
                    $existing = $registry.scripts | Where-Object { $_.errorCode -eq $script.errorCode }
                    if (-not $existing) {
                        $registry.scripts += @{
                            errorCode = $script.errorCode
                            scriptPath = $script.scriptPath
                            description = $script.description
                            successCount = 1
                            lastSuccess = Get-Date -Format "yyyy-MM-dd"
                        }
                    } else {
                        $existing.successCount++
                        $existing.lastSuccess = Get-Date -Format "yyyy-MM-dd"
                    }
                }

                $registry.lastUpdated = Get-Date -Format "yyyy-MM-dd"
                $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath

                Write-Host "Stored $successfulFixes successful scripts for reuse" -ForegroundColor Green
            }
        }

        Write-Host "Auto-fix phase complete: $successfulFixes succeeded, $failedFixes failed" -ForegroundColor Cyan

        if ($failedFixes -gt 0) {
            Write-Host "Some fixes failed - proceeding to manual enforcement phase" -ForegroundColor Yellow
            # Could automatically transition to 'enforce' phase here
        }
    }

    'baseline' {
        # Count current warnings/errors
        $result = dotnet build --configuration Release /p:TreatWarningsAsErrors=false 2>&1
        $warnings = ($result | Select-String "warning").Count
        $errors = ($result | Select-String "error").Count

        Write-Host "Current state: $warnings warnings, $errors errors" -ForegroundColor Yellow

        if ($warnings -eq 0 -and $errors -eq 0) {
            Write-Host "✅ Already at zero warnings/errors!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Need enforcement phase" -ForegroundColor Yellow
        }
    }

    'enforce' {
        # Enable warnings as errors
        Write-Host "Enabling warnings-as-errors..." -ForegroundColor Yellow

        # Update .csproj files
        Get-ChildItem -Recurse -Filter "*.csproj" | ForEach-Object {
            $content = Get-Content $_.FullName -Raw

            if ($content -notmatch "<TreatWarningsAsErrors>true</TreatWarningsAsErrors>") {
                $content = $content -replace "</PropertyGroup>", "  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>`n  </PropertyGroup>"
                Set-Content $_.FullName $content
                Write-Host "Updated: $($_.Name)" -ForegroundColor Green
            }
        }

        # Test build
        $result = dotnet build --configuration Release /p:TreatWarningsAsErrors=true 2>&1
        $errors = ($result | Select-String "error").Count

        if ($errors -eq 0) {
            Write-Host "✅ Enforcement successful!" -ForegroundColor Green
        } else {
            Write-Host "❌ $errors errors found. Need suppression phase." -ForegroundColor Red
        }
    }

    'suppress' {
        # Add temporary suppressions
        Write-Host "Adding temporary suppressions..." -ForegroundColor Yellow

        $suppressions = @()

        # Scan for common patterns and create suppressions
        $result = dotnet build --configuration Release /p:TreatWarningsAsErrors=true 2>&1

        $result | Select-String "error (?<code>\\w+):" | ForEach-Object {
            $code = $_.Matches.Groups['code'].Value
            $suppressions += "dotnet_diagnostic.$code.severity = warning"
        }

        # Update .editorconfig
        $editorConfig = ".editorconfig"
        if (Test-Path $editorConfig) {
            $content = Get-Content $editorConfig -Raw
        } else {
            $content = "[*.cs]`n"
        }

        foreach ($suppression in $suppressions) {
            if ($content -notmatch [regex]::Escape($suppression)) {
                $content += "`n$suppression"
            }
        }

        Set-Content $editorConfig $content
        Write-Host "Added $($suppressions.Count) temporary suppressions" -ForegroundColor Green
    }

    'gradual' {
        # Remove suppressions gradually
        Write-Host "Gradual tightening in progress..." -ForegroundColor Yellow

        $editorConfig = ".editorconfig"
        if (Test-Path $editorConfig) {
            $content = Get-Content $editorConfig -Raw

            # Remove culture-related suppressions first
            $content = $content -replace "dotnet_diagnostic\\.CA1304\\.severity = warning`n", ""
            $content = $content -replace "dotnet_diagnostic\\.CA1305\\.severity = warning`n", ""

            Set-Content $editorConfig $content
            Write-Host "Removed CA1304/CA1305 suppressions" -ForegroundColor Green
        }
    }

    'strict' {
        # Full enforcement, no suppressions
        Write-Host "Enforcing strict zero-tolerance policy..." -ForegroundColor Yellow

        $editorConfig = ".editorconfig"
        if (Test-Path $editorConfig) {
            $content = Get-Content $editorConfig -Raw

            # Remove all temporary suppressions
            $content = $content -replace "dotnet_diagnostic\\.\\w+\\.severity = warning`n", ""

            Set-Content $editorConfig $content
        }

        # Test final build
        $result = dotnet build --configuration Release /p:TreatWarningsAsErrors=true 2>&1
        $errors = ($result | Select-String "error").Count

        if ($errors -eq 0) {
            Write-Host "✅ Strict enforcement achieved!" -ForegroundColor Green
        } else {
            Write-Host "❌ $errors errors remaining" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "=== Phase $Phase Complete ===" -ForegroundColor Cyan
```

#### CI/CD Pipeline Integration

```yaml
# Add to azure-pipelines.yml
- task: PowerShell@2
  displayName: 'Auto-Fix Known Code Quality Issues'
  inputs:
    targetType: 'inline'
    script: |
      $fixScripts = @'
      [
        {"errorCode":"IDE1006","scriptPath":".cursor/scripts/quality/fix-async-method-naming.ps1","description":"Fix async method naming"},
        {"errorCode":"CA1304","scriptPath":".cursor/scripts/quality/fix-culture-info.ps1","description":"Fix culture info issues"}
      ]
      '@
      ./scripts/validate-code-quality.ps1 -Phase auto-fix -FixScripts $fixScripts

- task: PowerShell@2
  displayName: 'Validate Code Quality Enforcement'
  inputs:
    targetType: 'inline'
    script: |
      ./scripts/validate-code-quality.ps1 -Phase $(QualityPhase) -ToleranceLevel $(WarningTolerance)

# Pipeline variables
variables:
  QualityPhase: 'enforce'  # Change gradually: auto-fix -> enforce -> suppress -> gradual -> strict
  WarningTolerance: 0
```
