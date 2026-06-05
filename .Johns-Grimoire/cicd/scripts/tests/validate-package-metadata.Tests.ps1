<#
.SYNOPSIS
    Pester tests for validate-package-metadata.ps1

.DESCRIPTION
    Comprehensive test suite covering:
    - Write-Log function behavior
    - Azure Pipelines integration
    - Parameter validation
    - XML parsing from .csproj files
    - Required field validation
    - Recommended field validation
    - Directory.Build.props inheritance
    - Validation warnings and errors
    - Exit codes
    - Documentation completeness
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.ps1', '.ps1'
$scriptPath = Join-Path (Split-Path $here -Parent) $sut

# Import shared test helper module
$TestHelpersPath = Join-Path (Split-Path $here -Parent) "modules\TestHelpers.psm1"
Import-Module $TestHelpersPath -Force

Describe "validate-package-metadata.ps1" {
    
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
        It "Should integrate with Azure Pipelines logging" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '##vso\[task\.logissue type=error\]'
        }
        
        It "Should check for AGENT_TEMPDIRECTORY environment" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$env:AGENT_TEMPDIRECTORY'
        }
        
        It "Should use Azure Pipelines warning commands" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '##vso\[task\.logissue type=warning\]'
        }
    }
    
    Context "Parameter Validation" {
        It "Should have Configuration parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[Parameter.*\]\s*\[ValidateSet\("Debug", "Release"\)\]\s*\[string\]\$Configuration'
        }
        
        It "Should default Configuration to Release" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$Configuration = "Release"'
        }
        
        It "Should support pipeline input for ProjectPaths" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ValueFromPipeline=\$true'
        }
        
        It "Should use CmdletBinding" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[CmdletBinding\(\)\]'
        }
    }
    
    Context "Required Fields Definition" {
        It "Should define required fields array" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$requiredFields.*=.*@\('
        }
        
        It "Should require PackageId" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"PackageId"'
        }
        
        It "Should require Version" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"Version"'
        }
        
        It "Should require Authors" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"Authors"'
        }
        
        It "Should require Description" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"Description"'
        }
        
        It "Should require PackageLicenseExpression" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"PackageLicenseExpression"'
        }
        
        It "Should require RepositoryUrl" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"RepositoryUrl"'
        }
    }
    
    Context "Recommended Fields Definition" {
        It "Should define recommended fields array" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$recommendedFields.*=.*@\('
        }
        
        It "Should recommend PackageTags" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"PackageTags"'
        }
        
        It "Should recommend PackageIcon" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"PackageIcon"'
        }
        
        It "Should recommend PackageReadmeFile" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"PackageReadmeFile"'
        }
    }
    
    Context "XML Parsing" {
        It "Should read XML from .csproj files" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[xml\]\$projectXml.*Get-Content'
        }
        
        It "Should check for Directory.Build.props" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Directory\.Build\.props'
        }
        
        It "Should read properties from PropertyGroup" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.PropertyGroup'
        }
        
        It "Should build allProperties hashtable" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$allProperties.*=.*@\{\}'
        }
    }
    
    Context "Project Discovery" {
        It "Should auto-discover projects in src folder" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Get-ChildItem.*-Path "src"'
        }
        
        It "Should filter for .csproj files" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '-Filter "\*\.csproj"'
        }
        
        It "Should exit gracefully when no projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$projectFiles\.Count -eq 0\).*exit 0'
        }
    }
    
    Context "Required Field Validation Logic" {
        It "Should check for missing required fields" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$missingRequired'
        }
        
        It "Should check for empty required fields" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$emptyRequired'
        }
        
        It "Should validate using ContainsKey" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '-not \$allProperties\.ContainsKey'
        }
        
        It "Should check for whitespace-only values" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'IsNullOrWhiteSpace'
        }
    }
    
    Context "Recommended Field Validation Logic" {
        It "Should check for missing recommended fields" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$missingRecommended'
        }
        
        It "Should warn about missing recommended fields" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'RECOMMENDED FIELDS MISSING'
        }
    }
    
    Context "Specific Field Validation" {
        It "Should validate description length (minimum 20 chars)" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Description.*\.Length -lt 20'
        }
        
        It "Should warn about short descriptions" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Description too short'
        }
        
        It "Should validate version format (X.Y.Z)" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Version.*-notmatch'
        }
        
        It "Should validate license against known licenses" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$validLicenses'
        }
        
        It "Should accept MIT license" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"MIT"'
        }
        
        It "Should accept Apache-2.0 license" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"Apache-2\.0"'
        }
    }
    
    Context "Error and Warning Reporting" {
        It "Should set hasErrors flag when required fields missing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$hasErrors = \$true'
        }
        
        It "Should set hasWarnings flag for recommended fields" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$hasWarnings = \$true'
        }
        
        It "Should collect error messages" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$errors \+='
        }
        
        It "Should collect warning messages" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\$warnings \+='
        }
    }
    
    Context "Exit Codes" {
        It "Should exit 0 when no projects found" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$projectFiles\.Count -eq 0\).*exit 0'
        }
        
        It "Should exit 1 when required fields missing" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'if \(\$hasErrors\).*exit 1'
        }
        
        It "Should exit 0 when only warnings present" {
            $scriptContent = Get-Content $scriptPath -Raw
            # Script exits 0 at the end if no errors
            $lines = Get-Content $scriptPath
            $lastExitLine = $lines | Where-Object { $_ -match 'exit' } | Select-Object -Last 1
            $lastExitLine | Should -Match 'exit 0'
        }
    }
    
    Context "Pipeline Output Objects" {
        It "Should output PSCustomObject for each project" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\[PSCustomObject\]@\{'
        }
        
        It "Should include Project property" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Project = \$projectName'
        }
        
        It "Should include Path property" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Path = \$project\.FullName'
        }
        
        It "Should include Valid property" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Valid = \$isValid'
        }
        
        It "Should include Errors array" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Errors = \$errors'
        }
        
        It "Should include Warnings array" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Warnings = \$warnings'
        }
    }
    
    Context "User Guidance" {
        It "Should provide Cursor AI guidance for fixing errors" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'AUTOMATED SOLUTION.*Cursor AI'
        }
        
        It "Should suggest using prompts" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'generate-package-metadata'
        }
        
        It "Should provide manual alternative guidance" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'MANUAL ALTERNATIVE'
        }
        
        It "Should show example PropertyGroup XML" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '<PropertyGroup>'
        }
        
        It "Should link to NuGet documentation" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'nuget/create-packages'
        }
        
        It "Should provide license selection guidance" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'choosealicense\.com'
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
        
        It "Should have usage examples" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.EXAMPLE'
        }
        
        It "Should have .NOTES section with prerequisites" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.NOTES.*Prerequisite'
        }
        
        It "Should link to NuGet best practices documentation" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '\.LINK.*nuget.*best-practices'
        }
    }
}

