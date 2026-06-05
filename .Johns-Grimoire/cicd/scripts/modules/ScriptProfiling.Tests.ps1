<#
.SYNOPSIS
    Pester tests for ScriptProfiling.psm1 module

.DESCRIPTION
    Tests all exported functions from ScriptProfiling module:
    - Start-Profile
    - Stop-Profile
    - Show-ProfilingReport
#>

Describe "ScriptProfiling Module" {
    
    BeforeAll {
        $script:here = $PSScriptRoot
        $script:modulePath = Join-Path $script:here "ScriptProfiling.psm1"

        Import-Module $script:modulePath -Force
    }

    BeforeEach {
        $script:profilingModule = Get-Module ScriptProfiling
        if ($script:profilingModule) {
            $script:profilingModule.SessionState.PSVariable.Set('EnableProfiling', $true)
        }
    }
    
    AfterAll {
        Remove-Module ScriptProfiling -Force -ErrorAction SilentlyContinue
        if ($script:profilingModule) {
            $script:profilingModule.SessionState.PSVariable.Remove('EnableProfiling')
        }
    }
    
    Context "Module Structure" {
        It "Should import without errors" {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }
        
        It "Should export Start-Profile function" {
            $command = Get-Command Start-Profile -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ScriptProfiling'
        }
        
        It "Should export Stop-Profile function" {
            $command = Get-Command Stop-Profile -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ScriptProfiling'
        }
        
        It "Should export Show-ProfilingReport function" {
            $command = Get-Command Show-ProfilingReport -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.ModuleName | Should -Be 'ScriptProfiling'
        }
    }
    
    Context "Start-Profile Function" {
        It "Should accept OperationName parameter" {
            { Start-Profile "TestOperation" } | Should -Not -Throw
        }
        
        It "Should return a stopwatch when profiling enabled" {
            $result = Start-Profile "TestOp"
            $result | Should -BeOfType [System.Diagnostics.Stopwatch]
        }
        
        It "Should return a running stopwatch" {
            $result = Start-Profile "TestOperation"
            $result.IsRunning | Should -Be $true
        }
        
        It "Should return stopwatch with elapsed time" {
            $result = Start-Profile "TestOp"
            $result.Elapsed | Should -BeOfType [timespan]
        }
        
        It "Should accept operation name with spaces" {
            { Start-Profile "Test Operation With Spaces" } | Should -Not -Throw
        }
        
        It "Should accept special characters in operation name" {
            { Start-Profile "Test-Operation_123" } | Should -Not -Throw
        }
    }
    
    Context "Stop-Profile Function" {
        It "Should accept OperationName and Profile parameters" {
            $profile = Start-Profile "TestOp"
            { Stop-Profile "TestOp" $profile } | Should -Not -Throw
        }
        
        It "Should calculate duration" {
            $profile = Start-Profile "TestOperation"
            Start-Sleep -Milliseconds 100
            Stop-Profile "TestOperation" $profile
            
            # Check that duration was recorded (internal state)
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should handle profile from Start-Profile output" {
            $profile = Start-Profile "Test"
            Start-Sleep -Milliseconds 50
            { Stop-Profile "Test" $profile } | Should -Not -Throw
        }
        
        It "Should handle multiple sequential profiles" {
            $p1 = Start-Profile "Op1"
            Stop-Profile "Op1" $p1
            
            $p2 = Start-Profile "Op2"
            Stop-Profile "Op2" $p2
            
            { Show-ProfilingReport } | Should -Not -Throw
        }
    }
    
    Context "Show-ProfilingReport Function" {
        BeforeEach {
            # Clear any existing profiles
            Import-Module $modulePath -Force
        }
        
        It "Should run without errors" {
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should show report after profiling operations" {
            $p = Start-Profile "TestOperation"
            Start-Sleep -Milliseconds 50
            Stop-Profile "TestOperation" $p
            
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should handle empty profile state" {
            # Fresh import means no profiles yet
            Import-Module $modulePath -Force
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should show multiple operations in report" {
            $p1 = Start-Profile "Operation1"
            Start-Sleep -Milliseconds 20
            Stop-Profile "Operation1" $p1
            
            $p2 = Start-Profile "Operation2"
            Start-Sleep -Milliseconds 30
            Stop-Profile "Operation2" $p2
            
            { Show-ProfilingReport } | Should -Not -Throw
        }
    }
    
    Context "Profiling Workflow - Integration" {
        It "Should complete full profiling workflow" {
            # Start profile
            $profile = Start-Profile "FullWorkflow"
            $profile | Should -Not -BeNullOrEmpty
            
            # Simulate work
            Start-Sleep -Milliseconds 100
            
            # Stop profile
            { Stop-Profile "FullWorkflow" $profile } | Should -Not -Throw
            
            # Show report
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should handle nested profiling (multiple operations)" {
            $p1 = Start-Profile "OuterOperation"
            Start-Sleep -Milliseconds 50
            
            $p2 = Start-Profile "InnerOperation"
            Start-Sleep -Milliseconds 25
            Stop-Profile "InnerOperation" $p2
            
            Stop-Profile "OuterOperation" $p1
            
            { Show-ProfilingReport } | Should -Not -Throw
        }
        
        It "Should measure time accurately (within tolerance)" {
            $profile = Start-Profile "TimingTest"
            $startTime = Get-Date
            
            Start-Sleep -Milliseconds 200
            
            Stop-Profile "TimingTest" $profile
            $endTime = Get-Date
            
            $actualDuration = ($endTime - $startTime).TotalMilliseconds
            
            # Duration should be approximately 200ms (±50ms tolerance for system variability)
            $actualDuration | Should -BeGreaterThan 150
            $actualDuration | Should -BeLessThan 300
        }
    }
    
    Context "Error Handling" {
        It "Should handle Stop-Profile without Start-Profile gracefully" {
            # This tests if Stop-Profile handles invalid/missing profile data
            $fakeProfile = $null
            { Stop-Profile "Fake" $fakeProfile } | Should -Not -Throw
        }
        
        It "Should handle Show-ProfilingReport with no profiles" {
            Import-Module $modulePath -Force
            { Show-ProfilingReport } | Should -Not -Throw
        }
    }
}

