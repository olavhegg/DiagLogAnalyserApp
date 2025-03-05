# Helper functions for GUI operations

function Set-ResultsFont {
    param([System.Windows.Forms.Control]$Control)
    try {
        $fontFamily = Get-AppSetting -Name "ResultsFontFamily" -DefaultValue "Consolas"
        $fontSize = Get-AppSetting -Name "ResultsFontSize" -DefaultValue 9
        $Control.Font = New-Object System.Drawing.Font($fontFamily, $fontSize)
    }
    catch {
        $Control.Font = New-Object System.Drawing.Font("Consolas", 9)
    }
}

function Show-Error {
    param([string]$Message, [string]$Title = "Error")
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error)
}

function Update-Status {
    param([string]$Message)
    $statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
    if ($statusLabel) {
        $statusLabel.Text = $Message
    }
}

# ... Add more helper functions
