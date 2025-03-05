# DiagLog Analyzer - Global Bridge Module
# This module ensures functions are available globally across modules

# Get the Settings module path relative to this script's location
$script:BaseDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:ConfigDir = Join-Path -Path $script:BaseDir -ChildPath "src\Config"
$script:SettingsModule = Join-Path -Path $script:ConfigDir -ChildPath "Settings.psm1"

# Make Settings functions available globally with explicit function definitions
# This ensures functions are available even if module scope issues occur

function Global:Get-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null
    )
    
    # Try to call the original function from Settings module
    try {
        # First, make sure Settings module is loaded
        if (-not (Get-Module -Name "Settings")) {
            Import-Module $script:SettingsModule -Force -Global
        }
        
        # Call the function
        if (Get-Command -Name Get-AppSetting -Module Settings -ErrorAction SilentlyContinue) {
            return Get-AppSetting -Name $Name -DefaultValue $DefaultValue
        }
        else {
            # Fallback to global AppSettings if function not available
            if ($null -ne $Global:AppSettings -and $Global:AppSettings.PSObject.Properties.Name -contains $Name) {
                return $Global:AppSettings.$Name
            }
            else {
                return $DefaultValue
            }
        }
    }
    catch {
        # Fallback to the default value
        Write-Warning "Error in Global:Get-AppSetting: $_"
        return $DefaultValue
    }
}

function Global:Set-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $Value
    )
    
    # Try to call the original function from Settings module
    try {
        # First, make sure Settings module is loaded
        if (-not (Get-Module -Name "Settings")) {
            Import-Module $script:SettingsModule -Force -Global
        }
        
        # Call the function
        if (Get-Command -Name Set-AppSetting -Module Settings -ErrorAction SilentlyContinue) {
            return Set-AppSetting -Name $Name -Value $Value
        }
        else {
            # Fallback to directly setting the global AppSettings
            if ($null -eq $Global:AppSettings) {
                $Global:AppSettings = [PSCustomObject]@{}
            }
            
            if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
                $Global:AppSettings.$Name = $Value
            }
            else {
                $Global:AppSettings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
            }
            
            return $true
        }
    }
    catch {
        Write-Warning "Error in Global:Set-AppSetting: $_"
        return $false
    }
}

function Global:Initialize-DLASettings {
    # Try to call the original function
    try {
        # First, make sure Settings module is loaded
        if (-not (Get-Module -Name "Settings")) {
            Import-Module $script:SettingsModule -Force -Global
        }
        
        # Call the function
        if (Get-Command -Name Initialize-Settings -Module Settings -ErrorAction SilentlyContinue) {
            return Initialize-Settings
        }
        elseif (Get-Command -Name Initialize-DLASettings -Module Settings -ErrorAction SilentlyContinue) {
            return Initialize-DLASettings
        }
        else {
            Write-Warning "Could not find initialization function in Settings module"
            return $false
        }
    }
    catch {
        Write-Warning "Error in Global:Initialize-DLASettings: $_"
        return $false
    }
}

function Global:Get-DLASetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Try to call the original function
    try {
        # First, make sure Settings module is loaded
        if (-not (Get-Module -Name "Settings")) {
            Import-Module $script:SettingsModule -Force -Global
        }
        
        # Call the function
        if (Get-Command -Name Get-DLASetting -Module Settings -ErrorAction SilentlyContinue) {
            return Get-DLASetting -Name $Name
        }
        else {
            # Fallback to using script-level settings in the Settings module
            $settingsModule = Get-Module -Name "Settings"
            if ($null -ne $settingsModule -and $null -ne $settingsModule.SessionState.PSVariable.Get("Settings").Value) {
                $settings = $settingsModule.SessionState.PSVariable.Get("Settings").Value
                if ($null -ne $settings -and $settings.ContainsKey($Name)) {
                    return $settings[$Name]
                }
            }
            
            # Final fallback to Get-AppSetting
            return Global:Get-AppSetting -Name $Name
        }
    }
    catch {
        Write-Warning "Error in Global:Get-DLASetting: $_"
        return $null
    }
}

# Export the functions - this is important for module autoloading
Export-ModuleMember -Function * -Variable *