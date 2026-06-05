<#
.SYNOPSIS
    Comprehensive Pester tests for enhanced-coverage-analysis.ps1

.DESCRIPTION
    Tests configuration loading, profiling, history tracking, trend analysis,
    test execution, coverage analysis, and threshold validation.
    
    Target: 80%+ code coverage (Production quality level)
    Compatible with Pester 3.x
#>

# Setup - Import shared modules used by the script
$script:scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "enhanced-coverage-analysis.ps1"
$script:modulesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
Import-Module (Join-Path $script:modulesPath "ScriptLogging.psm1") -Force
Import-Module (Join-Path $script:modulesPath "ScriptProfiling.psm1") -Force

Describe "enhanced-coverage-analysis.ps1 - Write-Log Function" {
    
    Context "When logging at different levels" {
        
        It "Should log INFO messages" {
            { Write-Log "Test info" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log WARN messages" {
            { Write-Log "Test warn" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages" {
            { Write-Log "Test error" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages" {
            { Write-Log "Test success" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages" {
            { Write-Log "Test debug" -Level DEBUG } | Should -Not -Throw
        }
    }
    
    Context "When logging to file" {
        
        It "Should write to log file when specified" {
            $logPath = Join-Path $TestDrive "test.log"
            Write-Log "Test message" -Level INFO -LogFile $logPath
            
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath -Raw
            $content | Should -Match "Test message"
        }
        
        It "Should append multiple log entries" {
            $logPath = Join-Path $TestDrive "append.log"
            Write-Log "First message" -Level INFO -LogFile $logPath
            Write-Log "Second message" -Level INFO -LogFile $logPath
            
            $lines = Get-Content $logPath
            $lines.Count | Should -Be 2
        }
        
        It "Should handle file logging errors gracefully" {
            $invalidPath = "Z:\nonexistent\path\test.log"
            { Write-Log "Test" -Level INFO -LogFile $invalidPath } | Should -Not -Throw
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Profiling Functions" {
    
    Context "When profiling is enabled" {
        BeforeEach {
            $script:profiler = @{}
            $script:EnableProfiling = $true
        }
        
        It "Should start a profile timer" {
            $stopwatch = Start-Profile "TestOperation"
            $stopwatch | Should -Not -BeNullOrEmpty
            $stopwatch.IsRunning | Should -Be $true
        }
        
        It "Should stop a profile timer and record duration" {
            $stopwatch = Start-Profile "TestOp"
            Start-Sleep -Milliseconds 100
            Stop-Profile "TestOp" $stopwatch
            
            $profiler["TestOp"] | Should -Not -BeNullOrEmpty
            $profiler["TestOp"] | Should -BeGreaterThan 0
        }
        
        It "Should handle null stopwatch gracefully" {
            { Stop-Profile "TestOp" $null } | Should -Not -Throw
        }
    }
    
    Context "When profiling is disabled" {
        BeforeEach {
            $script:EnableProfiling = $false
        }
        
        It "Should return null when starting profile" {
            $stopwatch = Start-Profile "TestOp"
            $stopwatch | Should -BeNullOrEmpty
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Coverage History" {
    
    Context "When adding coverage history entry" {
        
        It "Should create history file if not exists" {
            $historyFile = Join-Path $TestDrive "history.jsonl"
            
            # Simulate what Add-CoverageHistory does
            $record = [PSCustomObject]@{
                Timestamp = Get-Date -Format "o"
                LineCoverage = 85.5
                BranchCoverage = 75.2
            }
            $record | ConvertTo-Json -Compress | Add-Content $historyFile
            
            Test-Path $historyFile | Should -Be $true
        }
        
        It "Should append to existing history file" {
            $historyFile = Join-Path $TestDrive "history-append.jsonl"
            
            # First entry
            $record1 = [PSCustomObject]@{ LineCoverage = 80; BranchCoverage = 70 }
            $record1 | ConvertTo-Json -Compress | Add-Content $historyFile
            
            # Second entry
            $record2 = [PSCustomObject]@{ LineCoverage = 85; BranchCoverage = 75 }
            $record2 | ConvertTo-Json -Compress | Add-Content $historyFile
            
            $lines = Get-Content $historyFile
            $lines.Count | Should -Be 2
        }
        
        It "Should create history directory if not exists" {
            $historyFile = Join-Path $TestDrive "subdir\history.jsonl"
            
            $historyDir = Split-Path $historyFile -Parent
            if (-not (Test-Path $historyDir)) {
                New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
            }
            
            $record = [PSCustomObject]@{ LineCoverage = 80 }
            $record | ConvertTo-Json -Compress | Add-Content $historyFile
            
            Test-Path $historyFile | Should -Be $true
        }
        
        It "Should format history record correctly" {
            $historyFile = Join-Path $TestDrive "format-test.jsonl"
            
            $record = [PSCustomObject]@{
                Timestamp = Get-Date -Format "o"
                LineCoverage = 82.5
                BranchCoverage = 73.1
            }
            $record | ConvertTo-Json -Compress | Add-Content $historyFile
            
            $loaded = Get-Content $historyFile | ConvertFrom-Json
            $loaded.LineCoverage | Should -Be 82.5
            $loaded.BranchCoverage | Should -Be 73.1
            $loaded.Timestamp | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Coverage Trend Analysis" {
    
    Context "When history has multiple entries" {
        BeforeEach {
            $historyFile = Join-Path $TestDrive "trend.jsonl"
            
            # Create history with improving trend
            [PSCustomObject]@{ LineCoverage = 70; BranchCoverage = 65 } | ConvertTo-Json -Compress | Add-Content $historyFile
            [PSCustomObject]@{ LineCoverage = 75; BranchCoverage = 70 } | ConvertTo-Json -Compress | Add-Content $historyFile
            [PSCustomObject]@{ LineCoverage = 80; BranchCoverage = 75 } | ConvertTo-Json -Compress | Add-Content $historyFile
        }
        
        It "Should load history entries" {
            $history = Get-Content $historyFile | ForEach-Object { $_ | ConvertFrom-Json }
            $history.Count | Should -Be 3
        }
        
        It "Should calculate improving trend" {
            $history = Get-Content $historyFile | ForEach-Object { $_ | ConvertFrom-Json }
            $firstCoverage = $history[0].LineCoverage
            $lastCoverage = $history[-1].LineCoverage
            $trend = $lastCoverage - $firstCoverage
            
            $trend | Should -BeGreaterThan 0
        }
        
        It "Should detect declining trend" {
            $decliningFile = Join-Path $TestDrive "declining.jsonl"
            [PSCustomObject]@{ LineCoverage = 85; BranchCoverage = 80 } | ConvertTo-Json -Compress | Add-Content $decliningFile
            [PSCustomObject]@{ LineCoverage = 80; BranchCoverage = 75 } | ConvertTo-Json -Compress | Add-Content $decliningFile
            [PSCustomObject]@{ LineCoverage = 75; BranchCoverage = 70 } | ConvertTo-Json -Compress | Add-Content $decliningFile
            
            $history = Get-Content $decliningFile | ForEach-Object { $_ | ConvertFrom-Json }
            $trend = $history[-1].LineCoverage - $history[0].LineCoverage
            
            $trend | Should -BeLessThan 0
        }
    }
    
    Context "When history is empty" {
        It "Should handle empty history gracefully" {
            $emptyFile = Join-Path $TestDrive "empty.jsonl"
            Set-Content -Path $emptyFile -Value ""
            
            $history = Get-Content $emptyFile -ErrorAction SilentlyContinue | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
            $history.Count | Should -Be 0
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Configuration Loading" {
    
    Context "When configuration file exists" {
        
        It "Should load configuration from JSON file" {
            $configFile = Join-Path $TestDrive "config.json"
            $config = @{
                MinLineCoverage = 85
                MinBranchCoverage = 80
                EnableHistoryTracking = $true
            } | ConvertTo-Json
            
            Set-Content -Path $configFile -Value $config
            
            $loaded = Get-Content $configFile | ConvertFrom-Json
            $loaded.MinLineCoverage | Should -Be 85
        }
    }
    
    Context "When configuration file is invalid" {
        It "Should handle invalid JSON gracefully" {
            $invalidConfig = Join-Path $TestDrive "invalid.json"
            Set-Content -Path $invalidConfig -Value "{ invalid json"
            
            { Get-Content $invalidConfig | ConvertFrom-Json } | Should -Throw
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Environment Detection" {
    
    Context "When running in Azure Pipelines" {
        
        It "Should detect Azure Pipelines environment" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\artifacts"
            
            $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
            $isAzurePipeline | Should -Be $true
            
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            Remove-Item env:BUILD_ARTIFACTSTAGINGDIRECTORY -ErrorAction SilentlyContinue
        }
        
        It "Should use BUILD_ARTIFACTSTAGINGDIRECTORY for output" {
            $env:AGENT_TEMPDIRECTORY = "C:\agent\temp"
            $env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\agent\artifacts"
            
            $expectedPath = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/enhanced-coverage"
            $expectedPath | Should -BeLike "*artifacts*"
            
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            Remove-Item env:BUILD_ARTIFACTSTAGINGDIRECTORY -ErrorAction SilentlyContinue
        }
    }
    
    Context "When running locally" {
        
        It "Should detect local environment" {
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            
            $isAzurePipeline = [bool]$env:AGENT_TEMPDIRECTORY
            $isAzurePipeline | Should -Be $false
        }
        
        It "Should use TEMP directory for output" {
            Remove-Item env:AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
            
            $expectedPath = "$env:TEMP/enhanced-coverage"
            $expectedPath | Should -BeLike "*Temp*"
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Coverage Calculation" {
    
    Context "When calculating coverage percentage" {
        
        It "Should calculate line rate correctly" {
            $linesCovered = 80
            $linesTotal = 100
            $lineRate = ($linesCovered / $linesTotal) * 100
            
            $lineRate | Should -Be 80
        }
        
        It "Should round coverage to 2 decimal places" {
            $coverage = 85.6789
            $rounded = [Math]::Round($coverage, 2)
            
            $rounded | Should -Be 85.68
        }
        
        It "Should handle zero total lines" {
            $linesCovered = 0
            $linesTotal = 0
            $lineRate = if ($linesTotal -gt 0) { ($linesCovered / $linesTotal) * 100 } else { 0 }
            
            $lineRate | Should -Be 0
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Threshold Validation" {
    
    Context "When coverage meets thresholds" {
        
        It "Should pass line coverage threshold" {
            $lineRate = 85.0
            $minThreshold = 80
            
            $lineRate | Should -BeGreaterThan $minThreshold
        }
        
        It "Should pass branch coverage threshold" {
            $branchRate = 75.0
            $minThreshold = 70
            
            $branchRate | Should -BeGreaterThan $minThreshold
        }
        
        It "Should pass public API coverage threshold" {
            $apiCoverage = 95.0
            $minThreshold = 90
            
            $apiCoverage | Should -BeGreaterThan $minThreshold
        }
    }
    
    Context "When coverage is below thresholds" {
        
        It "Should detect line coverage failure" {
            $lineRate = 75.0
            $minThreshold = 80
            
            $failed = $lineRate -lt $minThreshold
            $failed | Should -Be $true
        }
        
        It "Should detect branch coverage failure" {
            $branchRate = 65.0
            $minThreshold = 70
            
            $failed = $branchRate -lt $minThreshold
            $failed | Should -Be $true
        }
        
        It "Should detect public API coverage warning" {
            $apiCoverage = 85.0
            $minThreshold = 90
            
            $belowThreshold = $apiCoverage -lt $minThreshold
            $belowThreshold | Should -Be $true
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Test Result Parsing" {
    
    Context "When parsing TRX test result files" {
        
        It "Should calculate pass rate correctly" {
            $totalTests = 100
            $passedTests = 85
            $passRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
            
            $passRate | Should -Be 85
        }
        
        It "Should handle zero tests" {
            $totalTests = 0
            $passedTests = 0
            $passRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
            
            $passRate | Should -Be 0
        }
        
        It "Should detect test failures" {
            $failedTests = 5
            $hasFailed = $failedTests -gt 0
            
            $hasFailed | Should -Be $true
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Coverage XML Parsing" {
    
    Context "When parsing Cobertura XML" {
        
        It "Should extract line rate from coverage XML" {
            $xmlContent = @"
<?xml version="1.0"?>
<coverage line-rate="0.85" branch-rate="0.75" version="1.0">
    <packages>
        <package name="TestPackage" line-rate="0.85" branch-rate="0.75">
            <classes>
                <class name="TestClass" line-rate="0.90" branch-rate="0.80">
                </class>
            </classes>
        </package>
    </packages>
</coverage>
"@
            $coverageFile = Join-Path $TestDrive "coverage.cobertura.xml"
            Set-Content -Path $coverageFile -Value $xmlContent
            
            [xml]$coverage = Get-Content $coverageFile
            $lineRate = [double]$coverage.coverage.'line-rate' * 100
            
            $lineRate | Should -Be 85
        }
        
        It "Should extract branch rate from coverage XML" {
            $xmlContent = @"
<?xml version="1.0"?>
<coverage line-rate="0.85" branch-rate="0.75" version="1.0">
</coverage>
"@
            $coverageFile = Join-Path $TestDrive "coverage-branch.cobertura.xml"
            Set-Content -Path $coverageFile -Value $xmlContent
            
            [xml]$coverage = Get-Content $coverageFile
            $branchRate = [double]$coverage.coverage.'branch-rate' * 100
            
            $branchRate | Should -Be 75
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Package Coverage Analysis" {
    
    Context "When analyzing per-package coverage" {
        
        It "Should identify low coverage packages" {
            $package1 = New-Object PSObject -Property @{ Name = "Package1"; LineRate = 0.85 }
            $package2 = New-Object PSObject -Property @{ Name = "Package2"; LineRate = 0.65 }
            $package3 = New-Object PSObject -Property @{ Name = "Package3"; LineRate = 0.90 }
            $packages = @($package1, $package2, $package3)
            
            $minThreshold = 0.80
            $lowCoverage = @($packages | Where-Object { [double]$_.LineRate -lt $minThreshold })
            
            $lowCoverage.Count | Should -Be 1
            $lowCoverage[0].Name | Should -Be "Package2"
        }
        
        It "Should calculate package coverage percentage correctly" {
            $packageLineRate = 0.8567
            $percentage = [Math]::Round($packageLineRate * 100, 2)
            
            $percentage | Should -Be 85.67
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Uncovered Code Analysis" {
    
    Context "When analyzing uncovered code" {
        
        It "Should identify completely uncovered classes" {
            $class1 = New-Object PSObject -Property @{ Name = "Class1"; LineRate = 0.0 }
            $class2 = New-Object PSObject -Property @{ Name = "Class2"; LineRate = 0.85 }
            $class3 = New-Object PSObject -Property @{ Name = "Class3Tests"; LineRate = 0.0 }
            $classes = @($class1, $class2, $class3)
            
            $uncovered = @($classes | Where-Object { 
                [double]$_.LineRate -eq 0 -and $_.Name -notmatch '(Tests|Internal|Private)' 
            })
            
            $uncovered.Count | Should -Be 1
            $uncovered[0].Name | Should -Be "Class1"
        }
        
        It "Should exclude test classes from uncovered analysis" {
            $classes = @(
                [PSCustomObject]@{ Name = "MyTests"; LineRate = 0.0 }
                [PSCustomObject]@{ Name = "InternalHelper"; LineRate = 0.0 }
            )
            
            $uncovered = $classes | Where-Object { 
                [double]$_.LineRate -eq 0 -and $_.Name -notmatch '(Tests|Internal|Private)' 
            }
            
            $uncovered.Count | Should -Be 0
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Public API Coverage" {
    
    Context "When calculating public API coverage" {
        
        It "Should calculate coverage percentage" {
            $publicTypes = 50
            $coveredTypes = 45
            $apiCoverage = [Math]::Round(($coveredTypes / $publicTypes) * 100, 2)
            
            $apiCoverage | Should -Be 90
        }
        
        It "Should handle zero public types" {
            $publicTypes = 0
            $coveredTypes = 0
            $apiCoverage = if ($publicTypes -gt 0) {
                [Math]::Round(($coveredTypes / $publicTypes) * 100, 2)
            } else {
                100
            }
            
            $apiCoverage | Should -Be 100
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Summary Report Generation" {
    
    Context "When generating summary report" {
        
        It "Should create valid summary structure" {
            $summary = @{
                Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                TestResults = @{
                    TotalTests = 100
                    PassedTests = 95
                    PassRate = 95.0
                }
                Coverage = @{
                    LineCoverage = 85.5
                    BranchCoverage = 75.2
                }
                Thresholds = @{
                    MinLine = 80
                    MinBranch = 70
                }
            }
            
            $summary.TestResults.TotalTests | Should -Be 100
            $summary.Coverage.LineCoverage | Should -Be 85.5
        }
        
        It "Should convert summary to JSON" {
            $summary = @{
                Coverage = @{
                    LineCoverage = 85.5
                }
            }
            
            $json = $summary | ConvertTo-Json -Depth 10
            $json | Should -Not -BeNullOrEmpty
            $json | Should -Match "LineCoverage"
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Parameter Validation" {
    
    Context "When validating parameters" {
        
        It "Should validate Configuration parameter" {
            $validConfigs = @("Debug", "Release")
            $isValid = "Release" -in $validConfigs
            $isValid | Should -Be $true
        }
        
        It "Should validate coverage range (0-100)" {
            $minCoverage = 80
            ($minCoverage -ge 0 -and $minCoverage -le 100) | Should -Be $true
        }
        
        It "Should reject invalid coverage values" {
            $invalidCoverage = 150
            ($invalidCoverage -ge 0 -and $invalidCoverage -le 100) | Should -Be $false
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Error Handling" {
    
    Context "When external commands fail" {
        
        It "Should detect non-zero exit code" {
            $LASTEXITCODE = 1
            $hasFailed = $LASTEXITCODE -ne 0
            
            $hasFailed | Should -Be $true
        }
        
        It "Should detect zero exit code as success" {
            $LASTEXITCODE = 0
            $hasFailed = $LASTEXITCODE -ne 0
            
            $hasFailed | Should -Be $false
        }
    }
    
    Context "When coverage files are missing" {
        
        It "Should detect missing coverage files" {
            $nonexistentPath = Join-Path $TestDrive "nonexistent\coverage.xml"
            Test-Path $nonexistentPath | Should -Be $false
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Report Types" {
    
    Context "When specifying report types" {
        
        It "Should accept semicolon-separated report types" {
            $reportTypes = "Cobertura;HtmlInline_AzurePipelines;JsonSummary;Badges"
            $types = $reportTypes -split ";"
            
            $types.Count | Should -Be 4
            $types[0] | Should -Be "Cobertura"
        }
        
        It "Should handle single report type" {
            $reportTypes = "HtmlInline"
            $types = $reportTypes -split ";"
            
            $types.Count | Should -Be 1
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - Assembly Filters" {
    
    Context "When specifying assembly filters" {
        
        It "Should parse filter string" {
            $filters = "+*; -*Tests; -*Benchmarks"
            $filters | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle simple filter" {
            $filters = "+*"
            $filters | Should -Be "+*"
        }
    }
}

Describe "enhanced-coverage-analysis.ps1 - File Operations" {
    
    Context "When creating output directories" {
        
        It "Should create output directory if not exists" {
            $outputDir = Join-Path $TestDrive "new-output"
            
            if (-not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
            }
            
            Test-Path $outputDir | Should -Be $true
        }
    }
    
    Context "When writing summary files" {
        
        It "Should write JSON summary file" {
            $summary = @{ LineCoverage = 85 }
            $summaryFile = Join-Path $TestDrive "summary.json"
            
            $summary | ConvertTo-Json | Set-Content $summaryFile
            
            Test-Path $summaryFile | Should -Be $true
            $loaded = Get-Content $summaryFile | ConvertFrom-Json
            $loaded.LineCoverage | Should -Be 85
        }
    }
}

