# Import dependencies
. (Join-Path -Path $PSScriptRoot -ChildPath "Controls.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "EventHandlers.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "TabControls.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "Panels.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "Helpers.ps1")

# Global variables for application state
$script:MainForm = $null
$script:AnalysisResults = $null

function Initialize-MainWindow {
    param(
        [string]$PowerShellPath = "$PSHOME\powershell.exe"
    )
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DiagLog Analyzer"
    $form.Size = New-Object System.Drawing.Size(
        (Get-AppSetting -Name "MainFormWidth"),
        (Get-AppSetting -Name "MainFormHeight")
    )
    $form.StartPosition = "CenterScreen"
    
    # Store reference to main form
    $script:MainForm = $form
    
    # Set icon if available
    if ($PowerShellPath -and (Test-Path $PowerShellPath)) {
        try {
            $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PowerShellPath)
        }
        catch {
            Write-Log -Message "Could not load icon: $_" -Level WARNING -Component "GUI"
        }
    }
    
    # Add main tab control
    $tabControl = New-TabControl
    $form.Controls.Add($tabControl)
    
    # Add status strip
    $statusStrip = New-StatusStrip
    $form.Controls.Add($statusStrip)
    
    # Add form closing event
    $form.Add_FormClosing({
        param($sender, $e)
        Save-AppSettings
        Write-Log -Message "Application closing" -Level INFO -Component "GUI"
    })
    
    # Add form resize end event to save window size
    $form.Add_ResizeEnd({
        Set-AppSetting -Name "MainFormWidth" -Value $form.Size.Width
        Set-AppSetting -Name "MainFormHeight" -Value $form.Size.Height
    })
    
    return $form
}

function Show-MainWindow {
    param(
        [string]$PowerShellPath = "$PSHOME\powershell.exe"
    )
    
    try {
        Write-Log -Message "Initializing main window" -Level INFO -Component "GUI"
        $form = Initialize-MainWindow -PowerShellPath $PowerShellPath
        
        if ($null -eq $form) {
            throw "Failed to initialize main window"
        }
        
        Write-Log -Message "Showing main window" -Level INFO -Component "GUI"
        [void]$form.ShowDialog()
    }
    catch {
        Write-Log -Message "Error showing main window: $_" -Level ERROR -Component "GUI"
        throw
    }
}

# Helper function to update the status strip
function Update-Status {
    param([string]$Message)
    
    if ($null -ne $script:MainForm) {
        $statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
        if ($null -ne $statusLabel) {
            $statusLabel.Text = $Message
        }
    }
}

# Helper function to enable/disable tabs based on analysis state
function Update-TabStates {
    param([bool]$AnalysisCompleted)
    
    if ($null -ne $script:MainForm) {
        $tabControl = $script:MainForm.Controls["MainTabControl"]
        if ($null -ne $tabControl) {
            $tabControl.TabPages["SearchTab"].Enabled = $AnalysisCompleted
            $tabControl.TabPages["ExtractTab"].Enabled = $AnalysisCompleted
        }
    }
}
