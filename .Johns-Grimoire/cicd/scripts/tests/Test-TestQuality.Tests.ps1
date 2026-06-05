<#
.SYNOPSIS
    Meta-tests that validate the quality and structure of test files

.DESCRIPTION
    This test suite validates that test files themselves follow best practices:
    - Test file naming conventions
    - Test structure and organization
    - Required test contexts
    - Test documentation
    - Import patterns
#>

$ErrorActionPreference = "Stop"

Describe "Test File Quality Standards" {
    
    $testFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" -Recurse -File |
        Where-Object { $_.Name -ne "Test-TestQuality.Tests.ps1" }
    
    Context "Test File Naming Conventions" {
        
        It "All test files should end with .Tests.ps1" {
            $testFiles | ForEach-Object {
                $_.Name | Should Match '\.Tests\.ps1$'
            }
        }
        
        It "Test files should match their target script names" {
            $scriptPath = Split-Path $PSScriptRoot -Parent
            
            foreach ($testFile in $testFiles) {
                if ($testFile.Directory.Name -ne "modules") {
                    $targetScriptName = $testFile.BaseName -replace '\.Tests$', '.ps1'
                    $targetScriptPath = Join-Path $scriptPath $targetScriptName
                    
                    # Either script exists or it's a module test
                    $scriptExists = Test-Path $targetScriptPath
                    $isModuleTest = $testFile.Directory.Name -eq "modules"
                    
                    ($scriptExists -or $isModuleTest) | Should -Be $true
                }
            }
        }
    }
    
    Context "Test File Structure" {
        
        It "All test files should have a synopsis" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match '<#[\s\S]*?\.SYNOPSIS'
            }
        }
        
        It "All test files should have a description" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match '<#[\s\S]*?\.DESCRIPTION'
            }
        }
        
        It "All test files should set ErrorActionPreference" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match '\$ErrorActionPreference\s*=\s*("Stop"|''Stop'')'
            }
        }
        
        It "All test files should have at least one Describe block" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match 'Describe\s+'
            }
        }
        
        It "All test files should have at least one Context block" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match 'Context\s+'
            }
        }
        
        It "All test files should have at least one It block" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $content | Should Match 'It\s+'
            }
        }
    }
    
    Context "Test Import Patterns" {
        
        It "Script tests should import the script they're testing" {
            $scriptPath = Split-Path $PSScriptRoot -Parent
            
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                
                # Should have some kind of path calculation and import
                $hasImport = $content -match 'Import-Module' -or 
                             $content -match '\$scriptPath' -or
                             $content -match '\$ModulePath' -or
                             $content -match 'Join-Path.*Parent'
                
                $hasImport | Should -Be $true
            }
        }
    }
    
    Context "Test Coverage Indicators" {
        
        It "Test files should test multiple scenarios (multiple It blocks)" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $itBlocks = ([regex]::Matches($content, 'It\s+[''"]')).Count
                
                # Should have at least 3 test cases
                $itBlocks | Should -BeGreaterThan 2
            }
        }
        
        It "Test files should have descriptive test names (not just 'Should work')" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                
                # Extract It block descriptions
                $itMatches = [regex]::Matches($content, 'It\s+[''"]([^''"]+)[''"]')
                
                foreach ($match in $itMatches) {
                    $description = $match.Groups[1].Value
                    
                    # Should not be generic
                    $description | Should -Not -Match '^(work|pass|succeed|run)s?$'
                    
                    # Should be reasonably descriptive (>15 chars)
                    $description.Length | Should -BeGreaterThan 15
                }
            }
        }
    }
    
    Context "Test Organization" {
        
        It "Test files should group related tests in Context blocks" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                $contextCount = ([regex]::Matches($content, 'Context\s+[''"]')).Count
                
                # Should have at least 2 context blocks for organization
                $contextCount | Should -BeGreaterThan 1
            }
        }
        
        It "Context blocks should have descriptive names" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                
                # Extract Context block names
                $contextMatches = [regex]::Matches($content, 'Context\s+[''"]([^''"]+)[''"]')
                
                foreach ($match in $contextMatches) {
                    $description = $match.Groups[1].Value
                    
                    # Should be descriptive (>10 chars)
                    $description.Length | Should -BeGreaterThan 10
                }
            }
        }
    }
    
    Context "Test Assertions" {
        
        It "All It blocks should contain at least one assertion" {
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                
                # Extract It blocks
                $itPattern = 'It\s+[''"][^''"]+[''"](\s*-Skip)?\s*\{'
                $itMatches = [regex]::Matches($content, $itPattern)
                
                foreach ($match in $itMatches) {
                    # Check if test is skipped or has assertion
                    $isSkipped = $match.Value -match '-Skip'
                    
                    if (-not $isSkipped) {
                        # For non-skipped tests, check for assertion in nearby content
                        $matchEnd = $match.Index + $match.Length
                        $remainingContent = $content.Substring($matchEnd, [Math]::Min(500, $content.Length - $matchEnd))
                        $hasAssertion = $remainingContent -match 'Should\s+'
                        
                        if (-not $hasAssertion) {
                            Write-Warning "Test may be missing assertion in $($testFile.Name)"
                        }
                    }
                }
            }
        }
    }
}

Describe "Test File Coverage Analysis" {
    
    Context "Module Test Coverage" {
        
        It "All modules should have corresponding test files" {
            $modulesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
            $modules = Get-ChildItem -Path $modulesPath -Filter "*.psm1" -File
            
            foreach ($module in $modules) {
                $testFileName = "$($module.BaseName).Tests.ps1"
                $testFilePath = Join-Path "$PSScriptRoot\modules" $testFileName
                
                Test-Path $testFilePath | Should -Be $true
            }
        }
    }
    
    Context "Script Test Coverage" {
        
        It "Critical validation scripts should have test files" {
            $scriptPath = Split-Path $PSScriptRoot -Parent
            
            $criticalScripts = @(
                "validate-documentation.ps1"
                "validate-package-metadata.ps1"
                "validate-tag-context.ps1"
                "verify-xml-files.ps1"
            )
            
            foreach ($script in $criticalScripts) {
                $testFileName = "$([System.IO.Path]::GetFileNameWithoutExtension($script)).Tests.ps1"
                $testFilePath = Join-Path $PSScriptRoot $testFileName
                
                Test-Path $testFilePath | Should -Be $true
            }
        }
    }
}

Describe "Test Execution Quality" {
    
    Context "Test File Executability" {
        
        $testFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" -Recurse -File |
            Where-Object { $_.Name -ne "Test-TestQuality.Tests.ps1" }
        
        It "All test files should be syntactically valid" {
            foreach ($testFile in $testFiles) {
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content $testFile.FullName -Raw),
                    [ref]$errors
                )
                
                if ($errors.Count -gt 0) {
                    Write-Warning "Syntax errors in $($testFile.Name): $($errors -join ', ')"
                }
                
                $errors.Count | Should -Be 0
            }
        }
    }
    
    Context "Test Isolation" {
        
        It "Tests should not depend on execution order" {
            # This is a guideline check - tests should be independent
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -Raw
                
                # Check for suspicious patterns that might indicate order dependency
                $hasSharedState = $content -match '\$script:' -or
                                  $content -match '\$global:'
                
                # This is a warning, not a failure - sometimes shared state is intentional
                if ($hasSharedState) {
                    Write-Warning "$($testFile.Name) uses script/global scope - ensure tests are independent"
                }
            }
        }
    }
}

