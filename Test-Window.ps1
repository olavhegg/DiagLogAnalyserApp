
# Main Window Module

. (Join-Path -Path $PSScriptRoot -ChildPath "Controls.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "EventHandlers.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "TabControls.ps1")

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
    $form.Add_FormClosing({ Save-AppSettings })
    
    return $form
}

function Show-MainWindow {
    param(
        [string]$PowerShellPath = "$PSHOME\powershell.exe"
    )
    
    $form = Initialize-MainWindow -PowerShellPath $PowerShellPath
    [void]$form.ShowDialog()
}