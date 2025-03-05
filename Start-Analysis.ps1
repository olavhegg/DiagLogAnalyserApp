# DiagLog Analyzer
# Main application script

# Setup error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Show error message box if we're in GUI mode
    if ($null -ne [System.Windows.Forms.Application]::OpenForms -and 
        [System.Windows.Forms.Application]::OpenForms.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "An unhandled error occurred:`n`n$_`n`nSee the console for more details.", 
            "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    
    Read-Host "Press Enter to exit"
    exit 1
}

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if we're running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "Running without administrator privileges - some features may be limited." -ForegroundColor Yellow
}

# Import required modules
try {
    Write-Host "Loading modules..." -ForegroundColor Cyan
    
    # Add required .NET assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName PresentationFramework
    
    # Load required modules
    $modulesToLoad = @(
        ".\src\Utils\Logging.ps1",
        ".\src\GUI\Controls.ps1",  # Ensure Controls.ps1 is loaded early
        ".\src\Core\Analyzer.ps1",
        ".\src\Core\CabExtractor.ps1",
        ".\src\Core\FileSearch.ps1",
        ".\src\Utils\FileSystem.ps1",
        ".\src\Utils\Reporting.ps1",
        ".\src\GUI\Helpers.ps1",
        ".\src\GUI\EventHandlers.ps1",
        ".\src\GUI\Panels.ps1",
        ".\src\GUI\TabControls.ps1",
        ".\src\GUI\MainWindow.ps1"
    )

    foreach ($module in $modulesToLoad) {
        try {
            . (Join-Path -Path $scriptPath -ChildPath $module)
            Write-Log "Loaded module: $module" -Level "INFO"
        } catch {
            Write-Log "Failed to load module: $module" -Level "ERROR"
            throw "Failed to load required module: $module"
        }
    }
    
    Write-Host "All modules loaded successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# Initialize application
try {
    # Initialize logging
    Initialize-Logging
    Write-Log -Message "Application starting" -Level INFO
    
    # Find PowerShell path for icon
    $powerShellPath = if (Test-Path "$PSHOME\powershell.exe") {
        "$PSHOME\powershell.exe"
    } elseif (Test-Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe") {
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    } else {
        $null
    }
    
    # Launch main window
    Show-MainWindow -PowerShellPath $powerShellPath
}
catch {
    Write-Log -Message "Error starting application: $_" -Level ERROR
    Write-Host "Error starting application: $_" -ForegroundColor Red
    exit 1
}
finally {
    Write-Log -Message "Application closed" -Level INFO
}