# DiagLog Analyzer - Main Form
# This file contains the main application window and UI logic

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

# Import required modules using proper module paths
$modulesToImport = @(
    (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\Logging.psm1"),
    (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\Analyzer.psm1")
)

foreach ($module in $modulesToImport) {
    Import-Module $module -Force
}

# Keep global variables
$script:AnalysisResults = $null
$script:MainForm = $null

# The rest of the MainForm.ps1 file can now be much simpler
function Show-MainForm {
    param(
        [string]$PowerShellPath = "$PSHOME\powershell.exe"
    )
    
    $script:MainForm = New-MainForm
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($script:MainForm)
}

function New-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DiagLog Analyzer"
    $form.Size = New-Object System.Drawing.Size(800,600)
    $form.StartPosition = "CenterScreen"
    
    # Add form controls here
    
    return $form
}

# Export functions
Export-ModuleMember -Function Show-MainForm, Update-Status, Update-TabStates