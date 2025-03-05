# DiagLog Analyzer - CAB Extraction Tab
# This module implements a simple CAB extraction tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the CAB Extraction Tab
function New-CabExtractionTab {
    Write-DLALog -Message "Creating CAB Extraction tab" -Level INFO -Component "CabExtractionTab"
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "CAB Extraction"
    $tab.Name = "CabExtractionTab"
    $tab.Enabled = $false  # Initially disabled until analysis is complete
    
    # Output folder controls
    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Text = "Output Folder:"
    $lblOutput.Location = New-Object System.Drawing.Point(10, 15)
    $lblOutput.AutoSize = $true
    
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(120, 12)
    $txtOutput.Width = 400
    $txtOutput.Name = "OutputPath"
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Browse..."
    $btnBrowse.Location = New-Object System.Drawing.Point(530, 10)
    $btnBrowse.Width = 80
    $btnBrowse.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select output folder for CAB extraction"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtOutput.Text = $folderBrowser.SelectedPath
        }
    })
    
    # Options for extraction
    $chkSkipExisting = New-Object System.Windows.Forms.CheckBox
    $chkSkipExisting.Text = "Skip Existing Extracts"
    $chkSkipExisting.Location = New-Object System.Drawing.Point(10, 45)
    $chkSkipExisting.Checked = $true
    $chkSkipExisting.AutoSize = $true
    
    # Extract button
    $btnExtract = New-Object System.Windows.Forms.Button
    $btnExtract.Text = "Extract CAB Files"
    $btnExtract.Location = New-Object System.Drawing.Point(10, 75)
    $btnExtract.Width = 150
    $btnExtract.Add_Click({
        # Get the form and analysis results
        $form = [System.Windows.Forms.Form]::ActiveForm
        $analysisResults = $null
        
        if ($form -and ($form | Get-Member -Name "AnalysisResults")) {
            $analysisResults = $form.AnalysisResults
        }
        
        # Check if we have analysis results
        if ($null -eq $analysisResults -or -not $analysisResults.CabFiles -or $analysisResults.CabFiles.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No CAB files found in analysis results!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Get output path
        $outputPath = $txtOutput.Text
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            # Use default path next to source folder
            $outputPath = Join-Path -Path (Split-Path -Parent $analysisResults.SourcePath) -ChildPath "extracted_cabs"
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path -Path $outputPath)) {
            try {
                New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to create output directory: $_", "DiagLog Analyzer", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
        }
        
        # Update UI
        Write-DLALog -Message "Extracting CAB files to $outputPath" -Level INFO -Component "CabExtractionTab"
        $btnExtract.Enabled = $false
        $lstResults.Items.Clear()
        $lstResults.Items.Add("Starting CAB extraction...")
        
        try {
            # Create parameter hashtable
            $params = @{
                AnalysisResults = $analysisResults
                SkipExisting = $chkSkipExisting.Checked
            }
            
            # Call existing Expand-AnalysisCabFiles function
            $extractionResults = Expand-AnalysisCabFiles @params
            
            # Display results
            $lstResults.Items.Add("CAB extraction completed")
            $lstResults.Items.Add("-----------------------------------")
            $lstResults.Items.Add("Total CABs: $($extractionResults.TotalCabs)")
            $lstResults.Items.Add("Extracted: $($extractionResults.ExtractedCount)")
            $lstResults.Items.Add("Skipped: $($extractionResults.SkippedCount)")
            $lstResults.Items.Add("Failed: $($extractionResults.FailedCount)")
            $lstResults.Items.Add("-----------------------------------")
            
            # Add individual results
            foreach ($result in $extractionResults.Results) {
                $status = if ($result.Success) { "Success" } else { "Failed" }
                $lstResults.Items.Add("$status - $($result.CabPath)")
            }
            
            Write-DLALog -Message "CAB extraction completed" -Level INFO -Component "CabExtractionTab"
        }
        catch {
            Write-DLALog -Message "Error during CAB extraction: $_" -Level ERROR -Component "CabExtractionTab"
            $lstResults.Items.Add("Error during CAB extraction: $_")
        }
        finally {
            $btnExtract.Enabled = $true
        }
    })
    
    # Results list box
    $lstResults = New-Object System.Windows.Forms.ListBox
    $lstResults.Location = New-Object System.Drawing.Point(10, 110)
    $lstResults.Size = New-Object System.Drawing.Size(860, 515)
    $lstResults.Name = "ResultsList"
    $lstResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    
    # Add controls to the tab
    $tab.Controls.AddRange(@($lblOutput, $txtOutput, $btnBrowse, $chkSkipExisting, $btnExtract, $lstResults))
    
    return $tab
}

# Export functions
Export-ModuleMember -Function New-CabExtractionTab