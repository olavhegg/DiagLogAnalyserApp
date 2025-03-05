# DiagLog Analyzer - Logging Adapter
# This module provides compatibility between the new settings and existing logging

# Check if the original logging function exists
$originalLoggingExists = $null -ne (Get-Command -Name "Write-DLALog" -ErrorAction SilentlyContinue)

# If the original logging doesn't exist, create a basic version
if (-not $originalLoggingExists) {
    function global:Write-DLALog {
        param (
            [Parameter(Mandatory=$true)]
            [string]$Message,
            
            [Parameter(Mandatory=$false)]
            [string]$Level = "INFO",
            
            [Parameter(Mandatory=$false)]
            [string]$Component = "General"
        )
        
        # Format the log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] [$Component] $Message"
        
        # Output to console
        Write-Host $logEntry
        
        # Try to write to a log file
        try {
            $logDir = Join-Path -Path $PSScriptRoot -ChildPath "..\..\logs"
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            $logFile = Join-Path -Path $logDir -ChildPath "diaganalyzer_$(Get-Date -Format 'yyyyMMdd').log"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail if we can't write to the log file
        }
    }
}

# Create a function to initialize logging that works with the new settings
function Initialize-DLALogging {
    try {
        # Get the log path from settings
        $logPath = Get-AppSetting -Name "LogPath" -DefaultValue (Join-Path -Path $PSScriptRoot -ChildPath "..\..\logs")
        
        # Ensure log directory exists
        if (-not (Test-Path -Path $logPath)) {
            New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        }
        
        # Log initialization
        Write-DLALog -Message "Logging initialized with path: $logPath" -Level INFO -Component "Logging"
        return $true
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        return $false
    }
}

# Define a function to get a logging setting for backward compatibility
function Get-DLASetting {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Map old setting names to new ones
    $settingsMap = @{
        "LogPath" = "LogPath"
        "LogLevel" = "LogLevelName"
        "ResultsPath" = "DefaultOutputPath"
        "TempPath" = "DiagWorkingPath"
    }
    
    # Get the corresponding new setting name
    $newName = $settingsMap[$Name]
    if ($newName) {
        return Get-AppSetting -Name $newName
    }
    
    # Try the original name as a fallback
    return Get-AppSetting -Name $Name
}

# Export functions
Export-ModuleMember -Function Initialize-DLALogging, Get-DLASetting