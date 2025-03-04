# DiagLog Analyzer
# Main application script

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

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

# Start the application
Write-Host "Starting DiagLog Analyzer..."

# Initialize logging
Initialize-Logging

# Launch the main form
Show-MainForm
