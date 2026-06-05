#Requires -Version 7.0
<#
.SYNOPSIS
    Fixes blank lines within XML documentation comments that cause CS1570 errors.

.DESCRIPTION
    Removes blank lines that appear between XML comment lines (///) in C# files.
    These blank lines cause "badly formed XML" errors (CS1570) during compilation.

.PARAMETER Path
    Path to file or directory to process. Defaults to current directory.

.PARAMETER WhatIf
    Show what would be changed without making actual changes.

.EXAMPLE
    .\fix-xml-blank-lines.ps1 -Path tst\

.EXAMPLE
    .\fix-xml-blank-lines.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$Path = "."
)

$ErrorActionPreference = 'Stop'

# Get all C# files
$files = if (Test-Path $Path -PathType Leaf) {
    @(Get-Item $Path)
} else {
    Get-ChildItem -Path $Path -Recurse -Filter "*.cs"
}

Write-Host "`n🔍 Found $($files.Count) C# files to process`n" -ForegroundColor Cyan

$fixedCount = 0
$totalBlankLinesRemoved = 0

foreach ($file in $files) {
    $lines = Get-Content $file.FullName
    $result = [System.Collections.Generic.List[string]]::new()
    $blankLinesRemoved = 0
    $inXmlComment = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if we're in an XML comment block
        if ($line -match '^\s*///') {
            $inXmlComment = $true
            $result.Add($line)
        }
        # Skip blank lines within XML comment blocks
        elseif ($inXmlComment -and $line -match '^\s*$') {
            $blankLinesRemoved++
            # Don't add this line
        }
        # We've left the XML comment block
        elseif ($inXmlComment -and $line -notmatch '^\s*///') {
            $inXmlComment = $false
            $result.Add($line)
        }
        # Regular code line
        else {
            $result.Add($line)
        }
    }
    
    if ($blankLinesRemoved -gt 0) {
        $fixedCount++
        $totalBlankLinesRemoved += $blankLinesRemoved
        
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove $blankLinesRemoved blank lines from XML comments")) {
            Set-Content -Path $file.FullName -Value $result -NoNewline
            Write-Host "✅ Fixed: $($file.Name) ($blankLinesRemoved blank lines removed)" -ForegroundColor Green
        } else {
            Write-Host "Would fix: $($file.Name) ($blankLinesRemoved blank lines)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "   Files processed: $($files.Count)"
Write-Host "   Files fixed: $fixedCount" -ForegroundColor Green
Write-Host "   Total blank lines removed: $totalBlankLinesRemoved" -ForegroundColor Green

if ($WhatIfPreference) {
    Write-Host "`n⚠️  DRY RUN - No files were modified. Run without -WhatIf to apply changes.`n" -ForegroundColor Yellow
}
