# DiagLog Analyzer - Simplified Settings Management
# This module handles application settings and configuration

# Calculate base paths directly
$script:RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:SettingsPath = Join-Path -Path $script:RootDir -ChildPath "settings.json"

# Global variable to store settings
$Global:AppSettings = $null

# Basic settings with absolute paths for logging compatibility
$script:Settings = @{
    LogPath = Join-Path -Path $script:RootDir -ChildPath "logs\diaganalyzer.log"
    ResultsPath = Join-Path -Path $script:RootDir -ChildPath "results"
    TempPath = Join-Path -Path $script:RootDir -ChildPath "temp"
    LogLevel = "INFO"  # DEBUG, INFO, WARN, ERROR
}

# Define default settings with absolute paths
$script:DefaultSettings = @{
    "AppName" = "DiagLog Analyzer"
    "Version" = "1.0.0"
    "DefaultOutputPath" = Join-Path -Path $script:RootDir -ChildPath "results"
    "LogPath" = Join-Path -Path $script:RootDir -ChildPath "logs\diaganalyzer.log"
    "MaxFileSizeForTextSearch" = 50MB
    "DefaultFileTypesToSearch" = @(".log", ".txt", ".xml", ".html", ".json", ".csv", ".etl", ".evtx", ".reg")
    "ExtractCabsAutomatically" = $false
    "SkipExistingCabExtracts" = $true
    "MainFormWidth" = 900
    "MainFormHeight" = 700
    "ResultsFontFamily" = "Consolas"
    "ResultsFontSize" = 9
    "LogLevelName" = "INFO"
    "DiagTimeout" = 3600
    "MaxConcurrentDiags" = 3
    "DiagWorkingPath" = Join-Path -Path $script:RootDir -ChildPath "temp"
    "DiagResultsPath" = Join-Path -Path $script:RootDir -ChildPath "results"
    "AutoCleanupDiags" = $true
    "DiagCleanupAgeDays" = 7
    "DiagDefaultParameters" = @{
        SkipVersionCheck = $false
        ForceElevated = $true
        IncludeSystemLogs = $true
    }
}

# Simple function to create required directories
function Ensure-Directories {
    param (
        [string[]]$Paths
    )
    
    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrEmpty($path) -and -not (Test-Path -Path $path)) {
            try {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $path"
            }
            catch {
                Write-Warning "Failed to create directory $path`: $_"
            }
        }
    }
}

# Function to initialize settings
function Initialize-Settings {
    param(
        [switch]$Force
    )
    
    # Skip if already initialized and not forcing
    if ($null -ne $Global:AppSettings -and -not $Force) {
        Write-Verbose "Settings already initialized, use -Force to reinitialize"
        return $Global:AppSettings
    }
    
    # Ensure required directories exist
    $directoryPaths = @(
        (Join-Path -Path $script:RootDir -ChildPath "logs"),
        (Join-Path -Path $script:RootDir -ChildPath "results"),
        (Join-Path -Path $script:RootDir -ChildPath "temp")
    )
    Ensure-Directories -Paths $directoryPaths
    
    # Check if settings file exists
    if (Test-Path -Path $script:SettingsPath) {
        try {
            # Load settings from JSON file
            $settingsContent = Get-Content -Path $script:SettingsPath -Raw -ErrorAction Stop
            $Global:AppSettings = ConvertFrom-Json -InputObject $settingsContent -ErrorAction Stop
            Write-Verbose "Settings loaded from $script:SettingsPath"
        }
        catch {
            Write-Warning "Failed to load settings: $_"
            # If loading fails, create default settings
            $Global:AppSettings = [PSCustomObject]$script:DefaultSettings
        }
    }
    else {
        # Create default settings 
        $Global:AppSettings = [PSCustomObject]$script:DefaultSettings
        Write-Verbose "Settings file not found, using defaults"
    }
    
    # Ensure all required settings exist with valid values
    foreach ($key in $script:DefaultSettings.Keys) {
        # Add missing properties
        if (-not ($Global:AppSettings.PSObject.Properties.Name -contains $key)) {
            $Global:AppSettings | Add-Member -NotePropertyName $key -NotePropertyValue $script:DefaultSettings[$key]
        }
        # Fix null or invalid values
        elseif ($null -eq $Global:AppSettings.$key -or 
                ([string]::IsNullOrEmpty($Global:AppSettings.$key.ToString()) -and 
                $Global:AppSettings.$key -isnot [bool] -and 
                $Global:AppSettings.$key -isnot [array])) {
            $Global:AppSettings.$key = $script:DefaultSettings[$key]
        }
    }
    
    # Update script:Settings for compatibility with existing logging
    $script:Settings.LogPath = $Global:AppSettings.LogPath
    $script:Settings.ResultsPath = $Global:AppSettings.DefaultOutputPath
    $script:Settings.TempPath = $Global:AppSettings.DiagWorkingPath
    $script:Settings.LogLevel = $Global:AppSettings.LogLevelName
    
    # Save validated settings
    Save-AppSettings
    
    return $Global:AppSettings
}

# Alternative name for backwards compatibility
function Initialize-DLASettings {
    param(
        [switch]$Force
    )
    
    return Initialize-Settings -Force:$Force
}

# Function to get a setting value
function Get-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    # Get property value
    if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
        $value = $Global:AppSettings.$Name
        
        # Return default if value is null
        if ($null -eq $value -and $null -ne $DefaultValue) {
            return $DefaultValue
        }
        
        return $value
    }
    else {
        Write-Verbose "Setting '$Name' not found, returning default value"
        return $DefaultValue
    }
}

# Function to set a setting value
function Set-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $Value
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    try {
        # Check if property exists
        if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
            # Update existing property
            $Global:AppSettings.$Name = $Value
        }
        else {
            # Add new property
            $Global:AppSettings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
        }
        
        # Update script:Settings if it's a corresponding property
        switch ($Name) {
            "LogPath" { $script:Settings.LogPath = $Value }
            "DefaultOutputPath" { $script:Settings.ResultsPath = $Value }
            "DiagWorkingPath" { $script:Settings.TempPath = $Value }
            "LogLevelName" { $script:Settings.LogLevel = $Value }
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to set setting '$Name': $_"
        return $false
    }
}

# Function to get old style settings for backward compatibility
function Get-DLASetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if ($script:Settings.ContainsKey($Name)) {
        return $script:Settings[$Name]
    }
    
    return $null
}

# Function to save settings to file
function Save-AppSettings {
    try {
        # Ensure settings are initialized
        if ($null -eq $Global:AppSettings) {
            Initialize-Settings
        }
        
        # Convert to JSON and save
        $jsonSettings = ConvertTo-Json -InputObject $Global:AppSettings -Depth 10
        
        # Ensure directory exists
        $settingsDir = Split-Path -Parent $script:SettingsPath
        if (-not (Test-Path -Path $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }
        
        Set-Content -Path $script:SettingsPath -Value $jsonSettings -Encoding UTF8
        
        Write-Verbose "Settings saved to $script:SettingsPath"
        return $true
    }
    catch {
        Write-Warning "Failed to save settings: $_"
        return $false
    }
}

# Function to reset settings to default
function Reset-Settings {
    try {
        # Create backup if settings file exists
        if (Test-Path -Path $script:SettingsPath) {
            $backupFolder = Join-Path -Path (Split-Path -Parent $script:SettingsPath) -ChildPath "backups"
            
            if (-not (Test-Path -Path $backupFolder)) {
                New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = Join-Path -Path $backupFolder -ChildPath "settings_$timestamp.json"
            
            Copy-Item -Path $script:SettingsPath -Destination $backupPath -Force
        }
        
        # Create new settings
        $Global:AppSettings = [PSCustomObject]$script:DefaultSettings
        
        # Save to file
        Save-AppSettings
        
        return $true
    }
    catch {
        Write-Warning "Failed to reset settings: $_"
        return $false
    }
}

# Function to get the entire settings object
function Get-AppSettings {
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    return $Global:AppSettings
}

# Initialize settings when module is imported
Initialize-Settings -Force

# Export all required functions as both script and global functions
# This ensures they're available in any scope
$functionNames = @(
    'Initialize-Settings',
    'Initialize-DLASettings',
    'Get-AppSetting',
    'Set-AppSetting',
    'Get-DLASetting',
    'Save-AppSettings',
    'Reset-Settings',
    'Get-AppSettings'
)

# Export functions locally
Export-ModuleMember -Function $functionNames -Variable @('AppSettings')

# Create global versions of critical functions
foreach ($funcName in $functionNames) {
    $scriptBlock = (Get-Command $funcName).ScriptBlock
    
    # Create global function
    Set-Item -Path "function:Global:$funcName" -Value $scriptBlock
}

# Export a notice confirming module is loaded and functions are available
Write-Verbose "Settings module loaded successfully. Functions exported both locally and globally."