# DiagLog Analyzer
# Main application script

# Setup error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Show error message box if we're in GUI mode
    if ($null -ne [System.Windows.Forms.Application]::OpenForms -and [System.Windows.Forms.Application]::OpenForms.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show("An unhandled error occurred:`n`n$_`n`nSee the console for more details.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    
    Read-Host "Press Enter to exit"
    exit 1
}

# Get script path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if we're running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "DiagLog Analyzer is not running with administrator privileges." -ForegroundColor Yellow
    Write-Host "Some features may not work correctly, especially accessing protected system files." -ForegroundColor Yellow
}

# Import required modules
try {
    Write-Host "Loading modules..." -ForegroundColor Cyan
    
    # Load GUI components
    . (Join-Path -Path $scriptPath -ChildPath "src\GUI\MainForm.ps1")
    . (Join-Path -Path $scriptPath -ChildPath "src\GUI\Controls.ps1")
    
    # Load core functionality
    . (Join-Path -Path $scriptPath -ChildPath "src\Core\Analyzer.ps1")
    . (Join-Path -Path $scriptPath -ChildPath "src\Core\CabExtractor.ps1")
    . (Join-Path -Path $scriptPath -ChildPath "src\Core\FileSearch.ps1")
    
    # Load utilities
    . (Join-Path -Path $scriptPath -ChildPath "src\Utils\FileSystem.ps1")
    . (Join-Path -Path $scriptPath -ChildPath "src\Utils\Logging.ps1")
    . (Join-Path -Path $scriptPath -ChildPath "src\Utils\Reporting.ps1")
    
    # Load configuration
    . (Join-Path -Path $scriptPath -ChildPath "src\Config\Settings.ps1")
    
    Write-Host "All modules loaded successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# Start the application
Write-Host "Starting DiagLog Analyzer..." -ForegroundColor Cyan

# Initialize logging
Initialize-Logging

# Launch the main form
try {
    Write-Log -Message "Application started" -Level INFO
    Show-MainForm
}
catch {
    Write-Log -Message "Error starting application: $_" -Level ERROR
    Write-Host "Error starting application: $_" -ForegroundColor Red
    exit 1
}
finally {
    Write-Log -Message "Application closed" -Level INFO
}