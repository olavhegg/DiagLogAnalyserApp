# DiagLog Analyzer - Logging Utility
# This module provides logging functionality for the application

# Import dependencies
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Config\Settings.ps1")

# Log levels
enum LogLevel {
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
}

# Current log level - anything below this will not be logged
$script:CurrentLogLevel = [LogLevel]::INFO

# Current log file
$script:CurrentLogFile = $null

function Initialize-Logging {
    param (
        [LogLevel]$LogLevel = [LogLevel]::INFO
    )
    
    $script:CurrentLogLevel = $LogLevel
    
    # Create log directory if it doesn't exist
    $logPath = Get-AppSetting -Name "LogPath"
    if (-not (Test-Path -Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    # Create a new log file with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFileName = "DiagLogAnalyzer-$timestamp.log"
    $script:CurrentLogFile = Join-Path -Path $logPath -ChildPath $logFileName
    
    # Write header to log file
    $header = @"
# DiagLog Analyzer Log File
# Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Log Level: $LogLevel
# ----------------------------------------
"@
    
    $header | Out-File -FilePath $script:CurrentLogFile -Encoding utf8
    
    Write-Log -Message "Logging initialized" -Level INFO
}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [LogLevel]$Level = [LogLevel]::INFO,
        
        [string]$Component = "General"
    )
    
    # Skip if log level is below current
    if ([int]$Level -lt [int]$script:CurrentLogLevel) {
        return
    }
    
    # Ensure log file is initialized
    if ($null -eq $script:CurrentLogFile) {
        Initialize-Logging
    }
    
    # Format log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Write to log file
    $logEntry | Out-File -FilePath $script:CurrentLogFile -Append -Encoding utf8
    
    # Also write to console for certain levels
    if ([int]$Level -ge [int][LogLevel]::WARNING) {
        switch ($Level) {
            ([LogLevel]::WARNING) { Write-Warning $Message }
            ([LogLevel]::ERROR) { Write-Error $Message }
            default { Write-Output $logEntry }
        }
    }
}

function Get-LogFile {
    return $script:CurrentLogFile
}

function Set-LogLevel {
    param (
        [Parameter(Mandatory=$true)]
        [LogLevel]$Level
    )
    
    $script:CurrentLogLevel = $Level
    Write-Log -Message "Log level changed to $Level" -Level INFO
}