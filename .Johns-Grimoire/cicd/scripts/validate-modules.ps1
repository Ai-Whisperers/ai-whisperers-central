<#
.SYNOPSIS
    Validates all shared modules are working correctly after migration

.DESCRIPTION
    Comprehensive validation of all 4 shared modules:
    - ScriptLogging.psm1
    - ScriptProfiling.psm1
    - ConfigurationLoader.psm1
    - EnvironmentDetection.psm1

.EXAMPLE
    .\validate-modules.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "  Module Validation - Post-Migration Health Check" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "`n"

$passed = 0
$failed = 0
$tests = @()

function Test-Module {
    param(
        [string]$TestName,
        [scriptblock]$TestScript
    )
    
    Write-Host "Testing: " -NoNewline
    Write-Host $TestName.PadRight(60) -NoNewline -ForegroundColor Yellow
    
    try {
        $result = & $TestScript
        if ($result) {
            Write-Host " ✅ PASS" -ForegroundColor Green
            $script:passed++
            return $true
        } else {
            Write-Host " ❌ FAIL" -ForegroundColor Red
            $script:failed++
            return $false
        }
    } catch {
        Write-Host " ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
        return $false
    }
}

# Test 1: ScriptLogging Module
Write-Host "`n[1] ScriptLogging.psm1 Tests" -ForegroundColor Cyan
Write-Host "-" * 80

Test-Module "Module imports without errors" {
    Import-Module "$PSScriptRoot/modules/ScriptLogging.psm1" -Force
    return $true
}

Test-Module "Write-Log function exists" {
    $null -ne (Get-Command Write-Log -ErrorAction SilentlyContinue)
}

Test-Module "Write-Log INFO level works" {
    Write-Log "Test INFO" -Level INFO
    return $true
}

Test-Module "Write-Log WARN level works" {
    Write-Log "Test WARN" -Level WARN
    return $true
}

Test-Module "Write-Log ERROR level works" {
    Write-Log "Test ERROR" -Level ERROR
    return $true
}

Test-Module "Write-Log SUCCESS level works" {
    Write-Log "Test SUCCESS" -Level SUCCESS
    return $true
}

Test-Module "Write-Log DEBUG level works" {
    Write-Log "Test DEBUG" -Level DEBUG
    return $true
}

# Test 2: ScriptProfiling Module
Write-Host "`n[2] ScriptProfiling.psm1 Tests" -ForegroundColor Cyan
Write-Host "-" * 80

Test-Module "Module imports without errors" {
    Import-Module "$PSScriptRoot/modules/ScriptProfiling.psm1" -Force
    return $true
}

Test-Module "Start-Profile function exists" {
    $null -ne (Get-Command Start-Profile -ErrorAction SilentlyContinue)
}

Test-Module "Stop-Profile function exists" {
    $null -ne (Get-Command Stop-Profile -ErrorAction SilentlyContinue)
}

Test-Module "Show-ProfilingReport function exists" {
    $null -ne (Get-Command Show-ProfilingReport -ErrorAction SilentlyContinue)
}

Test-Module "Profiling workflow executes correctly" {
    $p = Start-Profile "TestOperation"
    Start-Sleep -Milliseconds 50
    Stop-Profile "TestOperation" $p
    Show-ProfilingReport
    return $true
}

# Test 3: ConfigurationLoader Module
Write-Host "`n[3] ConfigurationLoader.psm1 Tests" -ForegroundColor Cyan
Write-Host "-" * 80

Test-Module "Module imports without errors" {
    Import-Module "$PSScriptRoot/modules/ConfigurationLoader.psm1" -Force
    return $true
}

Test-Module "Import-ScriptConfiguration function exists" {
    $null -ne (Get-Command Import-ScriptConfiguration -ErrorAction SilentlyContinue)
}

Test-Module "Get-ConfigValue function exists" {
    $null -ne (Get-Command Get-ConfigValue -ErrorAction SilentlyContinue)
}

Test-Module "Merge-ConfigurationWithParameters function exists" {
    $null -ne (Get-Command Merge-ConfigurationWithParameters -ErrorAction SilentlyContinue)
}

Test-Module "Import-ScriptConfiguration handles missing file gracefully" {
    $config = Import-ScriptConfiguration -ConfigFile "nonexistent.json"
    return $null -eq $config
}

# Test 4: EnvironmentDetection Module
Write-Host "`n[4] EnvironmentDetection.psm1 Tests" -ForegroundColor Cyan
Write-Host "-" * 80

Test-Module "Module imports without errors" {
    Import-Module "$PSScriptRoot/modules/EnvironmentDetection.psm1" -Force
    return $true
}

Test-Module "Test-AzurePipelines function exists" {
    $null -ne (Get-Command Test-AzurePipelines -ErrorAction SilentlyContinue)
}

Test-Module "Get-DefaultOutputPath function exists" {
    $null -ne (Get-Command Get-DefaultOutputPath -ErrorAction SilentlyContinue)
}

Test-Module "Test-PowerShellVersion function exists" {
    $null -ne (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue)
}

Test-Module "Get-BuildContext function exists" {
    $null -ne (Get-Command Get-BuildContext -ErrorAction SilentlyContinue)
}

Test-Module "Test-AzurePipelines returns boolean" {
    $result = Test-AzurePipelines
    return $result -is [bool]
}

Test-Module "Get-DefaultOutputPath returns valid path" {
    $path = Get-DefaultOutputPath -SubPath "test"
    return (-not [string]::IsNullOrEmpty($path))
}

Test-Module "Test-PowerShellVersion validates correctly" {
    $result = Test-PowerShellVersion -MinVersion "5.1"
    return $result -is [bool]
}

Test-Module "Get-BuildContext returns hashtable with IsCI" {
    $context = Get-BuildContext
    return ($context -is [hashtable] -and $context.ContainsKey('IsCI'))
}

# Test 5: Integration Tests
Write-Host "`n[5] Integration Tests" -ForegroundColor Cyan
Write-Host "-" * 80

Test-Module "All modules can be imported simultaneously" {
    Import-Module "$PSScriptRoot/modules/ScriptLogging.psm1" -Force
    Import-Module "$PSScriptRoot/modules/ScriptProfiling.psm1" -Force
    Import-Module "$PSScriptRoot/modules/ConfigurationLoader.psm1" -Force
    Import-Module "$PSScriptRoot/modules/EnvironmentDetection.psm1" -Force
    return $true
}

Test-Module "Logging works with environment detection" {
    $isCI = Test-AzurePipelines
    Write-Log "Running in CI: $isCI" -Level INFO
    return $true
}

Test-Module "Profiling works with logging" {
    $p = Start-Profile "IntegrationTest"
    Write-Log "Profiling test operation" -Level INFO
    Start-Sleep -Milliseconds 10
    Stop-Profile "IntegrationTest" $p
    return $true
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "`n"

$total = $passed + $failed
$successRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }

Write-Host "Total Tests:    " -NoNewline
Write-Host $total -ForegroundColor White

Write-Host "Passed:         " -NoNewline
Write-Host $passed -ForegroundColor Green

Write-Host "Failed:         " -NoNewline
Write-Host $failed -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

Write-Host "Success Rate:   " -NoNewline
Write-Host "$successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

Write-Host "`n"

if ($failed -eq 0) {
    Write-Host "✅ All module validations passed!" -ForegroundColor Green
    Write-Host "All 4 modules are working correctly after migration." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some validations failed!" -ForegroundColor Red
    Write-Host "Please review the failed tests above." -ForegroundColor Yellow
    exit 1
}

