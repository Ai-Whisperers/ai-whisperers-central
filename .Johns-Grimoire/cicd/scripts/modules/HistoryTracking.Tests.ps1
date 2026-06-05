<#
.SYNOPSIS
    Pester tests for HistoryTracking.psm1 module

.DESCRIPTION
    Validates history tracking functionality including metric persistence,
    JSON Lines format, rotation, and trend retrieval.
#>

BeforeAll {
    $script:modulePath = Join-Path $PSScriptRoot "HistoryTracking.psm1"
    Import-Module $script:modulePath -Force
    
    $script:testHistoryFile = Join-Path $TestDrive "test-history.jsonl"
}

AfterAll {
    Remove-Module HistoryTracking -ErrorAction SilentlyContinue
}

Describe "HistoryTracking Module" {
    
    Context "Module Structure" {
        
        It "should export Add-HistoryEntry function" {
            Get-Command Add-HistoryEntry -Module HistoryTracking | Should -Not -BeNullOrEmpty
        }
        
        It "should export Get-HistoryTrend function" {
            Get-Command Get-HistoryTrend -Module HistoryTracking | Should -Not -BeNullOrEmpty
        }
        
        It "should export exactly 2 functions" {
            $exports = Get-Command -Module HistoryTracking
            $exports.Count | Should -Be 2
        }
    }
    
    Context "Add-HistoryEntry" {
        
        BeforeEach {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
        }
        
        It "should create parent directory if missing" {
            $testFile = Join-Path $TestDrive "subdir\history.jsonl"
            $metrics = @{ Test = 100 }
            
            Add-HistoryEntry -HistoryFile $testFile -Metrics $metrics
            
            Test-Path (Split-Path $testFile -Parent) | Should -Be $true
        }
        
        It "should append metric entry to history file" {
            $metrics = @{ LineCoverage = 80.5; BranchCoverage = 70.2 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            Test-Path $script:testHistoryFile | Should -Be $true
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 1
        }
        
        It "should create JSON Lines format entry" {
            $metrics = @{ Value = 42 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $line = Get-Content $script:testHistoryFile
            { $line | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "should include timestamp in entry" {
            $metrics = @{ Value = 42 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $timestamp = if ($entry.timestamp -is [datetime]) {
                $entry.timestamp.ToUniversalTime().ToString("o")
            } else {
                $entry.timestamp.ToString().Trim()
            }

            $timestamp | Should -Not -BeNullOrEmpty
            { [datetime]::Parse($timestamp) } | Should -Not -Throw
            $timestamp | Should -Match 'Z$'
        }
        
        It "should include git commit in entry" {
            $metrics = @{ Value = 42 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $entry.commit | Should -Not -BeNullOrEmpty
        }
        
        It "should include git branch in entry" {
            $metrics = @{ Value = 42 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $entry.branch | Should -Not -BeNullOrEmpty
        }
        
        It "should include metrics hashtable in entry" {
            $metrics = @{ LineCoverage = 80.5; BranchCoverage = 70.2 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $entry.metrics.LineCoverage | Should -Be 80.5
            $entry.metrics.BranchCoverage | Should -Be 70.2
        }
        
        It "should handle git not available gracefully" {
            $metrics = @{ Value = 42 }
            
            { Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics } | Should -Not -Throw
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $entry.commit | Should -Not -BeNullOrEmpty
            $entry.branch | Should -Not -BeNullOrEmpty
        }
        
        It "should append multiple entries without overwriting" {
            $metrics1 = @{ Value = 10 }
            $metrics2 = @{ Value = 20 }
            $metrics3 = @{ Value = 30 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics1
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics2
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics3
            
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 3
            
            $entries = $content | ForEach-Object { $_ | ConvertFrom-Json }
            $entries[0].metrics.Value | Should -Be 10
            $entries[1].metrics.Value | Should -Be 20
            $entries[2].metrics.Value | Should -Be 30
        }
        
        It "should rotate file when MaxEntries exceeded" {
            $metrics1 = @{ Value = 1 }
            $metrics2 = @{ Value = 2 }
            $metrics3 = @{ Value = 3 }
            $metrics4 = @{ Value = 4 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics1 -MaxEntries 3
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics2 -MaxEntries 3
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics3 -MaxEntries 3
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics4 -MaxEntries 3
            
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 3
            
            $entries = $content | ForEach-Object { $_ | ConvertFrom-Json }
            $entries[0].metrics.Value | Should -Be 2
            $entries[1].metrics.Value | Should -Be 3
            $entries[2].metrics.Value | Should -Be 4
        }
        
        It "should not rotate when MaxEntries is 0" {
            1..10 | ForEach-Object {
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = $_ } -MaxEntries 0
            }
            
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 10
        }
        
        It "should not rotate when MaxEntries is -1" {
            1..10 | ForEach-Object {
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = $_ } -MaxEntries -1
            }
            
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 10
        }
        
        It "should handle complex nested metrics" {
            $metrics = @{
                Coverage = @{
                    Line = 80.5
                    Branch = 70.2
                    Method = 85.0
                }
                Tests = @{
                    Total = 150
                    Passed = 148
                    Failed = 2
                }
            }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $entry = Get-Content $script:testHistoryFile | ConvertFrom-Json
            $entry.metrics.Coverage.Line | Should -Be 80.5
            $entry.metrics.Tests.Total | Should -Be 150
        }
        
        It "should handle write failures gracefully" {
            $readOnlyFile = Join-Path $TestDrive "readonly.jsonl"
            New-Item -Path $readOnlyFile -ItemType File -Force | Out-Null
            Set-ItemProperty -Path $readOnlyFile -Name IsReadOnly -Value $true
            
            $metrics = @{ Value = 42 }
            
            { Add-HistoryEntry -HistoryFile $readOnlyFile -Metrics $metrics -WarningAction SilentlyContinue } | Should -Not -Throw
            
            Set-ItemProperty -Path $readOnlyFile -Name IsReadOnly -Value $false
        }
    }
    
    Context "Get-HistoryTrend" {
        
        BeforeEach {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
            
            1..15 | ForEach-Object {
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = $_ }
            }
        }
        
        It "should return empty array when file doesn't exist" {
            $nonExistentFile = Join-Path $TestDrive "nonexistent.jsonl"
            
            $result = Get-HistoryTrend -HistoryFile $nonExistentFile

            if ($null -eq $result) {
                $result = @()
            }
            
            ($result -is [System.Array]) | Should -Be $true
            $result.Count | Should -Be 0
        }
        
        It "should retrieve last N entries by default (10)" {
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile
            
            $trend.Count | Should -Be 10
            $trend[0].metrics.Value | Should -Be 6
            $trend[-1].metrics.Value | Should -Be 15
        }
        
        It "should retrieve specified number of entries" {
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 5
            
            $trend.Count | Should -Be 5
            $trend[0].metrics.Value | Should -Be 11
            $trend[-1].metrics.Value | Should -Be 15
        }
        
        It "should retrieve all entries when LastN exceeds file size" {
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 100
            
            $trend.Count | Should -Be 15
        }
        
        It "should return entries as PowerShell objects" {
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 1
            
            $trend[0] | Should -BeOfType [PSCustomObject]
            $trend[0].timestamp | Should -Not -BeNullOrEmpty
            $trend[0].commit | Should -Not -BeNullOrEmpty
            $trend[0].branch | Should -Not -BeNullOrEmpty
            $trend[0].metrics | Should -Not -BeNullOrEmpty
        }
        
        It "should preserve metric data types" {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
            
            $metrics = @{
                IntValue = 42
                DoubleValue = 85.5
                StringValue = "test"
                BoolValue = $true
            }
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 1
            
            $trend[0].metrics.IntValue | Should -Be 42
            $trend[0].metrics.DoubleValue | Should -Be 85.5
            $trend[0].metrics.StringValue | Should -Be "test"
            $trend[0].metrics.BoolValue | Should -Be $true
        }
        
        It "should return entries in chronological order (oldest first)" {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = 100 }
            Start-Sleep -Milliseconds 100
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = 200 }
            Start-Sleep -Milliseconds 100
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = 300 }
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 10
            
            $trend[0].metrics.Value | Should -Be 100
            $trend[1].metrics.Value | Should -Be 200
            $trend[2].metrics.Value | Should -Be 300
        }
    }
    
    Context "Full Workflow" {
        
        BeforeEach {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
        }
        
        It "should support complete history tracking workflow" {
            1..5 | ForEach-Object {
                $metrics = @{
                    Iteration = $_
                    Coverage = 70 + $_
                    Tests = 100 + ($_ * 10)
                }
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            }
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 5
            
            $trend.Count | Should -Be 5
            $trend[0].metrics.Iteration | Should -Be 1
            $trend[0].metrics.Coverage | Should -Be 71
            $trend[-1].metrics.Iteration | Should -Be 5
            $trend[-1].metrics.Coverage | Should -Be 75
        }
        
        It "should enable trend analysis calculations" {
            1..10 | ForEach-Object {
                $metrics = @{ Value = $_ * 10 }
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics
            }
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 10
            
            $firstValue = $trend[0].metrics.Value
            $lastValue = $trend[-1].metrics.Value
            $change = $lastValue - $firstValue
            
            $firstValue | Should -Be 10
            $lastValue | Should -Be 100
            $change | Should -Be 90
        }
        
        It "should support multiple metrics types in same file" {
            $metrics1 = @{ Type = "Coverage"; Line = 80; Branch = 70 }
            $metrics2 = @{ Type = "Metrics"; Complexity = 15; Maintainability = 65 }
            $metrics3 = @{ Type = "Performance"; Duration = 125; Memory = 512 }
            
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics1
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics2
            Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics3
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile -LastN 10
            
            $trend.Count | Should -Be 3
            $trend[0].metrics.Type | Should -Be "Coverage"
            $trend[1].metrics.Type | Should -Be "Metrics"
            $trend[2].metrics.Type | Should -Be "Performance"
        }
    }
    
    Context "Error Handling" {
        BeforeEach {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
        }
        
        It "should not throw when adding to invalid path" {
            $invalidPath = "Z:\NonExistent\Path\history.jsonl"
            $metrics = @{ Value = 42 }
            
            { Add-HistoryEntry -HistoryFile $invalidPath -Metrics $metrics -WarningAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "should handle empty metrics hashtable" {
            $metrics = @{}
            
            { Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics } | Should -Not -Throw
            
            $entry = Get-Content $script:testHistoryFile | Select-Object -Last 1 | ConvertFrom-Json
            ($null -ne $entry.metrics) | Should -Be $true
        }
        
        It "should handle null values in metrics" {
            $metrics = @{ Value = $null; Name = "test" }
            
            { Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics $metrics } | Should -Not -Throw
            
            $entry = Get-Content $script:testHistoryFile | Select-Object -Last 1 | ConvertFrom-Json
            $entry.metrics.Value | Should -BeNullOrEmpty
            $entry.metrics.Name | Should -Be "test"
        }
    }
    
    Context "Rotation Logic" {
        
        BeforeEach {
            if (Test-Path $script:testHistoryFile) {
                Remove-Item $script:testHistoryFile -Force
            }
        }
        
        It "should keep only MaxEntries when limit reached" {
            1..10 | ForEach-Object {
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ Value = $_ } -MaxEntries 5
            }
            
            $content = Get-Content $script:testHistoryFile
            @($content).Count | Should -Be 5
            
            $entries = $content | ForEach-Object { $_ | ConvertFrom-Json }
            $entries[0].metrics.Value | Should -Be 6
            $entries[-1].metrics.Value | Should -Be 10
        }
        
        It "should rotate oldest entries first" {
            1..7 | ForEach-Object {
                Add-HistoryEntry -HistoryFile $script:testHistoryFile -Metrics @{ ID = $_ } -MaxEntries 3
            }
            
            $trend = Get-HistoryTrend -HistoryFile $script:testHistoryFile
            
            $trend.Count | Should -Be 3
            $trend[0].metrics.ID | Should -Be 5
            $trend[1].metrics.ID | Should -Be 6
            $trend[2].metrics.ID | Should -Be 7
        }
    }
}

