# DiagLog Analyzer - Settings Management
# This module handles application settings and configuration

# Default settings file path
$script:SettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\settings.json"

# Global variable to store settings
$Global:AppSettings = $null

function Initialize-Settings {
    # Check if settings file exists
    if (Test-Path -Path $script:SettingsPath) {
        try {
            # Load settings from JSON file
            $Global:AppSettings = Get-Content -Path $script:SettingsPath -Raw | ConvertFrom-Json
            Write-Verbose "Settings loaded from $script:SettingsPath"
        }
        catch {
            Write-Warning "Failed to load settings: $_"
            # Create default settings
            Create-DefaultSettings
        }
    }
    else {
        # Create default settings
        Create-DefaultSettings
    }
    
    # Ensure directories exist
    $outputPath = Get-AppSetting -Name "DefaultOutputPath"
    $logPath = Get-AppSetting -Name "LogPath"
    
    $paths = @($outputPath, $logPath)
    foreach ($path in $paths) {
        if (-not [string]::IsNullOrEmpty($path) -and -not (Test-Path -Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

function Create-DefaultSettings {
    # Default settings
    $Global:AppSettings = [PSCustomObject]@{
        AppName = "DiagLog Analyzer"
        Version = "1.0.0"
        DefaultOutputPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\results"
        LogPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\logs"
        MaxFileSizeForTextSearch = 50MB
        DefaultFileTypesToSearch = @(".log", ".txt", ".xml", ".html", ".json", ".csv")
        ExtractCabsAutomatically = $false
        SkipExistingCabExtracts = $true
        MainFormWidth = 900
        MainFormHeight = 700
        ResultsFontFamily = "Consolas"
        ResultsFontSize = 9
        LogLevelName = "INFO"
    }
    
    # Save default settings
    Save-AppSettings
    
    Write-Verbose "Created default settings"
}

function Get-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    # Get property value using reflection (works with PSCustomObject)
    if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
        return $Global:AppSettings.$Name
    }
    else {
        Write-Warning "Setting '$Name' not found"
        return $null
    }
}

# This is a targeted fix for the Set-AppSetting function to handle null values properly

function Set-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]  # Changed from Mandatory=$true to allow null values
        [AllowNull()]                  # Explicitly allow null values
        [object]$Value
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    # Check if property exists
    if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
        # Set property via reflection
        $Global:AppSettings.$Name = $Value
    }
    else {
        # Add new property
        $Global:AppSettings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Save-AppSettings {
    try {
        # Ensure settings are initialized
        if ($null -eq $Global:AppSettings) {
            Initialize-Settings
        }
        
        # Convert to JSON and save
        # Use Depth parameter to ensure all nested objects are properly serialized
        $jsonSettings = ConvertTo-Json -InputObject $Global:AppSettings -Depth 10 -Compress:$false
        Set-Content -Path $script:SettingsPath -Value $jsonSettings -Encoding UTF8
        
        Write-Verbose "Settings saved to $script:SettingsPath"
        return $true
    }
    catch {
        Write-Warning "Failed to save settings: $_"
        return $false
    }
}

# Initialize settings when the module is loaded
Initialize-Settings