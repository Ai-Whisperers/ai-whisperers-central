<#
.SYNOPSIS
    Pester tests for validate-tag-context.ps1

.DESCRIPTION
    Comprehensive test suite covering:
    - Write-Log function behavior
    - Azure Pipelines integration
    - Parameter handling
    - Tag format detection
    - Release tag validation
    - Branching policy enforcement
    - Git command handling
    - Exit codes
    - Documentation completeness
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.ps1', '.ps1'
$scriptPath = Join-Path (Split-Path $here -Parent) $sut

Describe "validate-tag-context.ps1" {
    
    Context "Write-Log Function" {
        It "Should have Write-Log function defined" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'function Write-Log'
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
        
        It "Should have timestamp in log output" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$timestamp.*Get-Date'
        }
    }
    
    Context "Azure Pipelines Integration" {
        It "Should integrate with Azure Pipelines logging for errors" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '##vso\[task\.logissue type=error\]'
        }
        
        It "Should check for AGENT_TEMPDIRECTORY environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:AGENT_TEMPDIRECTORY'
        }
        
        It "Should use Azure Pipelines warning commands" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'type=warning'
        }
    }
    
    Context "Parameter Handling" {
        It "Should have TagName parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$TagName'
        }
        
        It "Should default TagName to BUILD_SOURCEBRANCH" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$TagName = \$env:BUILD_SOURCEBRANCH'
        }
        
        It "Should have ErrorActionPreference set to Stop" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$ErrorActionPreference = "Stop"'
        }
    }
    
    Context "Tag Format Detection" {
        It "Should check for null or empty TagName" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'IsNullOrWhiteSpace\(\$TagName\)'
        }
        
        It "Should exit 0 when no tag name provided" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if.*IsNullOrWhiteSpace.*exit 0'
        }
        
        It "Should detect refs/tags/ prefix" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'refs/tags/\*'
        }
        
        It "Should skip validation for non-tag sources" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'is not a tag.*Validation skipped'
        }
        
        It "Should clean tag name by removing refs/tags/ prefix" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$cleanTagName.*-replace ".*refs/tags/"'
        }
    }
    
    Context "Release Tag Detection" {
        It "Should check for release- prefix" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$cleanTagName -match "\^release-"'
        }
        
        It "Should skip validation for non-release tags" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'not a release tag.*Validation skipped'
        }
        
        It "Should validate release tags only" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Validating release tag'
        }
    }
    
    Context "Git Commands" {
        It "Should fetch remote branches" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'git fetch origin --prune'
        }
        
        It "Should handle git fetch failures gracefully" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'try.*git fetch.*catch'
        }
        
        It "Should get containing branches with git branch" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'git branch -r --contains HEAD'
        }
        
        It "Should warn about shallow clone issues" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'shallow clone'
        }
        
        It "Should mention fetchDepth requirement" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'fetchDepth'
        }
    }
    
    Context "Branch Validation Logic" {
        It "Should validate against main branch" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$branchName -eq "main"'
        }
        
        It "Should validate against release/* branches" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$branchName -like "release/\*"'
        }
        
        It "Should set valid flag when stable branch found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$valid = \$true'
        }
        
        It "Should remove origin/ prefix for matching" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$branchName.*-replace "\^origin/"'
        }
        
        It "Should iterate through containing branches" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'foreach \(\$branch in \$containingBranches\)'
        }
    }
    
    Context "Success Reporting" {
        It "Should report success when valid" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'SUCCESS: Tag.*is valid'
        }
        
        It "Should exit 0 on success" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$valid\).*exit 0'
        }
        
        It "Should log found valid branch" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Found valid parent stable branch'
        }
    }
    
    Context "Policy Violation Reporting" {
        It "Should report policy violation" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'POLICY VIOLATION'
        }
        
        It "Should explain violation reason" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'NOT on a stable branch'
        }
        
        It "Should mention disallowed branch types" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'feature, fix, or develop'
        }
        
        It "Should provide Cursor AI guidance" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'fix-release-tag-workflow'
        }
        
        It "Should link to versioning rules" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'tag-based-versioning-rule'
        }
        
        It "Should link to branch lifecycle rules" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'branch-lifecycle-rule'
        }
    }
    
    Context "Quick Fix Guidance" {
        It "Should provide tag deletion commands" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'git tag -d'
        }
        
        It "Should provide remote tag deletion commands" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'git push origin :refs/tags/'
        }
        
        It "Should explain RC testing workflow" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'RC Testing \(test-\* tags\)'
        }
        
        It "Should explain production release workflow" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Production Release \(release-\* tags\)'
        }
        
        It "Should show current branch context" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'git branch --show-current'
        }
    }
    
    Context "Exit Codes" {
        It "Should exit 0 for non-tag sources" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Multiple exit 0 scenarios
            $exitZeroMatches = Select-String -Path $scriptPath -Pattern 'exit 0'
            $exitZeroMatches.Count | Should -BeGreaterThan 1
        }
        
        It "Should exit 1 for policy violations" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'exit 1'
        }
        
        It "Should exit gracefully when tag name is empty" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if.*IsNullOrWhiteSpace.*exit 0'
        }
    }
    
    Context "Error Handling" {
        It "Should use try-catch for git operations" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'try \{.*git fetch.*\}.*catch'
        }
        
        It "Should warn on git fetch failure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Failed to fetch remotes'
        }
        
        It "Should handle missing containing branches" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(-not \$containingBranches\)'
        }
    }
    
    Context "Branch Context Information" {
        It "Should list containing branches" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Commit is contained in'
        }
        
        It "Should iterate through branches for display" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ForEach-Object.*Write-Log'
        }
        
        It "Should show current HEAD branch" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'HEAD is on:'
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
        
        It "Should document TagName parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PARAMETER TagName'
        }
        
        It "Should have usage examples" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.EXAMPLE'
        }
        
        It "Should have .NOTES section" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.NOTES'
        }
        
        It "Should explain branching governance" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'branching governance'
        }
        
        It "Should document main and release/* branch requirements" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "main.*release/\*"
        }
    }
}

