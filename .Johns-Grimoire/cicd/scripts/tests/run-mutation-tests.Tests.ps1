<#
.SYNOPSIS
    Pester tests for run-mutation-tests.ps1

.DESCRIPTION
    Tests the mutation testing script including:
    - Write-Log function behavior
    - Test project discovery
    - Mutation score validation logic
    - Stryker.NET integration
    - Report generation
    - Azure Pipelines integration
#>

$ErrorActionPreference = "Stop"

# Get script path
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "run-mutation-tests.ps1"

# Import shared logging module (tests now validate the shared module)
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Describe "run-mutation-tests.ps1 Tests" {
    
    Context "Write-Log Function" {
        
        It "Should log INFO messages without throwing" {
            { Write-Log "Test message" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages without throwing" {
            { Write-Log "Success message" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log WARN messages without throwing" {
            { Write-Log "Warning message" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages without throwing" {
            { Write-Log "Error message" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages without throwing" {
            { Write-Log "Debug message" -Level DEBUG } | Should -Not -Throw
        }
        
        It "Should default to INFO level when not specified" {
            { Write-Log "Default level" } | Should -Not -Throw
        }
    }
    
    Context "Azure Pipelines Integration" {
        
        It "Should log ERROR in Azure Pipelines environment without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\_work\temp"
                { Write-Log "Error test" -Level ERROR } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should log WARN in Azure Pipelines environment without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                $env:AGENT_TEMPDIRECTORY = "C:\agent\_work\temp"
                { Write-Log "Warning test" -Level WARN } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                } else {
                    Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should log outside Azure Pipelines without throwing" {
            $originalAgentTemp = $env:AGENT_TEMPDIRECTORY
            try {
                Remove-Item Env:\AGENT_TEMPDIRECTORY -ErrorAction SilentlyContinue
                { Write-Log "Test" -Level ERROR } | Should -Not -Throw
            } finally {
                if ($originalAgentTemp) {
                    $env:AGENT_TEMPDIRECTORY = $originalAgentTemp
                }
            }
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should have Configuration parameter with ValidateSet" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[ValidateSet\("Debug", "Release"\)\]'
        }
        
        It "Should have Configuration parameter with default value Release" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Configuration = "Release"'
        }
        
        It "Should have TargetScore parameter with ValidateRange" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[ValidateRange\(0, 100\)\]'
        }
        
        It "Should have TargetScore parameter with default value 75" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$TargetScore = 75'
        }
        
        It "Should have ShowProgress switch parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$ShowProgress'
        }
        
        It "Should have OutputPath parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$OutputPath'
        }
    }
    
    Context "Environment Detection" {
        
        It "Should detect Azure Pipelines environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$isAzurePipeline'
        }
        
        It "Should set output path for Azure Pipelines" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:BUILD_ARTIFACTSTAGINGDIRECTORY'
        }
        
        It "Should set output path for local execution" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:TEMP'
        }
        
        It "Should handle progress bar display logic" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$showProgressBar'
        }
    }
    
    Context "Test Project Discovery" {
        
        It "Should search for test projects recursively" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-ChildItem.*-Path "tst".*-Recurse.*\*\.Tests\.csproj'
        }
        
        It "Should exit with code 0 when no test projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$testProjects\.Count -eq 0\).*exit 0'
        }
        
        It "Should log warning when no test projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*No test projects found.*WARN'
        }
    }
    
    Context "Stryker Configuration" {
        
        It "Should create Stryker configuration with project name" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$strykerConfig.*"project"'
        }
        
        It "Should include test-projects in configuration" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"test-projects"'
        }
        
        It "Should configure reporters (html, json, cleartext, progress)" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"reporters".*"html".*"json".*"cleartext".*"progress"'
        }
        
        It "Should set thresholds with target score" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"thresholds"'
            $scriptContent | Should -Match '"break" = \$TargetScore'
        }
        
        It "Should set concurrency level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"concurrency"'
        }
        
        It "Should set mutation-level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"mutation-level"'
        }
    }
    
    Context "Mutation Testing Execution" {
        
        It "Should execute dotnet stryker command" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'dotnet stryker.*--config-file'
        }
        
        It "Should use stryker-config.json as config file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'stryker-config\.json'
        }
        
        It "Should use Push-Location to change directory" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Push-Location'
        }
        
        It "Should use Pop-Location in finally block" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Pop-Location'
        }
        
        It "Should clean up config file in finally block" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Remove-Item \$configFile'
        }
    }
    
    Context "Report Parsing and Results" {
        
        It "Should search for mutation-report.json" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'mutation-report\.json'
        }
        
        It "Should parse JSON report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ConvertFrom-Json'
        }
        
        It "Should extract mutation score from report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$mutationScore'
        }
        
        It "Should copy report files to output directory" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Copy-Item.*-Destination.*-Recurse'
        }
    }
    
    Context "Mutation Score Validation" {
        
        It "Should compare mutation score against target" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$totalScore -lt \$TargetScore\)'
        }
        
        It "Should log warning when below target" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*below target.*WARN'
        }
        
        It "Should log success when meeting target" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*meets target.*SUCCESS'
        }
        
        It "Should provide recommendations when below target" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Consider:'
        }
    }
    
    Context "Summary Report Generation" {
        
        It "Should calculate average mutation score" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$totalScore.*Measure-Object.*-Average'
        }
        
        It "Should create summary object with timestamp" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$summary.*Timestamp.*Get-Date'
        }
        
        It "Should save summary to JSON file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'mutation-summary\.json'
            $scriptContent | Should -Match 'ConvertTo-Json'
        }
        
        It "Should include target score in summary" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'TargetScore = \$TargetScore'
        }
        
        It "Should include average score in summary" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'AverageScore = \$totalScore'
        }
    }
    
    Context "Error Handling" {
        
        It "Should have ErrorActionPreference set to Stop" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$ErrorActionPreference = "Stop"'
        }
        
        It "Should have try-catch block for mutation testing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'try \{'
            $scriptContent | Should -Match '\} catch \{'
        }
        
        It "Should have finally block for cleanup" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\} finally \{'
        }
        
        It "Should log errors when mutation testing fails" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*failed.*ERROR'
        }
    }
    
    Context "Exit Codes" {
        
        It "Should exit with code 0 on success (mutation testing is optional)" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'exit 0'
        }
        
        It "Should not fail build even if mutation score is low" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Should only have exit 0, no exit 1
            $exitLines = ($scriptContent -split "`n" | Where-Object { $_ -match '^exit \d+' })
            $exitLines.Count | Should -Be 2
        }
    }
    
    Context "Progress Reporting" {
        
        It "Should use Write-Progress for progress reporting" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Progress'
        }
        
        It "Should calculate percent complete" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$percentComplete'
        }
        
        It "Should complete progress bar at end" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Progress.*-Completed'
        }
        
        It "Should show progress conditionally based on ShowProgress parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$showProgressBar'
        }
    }
    
    Context "Long Duration Warning (UX Feature)" {
        
        It "Should display duration warning at start" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Warning:.*Mutation testing can take.*minutes'
        }
        
        It "Should use WARN level for duration warning" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*10-30 minutes.*WARN'
        }
    }
    
    Context "Stryker Tool Installation" {
        
        It "Should check for install-tools.ps1 script" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'install-tools\.ps1'
        }
        
        It "Should use central installer if available" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(Test-Path \$installScript\)'
        }
        
        It "Should have fallback installation method" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'dotnet tool install --global dotnet-stryker'
        }
    }
    
    Context "Report Output Paths" {
        
        It "Should create output directory if not exists" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(-not \(Test-Path \$OutputPath\)\)'
            $scriptContent | Should -Match 'New-Item.*-ItemType Directory'
        }
        
        It "Should create project-specific report subdirectories" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$projectReportDir = Join-Path \$OutputPath \$projectName'
        }
        
        It "Should copy Stryker output to report directory" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Copy-Item'
        }
    }
    
    Context "Documentation Completeness" {
        
        It "Should have .SYNOPSIS section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.SYNOPSIS'
        }
        
        It "Should have .DESCRIPTION section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.DESCRIPTION'
        }
        
        It "Should have .PARAMETER documentation for Configuration" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER Configuration'
        }
        
        It "Should have .PARAMETER documentation for OutputPath" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER OutputPath'
        }
        
        It "Should have .PARAMETER documentation for TargetScore" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER TargetScore'
        }
        
        It "Should have .EXAMPLE sections (at least 2)" {
            $scriptContent = Get-Content $scriptPath -Raw
            $examples = ([regex]::Matches($scriptContent, '\.EXAMPLE')).Count
            $examples -ge 2 | Should -Be $true
        }
        
        It "Should have .NOTES section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.NOTES'
        }
        
        It "Should have .LINK section with Stryker documentation" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.LINK'
            $scriptContent | Should -Match 'stryker-mutator\.io'
        }
    }
}


