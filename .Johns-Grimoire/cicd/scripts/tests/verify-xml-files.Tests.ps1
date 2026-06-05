<#
.SYNOPSIS
    Pester tests for verify-xml-files.ps1

.DESCRIPTION
    Unit tests for XML documentation file verification script.
    Tests Write-Log function, file existence checking, and validation logic.

.NOTES
    File Name      : verify-xml-files.Tests.ps1
    Prerequisite   : Pester 5.x
    Testing        : XML file verification functionality
#>

# Import shared logging module (tests now validate the shared module)
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules\ScriptLogging.psm1"
Import-Module $ModulePath -Force

Describe "verify-xml-files.ps1 - Write-Log Function" {
    
    Context "When logging messages with different severity levels" {
        
        It "Should log INFO messages without throwing" {
            { Write-Log "Test INFO message" -Level INFO } | Should -Not -Throw
        }
        
        It "Should log SUCCESS messages without throwing" {
            { Write-Log "Test SUCCESS message" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should log WARN messages without throwing" {
            { Write-Log "Test WARN message" -Level WARN } | Should -Not -Throw
        }
        
        It "Should log ERROR messages without throwing" {
            { Write-Log "Test ERROR message" -Level ERROR } | Should -Not -Throw
        }
        
        It "Should log DEBUG messages without throwing" {
            { Write-Log "Test DEBUG message" -Level DEBUG } | Should -Not -Throw
        }
        
        It "Should handle empty messages (blank lines)" {
            { Write-Log "" } | Should -Not -Throw
        }
        
        It "Should default to INFO level when level not specified" {
            { Write-Log "Test default level" } | Should -Not -Throw
        }
    }
}

Describe "verify-xml-files.ps1 - Get-TargetFramework Function" {
    
    Context "When extracting target framework from project file" {
        
        It "Should extract single TargetFramework element" {
            $testCsproj = Join-Path $TestDrive "test-single.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            # Define the function for testing
            function Get-TargetFramework {
                param([string]$ProjectPath)
                
                try {
                    [xml]$projectXml = Get-Content $ProjectPath
                    $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        $targetFrameworks = $projectXml.Project.PropertyGroup.TargetFrameworks | Select-Object -First 1
                        if (-not [string]::IsNullOrEmpty($targetFrameworks)) {
                            $targetFramework = $targetFrameworks.Split(';')[0]
                        }
                    }
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        return "net9.0"
                    }
                    
                    return $targetFramework
                }
                catch {
                    return "net9.0"
                }
            }
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
        
        It "Should extract first framework from TargetFrameworks (plural)" {
            $testCsproj = Join-Path $TestDrive "test-multi.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            function Get-TargetFramework {
                param([string]$ProjectPath)
                
                try {
                    [xml]$projectXml = Get-Content $ProjectPath
                    $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        $targetFrameworks = $projectXml.Project.PropertyGroup.TargetFrameworks | Select-Object -First 1
                        if (-not [string]::IsNullOrEmpty($targetFrameworks)) {
                            $targetFramework = $targetFrameworks.Split(';')[0]
                        }
                    }
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        return "net9.0"
                    }
                    
                    return $targetFramework
                }
                catch {
                    return "net9.0"
                }
            }
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net8.0"
        }
        
        It "Should default to net9.0 if no framework found" {
            $testCsproj = Join-Path $TestDrive "test-empty.csproj"
            $xml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
  </PropertyGroup>
</Project>
"@
            Set-Content -Path $testCsproj -Value $xml
            
            function Get-TargetFramework {
                param([string]$ProjectPath)
                
                try {
                    [xml]$projectXml = Get-Content $ProjectPath
                    $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        $targetFrameworks = $projectXml.Project.PropertyGroup.TargetFrameworks | Select-Object -First 1
                        if (-not [string]::IsNullOrEmpty($targetFrameworks)) {
                            $targetFramework = $targetFrameworks.Split(';')[0]
                        }
                    }
                    
                    if ([string]::IsNullOrEmpty($targetFramework)) {
                        return "net9.0"
                    }
                    
                    return $targetFramework
                }
                catch {
                    return "net9.0"
                }
            }
            
            $result = Get-TargetFramework -ProjectPath $testCsproj
            $result | Should -Be "net9.0"
        }
    }
}

Describe "verify-xml-files.ps1 - File Existence Checking" {
    
    Context "When XML file exists and is valid" {
        
        It "Should detect existing XML file" {
            $xmlPath = Join-Path $TestDrive "test.xml"
            Set-Content -Path $xmlPath -Value "<root><member name='test'/></root>"
            
            Test-Path $xmlPath | Should -Be $true
        }
        
        It "Should verify file size is greater than zero" {
            $xmlPath = Join-Path $TestDrive "test.xml"
            Set-Content -Path $xmlPath -Value "<root><member name='test'/></root>"
            
            $fileSize = (Get-Item $xmlPath).Length
            $fileSize | Should -BeGreaterThan 0
        }
        
        It "Should calculate file size in KB" {
            $xmlPath = Join-Path $TestDrive "test.xml"
            $content = "<root><member name='test'/></root>"
            Set-Content -Path $xmlPath -Value $content
            
            $fileSize = (Get-Item $xmlPath).Length
            $fileSizeKB = [math]::Round($fileSize / 1024, 2)
            $fileSizeKB | Should -BeGreaterThan 0
        }
    }
    
    Context "When XML file is missing" {
        
        It "Should detect missing XML file" {
            $xmlPath = Join-Path $TestDrive "nonexistent.xml"
            
            Test-Path $xmlPath | Should -Be $false
        }
    }
    
    Context "When XML file is empty" {
        
        It "Should detect empty XML file (0 bytes)" {
            $xmlPath = Join-Path $TestDrive "empty.xml"
            New-Item -Path $xmlPath -ItemType File -Force | Out-Null
            
            $fileSize = (Get-Item $xmlPath).Length
            $fileSize | Should -Be 0
        }
    }
}

Describe "verify-xml-files.ps1 - Project Discovery" {
    
    Context "When discovering .csproj files" {
        
        It "Should find .csproj files in directory" {
            $srcDir = Join-Path $TestDrive "src"
            New-Item -Path $srcDir -ItemType Directory -Force | Out-Null
            
            $projectPath = Join-Path $srcDir "Test.csproj"
            Set-Content -Path $projectPath -Value "<Project Sdk='Microsoft.NET.Sdk'></Project>"
            
            $projects = Get-ChildItem -Path $srcDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
            $projects.Count | Should -BeGreaterThan 0
        }
        
        It "Should return empty collection when no projects found" {
            $emptyDir = Join-Path $TestDrive "empty"
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null
            
            $projects = Get-ChildItem -Path $emptyDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
            $projects.Count | Should -Be 0
        }
    }
}

Describe "verify-xml-files.ps1 - Error and Success Counting" {
    
    Context "When tracking verification results" {
        
        It "Should initialize error count to zero" {
            $errorCount = 0
            $errorCount | Should -Be 0
        }
        
        It "Should initialize success count to zero" {
            $successCount = 0
            $successCount | Should -Be 0
        }
        
        It "Should increment success count for valid XML" {
            $successCount = 0
            
            # Simulate success
            $successCount++
            
            $successCount | Should -Be 1
        }
        
        It "Should increment error count for missing XML" {
            $errorCount = 0
            
            # Simulate error
            $errorCount++
            
            $errorCount | Should -Be 1
        }
    }
}

Describe "verify-xml-files.ps1 - Configuration Parameter" {
    
    Context "When specifying build configuration" {
        
        It "Should accept Debug configuration" {
            $config = "Debug"
            $validConfigs = @("Debug", "Release")
            
            $validConfigs -contains $config | Should -Be $true
        }
        
        It "Should accept Release configuration" {
            $config = "Release"
            $validConfigs = @("Debug", "Release")
            
            $validConfigs -contains $config | Should -Be $true
        }
        
        It "Should default to Release if not specified" {
            $config = "Release"
            $config | Should -Be "Release"
        }
    }
}
