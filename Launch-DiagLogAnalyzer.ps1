# DiagLog Analyzer - Main Launcher Script

# Add required assemblies first
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the root path and ensure it's using Windows path format
$script:RootPath = $PSScriptRoot
if (-not $script:RootPath) {
    $script:RootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$script:RootPath = $script:RootPath.Replace('/', '\')

# Create required directories if they don't exist
$requiredPaths = @(
    (Join-Path $script:RootPath "logs"),
    (Join-Path $script:RootPath "results"),
    (Join-Path $script:RootPath "temp")
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

# Module import order is important - define dependencies
$moduleOrder = @(
    "src\Config\Settings.psm1",        # Load first - no dependencies
    "src\Utils\Logging.psm1",          # Depends on Settings
    "src\Utils\FileSystem.psm1",       # Depends on Logging
    "src\Core\FileSearch.psm1",        # Depends on FileSystem
    "src\Core\CabExtractor.psm1",      # Depends on FileSystem
    "src\Core\Analyzer.psm1",          # Depends on all above
    "src\GUI\Controls.psm1",           # Depends on Settings
    "src\GUI\MainForm.psm1"            # Depends on all above
)

# Import modules in correct order
foreach ($module in $moduleOrder) {
    $modulePath = Join-Path -Path $script:RootPath -ChildPath $module
    Write-Host "Attempting to load module: $modulePath"
    
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            Write-Host "Successfully loaded module: $module" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to load module $module : $_"
            exit 1
        }
    }
    else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# Initialize settings and logging
try {
    Initialize-DLASettings
    Initialize-DLALogging
    Write-DLALog -Message "Starting DiagLog Analyzer" -Level INFO
    
    # Use Show-MainForm instead of direct form creation
    Show-MainForm
}
catch {
    $errorMsg = "Failed to start DiagLog Analyzer: $_"
    if (Get-Command Write-DLALog -ErrorAction SilentlyContinue) {
        Write-DLALog -Message $errorMsg -Level ERROR
    }
    else {
        Write-Error $errorMsg
    }
    [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
}