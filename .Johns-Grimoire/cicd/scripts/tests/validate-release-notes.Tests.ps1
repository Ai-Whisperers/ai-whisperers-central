<#
.SYNOPSIS
    Pester tests for validate-release-notes.ps1

.DESCRIPTION
    Tests changelog validation logic, version extraction, format checking,
    and Azure Pipelines integration
#>

$ErrorActionPreference = 'Stop'

# Import script for testing (dot-source to get functions)
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "validate-release-notes.ps1"

Describe "validate-release-notes.ps1" {
    BeforeAll {
        # Create temp directory for test changelogs
        $script:tempDir = Join-Path $env:TEMP "validate-release-notes-tests-$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        
        # Save original location
        $script:originalLocation = Get-Location
        
        # Create helper function to run script with test changelog
        function Invoke-ValidateReleaseNotes {
            param(
                [string]$ChangelogContent,
                [string]$Version,
                [hashtable]$EnvVars = @{}
            )
            
            # Create test CHANGELOG.md
            $changelogPath = Join-Path $script:tempDir "CHANGELOG.md"
            Set-Content -Path $changelogPath -Value $ChangelogContent -Force
            
            # Change to temp directory
            Push-Location $script:tempDir
            
            try {
                # Set environment variables
                foreach ($key in $EnvVars.Keys) {
                    Set-Item -Path "env:$key" -Value $EnvVars[$key]
                }
                
                # Run script
                $params = @{
                    FilePath = $scriptPath
                    ArgumentList = @("-Version", $Version)
                    NoNewWindow = $true
                    Wait = $true
                    PassThru = $true
                }
                
                $process = Start-Process -FilePath "powershell.exe" @params
                
                return $process.ExitCode
            }
            finally {
                # Restore environment
                foreach ($key in $EnvVars.Keys) {
                    Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
                }
                
                Pop-Location
            }
        }
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Restore location
        Set-Location $script:originalLocation
    }
    
    Context "CHANGELOG.md File Existence" {
        It "Should fail when CHANGELOG.md does not exist" {
            Push-Location $script:tempDir
            try {
                # Ensure no CHANGELOG.md exists
                Remove-Item -Path "CHANGELOG.md" -Force -ErrorAction SilentlyContinue
                
                # Run script directly with & operator to capture output
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $exitCode = $LASTEXITCODE
                
                $exitCode | Should -Be 1
                $output -join "`n" | Should -Match "CHANGELOG\.md not found"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should succeed when CHANGELOG.md exists with valid entry" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- Initial release
- New feature X
- New feature Y

### Fixed
- Bug fix A
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "1.0.0"
            $exitCode | Should -Be 0
        }
    }
    
    Context "Version Entry Detection" {
        It "Should fail when version entry is missing" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- Initial release
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "2.0.0"
            $exitCode | Should -Be 1
        }
        
        It "Should detect version with brackets [1.0.0]" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "1.0.0"
            $exitCode | Should -Be 0
        }
        
        It "Should detect version without brackets 1.0.0" {
            $changelog = @"
# Changelog

## 1.0.0 - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "1.0.0"
            $exitCode | Should -Be 0
        }
        
        It "Should handle multi-digit version numbers" {
            $changelog = @"
# Changelog

## [10.25.300] - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "10.25.300"
            $exitCode | Should -Be 0
        }
    }
    
    Context "Content Length Validation" {
        It "Should warn when release notes are very short" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

- Short
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "very short"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should not warn when release notes are detailed" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- New feature with detailed description that makes the content long enough
- Another feature with comprehensive explanation
- Third feature with even more detail

### Changed
- Changed behavior X with reasoning
- Updated component Y

### Fixed
- Fixed issue Z with root cause analysis
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Not -Match "very short"
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Context "Standard Sections Detection" {
        It "Should detect Added section" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- New feature
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "Added section: \[PASS\]"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should detect Changed section" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Changed
- Updated behavior
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "Changed section: \[PASS\]"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should detect Fixed section" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Fixed
- Bug fix
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "Fixed section: \[PASS\]"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should detect Breaking Changes section" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Breaking Changes
- API change
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "Breaking Changes: \[PASS\]"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should warn when no standard sections found" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

Some unstructured release notes without standard sections.
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                $output = & $scriptPath -Version "1.0.0" 2>&1
                $output -join "`n" | Should -Match "No standard sections found"
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Context "Exit Codes" {
        It "Should exit 0 on successful validation" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "1.0.0"
            $exitCode | Should -Be 0
        }
        
        It "Should exit 1 when CHANGELOG.md is missing" {
            Push-Location $script:tempDir
            try {
                Remove-Item -Path "CHANGELOG.md" -Force -ErrorAction SilentlyContinue
                
                & $scriptPath -Version "1.0.0" 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 1
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should exit 1 when version entry is missing" {
            $changelog = @"
# Changelog

## [1.0.0] - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "2.0.0"
            $exitCode | Should -Be 1
        }
        
        It "Should exit 0 when skipping non-release tag" {
            Push-Location $script:tempDir
            try {
                # Simulate non-release branch
                $env:BUILD_SOURCEBRANCH = "refs/heads/develop"
                
                & $scriptPath 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                Remove-Item -Path "env:BUILD_SOURCEBRANCH" -ErrorAction SilentlyContinue
                Pop-Location
            }
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept valid version parameter" {
            $changelog = @"
# Changelog

## [1.2.3] - 2025-12-07

### Added
- Feature
"@
            $exitCode = Invoke-ValidateReleaseNotes -ChangelogContent $changelog -Version "1.2.3"
            $exitCode | Should -Be 0
        }
        
        It "Should handle empty version parameter with tag" {
            $changelog = @"
# Changelog

## [5.6.7] - 2025-12-07

### Added
- Feature
"@
            Push-Location $script:tempDir
            try {
                Set-Content -Path "CHANGELOG.md" -Value $changelog -Force
                
                # Simulate release tag
                $env:BUILD_SOURCEBRANCH = "refs/tags/release-5.6.7"
                
                & $scriptPath 2>&1 | Out-Null
                $exitCode = $LASTEXITCODE
                
                Remove-Item -Path "env:BUILD_SOURCEBRANCH" -ErrorAction SilentlyContinue
                
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }
}

