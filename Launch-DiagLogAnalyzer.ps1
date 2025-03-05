# DiagLog Analyzer - Simple Launcher
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get root path
$rootPath = $PSScriptRoot
if (-not $rootPath) {
    $rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Ensure basic directories exist
$requiredPaths = @("logs", "results", "temp")
foreach ($dir in $requiredPaths) {
    $path = Join-Path $rootPath $dir
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

# Basic logging function for modules to use
function Global:Write-DLALog {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "General"
    )
    Write-Host "[$Level] [$Component] $Message"
}

# Basic setting function for modules to use
function Global:Get-AppSetting {
    param (
        [string]$Name,
        $DefaultValue = $null
    )
    return $DefaultValue
}

# Import essential modules
$modules = @(
    "src\Core\FileSearch.psm1",
    "src\Core\Analyzer.psm1",
    "src\GUI\Tabs\AnalysisTab.psm1",
    "src\GUI\Tabs\SearchTab.psm1", 
    "src\GUI\Tabs\ReportsTab.psm1",  # Added Reports Tab
    "src\GUI\Tabs\SettingsTab.psm1", # Added Settings Tab
    "src\GUI\Tabs\AboutTab.psm1",
    "src\GUI\MainForm.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $rootPath $module
    try {
        Write-Host "Loading module: $modulePath"
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        Write-Host "Error loading module $module : $_" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show("Error loading module $module : $_", "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Launch the application
try {
    Write-Host "Launching DiagLog Analyzer..." -ForegroundColor Green
    if (Get-Command Show-MainForm -ErrorAction SilentlyContinue) {
        Show-MainForm
    } else {
        throw "Show-MainForm function not found"
    }
}
catch {
    $errorMsg = "Failed to start DiagLog Analyzer: $_"
    Write-Host $errorMsg -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
}