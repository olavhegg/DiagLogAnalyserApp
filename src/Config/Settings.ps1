# DiagLog Analyzer - Settings Management
# This module handles application settings and configuration

# Default settings
$script:AppSettings = @{
    # Application info
    AppName = "DiagLog Analyzer"
    Version = "1.0.0"
    
    # Default paths
    DefaultOutputPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\results"
    LogPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\logs"
    
    # Analysis settings
    MaxFileSizeForTextSearch = 50MB  # Skip larger files for text search
    DefaultFileTypesToSearch = @(".log", ".txt", ".xml", ".html", ".json", ".csv")
    
    # CAB extraction settings
    ExtractCabsAutomatically = $false
    SkipExistingCabExtracts = $true
    
    # UI settings
    MainFormWidth = 900
    MainFormHeight = 700
    ResultsFontFamily = "Consolas"
    ResultsFontSize = 9
}

# User settings file path
$script:UserSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\settings.json"

function Initialize-Settings {
    # Load user settings if they exist, otherwise use defaults
    if (Test-Path -Path $script:UserSettingsPath) {
        try {
            $userSettings = Get-Content -Path $script:UserSettingsPath -Raw | ConvertFrom-Json
            
            # Convert from JSON to hashtable and merge with defaults
            $userSettingsHash = @{}
            $userSettings.PSObject.Properties | ForEach-Object {
                $userSettingsHash[$_.Name] = $_.Value
            }
            
            # Update default settings with user settings
            foreach ($key in $userSettingsHash.Keys) {
                if ($null -ne $userSettingsHash[$key]) {
                    $script:AppSettings[$key] = $userSettingsHash[$key]
                }
            }
            
            Write-Verbose "User settings loaded from $script:UserSettingsPath"
        }
        catch {
            Write-Warning "Failed to load user settings: $_"
        }
    }
    else {
        Write-Verbose "No user settings file found. Using defaults."
    }
    
    # Ensure directories exist
    $paths = @($script:AppSettings.DefaultOutputPath, $script:AppSettings.LogPath)
    foreach ($path in $paths) {
        if (-not (Test-Path -Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

function Get-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if ($script:AppSettings.ContainsKey($Name)) {
        return $script:AppSettings[$Name]
    }
    else {
        Write-Warning "Setting '$Name' not found"
        return $null
    }
}

function Set-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [object]$Value
    )
    
    $script:AppSettings[$Name] = $Value
}

function Save-AppSettings {
    try {
        $script:AppSettings | ConvertTo-Json | Set-Content -Path $script:UserSettingsPath
        Write-Verbose "Settings saved to $script:UserSettingsPath"
        return $true
    }
    catch {
        Write-Warning "Failed to save settings: $_"
        return $false
    }
}

# Initialize settings when the module is loaded
Initialize-Settings