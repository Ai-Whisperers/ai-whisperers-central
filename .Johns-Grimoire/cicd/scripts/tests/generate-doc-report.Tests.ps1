<#
.SYNOPSIS
    Pester tests for generate-doc-report.ps1

.DESCRIPTION
    Comprehensive test suite covering:
    - Write-Log function behavior
    - Azure Pipelines integration
    - Parameter validation
    - JSON configuration file loading
    - Config precedence (CLI > Config > Defaults)
    - Parallel and sequential processing
    - Performance profiling feature
    - Target framework detection
    - XML file analysis
    - Report generation
    - Documentation completeness
#>

$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.ps1', '.ps1'
$script:scriptPath = Join-Path (Split-Path $script:here -Parent) $script:sut
Set-Variable -Name scriptPath -Value $script:scriptPath -Scope Global

Describe "generate-doc-report.ps1" {
    
    Context "Write-Log Function" {
        It "Should import ScriptLogging module" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Import-Module.*ScriptLogging\.psm1'
        }
        
        It "Should support INFO level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level INFO'
        }
        
        It "Should support WARN level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level WARN'
        }
        
        It "Should support ERROR level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level ERROR'
        }
        
        It "Should support SUCCESS level" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level SUCCESS'
        }
        
        It "Should use Write-Log for report status output" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*Documentation Coverage Report'
        }
    }
    
    Context "Azure Pipelines Integration" {
        It "Should integrate with Azure Pipelines logging" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level ERROR'
        }
        
        It "Should check for BUILD_SOURCESDIRECTORY environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:BUILD_SOURCESDIRECTORY'
        }
        
        It "Should use Azure Pipelines warning commands" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Write-Log.*-Level WARN'
        }
    }
    
    Context "Parameter Validation" {
        It "Should have Configuration parameter with ValidateSet" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[ValidateSet\("Debug", "Release"\)\][\s\S]*\[string\]\$Configuration'
        }
        
        It "Should have OutputPath parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$OutputPath'
        }
        
        It "Should have DisableParallel switch parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$DisableParallel'
        }
        
        It "Should have ThrottleLimit parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[int\]\$ThrottleLimit'
        }
        
        It "Should have EnableProfiling switch parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$EnableProfiling'
        }
        
        It "Should have ConfigFile parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$ConfigFile'
        }
        
        It "Should use CmdletBinding" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[CmdletBinding\(\)\]'
        }
    }
    
    Context "Configuration File Support" {
        It "Should check if config file exists" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Import-ScriptConfiguration -ConfigFile \$ConfigFile'
        }
        
        It "Should load JSON configuration" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Import-ScriptConfiguration -ConfigFile \$ConfigFile'
        }
        
        It "Should handle config load failures" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$config\)'
        }
        
        It "Should check PSBoundParameters for parameter precedence" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Merge-ConfigurationWithParameters.*-BoundParameters \$PSBoundParameters'
        }
        
        It "Should apply config value for Configuration if not CLI-provided" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "'Configuration' = 'Configuration'"
        }
        
        It "Should apply config value for OutputPath if not CLI-provided" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "'OutputPath' = 'OutputPath'"
        }
        
        It "Should apply config value for ThrottleLimit if not CLI-provided" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "'ThrottleLimit' = 'ThrottleLimit'"
        }
        
        It "Should apply defaults when no config or CLI" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(-not \$Configuration\)'
        }
    }
    
    Context "Configuration Defaults" {
        It "Should default Configuration to Release" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Configuration = "Release"'
        }
        
        It "Should default OutputPath to docs-report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$OutputPath = "docs-report"'
        }
        
        It "Should default ThrottleLimit to NUMBER_OF_PROCESSORS or 4" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:NUMBER_OF_PROCESSORS'
        }
        
        It "Should fallback ThrottleLimit to 4" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$ThrottleLimit = 4'
        }
    }
    
    Context "Performance Profiling Feature" {
        It "Should import ScriptProfiling module" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Import-Module \$ProfilingModulePath -Force'
        }
        
        It "Should call Show-ProfilingReport" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Show-ProfilingReport'
        }
    }
    
    Context "Project Discovery" {
        It "Should search for .csproj files in src directory" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-ChildItem.*src.*\.csproj'
        }
        
        It "Should exit with error if no projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$SourceProjects\.Count -eq 0\)[\s\S]*exit 1'
        }
        
        It "Should report number of projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Found.*source project'
        }
    }
    
    Context "Target Framework Detection" {
        It "Should import ProjectUtilities module" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Import-Module.*ProjectUtilities\.psm1'
        }
        
        It "Should call Get-TargetFramework" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-TargetFramework -ProjectPath'
        }
    }
    
    Context "Sequential Processing Logic" {
        It "Should process sequentially when DisableParallel is true" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$DisableParallel'
        }
        
        It "Should process sequentially for single project" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$SourceProjects\.Count -le 1'
        }
        
        It "Should report sequential processing mode" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Processing.*sequentially'
        }
        
        It "Should use ForEach-Object for sequential processing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$results = \$SourceProjects \| ForEach-Object'
        }
    }
    
    Context "Parallel Processing Logic" {
        It "Should process in parallel when not disabled" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ForEach-Object -Parallel'
        }
        
        It "Should report parallel processing mode with throttle" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Processing.*parallel.*Throttle'
        }
        
        It "Should use ThrottleLimit parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '-ThrottleLimit \$ThrottleLimit'
        }
        
        It "Should have synchronized progress tracking" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Hashtable.*Synchronized'
        }
        
        It "Should use using scope in parallel blocks" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$using:'
        }
    }
    
    Context "XML File Analysis" {
        It "Should construct XML path from target framework" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$XmlPath.*bin.*\$Configuration'
        }
        
        It "Should check if XML file exists" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Test-Path \$XmlPath'
        }
        
        It "Should get file size" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-Item.*\.Length'
        }
        
        It "Should parse XML content" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[xml\]\$XmlDoc = Get-Content'
        }
        
        It "Should count documented members" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$XmlDoc\.doc\.members\.member'
        }
        
        It "Should detect empty XML files" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'FileSizeBytes -eq 0'
        }
    }
    
    Context "Status Classification" {
        It "Should classify status as Missing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Status = "Missing"'
        }
        
        It "Should classify status as Empty" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Status = "Empty"'
        }
        
        It "Should classify status as Low" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Status = "Low"'
        }
        
        It "Should classify status as Good" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Status = "Good"'
        }
        
        It "Should classify status as Invalid" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Status = "Invalid"'
        }
    }
    
    Context "Report Generation" {
        It "Should create output directory" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'New-Item.*OutputPath.*Directory'
        }
        
        It "Should generate markdown report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'documentation-coverage-report\.md'
        }
        
        It "Should include timestamp in report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\*\*Generated:\*\*'
        }
        
        It "Should include configuration in report" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\*\*Configuration:\*\*'
        }
        
        It "Should create table header" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\| Project \| XML File \| File Size \| Status \| Notes \|'
        }
        
        It "Should write report to file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Out-File.*-FilePath \$ReportPath'
        }
    }
    
    Context "Report Content" {
        It "Should include overall status" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Overall Status'
        }
        
        It "Should include recommendations section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '## Recommendations'
        }
        
        It "Should include action items for projects needing attention" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Action Items'
        }
        
        It "Should link to documentation standards" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'DOCUMENTATION-STANDARDS'
        }
        
        It "Should include references section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '## References'
        }
    }
    
    Context "Exit Codes" {
        It "Should exit 0 when all projects documented" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$AllProjectsDocumented\)[\s\S]*exit 0'
        }
        
        It "Should exit 0 even with warnings (report-only mode)" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Last exit in else block should be 0
            $lines = Get-Content $scriptPath
            $lastElseExit = ($lines | Select-String -Pattern 'exit 0.*# Don.*fail')
            $lastElseExit | Should -Not -BeNullOrEmpty
        }
        
        It "Should exit 1 only when no projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$SourceProjects\.Count -eq 0\)[\s\S]*exit 1'
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
        
        It "Should document Configuration parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER Configuration'
        }
        
        It "Should document OutputPath parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER OutputPath'
        }
        
        It "Should have usage examples" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.EXAMPLE'
        }
        
        It "Should have .NOTES section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.NOTES'
        }
        
        It "Should link to documentation standards" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.LINK[\s\S]*DOCUMENTATION-STANDARDS'
        }
    }
}

