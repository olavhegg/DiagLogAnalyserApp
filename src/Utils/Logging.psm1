# DiagLog Analyzer - Logging Utility
# This module provides logging functionality for the application

# Script variables
$script:LogInitialized = $false
$script:LogFile = $null
$script:LogLevel = @{
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
}

# Get the base directory for fallback paths
$script:BaseDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:DefaultLogPath = Join-Path -Path $script:BaseDir -ChildPath "logs\diaganalyzer.log"

function Initialize-DLALogging {
    [CmdletBinding()]
    param()
    
    try {
        # Try to get log path from settings
        $logPath = $null
        
        # First try Get-DLASetting
        if (Get-Command -Name Get-DLASetting -ErrorAction SilentlyContinue) {
            try {
                $logPath = Get-DLASetting -Name "LogPath"
            }
            catch {
                Write-Verbose "Error getting LogPath from Get-DLASetting: $_"
            }
        }
        
        # Then try Get-AppSetting
        if ([string]::IsNullOrEmpty($logPath) -and (Get-Command -Name Get-AppSetting -ErrorAction SilentlyContinue)) {
            try {
                $logPath = Get-AppSetting -Name "LogPath" -DefaultValue $script:DefaultLogPath
            }
            catch {
                Write-Verbose "Error getting LogPath from Get-AppSetting: $_"
            }
        }
        
        # Fall back to default if still empty
        if ([string]::IsNullOrEmpty($logPath)) {
            $logPath = $script:DefaultLogPath
            Write-Verbose "Using default log path: $logPath"
        }
        
        # Ensure the directory exists
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $script:LogFile = $logPath
        $script:LogInitialized = $true
        
        Write-Verbose "Logging initialized to: $logPath"
        return $true
    }
    catch {
        # Create a console error message
        Write-Error "Failed to initialize logging: $_"
        
        # Fall back to a default log in the base directory
        try {
            $fallbackLog = Join-Path -Path $script:BaseDir -ChildPath "diaganalyzer.log"
            $script:LogFile = $fallbackLog
            $script:LogInitialized = $true
            
            # Log the initialization error
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $errorEntry = "$timestamp [ERROR] [Logging] Failed to initialize logging properly: $_"
            Add-Content -Path $fallbackLog -Value $errorEntry -Encoding UTF8 -ErrorAction SilentlyContinue
            
            return $true
        }
        catch {
            # Really can't log anywhere
            return $false
        }
    }
}

function Write-DLALog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [string]$Component = 'General',
        
        [Parameter()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter()]
        [switch]$NoWrite
    )
    
    if (-not $script:LogInitialized) {
        $initialized = Initialize-DLALogging
        if (-not $initialized) {
            # If initialization failed, just write to console and return
            Write-Host "$Level [$Component] $Message"
            return
        }
    }
    
    # Make sure we have a valid log file
    if ([string]::IsNullOrEmpty($script:LogFile)) {
        $script:LogFile = Join-Path -Path $script:BaseDir -ChildPath "diaganalyzer.log"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] [$Component] $Message"
    
    # Add to log file - with error handling
    try {
        $logEntry | Add-Content -Path $script:LogFile -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Try a fallback location
        try {
            $fallbackLog = Join-Path -Path $script:BaseDir -ChildPath "diaganalyzer.log"
            $logEntry | Add-Content -Path $fallbackLog -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Unable to log to file, continue to console output
        }
    }
    
    # Output to console with appropriate stream
    if (-not $NoWrite) {
        switch ($Level) {
            'ERROR' { 
                Write-Error $logEntry
                if ($ErrorRecord) {
                    Write-Error $ErrorRecord
                }
            }
            'WARNING' { Write-Warning $logEntry }
            'INFO' { Write-Verbose $logEntry -Verbose }
            'DEBUG' { Write-Debug $logEntry }
        }
    }
    
    # If there's an error record, log the stack trace
    if ($ErrorRecord) {
        $trace = $ErrorRecord.ScriptStackTrace
        if (-not [string]::IsNullOrEmpty($stackTrace)) {
            $stackEntry = "$timestamp [$Level] [$Component] $trace"
            try {
                $stackEntry | Add-Content -Path $script:LogFile -Encoding UTF8 -ErrorAction SilentlyContinue
            }
            catch {
                # Unable to log stack trace
            }
            
            if (-not $NoWrite) {
                Write-Error $trace
            }
        }
    }
}

function Get-DLALogFile {
    # Initialize if needed
    if (-not $script:LogInitialized) {
        Initialize-DLALogging | Out-Null
    }
    
    return $script:LogFile
}

function Clear-DLALog {
    # Initialize if needed
    if (-not $script:LogInitialized) {
        Initialize-DLALogging | Out-Null
    }
    
    if (Test-Path $script:LogFile) {
        Clear-Content -Path $script:LogFile
        Write-DLALog -Message "Log file cleared" -Level INFO -NoWrite
    }
}

# Convenience functions for different log levels
function Write-DLADebug { 
    param([string]$Message, [string]$Component = "General") 
    Write-DLALog -Message $Message -Level DEBUG -Component $Component 
}

function Write-DLAInfo { 
    param([string]$Message, [string]$Component = "General") 
    Write-DLALog -Message $Message -Level INFO -Component $Component 
}

function Write-DLAWarning { 
    param([string]$Message, [string]$Component = "General") 
    Write-DLALog -Message $Message -Level WARNING -Component $Component 
}

function Write-DLAError { 
    param(
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Component = "General"
    ) 
    Write-DLALog -Message $Message -Level ERROR -ErrorRecord $ErrorRecord -Component $Component
}

# Export the functions
Export-ModuleMember -Function Initialize-DLALogging, 
                            Write-DLALog,
                            Write-DLADebug,
                            Write-DLAInfo,
                            Write-DLAWarning,
                            Write-DLAError,
                            Get-DLALogFile,
                            Clear-DLALog