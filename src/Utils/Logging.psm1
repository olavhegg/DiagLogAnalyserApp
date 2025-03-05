# DiagLog Analyzer - Logging Utility
# This module provides logging functionality for the application

# Import settings module
$settingsModule = Join-Path -Path $PSScriptRoot -ChildPath "..\Config\Settings.psm1"
Import-Module $settingsModule -Force

# Script variables
$script:LogInitialized = $false
$script:LogFile = $null
$script:LogLevel = @{
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
}

function Initialize-DLALogging {
    [CmdletBinding()]
    param()
    
    try {
        $logPath = Get-DLASetting -Name "LogPath"
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
        Write-Error "Failed to initialize logging: $_"
        return $false
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
        Initialize-DLALogging
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] [$Component] $Message"
    
    # Add to log file
    $logEntry | Add-Content -Path $script:LogFile -Encoding UTF8
    
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
        $stackTrace = $ErrorRecord.ScriptStackTrace
        if (-not [string]::IsNullOrEmpty($stackTrace)) {
            $stackEntry = "$timestamp [$Level] [$Component] $stackTrace"
            $stackEntry | Add-Content -Path $script:LogFile -Encoding UTF8
            
            if (-not $NoWrite) {
                Write-Error $stackTrace
            }
        }
    }
}

function Get-DLALogFile {
    return $script:LogFile
}

function Clear-DLALog {
    if (Test-Path $script:LogFile) {
        Clear-Content -Path $script:LogFile
        Write-DLALog -Message "Log file cleared" -Level INFO -NoWrite
    }
}

# Convenience functions for different log levels
function Write-DLADebug { param([string]$Message) Write-DLALog -Message $Message -Level DEBUG }
function Write-DLAInfo { param([string]$Message) Write-DLALog -Message $Message -Level INFO }
function Write-DLAWarning { param([string]$Message) Write-DLALog -Message $Message -Level WARNING }
function Write-DLAError { 
    param(
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    ) 
    Write-DLALog -Message $Message -Level ERROR -ErrorRecord $ErrorRecord
}

Export-ModuleMember -Function Initialize-DLALogging, 
                            Write-DLALog,
                            Write-DLADebug,
                            Write-DLAInfo,
                            Write-DLAWarning,
                            Write-DLAError,
                            Get-DLALogFile,
                            Clear-DLALog