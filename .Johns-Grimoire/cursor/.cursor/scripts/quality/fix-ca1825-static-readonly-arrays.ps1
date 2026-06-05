#!/usr/bin/env pwsh
#Requires -Version 7.2
#Requires -PSEdition Core

<#
.SYNOPSIS
    Fixes CA1825 code analysis suggestions to use static readonly fields for constant array arguments.

.DESCRIPTION
    Automatically fixes code analysis suggestions that recommend using 'static readonly' fields
    over constant array arguments when methods are called repeatedly and are not mutating the passed array.
    
    Specifically addresses:
    - Inline array literals passed as method arguments (new[] { ... })
    - Array initializers in method calls (new string[] { ... })
    - Repeated array arguments that should be extracted to static readonly fields
    
    This script improves performance by avoiding repeated array allocations.
    
    Related to CA1825: "Avoid zero-length array allocations" and performance best practices.

.PARAMETER Path
    Path to the C# file or directory to process. If a directory is specified,
    all .cs files in that directory and subdirectories will be processed.

.PARAMETER Recurse
    When Path is a directory, recurse into subdirectories.

.PARAMETER WhatIf
    Show what would be changed without actually making changes.

.PARAMETER Verbose
    Enable verbose output showing detailed processing information.

.PARAMETER EmitAiInstructions
    Emit AI fix instructions artifacts (TSV + JSON + Markdown) for cases the script intentionally skips due to
    conservative guardrails (e.g., complex array elements, or inability to locate an insertion point for fields),
    so another AI can apply safe, deterministic edits with minimal extra discovery.

.PARAMETER AiInstructionsPath
    Optional explicit path for the AI instructions Markdown output.

.EXAMPLE
    .\fix-ca1825-static-readonly-arrays.ps1 -Path "src/MyClass.cs"
    Fix array arguments in a specific file

.EXAMPLE
    .\fix-ca1825-static-readonly-arrays.ps1 -Path "src/" -Recurse
    Fix array arguments in all C# files under src/ directory

.EXAMPLE
    .\fix-ca1825-static-readonly-arrays.ps1 -Path "MyClass.cs" -WhatIf -Verbose
    Show what changes would be made without applying them

.NOTES
    File Name      : fix-ca1825-static-readonly-arrays.ps1
    Author         : AI Assistant
    Prerequisite   : PowerShell 7.2+, file write permissions
    Error Codes    : Fixes CA1825-related performance suggestions (static readonly array optimization)
    Related Rules  : rule.quality.zero-warnings-zero-errors.v1, code analysis best practices
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to C# file or directory to process")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Recurse into subdirectories when Path is a directory")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "Include test files (tst/**) in processing. Default is to skip tests to avoid non-constant array hoisting.")]
    [switch]$IncludeTests,

    [Parameter(Mandatory = $false, HelpMessage = "Skip Roslyn (dotnet format) pre-pass and run only the heuristic fixer")]
    [switch]$SkipRoslyn,

    [Parameter(Mandatory = $false, HelpMessage = "Emit AI fix instructions artifacts (TSV + JSON + Markdown) for intentionally skipped cases")]
    [switch]$EmitAiInstructions,

    [Parameter(Mandatory = $false, HelpMessage = "Optional explicit path for the AI instructions Markdown output")]
    [string]$AiInstructionsPath
)

$ErrorActionPreference = 'Stop'

$commonModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (-not (Test-Path $commonModulePath)) {
    throw "Common module not found at: $commonModulePath"
}
Import-Module $commonModulePath -Force -ErrorAction Stop

# Roslyn pre-pass (dotnet format) helpers
$roslynModulePath = Join-Path $PSScriptRoot 'modules\RoslynFixes.psm1'
if (Test-Path $roslynModulePath) {
    Import-Module $roslynModulePath -Force
}

$aiFixInstructionsModulePath = Join-Path $PSScriptRoot "modules\AiFixInstructions.psm1"
if (Test-Path $aiFixInstructionsModulePath) {
    Import-Module $aiFixInstructionsModulePath -Force
}

# Get all C# files to process
function Get-CSharpFiles {
    param([string]$TargetPath, [bool]$RecurseDirectories)

    if (Test-Path $TargetPath -PathType Leaf) {
        if ($TargetPath -like "*.cs") {
            if (-not $IncludeTests -and $TargetPath -match '(?i)\\tst\\') {
                return @()
            }
            return @($TargetPath)
        } else {
            Write-Failure "Specified file is not a C# file: $TargetPath"
            return @()
        }
    }

    if (Test-Path $TargetPath -PathType Container) {
        $searchOptions = @{
            Path    = $TargetPath
            Filter  = "*.cs"
            File    = $true
        }
        if ($RecurseDirectories) {
            $searchOptions.Recurse = $true
        }

        $files = Get-ChildItem @searchOptions | Select-Object -ExpandProperty FullName
        if (-not $IncludeTests) {
            $files = @($files | Where-Object { $_ -notmatch '(?i)\\tst\\' })
        }

        return $files
    }

    Write-Failure "Path does not exist: $TargetPath"
    return @()
}

# Extract array type from array initializer
function Get-ArrayType {
    param([string]$ArrayContent)
    
    # Check if content contains strings (quotes)
    if ($ArrayContent -match '["'']') {
        return 'string'
    }
    
    # Check if content contains numbers only
    if ($ArrayContent -match '^\s*\d+(\s*,\s*\d+)*\s*$') {
        return 'int'
    }
    
    # Default to object for mixed or unknown types
    return 'object'
}

function Test-IsSafeConstantArrayContent {
    param([string]$ArrayContent)

    # Remove string literals, then look for remaining identifiers.
    # If any identifier remains (other than true/false/null), treat as non-constant and skip hoisting.
    $withoutStrings = [regex]::Replace($ArrayContent, '"(?:\\.|[^"])*"|''(?:\\.|[^''])*''', '')

    if ($withoutStrings -match '\b(?!true\b|false\b|null\b)[A-Za-z_]\w*\b') {
        return $false
    }

    return $true
}

# Generate unique field name from array content
function Get-FieldName {
    param([string]$ArrayContent, [string]$Context, [hashtable]$ExistingNames)
    
    # Extract first word from array content to create meaningful name
    $firstWord = ""
    if ($ArrayContent -match '["'']([^"'']+)["'']') {
        $firstWord = $matches[1]
    } elseif ($ArrayContent -match '(\w+)') {
        $firstWord = $matches[1]
    }
    
    # Create base field name from first word
    if ($firstWord.Length -gt 0) {
        $baseName = "_${firstWord}Array"
    } else {
        $baseName = "_arrayValues"
    }
    
    # Ensure uniqueness by appending number if needed
    $fieldName = $baseName
    $counter = 1
    while ($ExistingNames.ContainsKey($fieldName)) {
        $fieldName = "${baseName}$counter"
        $counter++
    }
    
    $ExistingNames[$fieldName] = $true
    return $fieldName
}

# Fix static readonly array arguments
function Fix-StaticReadonlyArrays {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [object]$AiInstructionRecords,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$RunId
    )

    try {
        $content = [System.IO.File]::ReadAllText($FilePath)
        if ($null -eq $content) {
            Write-InfoMessage "Skipping (null file content): $FilePath"
            return $false
        }
        $originalContent = $content
        $changesMade = 0
        $fieldDeclarations = @()
        $fieldReplacements = @{}
        $existingFieldNames = @{}

        function Get-LineNumberAtIndex {
            param(
                [Parameter(Mandatory)]
                [string]$Text,

                [Parameter(Mandatory)]
                [int]$Index
            )

            if ($Index -le 0) { return 1 }
            if ($Index -ge $Text.Length) { $Index = $Text.Length - 1 }
            return ([regex]::Matches($Text.Substring(0, $Index), "`n").Count + 1)
        }

        function Get-LineAtIndex {
            param(
                [Parameter(Mandatory)]
                [string]$Text,

                [Parameter(Mandatory)]
                [int]$Index
            )

            $lineStart = $Text.LastIndexOf("`n", [Math]::Max(0, $Index - 1))
            if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }

            $lineEnd = $Text.IndexOf("`n", $Index)
            if ($lineEnd -lt 0) { $lineEnd = $Text.Length }

            return $Text.Substring($lineStart, $lineEnd - $lineStart).TrimEnd("`r")
        }

        function Try-AddAiSkipRecord {
            param(
                [Parameter(Mandatory)]
                [ValidateSet('skipped','error')]
                [string]$Status,

                [Parameter(Mandatory)]
                [string]$Reason,

                [Parameter(Mandatory)]
                [int]$Index,

                [Parameter(Mandatory)]
                [string]$ContextLine,

                [Parameter(Mandatory = $false)]
                [string]$Notes
            )

            if (-not $AiInstructionRecords) { return }
            if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) { return }

            $repoRootForRel = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { (Get-Location).Path } else { $RepoRoot }
            $relative = if (Get-Command Convert-ToRepoRelativePath -ErrorAction SilentlyContinue) {
                Convert-ToRepoRelativePath -RepoRoot $repoRootForRel -FullPath $FilePath
            } else {
                $FilePath
            }

            $line = Get-LineNumberAtIndex -Text $content -Index $Index

            $AiInstructionRecords.Add(
                (New-AiFixInstructionRecord `
                    -Status $Status `
                    -RuleId 'ca1825' `
                    -RunId $RunId `
                    -DiagnosticCode 'CA1825' `
                    -Reason $Reason `
                    -RepoRoot $repoRootForRel `
                    -FilePath $FilePath `
                    -RelativeFilePath $relative `
                    -Line $line `
                    -ContextStartLine $line `
                    -ContextEndLine $line `
                    -ContextBefore $ContextLine `
                    -ContextAfter '' `
                    -TransformationKind 'unknown' `
                    -TransformationBefore '' `
                    -TransformationAfter '' `
                    -TransformationNotes $Notes `
                    -DoNotAutoApply $true)
            ) | Out-Null
        }

        # Pattern 1: new[] { ... } in method arguments
        # Matches: MethodName(new[] { "value1", "value2" })
        $pattern1 = '(?s)(\w+)\s*\(\s*new\s*\[\]\s*\{([^}]+)\}\s*\)'
        
        $matches1 = [regex]::Matches($content, $pattern1)
        foreach ($match in $matches1) {
            $methodCall = $match.Groups[0].Value
            $methodName = $match.Groups[1].Value
            $arrayContent = $match.Groups[2].Value.Trim()
            
            # Skip if array is too complex or contains method calls
            if ($arrayContent -match 'new\s+\w+|\(|\)|=>') {
                Try-AddAiSkipRecord -Status 'skipped' -Reason 'skipped-complex-elements' -Index $match.Index -ContextLine (Get-LineAtIndex -Text $originalContent -Index $match.Index) -Notes 'Array content includes new/parentheses/lambda; hoisting is intentionally conservative.'
                continue
            }

            # Skip any array that isn't clearly constant (e.g., uses local variables like `existing` / `expectedEntity`).
            if (-not (Test-IsSafeConstantArrayContent -ArrayContent $arrayContent)) {
                Try-AddAiSkipRecord -Status 'skipped' -Reason 'skipped-non-constant-elements' -Index $match.Index -ContextLine (Get-LineAtIndex -Text $originalContent -Index $match.Index) -Notes 'Array content contains identifiers; hoisting would change scope/type and can break builds. Leaving inline array allocation.'
                continue
            }
            
            # Avoid duplicate fields for same array content
            $arrayKey = $arrayContent.Replace(' ', '').Replace('"', "'").Replace("'", "'")
            if (-not $fieldReplacements.ContainsKey($arrayKey)) {
                # Generate unique field name
                $arrayType = Get-ArrayType $arrayContent
                if ($arrayType -eq 'object') {
                    Try-AddAiSkipRecord -Status 'skipped' -Reason 'skipped-non-constant-elements' -Index $match.Index -ContextLine (Get-LineAtIndex -Text $originalContent -Index $match.Index) -Notes 'Unable to infer a safe constant element type. Leaving inline array allocation.'
                    continue
                }
                $fieldName = Get-FieldName -ArrayContent $arrayContent -Context $methodCall -ExistingNames $existingFieldNames
                
                $fieldDeclarations += "    private static readonly ${arrayType}[] $fieldName = new[] { $arrayContent };"
                $fieldReplacements[$arrayKey] = @{
                    FieldName = $fieldName
                    Original = $methodCall
                }
            } else {
                $fieldName = $fieldReplacements[$arrayKey].FieldName
            }
            
            # Replace method call with field reference
            $replacement = "$methodName($fieldName)"
            $content = $content.Replace($methodCall, $replacement)
            $changesMade++
            
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                Write-InfoMessage "  Found array argument: $methodCall"
                Write-InfoMessage "  Will replace with field: $fieldName"
            }
        }

        # Pattern 2: new Type[] { ... } in method arguments
        # Matches: MethodName(new string[] { "value1", "value2" })
        $pattern2 = '(?s)(\w+)\s*\(\s*new\s+(\w+)\s*\[\]\s*\{([^}]+)\}\s*\)'
        
        $matches2 = [regex]::Matches($content, $pattern2)
        foreach ($match in $matches2) {
            $methodCall = $match.Groups[0].Value
            $methodName = $match.Groups[1].Value
            $arrayType = $match.Groups[2].Value
            $arrayContent = $match.Groups[3].Value.Trim()
            
            # Skip if array is too complex
            if ($arrayContent -match 'new\s+\w+|\(|\)|=>') {
                Try-AddAiSkipRecord -Status 'skipped' -Reason 'skipped-complex-elements' -Index $match.Index -ContextLine (Get-LineAtIndex -Text $originalContent -Index $match.Index) -Notes 'Array content includes new/parentheses/lambda; hoisting is intentionally conservative.'
                continue
            }

            if (-not (Test-IsSafeConstantArrayContent -ArrayContent $arrayContent)) {
                Try-AddAiSkipRecord -Status 'skipped' -Reason 'skipped-non-constant-elements' -Index $match.Index -ContextLine (Get-LineAtIndex -Text $originalContent -Index $match.Index) -Notes 'Array content contains identifiers; hoisting would change scope/type and can break builds. Leaving inline array allocation.'
                continue
            }
            
            # Avoid duplicate fields for same array content
            $arrayKey = $arrayContent.Replace(' ', '').Replace('"', "'").Replace("'", "'")
            if (-not $fieldReplacements.ContainsKey($arrayKey)) {
                # Generate unique field name
                $fieldName = Get-FieldName -ArrayContent $arrayContent -Context $methodCall -ExistingNames $existingFieldNames
                $fieldDeclarations += "    private static readonly ${arrayType}[] $fieldName = new ${arrayType}[] { $arrayContent };"
                $fieldReplacements[$arrayKey] = @{
                    FieldName = $fieldName
                    Original = $methodCall
                }
            } else {
                $fieldName = $fieldReplacements[$arrayKey].FieldName
            }
            
            # Replace method call
            $replacement = "$methodName($fieldName)"
            $content = $content.Replace($methodCall, $replacement)
            $changesMade++
            
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                Write-InfoMessage "  Found typed array argument: $methodCall"
                Write-InfoMessage "  Will replace with field: $fieldName"
            }
        }

        # Insert field declarations at the beginning of the class (after opening brace)
        if ($fieldDeclarations.Count -gt 0) {
            # Find class declaration and insert fields after opening brace
            # Look for class, struct, or record declarations - match the opening brace
            $classPattern = '(?s)((?:public\s+|private\s+|internal\s+|protected\s+)?(?:sealed\s+|abstract\s+|static\s+)?(?:class|struct|record)\s+\w+[^{]*\{)'
            if ($content -match $classPattern) {
                $classMatch = $matches[0]
                # Find the position of the opening brace
                $braceIndex = $classMatch.LastIndexOf('{')
                if ($braceIndex -ge 0) {
                    # Insert after the opening brace, accounting for the match position
                    $matchIndex = $content.IndexOf($classMatch)
                    $insertionPoint = $matchIndex + $braceIndex + 1
                
                # Check if fields already exist (avoid duplicates)
                $fieldsToAdd = @()
                foreach ($fieldDecl in $fieldDeclarations) {
                    if ($fieldDecl -match '(\w+)\s*=') {
                        $fieldName = $matches[1]
                        if (-not ($content -match "private\s+static\s+readonly.*?\s+$fieldName\s*=")) {
                            $fieldsToAdd += $fieldDecl
                        }
                    }
                }
                
                    if ($fieldsToAdd.Count -gt 0) {
                        $fieldsBlock = "`n" + ($fieldsToAdd -join "`n") + "`n"
                        $content = $content.Insert($insertionPoint, $fieldsBlock)
                        $changesMade++
                        
                        if ($PSBoundParameters.ContainsKey('Verbose')) {
                            Write-InfoMessage "  Added $($fieldsToAdd.Count) static readonly field declaration(s)"
                        }
                    }
                } else {
                    if ($PSBoundParameters.ContainsKey('Verbose')) {
                        Write-InfoMessage "  Warning: Could not find opening brace in class declaration"
                    }
                    Try-AddAiSkipRecord -Status 'error' -Reason 'error-no-type-insertion-brace' -Index 0 -ContextLine '' -Notes 'Could not find opening brace in matched type declaration; cannot insert static readonly fields safely.'
                }
            } else {
                if ($PSBoundParameters.ContainsKey('Verbose')) {
                    Write-InfoMessage "  Warning: Could not find class declaration to insert fields"
                }
                Try-AddAiSkipRecord -Status 'error' -Reason 'error-no-type-declaration-found' -Index 0 -ContextLine '' -Notes 'Could not locate a class/struct/record declaration to insert static readonly fields.'
            }
        }

        # Only write file if changes were made
        if ($changesMade -gt 0) {
            if ($WhatIfPreference) {
                Write-InfoMessage "Would fix $changesMade array argument(s) in $FilePath"
                if ($PSBoundParameters.ContainsKey('Verbose') -and $fieldDeclarations.Count -gt 0) {
                    Write-InfoMessage "  Would add $($fieldDeclarations.Count) static readonly field(s)"
                }
                return $true
            } else {
                $content | Set-Content $FilePath -NoNewline -ErrorAction Stop
                Write-Success "Fixed $changesMade array argument(s) in $FilePath"
                if ($PSBoundParameters.ContainsKey('Verbose') -and $fieldDeclarations.Count -gt 0) {
                    Write-InfoMessage "  Added $($fieldDeclarations.Count) static readonly field(s)"
                }
                return $true
            }
        } else {
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                Write-InfoMessage "No array argument issues found in $FilePath"
            }
            return $false
        }

    } catch {
        Write-ErrorMessage "Error processing $FilePath : $_"
        return $false
    }
}

# Main execution
try {
    Write-Step "CA1825 Static Readonly Array Arguments Fixer"
    Write-InfoMessage "Fixes code analysis suggestions to use static readonly fields for constant array arguments"

    $runId = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
    $repoRootForRel = (Get-Location).Path
    $aiInstructionRecords = $null
    $aiInstructionsOutputDir = $null

    if ($EmitAiInstructions) {
        if (-not (Get-Command New-AiFixInstructionRecord -ErrorAction SilentlyContinue)) {
            Write-ErrorMessage "AiFixInstructions module not available. Expected: $aiFixInstructionsModulePath"
            exit 2
        }

        $aiInstructionRecords = New-Object System.Collections.Generic.List[object]
        $aiInstructionsOutputDir = Join-Path (Join-Path $PSScriptRoot 'out') $runId
    }

    if (-not $SkipRoslyn -and (Get-Command -Name Invoke-RoslynFormatFix -ErrorAction SilentlyContinue)) {
        try {
            if ($PSCmdlet.ShouldProcess($Path, "Run Roslyn-based fixes via dotnet format (CA1825)")) {
                $roslynResult = Invoke-RoslynFormatFix -StartPath $Path -Diagnostics @('CA1825') -Severity 'info' -Include @($Path)
                if ($roslynResult.Attempted) {
                    if ($roslynResult.Applied) {
                        Write-InfoMessage "Roslyn pre-pass applied fixes via dotnet format (CA1825)."
                    } else {
                        Write-InfoMessage "Roslyn pre-pass ran but did not apply fixes (CA1825). Continuing with heuristic fixer."
                    }
                } else {
                    Write-InfoMessage "Roslyn pre-pass skipped (no single .sln discovered under repo root). Continuing with heuristic fixer."
                }
            }
        } catch {
            Write-InfoMessage "Roslyn pre-pass failed: $($_.Exception.Message). Continuing with heuristic fixer."
        }
    }

    $files = Get-CSharpFiles -TargetPath $Path -RecurseDirectories $Recurse

    if ($files.Count -eq 0) {
        Write-ErrorMessage "No C# files found to process"
        exit 1
    }

    Write-InfoMessage "Found $($files.Count) C# file(s) to process"

    $filesProcessed = 0
    $filesChanged = 0
    $totalChanges = 0

    foreach ($file in $files) {
        $filesProcessed++
        if ($Verbose) {
            Write-InfoMessage "Processing: $file"
        }

        $changed = Fix-StaticReadonlyArrays -FilePath $file -AiInstructionRecords $aiInstructionRecords -RepoRoot $repoRootForRel -RunId $runId
        if ($changed) {
            $filesChanged++
        }
    }

    if ($EmitAiInstructions) {
        $artifact = Write-AiFixInstructionsArtifacts `
            -Records @($aiInstructionRecords) `
            -OutputDirectory $aiInstructionsOutputDir `
            -RuleId "ca1825" `
            -RunId $runId `
            -InputPath $Path `
            -MarkdownPath $AiInstructionsPath

        Write-InfoMessage "AI instructions TSV : $($artifact.TsvPath)"
        Write-InfoMessage "AI instructions JSON: $($artifact.JsonPath)"
        Write-InfoMessage "AI instructions MD  : $($artifact.MarkdownPath)"
    }

    Write-Step "Summary"
    Write-InfoMessage "Processed: $filesProcessed file(s)"
    Write-InfoMessage "Changed: $filesChanged file(s)"

    if ($WhatIfPreference) {
        Write-InfoMessage "Run without -WhatIf to apply changes"
    }

    if ($filesChanged -gt 0) {
        Write-SuccessMessage "CA1825 static readonly array argument fixes completed successfully"
        exit 0
    } else {
        Write-InfoMessage "No CA1825 array argument issues found - files are already optimized"
        exit 0
    }

} catch {
    Write-ErrorMessage "Script execution failed: $_"
    exit 1
}


