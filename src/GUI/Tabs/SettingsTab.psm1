# DiagLog Analyzer - Settings Tab
# This module implements a simple Settings tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the Settings Tab
function New-SettingsTab {
    Write-DLALog -Message "Creating Settings tab" -Level INFO -Component "SettingsTab"
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Settings"
    $tab.Name = "SettingsTab"
    
    # Create settings group
    $grpGeneral = New-Object System.Windows.Forms.GroupBox
    $grpGeneral.Text = "General Settings"
    $grpGeneral.Location = New-Object System.Drawing.Point(10, 15)
    $grpGeneral.Size = New-Object System.Drawing.Size(400, 150)
    
    # Log level setting
    $lblLogLevel = New-Object System.Windows.Forms.Label
    $lblLogLevel.Text = "Log Level:"
    $lblLogLevel.Location = New-Object System.Drawing.Point(10, 25)
    $lblLogLevel.AutoSize = $true
    
    $cboLogLevel = New-Object System.Windows.Forms.ComboBox
    $cboLogLevel.Location = New-Object System.Drawing.Point(150, 22)
    $cboLogLevel.Width = 150
    $cboLogLevel.DropDownStyle = "DropDownList"
    
    # Add log levels
    $cboLogLevel.Items.AddRange(@("DEBUG", "INFO", "WARNING", "ERROR"))
    
    # Set default value
    try {
        $logLevel = Get-AppSetting -Name "LogLevelName" -DefaultValue "INFO"
        $index = $cboLogLevel.Items.IndexOf($logLevel)
        if ($index -ge 0) {
            $cboLogLevel.SelectedIndex = $index
        }
        else {
            $cboLogLevel.SelectedIndex = 1 # INFO
        }
    }
    catch {
        $cboLogLevel.SelectedIndex = 1 # INFO
    }
    
    # Results font size setting
    $lblFontSize = New-Object System.Windows.Forms.Label
    $lblFontSize.Text = "Results Font Size:"
    $lblFontSize.Location = New-Object System.Drawing.Point(10, 55)
    $lblFontSize.AutoSize = $true
    
    $numFontSize = New-Object System.Windows.Forms.NumericUpDown
    $numFontSize.Location = New-Object System.Drawing.Point(150, 53)
    $numFontSize.Width = 60
    $numFontSize.Minimum = 8
    $numFontSize.Maximum = 16
    
    # Set default value
    try {
        $fontSize = Get-AppSetting -Name "ResultsFontSize" -DefaultValue 9
        $numFontSize.Value = $fontSize
    }
    catch {
        $numFontSize.Value = 9
    }
    
    # Max file size setting
    $lblMaxFileSize = New-Object System.Windows.Forms.Label
    $lblMaxFileSize.Text = "Max Search File Size (MB):"
    $lblMaxFileSize.Location = New-Object System.Drawing.Point(10, 85)
    $lblMaxFileSize.AutoSize = $true
    
    $numMaxFileSize = New-Object System.Windows.Forms.NumericUpDown
    $numMaxFileSize.Location = New-Object System.Drawing.Point(150, 83)
    $numMaxFileSize.Width = 80
    $numMaxFileSize.Minimum = 1
    $numMaxFileSize.Maximum = 500
    $numMaxFileSize.Increment = 5
    
    # Set default value
    try {
        $maxFileSize = Get-AppSetting -Name "MaxFileSizeForTextSearch" -DefaultValue 50MB
        $numMaxFileSize.Value = [math]::Round($maxFileSize / 1MB)
    }
    catch {
        $numMaxFileSize.Value = 50
    }
    
    # Add controls to general group
    $grpGeneral.Controls.AddRange(@($lblLogLevel, $cboLogLevel, $lblFontSize, $numFontSize, $lblMaxFileSize, $numMaxFileSize))
    
    # Create CAB extraction group
    $grpCab = New-Object System.Windows.Forms.GroupBox
    $grpCab.Text = "CAB Extraction Settings"
    $grpCab.Location = New-Object System.Drawing.Point(10, 175)
    $grpCab.Size = New-Object System.Drawing.Size(400, 100)
    
    # Auto extract setting
    $chkAutoExtract = New-Object System.Windows.Forms.CheckBox
    $chkAutoExtract.Text = "Extract CABs Automatically"
    $chkAutoExtract.Location = New-Object System.Drawing.Point(10, 25)
    $chkAutoExtract.AutoSize = $true
    
    # Set default value
    try {
        $autoExtract = Get-AppSetting -Name "ExtractCabsAutomatically" -DefaultValue $false
        $chkAutoExtract.Checked = $autoExtract
    }
    catch {
        $chkAutoExtract.Checked = $false
    }
    
    # Skip existing setting
    $chkSkipExisting = New-Object System.Windows.Forms.CheckBox
    $chkSkipExisting.Text = "Skip Existing CAB Extracts"
    $chkSkipExisting.Location = New-Object System.Drawing.Point(10, 55)
    $chkSkipExisting.AutoSize = $true
    
    # Set default value
    try {
        $skipExisting = Get-AppSetting -Name "SkipExistingCabExtracts" -DefaultValue $true
        $chkSkipExisting.Checked = $skipExisting
    }
    catch {
        $chkSkipExisting.Checked = $true
    }
    
    # Add controls to CAB group
    $grpCab.Controls.AddRange(@($chkAutoExtract, $chkSkipExisting))
    
    # Save button
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save Settings"
    $btnSave.Location = New-Object System.Drawing.Point(10, 285)
    $btnSave.Width = 120
    $btnSave.Add_Click({
        try {
            # Save log level
            Set-AppSetting -Name "LogLevelName" -Value $cboLogLevel.SelectedItem.ToString()
            
            # Save font size
            Set-AppSetting -Name "ResultsFontSize" -Value $numFontSize.Value
            
            # Save max file size
            Set-AppSetting -Name "MaxFileSizeForTextSearch" -Value ($numMaxFileSize.Value * 1MB)
            
            # Save CAB settings
            Set-AppSetting -Name "ExtractCabsAutomatically" -Value $chkAutoExtract.Checked
            Set-AppSetting -Name "SkipExistingCabExtracts" -Value $chkSkipExisting.Checked
            
            # Save all settings
            Save-AppSettings
            
            [System.Windows.Forms.MessageBox]::Show("Settings saved successfully", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information)
                
            Write-DLALog -Message "Settings saved successfully" -Level INFO -Component "SettingsTab"
        }
        catch {
            Write-DLALog -Message "Error saving settings: $_" -Level ERROR -Component "SettingsTab"
            [System.Windows.Forms.MessageBox]::Show("Error saving settings: $_", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    
    # Reset button
    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Text = "Reset to Defaults"
    $btnReset.Location = New-Object System.Drawing.Point(140, 285)
    $btnReset.Width = 120
    $btnReset.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to reset all settings to default values?", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::YesNo, 
            [System.Windows.Forms.MessageBoxIcon]::Question)
            
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                # Reset settings
                Reset-Settings
                
                # Update UI
                $cboLogLevel.SelectedIndex = 1 # INFO
                $numFontSize.Value = 9
                $numMaxFileSize.Value = 50
                $chkAutoExtract.Checked = $false
                $chkSkipExisting.Checked = $true
                
                [System.Windows.Forms.MessageBox]::Show("Settings reset to defaults", "DiagLog Analyzer", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Information)
                    
                Write-DLALog -Message "Settings reset to defaults" -Level INFO -Component "SettingsTab"
            }
            catch {
                Write-DLALog -Message "Error resetting settings: $_" -Level ERROR -Component "SettingsTab"
                [System.Windows.Forms.MessageBox]::Show("Error resetting settings: $_", "DiagLog Analyzer", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })
    
    # Add controls to the tab
    $tab.Controls.AddRange(@($grpGeneral, $grpCab, $btnSave, $btnReset))
    
    return $tab
}

# Export functions
Export-ModuleMember -Function New-SettingsTab