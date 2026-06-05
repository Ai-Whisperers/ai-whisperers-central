# CI/CD Scripts Quick Start Guide

## 🚀 Getting Started

### Prerequisites

```powershell
# Install PowerShell 7+ (recommended)
winget install Microsoft.PowerShell

# Install .NET 9 SDK
winget install Microsoft.DotNet.SDK.9

# Install required global tools
cd cicd/scripts
.\install-tools.ps1
```

### Running Scripts

```powershell
# Navigate to scripts directory
cd E:\WPG\Git\E21\GitRepos\eneve.domain\cicd\scripts

# Run any script
.\<script-name>.ps1 [parameters]

# Get help for any script
Get-Help .\<script-name>.ps1 -Detailed
```

## 📋 Common Tasks

### 1. Validate Before Committing

```powershell
# Check documentation
.\validate-documentation.ps1

# Validate package metadata
.\validate-package-metadata.ps1

# Verify XML files exist
.\verify-xml-files.ps1
```

### 2. Check Code Quality

```powershell
# Calculate code metrics
.\calculate-code-metrics.ps1 -OutputPath "../../local-reports/metrics"

# Check for breaking changes
.\check-breaking-changes.ps1 -OutputPath "../../local-reports/compat"

# Scan license compliance
.\scan-licenses.ps1 -OutputPath "../../local-reports/licenses"
```

### 3. Analyze Test Coverage

```powershell
# Run enhanced coverage analysis
.\enhanced-coverage-analysis.ps1 -CoberturaFile "../../coverage/coverage.cobertura.xml"

# Collect local metrics
.\collect-local-metrics.ps1
```

### 4. Validate Release

```powershell
# Validate release notes
.\validate-release-notes.ps1 -Version "1.0.0-rc1"

# Validate tag context
.\validate-tag-context.ps1
```

### 5. Run Performance Tests

```powershell
# Run benchmarks
.\run-benchmarks.ps1 -Configuration Release

# Run mutation tests
.\run-mutation-tests.ps1 -TestProject "tst\Eneve.Domain.Tests"
```

## 🧪 Testing the Scripts

### Run All Tests

```powershell
# Run comprehensive test suite
.\run-all-tests.ps1

# Or run individual test files
Invoke-Pester -Path .\validate-documentation.Tests.ps1
Invoke-Pester -Path .\scan-licenses.Tests.ps1
Invoke-Pester -Path .\enhanced-coverage-analysis.Tests.ps1
```

### Test Individual Scripts

```powershell
# Test a specific script with verbose output
Invoke-Pester -Path .\install-tools.Tests.ps1 -Verbose

# Test with output to file
Invoke-Pester -Path .\validate-documentation.Tests.ps1 | 
    Out-File test-results.txt
```

## 📊 Generating Reports

### Local Reports

```powershell
# Create local reports directory
New-Item -ItemType Directory -Path "../../local-reports" -Force

# Generate all reports
.\scan-licenses.ps1 -OutputPath "../../local-reports/licenses"
.\calculate-code-metrics.ps1 -OutputPath "../../local-reports/metrics"
.\check-breaking-changes.ps1 -OutputPath "../../local-reports/compat"
```

### View Reports

```powershell
# Open reports in browser
Start-Process "../../local-reports/licenses/licenses.html"
Start-Process "../../local-reports/metrics/index.html"
Start-Process "../../local-reports/compat/index.html"
```

## 🔧 Troubleshooting

### Common Issues

#### "Script is not digitally signed"
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

#### "Command not found"
```powershell
# Ensure .dotnet\tools is in PATH
$env:PATH += ";$env:USERPROFILE\.dotnet\tools"

# Or reinstall tools
.\install-tools.ps1
```

#### "Package Source Mapping" errors
```powershell
# Check NuGet.Config in repository root
# Ensure package sources are properly configured
```

### Getting Help

```powershell
# View script help
Get-Help .\<script-name>.ps1 -Full

# View examples
Get-Help .\<script-name>.ps1 -Examples

# Check README
Get-Content README.md
```

## 💡 Pro Tips

### 1. Run Validation Locally Before Pushing

Create a pre-push validation script:

```powershell
# pre-push-validate.ps1
.\validate-documentation.ps1
.\validate-package-metadata.ps1
.\scan-licenses.ps1 -OutputPath "../../local-reports/licenses"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Validation failed! Fix issues before pushing." -ForegroundColor Red
    exit 1
}
```

### 2. Use AI-Assisted Error Fixes

When a script fails, look for the enhanced error messages:

```
═══════════════════════════════════════════════════════════════
  AUTOMATED SOLUTION: Use Cursor AI
═══════════════════════════════════════════════════════════════
```

Copy the suggested prompt to Cursor AI for automatic fixes!

### 3. Monitor Coverage Trends

```powershell
# Run coverage analysis regularly
.\enhanced-coverage-analysis.ps1 -CoberturaFile "../../coverage/coverage.cobertura.xml"

# Check history
Get-Content "../../coverage/coverage-history.jsonl" | ConvertFrom-Json | 
    Select-Object -Last 10
```

### 4. Automate with Task Scheduler

Create scheduled tasks to run nightly:
- `scan-licenses.ps1` - Weekly license compliance check
- `calculate-code-metrics.ps1` - Nightly code metrics
- `check-breaking-changes.ps1` - Before each release

## 📚 Resources

- **Full Documentation**: [README.md](README.md)
- **Test Drive Summary**: [TEST-DRIVE-SUMMARY.md](TEST-DRIVE-SUMMARY.md)
- **Cursor Rules**: `../../.cursor/rules/cicd/`
- **Azure Pipelines**: `../azure-pipelines.yml`

## 🎯 Quick Commands Cheat Sheet

```powershell
# Full validation suite
.\validate-documentation.ps1; .\validate-package-metadata.ps1; .\verify-xml-files.ps1

# Quality checks
.\calculate-code-metrics.ps1 -OutputPath "../../local-reports/metrics"; .\scan-licenses.ps1 -OutputPath "../../local-reports/licenses"

# Pre-release checks
.\validate-release-notes.ps1 -Version "1.0.0"; .\validate-tag-context.ps1; .\check-breaking-changes.ps1 -OutputPath "../../local-reports/compat"

# Run all tests
.\run-all-tests.ps1

# Install/update tools
.\install-tools.ps1
```

---

**Need Help?** Ask Cursor AI: "Help me use the CI/CD scripts" or check [TEST-DRIVE-SUMMARY.md](TEST-DRIVE-SUMMARY.md) for comprehensive documentation.

