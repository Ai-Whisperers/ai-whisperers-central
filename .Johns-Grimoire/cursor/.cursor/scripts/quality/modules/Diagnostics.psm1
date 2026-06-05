#Requires -Version 7.2
#Requires -PSEdition Core

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DiagnosticRecordsFromText {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $records = New-Object System.Collections.Generic.List[object]

    # MSBuild/CSC format:
    #   C:\path\file.cs(12,34): warning IDE0300: Message...
    #   C:\path\file.cs(12,34): error CS1591: Message...
    $msbuildPattern = '(?m)^(?<file>[A-Za-z]:\\.*?\.cs)\((?<line>\d+)(?:,(?<col>\d+))?\):\s*(?:warning|error)\s+(?<code>[A-Z]{2,10}\d{1,6})\b'
    foreach ($m in [regex]::Matches($Text, $msbuildPattern)) {
        $filePath = $m.Groups['file'].Value
        $line = [int]$m.Groups['line'].Value
        $col = if ($m.Groups['col'].Success) { [int]$m.Groups['col'].Value } else { $null }
        $code = $m.Groups['code'].Value
        $records.Add([pscustomobject]@{ Code = $code; FilePath = $filePath; Line = $line; Column = $col; Source = 'msbuild' })
    }

    # VS Error List "Copy" output often includes "... CODE ... C:\path\file.cs 12 ..."
    $vsCopyPattern = '(?m)\b(?<code>[A-Z]{2,10}\d{1,6})\b.*?(?<file>[A-Za-z]:\\[^\r\n]+?\.cs)\s+(?<line>\d+)\b'
    foreach ($m in [regex]::Matches($Text, $vsCopyPattern)) {
        $filePath = $m.Groups['file'].Value
        $line = [int]$m.Groups['line'].Value
        $code = $m.Groups['code'].Value
        $records.Add([pscustomobject]@{ Code = $code; FilePath = $filePath; Line = $line; Column = $null; Source = 'vscopy' })
    }

    return @($records)
}

function Get-DiagnosticTargetsFromReport {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ReportFilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Codes,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 50)]
        [int]$LinePadding = 2
    )

    if (-not (Test-Path $ReportFilePath -PathType Leaf)) {
        return @{
            Files = @()
            FileRanges = @{}
            Records = @()
        }
    }

    $text = Get-Content -LiteralPath $ReportFilePath -Raw -ErrorAction Stop
    $records = Get-DiagnosticRecordsFromText -Text $text
    if ($records.Count -eq 0) {
        return @{
            Files = @()
            FileRanges = @{}
            Records = @()
        }
    }

    $wanted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $Codes) { [void]$wanted.Add($c) }

    $fileToLines = @{}
    foreach ($r in $records) {
        if (-not $wanted.Contains($r.Code)) { continue }
        if ([string]::IsNullOrWhiteSpace($r.FilePath)) { continue }
        if (-not (Test-Path $r.FilePath -PathType Leaf)) { continue }

        if (-not $fileToLines.ContainsKey($r.FilePath)) {
            $fileToLines[$r.FilePath] = [System.Collections.Generic.HashSet[int]]::new()
        }

        $start = [Math]::Max(1, $r.Line - $LinePadding)
        $end = $r.Line + $LinePadding
        for ($ln = $start; $ln -le $end; $ln++) {
            [void]$fileToLines[$r.FilePath].Add($ln)
        }
    }

    $fileRanges = @{}
    foreach ($filePath in $fileToLines.Keys) {
        $lines = @($fileToLines[$filePath] | Sort-Object)
        if ($lines.Count -eq 0) { continue }

        $ranges = New-Object System.Collections.Generic.List[object]
        $rangeStart = $lines[0]
        $prev = $lines[0]
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $cur = $lines[$i]
            if ($cur -eq ($prev + 1)) { $prev = $cur; continue }
            $ranges.Add([pscustomobject]@{ StartLine = $rangeStart; EndLine = $prev })
            $rangeStart = $cur
            $prev = $cur
        }
        $ranges.Add([pscustomobject]@{ StartLine = $rangeStart; EndLine = $prev })

        $fileRanges[$filePath] = @($ranges)
    }

    return @{
        Files = @($fileRanges.Keys | Sort-Object)
        FileRanges = $fileRanges
        Records = $records
    }
}

function New-LineIndex {
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    # 0-based indices of line starts. Always includes 0 for line 1.
    $starts = New-Object System.Collections.Generic.List[int]
    $starts.Add(0)
    if ([string]::IsNullOrEmpty($Text)) { return @($starts) }

    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq "`n") {
            $next = $i + 1
            if ($next -lt $Text.Length) { $starts.Add($next) }
        }
    }
    return @($starts)
}

function Get-LineNumberFromIndex {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [int[]]$LineStarts,

        [Parameter(Mandatory)]
        [int]$Index
    )

    if ($Index -le 0) { return 1 }
    if ($LineStarts.Count -eq 0) { return 1 }

    $lo = 0
    $hi = $LineStarts.Count - 1
    while ($lo -le $hi) {
        $mid = [int](($lo + $hi) / 2)
        $start = $LineStarts[$mid]
        if ($start -eq $Index) { return ($mid + 1) }
        if ($start -lt $Index) { $lo = $mid + 1 } else { $hi = $mid - 1 }
    }
    return [Math]::Max(1, $hi + 1)
}

function Test-LineInRanges {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Ranges,

        [Parameter(Mandatory)]
        [int]$LineNumber
    )

    if ($Ranges.Count -eq 0) { return $true }

    $lo = 0
    $hi = $Ranges.Count - 1
    while ($lo -le $hi) {
        $mid = [int](($lo + $hi) / 2)
        $r = $Ranges[$mid]
        $start = [int]$r.StartLine
        $end = [int]$r.EndLine
        if ($LineNumber -lt $start) { $hi = $mid - 1; continue }
        if ($LineNumber -gt $end) { $lo = $mid + 1; continue }
        return $true
    }
    return $false
}

Export-ModuleMember -Function `
    Get-DiagnosticRecordsFromText, `
    Get-DiagnosticTargetsFromReport, `
    New-LineIndex, `
    Get-LineNumberFromIndex, `
    Test-LineInRanges


