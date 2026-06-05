<#
.SYNOPSIS
    Configuration file loading module with CLI parameter precedence

.DESCRIPTION
    Provides functions for loading JSON configuration files and merging them with
    CLI parameters. Implements the precedence rule: CLI > Config > Default.
    
    Supports nested property paths (e.g., 'Coverage.MinThreshold') and handles
    common edge cases (missing file, invalid JSON, missing properties).

.NOTES
    File Name      : ConfigurationLoader.psm1
    Author         : CI/CD Team
    Prerequisite   : PowerShell 5.1+
    
.EXAMPLE
    Import-Module "$PSScriptRoot/modules/ConfigurationLoader.psm1"
    $config = Import-ScriptConfiguration -ConfigFile $ConfigFile -BoundParameters $PSBoundParameters
#>

#region Import-ScriptConfiguration Function
<#
.SYNOPSIS
    Loads configuration from JSON file with CLI parameter precedence

.DESCRIPTION
    Loads a JSON configuration file and provides functions to merge values with
    CLI parameters. CLI parameters always take precedence over config file values.
    
    Returns a PSCustomObject representing the loaded configuration, or $null if
    file doesn't exist or is invalid.

.PARAMETER ConfigFile
    Path to JSON configuration file

.OUTPUTS
    [PSCustomObject] Configuration object, or $null if file doesn't exist/invalid

.EXAMPLE
    $config = Import-ScriptConfiguration -ConfigFile "$PSScriptRoot/config.json"
    if ($config) {
        Write-Host "Config loaded successfully"
    }

.EXAMPLE
    $config = Import-ScriptConfiguration -ConfigFile $ConfigFile
    if ($config -and -not $PSBoundParameters.ContainsKey('MinCoverage')) {
        $MinCoverage = $config.MinCoverage
    }
#>
function Import-ScriptConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigFile
    )
    
    # Return null if file doesn't exist
    if (-not (Test-Path $ConfigFile)) {
        Write-Verbose "Configuration file not found: $ConfigFile"
        return $null
    }
    
    # Try to parse JSON
    try {
        $rawContent = Get-Content $ConfigFile -Raw
        if ([string]::IsNullOrWhiteSpace($rawContent)) {
            Write-Verbose "Configuration file is empty: $ConfigFile"
            return [pscustomobject]@{}
        }

        $config = $rawContent | ConvertFrom-Json
        if ($null -eq $config) {
            Write-Verbose "Configuration file parsed to null: $ConfigFile"
            return [pscustomobject]@{}
        }

        Write-Verbose "Configuration loaded successfully from: $ConfigFile"
        return $config
    }
    catch {
        Write-Warning "Failed to parse configuration file: $ConfigFile"
        Write-Warning "Error: $($_.Exception.Message)"
        return $null
    }
}
#endregion

#region Get-ConfigValue Function
<#
.SYNOPSIS
    Gets a value from configuration with nested property path support

.DESCRIPTION
    Retrieves a value from a configuration object using dot-notation property paths.
    Supports nested properties (e.g., 'Coverage.MinThreshold') and returns $null
    if property doesn't exist.

.PARAMETER Config
    Configuration object (PSCustomObject from Import-ScriptConfiguration)

.PARAMETER PropertyPath
    Property path using dot notation (e.g., 'MinCoverage' or 'Coverage.MinThreshold')

.OUTPUTS
    Value from configuration, or $null if property doesn't exist

.EXAMPLE
    $value = Get-ConfigValue -Config $config -PropertyPath 'MinCoverage'

.EXAMPLE
    $value = Get-ConfigValue -Config $config -PropertyPath 'Coverage.MinThreshold'
#>
function Get-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Config,
        
        [Parameter(Mandatory=$true)]
        [string]$PropertyPath
    )
    
    if (-not $Config) {
        return $null
    }
    
    # Handle nested property paths (e.g., 'Coverage.MinThreshold')
    $parts = $PropertyPath.Split('.')
    $current = $Config
    
    foreach ($part in $parts) {
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) {
                Write-Verbose "Property not found in config: $PropertyPath"
                return $null
            }

            $current = $current[$part]
            continue
        }

        if ($current.PSObject.Properties.Name -notcontains $part) {
            Write-Verbose "Property not found in config: $PropertyPath"
            return $null
        }

        $current = $current.$part
    }
    
    return $current
}
#endregion

#region Merge-ConfigurationWithParameters Function
<#
.SYNOPSIS
    Merges configuration values into script variables with CLI precedence

.DESCRIPTION
    Applies configuration values to script-scoped variables using the precedence rule:
    CLI Parameter > Config File Value > Script Default
    
    Only applies config values if the parameter was not explicitly provided on CLI.

.PARAMETER Config
    Configuration object from Import-ScriptConfiguration

.PARAMETER BoundParameters
    The $PSBoundParameters hashtable from calling script

.PARAMETER ParameterMap
    Hashtable mapping parameter names to config property paths
    Format: @{ 'ParameterName' = 'ConfigPropertyPath' }
    
.PARAMETER VariableScope
    Scope for setting variables ('Script', 'Global', 'Local'). Default: 'Script'

.EXAMPLE
    Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParameters -ParameterMap @{
        'MinCoverage' = 'MinCoverage'
        'MaxComplexity' = 'Thresholds.MaxComplexity'
    }

.EXAMPLE
    # More complex mapping with nested properties
    $paramMap = @{
        'MinLineCoverage' = 'Coverage.Line'
        'MinBranchCoverage' = 'Coverage.Branch'
        'MaxComplexity' = 'Metrics.MaxCyclomaticComplexity'
        'OutputPath' = 'Output.Path'
    }
    Merge-ConfigurationWithParameters -Config $config -BoundParameters $PSBoundParameters -ParameterMap $paramMap
#>
function Merge-ConfigurationWithParameters {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$false)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$BoundParameters,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$ParameterMap,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Script', 'Global', 'Local')]
        [string]$VariableScope = 'Script'
    )
    
    $appliedValues = @{}

    # No-op if no config loaded
    if (-not $Config) {
        Write-Verbose "No configuration to merge"
        return $appliedValues
    }
    
    # Process each parameter mapping
    foreach ($paramName in $ParameterMap.Keys) {
        $configPath = $ParameterMap[$paramName]
        
        # Skip if parameter was explicitly provided on CLI
        if ($BoundParameters.ContainsKey($paramName)) {
            Write-Verbose "Skipping $paramName (provided via CLI)"
            continue
        }
        
        # Get value from config
        $configValue = Get-ConfigValue -Config $Config -PropertyPath $configPath
        
        # Apply config value if found
        if ($null -ne $configValue) {
            Write-Verbose "Applying config value for $paramName from $configPath"
            Set-Variable -Name $paramName -Value $configValue -Scope $VariableScope
            $appliedValues[$paramName] = $configValue
        }
    }

    return $appliedValues
}
#endregion

#region Export Module Members
Export-ModuleMember -Function @(
    'Import-ScriptConfiguration',
    'Get-ConfigValue',
    'Merge-ConfigurationWithParameters'
)
#endregion

