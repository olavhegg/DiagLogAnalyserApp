# DiagLog Analyzer Launcher
# This script launches the DiagLog Analyzer application and handles initialization

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Add error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Host "Critical error occurred: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Show an error dialog if possible
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("A critical error occurred:`n`n$_`n`nThe application will now exit.", 
            "DiagLog Analyzer Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    catch {
        # If we can't show a GUI error, at least wait for the user to read the console
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    exit 1
}

function Test-Prerequisites {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "DiagLog Analyzer requires PowerShell 5.0 or later. Current version: $($PSVersionTable.PSVersion)"
    }
    
    # Check for required modules/assemblies
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    }
    catch {
        throw "Failed to load required .NET assemblies: $_"
    }
    
    # Check for expand.exe (used for CAB extraction)
    try {
        $expandPath = (Get-Command "expand.exe" -ErrorAction SilentlyContinue).Source
        if (-not $expandPath) {
            Write-Warning "expand.exe not found in PATH. CAB extraction functionality may be limited."
        }
    }
    catch {
        Write-Warning "Failed to check for expand.exe: $_"
    }
    
    # Check for write permissions in the application directory
    try {
        $testFile = Join-Path -Path $scriptPath -ChildPath "writetest.tmp"
        [System.IO.File]::WriteAllText($testFile, "Write test")
        Remove-Item -Path $testFile -Force
    }
    catch {
        throw "The application doesn't have write permissions in its directory. Please run the application from a location where you have write permissions."
    }
}

function Start-Application {
    # Import the main application script
    try {
        . (Join-Path -Path $scriptPath -ChildPath "Start-Analysis.ps1")
    }
    catch {
        throw "Failed to load application: $_"
    }
}

# Main execution
Write-Host "DiagLog Analyzer - Starting..." -ForegroundColor Cyan

try {
    # Check prerequisites
    Test-Prerequisites
    
    # Start the application
    Start-Application
}
catch {
    Write-Host "Failed to start DiagLog Analyzer: $_" -ForegroundColor Red
    
    # Show an error dialog
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Failed to start DiagLog Analyzer:`n`n$_", 
        "Startup Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
    
    exit 1
}