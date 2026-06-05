---
type: exemplar
artifact-type: prompt
demonstrates: manage-code-quality-enforcement
domain: code-quality
quality-score: exceptional
version: 1.0.0
illustrates: code-quality.manage-code-quality-enforcement
extracted-from: .cursor/prompts/code-quality/manage-code-quality-enforcement.prompt.md
---

# Manage Code Quality Enforcement - Fix Scripts Exemplar

### Phase 2: Automated Fix Scripts (Reference)

#### Identify Applicable Fix Scripts

For each reported error/warning, check if an automated fix script exists:

```powershell
# Parse fix scripts JSON and match against build errors
$fixScripts = $FixScripts | ConvertFrom-Json

foreach ($error in $buildErrors) {
    $matchingScript = $fixScripts | Where-Object { $_.errorCode -eq $error.Code }

    if ($matchingScript) {
        Write-Host "Found fix script for $($error.Code): $($matchingScript.description)"
        # Queue script for execution
    }
}
```

#### Execute Fix Scripts

Run available fix scripts before attempting manual fixes:

```powershell
# Execute each matching fix script
foreach ($script in $matchingScripts) {
    Write-Host "Running fix script: $($script.scriptPath)"

    try {
        # Run the fix script with appropriate parameters
        & $script.scriptPath -Path $TargetPath -WhatIf:$WhatIfMode

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Fix script succeeded: $($script.description)"
            $successfulScripts += $script
        } else {
            Write-Warning "Fix script failed, will try manual approach"
        }
    }
    catch {
        Write-Warning "Fix script error: $($_.Exception.Message)"
    }
}
```

#### Store Successful Scripts

Save working scripts for future reuse:

```powershell
# Store successful scripts in a reusable script registry
$registryPath = ".cursor/scripts/quality/script-registry.json"

$registry = if (Test-Path $registryPath) {
    Get-Content $registryPath | ConvertFrom-Json
} else {
    @{ scripts = @() }
}

foreach ($script in $successfulScripts) {
    $existingScript = $registry.scripts | Where-Object { $_.errorCode -eq $script.errorCode }

    if (-not $existingScript) {
        $registry.scripts += @{
            errorCode = $script.errorCode
            scriptPath = $script.scriptPath
            description = $script.description
            lastUsed = Get-Date -Format "yyyy-MM-dd"
            successCount = 1
        }
    } else {
        $existingScript.lastUsed = Get-Date -Format "yyyy-MM-dd"
        $existingScript.successCount++
    }
}

$registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath
Write-Success "Stored $($successfulScripts.Count) successful scripts for reuse"
```
