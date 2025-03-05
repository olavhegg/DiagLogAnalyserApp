# DiagLog Analyzer - Settings Management
# This module handles application settings and configuration

# Default settings file path
$script:SettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\settings.json"

# Global variable to store settings
$Global:AppSettings = $null

$script:Config = @{
    LogPath = Join-Path $PSScriptRoot "../../logs"
    MaxLogSize = 10MB
    DefaultSearchPath = [Environment]::GetFolderPath('MyDocuments')
    DiagnosticSettings = @{
        DefaultTimeout = 3600  # 1 hour in seconds
        MaxConcurrentDiags = 3
        WorkingDirectory = Join-Path $PSScriptRoot "../../temp"
        ResultsDirectory = Join-Path $PSScriptRoot "../../results"
        AutoCleanup = $true
        CleanupAge = 7  # Days
    }
}

# Global settings
$script:Settings = @{
    LogPath = Join-Path $PSScriptRoot "..\..\logs\diaganalyzer.log"
    ResultsPath = Join-Path $PSScriptRoot "..\..\results"
    TempPath = Join-Path $PSScriptRoot "..\..\temp"
    LogLevel = "DEBUG"  # DEBUG, INFO, WARN, ERROR
}

function Get-AppSettings {
    return $script:Config
}

function Initialize-Settings {
    # Check if settings file exists
    if (Test-Path -Path $script:SettingsPath) {
        try {
            # Load settings from JSON file
            $Global:AppSettings = Get-Content -Path $script:SettingsPath -Raw | ConvertFrom-Json
            Write-Verbose "Settings loaded from $script:SettingsPath"
            
            # Validate settings and apply defaults where needed
            Validate-Settings
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

function Validate-Settings {
    # This function ensures all required settings have valid values
    # Check for missing properties and add them with default values
    
    # Define default settings map
    $defaultSettings = @{
        "AppName" = "DiagLog Analyzer"
        "Version" = "1.0.0"
        "DefaultOutputPath" = Join-Path -Path $PSScriptRoot -ChildPath "..\..\results"
        "LogPath" = Join-Path -Path $PSScriptRoot -ChildPath "..\..\logs"
        "MaxFileSizeForTextSearch" = 50MB
        "DefaultFileTypesToSearch" = @(".log", ".txt", ".xml", ".html", ".json", ".csv")
        "ExtractCabsAutomatically" = $false
        "SkipExistingCabExtracts" = $true
        "MainFormWidth" = 900
        "MainFormHeight" = 700
        "ResultsFontFamily" = "Consolas"
        "ResultsFontSize" = 9
        "LogLevelName" = "INFO"
    }
    
    # Validate and repair each setting
    foreach ($key in $defaultSettings.Keys) {
        # Check if property exists
        if (-not $Global:AppSettings.PSObject.Properties.Name -contains $key) {
            # Property doesn't exist, add it with default value
            $Global:AppSettings | Add-Member -NotePropertyName $key -NotePropertyValue $defaultSettings[$key]
            Write-Verbose "Added missing setting '$key' with default value: $($defaultSettings[$key])"
        }
        else {
            # Property exists, check if value is valid
            $currentValue = $Global:AppSettings.$key
            
            # Handle numerical values validation
            if ($key -in @("MainFormWidth", "MainFormHeight", "ResultsFontSize", "MaxFileSizeForTextSearch")) {
                # Ensure numerical values are valid (greater than 0)
                if ($null -eq $currentValue -or 
                    (-not [string]::IsNullOrEmpty($currentValue) -and -not [double]::TryParse($currentValue.ToString(), [ref]$null)) -or 
                    $currentValue -le 0) {
                    
                    # Replace invalid value with default
                    $Global:AppSettings.$key = $defaultSettings[$key]
                    Write-Verbose "Replaced invalid value for '$key' with default: $($defaultSettings[$key])"
                }
            }
            # Handle array values validation
            elseif ($key -eq "DefaultFileTypesToSearch") {
                if ($null -eq $currentValue -or -not ($currentValue -is [array])) {
                    $Global:AppSettings.$key = $defaultSettings[$key]
                    Write-Verbose "Replaced invalid value for '$key' with default array"
                }
            }
            # Handle string values validation
            elseif ($key -in @("AppName", "Version", "ResultsFontFamily", "LogLevelName")) {
                if ([string]::IsNullOrEmpty($currentValue)) {
                    $Global:AppSettings.$key = $defaultSettings[$key]
                    Write-Verbose "Replaced empty string for '$key' with default: $($defaultSettings[$key])"
                }
            }
            # Handle path validations
            elseif ($key -in @("DefaultOutputPath", "LogPath")) {
                if ([string]::IsNullOrEmpty($currentValue)) {
                    $Global:AppSettings.$key = $defaultSettings[$key]
                    Write-Verbose "Replaced empty path for '$key' with default: $($defaultSettings[$key])"
                }
            }
            # Handle boolean validations
            elseif ($key -in @("ExtractCabsAutomatically", "SkipExistingCabExtracts")) {
                if ($null -eq $currentValue) {
                    $Global:AppSettings.$key = $defaultSettings[$key]
                    Write-Verbose "Replaced null boolean for '$key' with default: $($defaultSettings[$key])"
                }
            }
        }
    }
    
    # Add diagnostic settings validation
    $diagSettings = @{
        "DiagTimeout" = 3600
        "MaxConcurrentDiags" = 3
        "DiagWorkingPath" = Join-Path -Path $PSScriptRoot -ChildPath "..\..\temp"
        "DiagResultsPath" = Join-Path -Path $PSScriptRoot -ChildPath "..\..\results"
        "AutoCleanupDiags" = $true
        "DiagCleanupAgeDays" = 7
        "DiagDefaultParameters" = @{
            SkipVersionCheck = $false
            ForceElevated = $true
            IncludeSystemLogs = $true
        }
    }
    
    foreach ($key in $diagSettings.Keys) {
        if (-not $Global:AppSettings.PSObject.Properties.Name -contains $key) {
            $Global:AppSettings | Add-Member -NotePropertyName $key -NotePropertyValue $diagSettings[$key]
            Write-Verbose "Added missing diagnostic setting '$key' with default value"
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
        # Add diagnostic-specific settings
        DiagTimeout = 3600
        MaxConcurrentDiags = 3
        DiagWorkingPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\temp"
        DiagResultsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\results"
        AutoCleanupDiags = $true
        DiagCleanupAgeDays = 7
        DiagDefaultParameters = @{
            SkipVersionCheck = $false
            ForceElevated = $true
            IncludeSystemLogs = $true
        }
    }
    
    # Save default settings
    Save-AppSettings
    
    Write-Verbose "Created default settings including diagnostic configuration"
}

function Get-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [object]$DefaultValue = $null
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    # Get property value using reflection (works with PSCustomObject)
    if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
        $value = $Global:AppSettings.$Name
        
        # Return default if value is null
        if ($null -eq $value -and $null -ne $DefaultValue) {
            return $DefaultValue
        }
        
        return $value
    }
    else {
        Write-Warning "Setting '$Name' not found, returning default value"
        return $DefaultValue
    }
}

function Set-AppSetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [object]$Value
    )
    
    # Ensure settings are initialized
    if ($null -eq $Global:AppSettings) {
        Initialize-Settings
    }
    
    try {
        # Check if property exists
        if ($Global:AppSettings.PSObject.Properties.Name -contains $Name) {
            # Set property via reflection
            $Global:AppSettings.$Name = $Value
        }
        else {
            # Add new property
            $Global:AppSettings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
        }
        return $true
    }
    catch {
        Write-Warning "Failed to set setting '$Name': $_"
        return $false
    }
}

function Save-AppSettings {
    try {
        # Ensure settings are initialized
        if ($null -eq $Global:AppSettings) {
            Initialize-Settings
        }
        
        # Run validation before saving
        Validate-Settings
        
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

# Create a backup of the settings file
function Backup-Settings {
    try {
        if (Test-Path -Path $script:SettingsPath) {
            $backupFolder = Join-Path -Path (Split-Path -Parent $script:SettingsPath) -ChildPath "backups"
            
            if (-not (Test-Path -Path $backupFolder)) {
                New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = Join-Path -Path $backupFolder -ChildPath "settings_$timestamp.json"
            
            Copy-Item -Path $script:SettingsPath -Destination $backupPath -Force
            Write-Verbose "Settings backed up to $backupPath"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to back up settings: $_"
        return $false
    }
}

# Reset settings to default
function Reset-Settings {
    try {
        # Create backup before resetting
        Backup-Settings
        
        # Create default settings
        Create-DefaultSettings
        
        Write-Verbose "Settings reset to default values"
        return $true
    }
    catch {
        Write-Warning "Failed to reset settings: $_"
        return $false
    }
}

function Initialize-DLASettings {
    Write-Host "Initializing settings..."
    # Nothing to do yet, settings are initialized when module loads
    return $true
}

function Get-DLASetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    return $script:Settings[$Name]
}

# Initialize settings when the module is loaded
Initialize-Settings

Export-ModuleMember -Function Get-AppSettings, 
                            Get-AppSetting, 
                            Set-AppSetting, 
                            Initialize-Settings, 
                            Save-AppSettings, 
                            Reset-Settings,
                            Initialize-DLASettings,
                            Get-DLASetting