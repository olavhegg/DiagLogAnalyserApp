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
    
    # Try to use log level from settings
    try {
        $logLevelName = Get-AppSetting -Name "LogLevelName"
        if (-not [string]::IsNullOrEmpty($logLevelName)) {
            $LogLevel = [LogLevel]::$logLevelName
        }
    } catch {
        # Silently fall back to default if there's an error
    }
    
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
        try {
            Initialize-Logging
        }
        catch {
            # If initialization fails, create a basic log file
            $script:CurrentLogFile = Join-Path -Path $env:TEMP -ChildPath "DiagLogAnalyzer-fallback.log"
            "# DiagLog Analyzer - Fallback Log" | Out-File -FilePath $script:CurrentLogFile -Encoding utf8
            "# Error initializing proper logging: $_" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding utf8
        }
    }
    
    # Format log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Write to log file
    try {
        $logEntry | Out-File -FilePath $script:CurrentLogFile -Append -Encoding utf8
    }
    catch {
        # If writing to log file fails, try writing to a fallback location
        try {
            $fallbackLog = Join-Path -Path $env:TEMP -ChildPath "DiagLogAnalyzer-fallback.log"
            $logEntry + " (Error writing to main log: $_)" | Out-File -FilePath $fallbackLog -Append -Encoding utf8
        }
        catch {
            # Last resort: just output to console
            Write-Host "Failed to write to any log: $logEntry" -ForegroundColor Red
        }
    }
    
    # Also write to console for certain levels
    if ([int]$Level -ge [int][LogLevel]::WARNING) {
        switch ($Level) {
            ([LogLevel]::WARNING) { Write-Warning $Message }
            ([LogLevel]::ERROR) { Write-Error $Message }
            default { Write-Host $logEntry }
        }
    }
}

function Get-LogFile {
    return $script:CurrentLogFile
}

function Set-LogLevel {
    param (
        [Parameter(Mandatory=$true)]
        [object]$Level
    )
    
    if ($Level -is [string]) {
        # Convert string to enum
        try {
            $Level = [LogLevel]::$Level
        }
        catch {
            Write-Warning "Invalid log level string: $Level. Defaulting to INFO."
            $Level = [LogLevel]::INFO
        }
    }
    elseif ($Level -isnot [LogLevel]) {
        Write-Warning "Invalid log level type. Defaulting to INFO."
        $Level = [LogLevel]::INFO
    }
    
    $script:CurrentLogLevel = $Level
    Write-Log -Message "Log level changed to $Level" -Level INFO
}