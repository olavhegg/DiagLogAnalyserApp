# DiagLog Analyzer - Analysis Tab
# This module implements the Analysis tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Script-level variables to maintain references
$script:txtResults = $null
$script:txtSource = $null
$script:btnSaveResults = $null
$script:sourcePath = $null 
$script:includeSubfolders = $true
$script:extractCab = $true
$script:extractToOriginal = $true
$script:deleteCab = $false
$script:skipExtracted = $true
$script:lastAnalysisResults = $null

# Create the Analysis Tab
function New-AnalysisTab {
    Write-DLALog -Message "Creating Analysis tab" -Level INFO -Component "AnalysisTab"
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Analysis"
    $tab.Name = "AnalysisTab"
    
    # Source folder controls
    $lblSource = New-Object System.Windows.Forms.Label
    $lblSource.Text = "Diagnostic Source:"
    $lblSource.Location = New-Object System.Drawing.Point(10, 15)
    $lblSource.AutoSize = $true
    $lblSource.Width = 110
    
    $txtSource = New-Object System.Windows.Forms.TextBox
    $txtSource.Location = New-Object System.Drawing.Point(120, 12)
    $txtSource.Width = 400
    $txtSource.Name = "SourcePath"
    # Store reference
    $script:txtSource = $txtSource
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Browse..."
    $btnBrowse.Location = New-Object System.Drawing.Point(530, 10)
    $btnBrowse.Width = 80
    $btnBrowse.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select Diagnostic folder or ZIP file to analyze"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $script:txtSource.Text = $folderBrowser.SelectedPath
            $script:sourcePath = $folderBrowser.SelectedPath
        }
    })
    
    # Analysis Options GroupBox
    $gbOptions = New-Object System.Windows.Forms.GroupBox
    $gbOptions.Text = "Analysis Options"
    $gbOptions.Location = New-Object System.Drawing.Point(10, 45)
    $gbOptions.Size = New-Object System.Drawing.Size(600, 95)
    
    # Include subfolders checkbox
    $chkSubfolders = New-Object System.Windows.Forms.CheckBox
    $chkSubfolders.Text = "Include Subfolders"
    $chkSubfolders.Location = New-Object System.Drawing.Point(15, 25)
    $chkSubfolders.Checked = $true
    $chkSubfolders.AutoSize = $true
    $chkSubfolders.Name = "IncludeSubfolders"
    $chkSubfolders.Add_CheckedChanged({
        $script:includeSubfolders = $chkSubfolders.Checked
    })
    
    # Extract CAB files checkbox
    $chkExtractCab = New-Object System.Windows.Forms.CheckBox
    $chkExtractCab.Text = "Extract CAB Files"
    $chkExtractCab.Location = New-Object System.Drawing.Point(15, 50)
    $chkExtractCab.Checked = $true
    $chkExtractCab.AutoSize = $true
    $chkExtractCab.Name = "ExtractCabFiles"
    $chkExtractCab.Add_CheckedChanged({
        $script:extractCab = $chkExtractCab.Checked
        $chkExtractOriginal.Enabled = $chkExtractCab.Checked
        $chkDeleteCab.Enabled = $chkExtractCab.Checked
        $chkSkipExtracted.Enabled = $chkExtractCab.Checked
    })
    
    # Extract to original location checkbox
    $chkExtractOriginal = New-Object System.Windows.Forms.CheckBox
    $chkExtractOriginal.Text = "Extract to Original Location"
    $chkExtractOriginal.Location = New-Object System.Drawing.Point(200, 25)
    $chkExtractOriginal.Checked = $true
    $chkExtractOriginal.AutoSize = $true
    $chkExtractOriginal.Name = "ExtractToOriginalLocation"
    $chkExtractOriginal.Add_CheckedChanged({
        $script:extractToOriginal = $chkExtractOriginal.Checked
    })
    
    # Delete CAB after extraction checkbox
    $chkDeleteCab = New-Object System.Windows.Forms.CheckBox
    $chkDeleteCab.Text = "Delete CAB Files After Extraction"
    $chkDeleteCab.Location = New-Object System.Drawing.Point(200, 50)
    $chkDeleteCab.Checked = $false
    $chkDeleteCab.AutoSize = $true
    $chkDeleteCab.Name = "DeleteCabAfterExtraction"
    $chkDeleteCab.Add_CheckedChanged({
        $script:deleteCab = $chkDeleteCab.Checked
    })
    
    # Skip already extracted CABs checkbox
    $chkSkipExtracted = New-Object System.Windows.Forms.CheckBox
    $chkSkipExtracted.Text = "Skip Already Extracted CABs"
    $chkSkipExtracted.Location = New-Object System.Drawing.Point(400, 25)
    $chkSkipExtracted.Checked = $true
    $chkSkipExtracted.AutoSize = $true
    $chkSkipExtracted.Name = "SkipAlreadyExtracted"
    $chkSkipExtracted.Add_CheckedChanged({
        $script:skipExtracted = $chkSkipExtracted.Checked
    })
    
    # Add controls to the options group box
    $gbOptions.Controls.AddRange(@($chkSubfolders, $chkExtractCab, $chkExtractOriginal, $chkDeleteCab, $chkSkipExtracted))
    
    # Results text box - create this BEFORE the button
    $txtResults = New-Object System.Windows.Forms.TextBox
    $txtResults.Location = New-Object System.Drawing.Point(10, 185)
    $txtResults.Size = New-Object System.Drawing.Size(860, 410)
    $txtResults.Multiline = $true
    $txtResults.ScrollBars = "Both"
    $txtResults.ReadOnly = $true
    $txtResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtResults.Name = "ResultsText"
    # Store reference at script level
    $script:txtResults = $txtResults
    
    # Start analysis button
    $btnAnalyze = New-Object System.Windows.Forms.Button
    $btnAnalyze.Text = "Start Analysis"
    $btnAnalyze.Location = New-Object System.Drawing.Point(10, 150)
    $btnAnalyze.Width = 120
    $btnAnalyze.Add_Click({ Start-Analysis })
    
    # Save results button
    $btnSaveResults = New-Object System.Windows.Forms.Button
    $btnSaveResults.Text = "Save Results"
    $btnSaveResults.Location = New-Object System.Drawing.Point(140, 150)
    $btnSaveResults.Width = 120
    $btnSaveResults.Enabled = $false
    $btnSaveResults.Add_Click({ Save-AnalysisResults })
    
    # Store reference at script level
    $script:btnSaveResults = $btnSaveResults
    
    # Add controls to the tab
    $tab.Controls.AddRange(@($lblSource, $txtSource, $btnBrowse, $gbOptions, $btnAnalyze, $btnSaveResults, $txtResults))
    
    return $tab
}

# Separate function to handle analysis (helps with scope issues)
function Start-Analysis {
    # Use script level variables
    $sourcePath = $script:txtSource.Text
    $resultBox = $script:txtResults
    
    # Check for null references
    if ($null -eq $resultBox) {
        Write-DLALog -Message "ResultBox is null in Start-Analysis" -Level ERROR -Component "AnalysisTab"
        [System.Windows.Forms.MessageBox]::Show("Internal error: Missing reference to results control", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a diagnostic source folder or ZIP file!", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Verify folder exists
    if (-not (Test-Path -Path $sourcePath -PathType Container)) {
        # Check if it's a ZIP file
        if ((Test-Path -Path $sourcePath -PathType Leaf) -and $sourcePath.EndsWith(".zip")) {
            # Ask user if they want to extract the ZIP
            $extractZip = [System.Windows.Forms.MessageBox]::Show(
                "The selected file is a ZIP archive. Would you like to extract it before analysis?", 
                "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Question)
                
            if ($extractZip -eq 'Yes') {
                # Extract ZIP file
                $extractPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($sourcePath), 
                                                         [System.IO.Path]::GetFileNameWithoutExtension($sourcePath))
                
                try {
                    # Create extraction directory if it doesn't exist
                    if (-not (Test-Path -Path $extractPath -PathType Container)) {
                        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
                    }
                    
                    $resultBox.Text = "Extracting ZIP file to $extractPath, please wait..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    # Extract ZIP using .NET
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($sourcePath, $extractPath)
                    
                    # Update source path to extracted folder
                    $sourcePath = $extractPath
                    $script:txtSource.Text = $extractPath
                    $script:sourcePath = $extractPath
                    
                    $resultBox.Text = "ZIP file extracted successfully. Proceeding with analysis..."
                    [System.Windows.Forms.Application]::DoEvents()
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to extract ZIP file: $_", "DiagLog Analyzer", 
                        [System.Windows.Forms.MessageBoxButtons]::OK, 
                        [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
            }
            else {
                return
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("The selected folder does not exist!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    }
    
    # Update UI
    Write-DLALog -Message "Starting analysis of $sourcePath" -Level INFO -Component "AnalysisTab"
    $resultBox.Text = "Analysis in progress, please wait..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        # Extract CAB files if option is selected
        if ($script:extractCab) {
            $resultBox.Text = "Extracting CAB files, please wait..."
            [System.Windows.Forms.Application]::DoEvents()
            
            $extractParams = @{
                FolderPath = $sourcePath
                IncludeSubFolders = $script:includeSubfolders
                ExtractToOriginalLocation = $script:extractToOriginal
                DeleteAfterExtraction = $script:deleteCab
                SkipAlreadyExtracted = $script:skipExtracted
            }
            
            Write-DLALog -Message "Starting CAB extraction with params: $($extractParams | ConvertTo-Json -Compress)" -Level INFO -Component "AnalysisTab"
            
            # Check if the function exists
            if (Get-Command -Name Start-CabExtraction -ErrorAction SilentlyContinue) {
                $extractionResults = Start-CabExtraction @extractParams
                
                # Update results
                $resultBox.Text += "`r`n`r`nCAB Extraction Results:`r`n"
                $resultBox.Text += "- Total CAB files found: $($extractionResults.TotalCabFiles)`r`n"
                $resultBox.Text += "- Successfully extracted: $($extractionResults.SuccessfulExtractions)`r`n"
                
                if ($script:skipExtracted -and $extractionResults.SkippedCabFiles -gt 0) {
                    $resultBox.Text += "- Skipped already extracted: $($extractionResults.SkippedCabFiles)`r`n"
                }
                
                $resultBox.Text += "- Failed extractions: $($extractionResults.FailedExtractions)`r`n"
                
                if ($extractionResults.Errors.Count -gt 0) {
                    $resultBox.Text += "`r`nErrors during extraction:`r`n"
                    foreach ($error in $extractionResults.Errors) {
                        $resultBox.Text += "- $error`r`n"
                    }
                }
                
                $resultBox.Text += "`r`nProceeding with folder analysis...`r`n"
                [System.Windows.Forms.Application]::DoEvents()
            }
            else {
                Write-DLALog -Message "Start-CabExtraction function not found - skipping CAB extraction" -Level WARNING -Component "AnalysisTab"
                $resultBox.Text += "`r`nCAB extraction function not found. Skipping this step.`r`n`r`nProceeding with folder analysis...`r`n"
                [System.Windows.Forms.Application]::DoEvents()
            }
        }
        
        # Call existing Start-FolderAnalysis function
        if (Get-Command -Name Start-FolderAnalysis -ErrorAction SilentlyContinue) {
            # Convert boolean value to switch parameter
            if ($script:includeSubfolders) {
                $analysisResults = Start-FolderAnalysis -FolderPath $sourcePath -IncludeSubFolders
            } else {
                $analysisResults = Start-FolderAnalysis -FolderPath $sourcePath
            }
            
            # Store last analysis results for saving
            $script:lastAnalysisResults = $analysisResults
            
            # Enable save results button
            if ($null -ne $script:btnSaveResults) {
                $script:btnSaveResults.Enabled = $true
            }
            
            # Display results
            if (Get-Command -Name Get-AnalysisSummary -ErrorAction SilentlyContinue) {
                $summary = Get-AnalysisSummary -AnalysisResults $analysisResults
                $resultBox.Text = $summary
            }
            else {
                # Basic summary
                $resultBox.Text = "Analysis Results for: $sourcePath`r`n`r`n"
                $resultBox.Text += "Total Files: $($analysisResults.TotalFiles)`r`n"
                $resultBox.Text += "Subfolder Count: $($analysisResults.SubfolderCount)`r`n`r`n"
                $resultBox.Text += "File Type Summary:`r`n"
                
                foreach ($type in $analysisResults.FileTypes.Keys | Sort-Object) {
                    $count = $analysisResults.FileTypes[$type]
                    $resultBox.Text += "  - $type : $count`r`n"
                }
            }
            
            # Store results in the form for other tabs to access
            $form = [System.Windows.Forms.Form]::ActiveForm
            if ($form) {
                $form | Add-Member -NotePropertyName "AnalysisResults" -NotePropertyValue $analysisResults -Force
                
                # If the form has a method to handle completion, call it
                if ($form | Get-Member -Name "OnAnalysisComplete" -MemberType ScriptMethod) {
                    $form.OnAnalysisComplete($analysisResults)
                }
                else {
                    # Manually try to enable the search tab
                    $tabControl = $form.Controls["MainTabControl"]
                    if ($tabControl) {
                        $searchTab = $tabControl.TabPages["SearchTab"]
                        if ($searchTab) {
                            $searchTab.Enabled = $true
                            Write-DLALog -Message "Enabled Search tab" -Level INFO -Component "AnalysisTab"
                        }
                    }
                }
            }
            
            Write-DLALog -Message "Analysis completed successfully" -Level INFO -Component "AnalysisTab"
        }
        else {
            Write-DLALog -Message "Start-FolderAnalysis function not found" -Level ERROR -Component "AnalysisTab"
            $resultBox.Text = "ERROR: Required function 'Start-FolderAnalysis' not found. Please check your installation."
        }
    }
    catch {
        Write-DLALog -Message "Error during analysis: $_" -Level ERROR -Component "AnalysisTab"
        $resultBox.Text = "Error during analysis: $_"
    }
}

# Function to save analysis results
function Save-AnalysisResults {
    # Check if we have analysis results
    if ($null -eq $script:lastAnalysisResults) {
        [System.Windows.Forms.MessageBox]::Show("No analysis results available to save.", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    try {
        # Show save dialog
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "Text files (*.txt)|*.txt|HTML files (*.html)|*.html|CSV files (*.csv)|*.csv|All files (*.*)|*.*"
        $saveDialog.Title = "Save Analysis Results"
        $saveDialog.DefaultExt = "txt"
        
        # Generate default filename based on folder name and date
        $folderName = Split-Path -Path $script:lastAnalysisResults.FolderPath -Leaf
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $saveDialog.FileName = "DiagLog-Analysis-$folderName-$timestamp.txt"
        
        if ($saveDialog.ShowDialog() -eq 'OK') {
            $outputPath = $saveDialog.FileName
            $extension = [System.IO.Path]::GetExtension($outputPath).ToLower()
            
            # Handle different output formats
            switch ($extension) {
                ".html" {
                    # Generate HTML report
                    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog Analyzer Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #3498db; margin-top: 20px; }
        .summary { background-color: #f5f5f5; padding: 10px; border-radius: 5px; }
        .filetypes { margin-top: 15px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>DiagLog Analyzer Report</h1>
    <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    
    <div class="summary">
        <h2>Analysis Summary</h2>
        <p><strong>Folder:</strong> $($script:lastAnalysisResults.FolderPath)</p>
        <p><strong>Analysis Start Time:</strong> $($script:lastAnalysisResults.StartTime)</p>
        <p><strong>Analysis End Time:</strong> $($script:lastAnalysisResults.EndTime)</p>
        <p><strong>Total Files:</strong> $($script:lastAnalysisResults.TotalFiles)</p>
        <p><strong>Subfolder Count:</strong> $($script:lastAnalysisResults.SubfolderCount)</p>
    </div>
    
    <h2>File Types</h2>
    <div class="filetypes">
        <table>
            <tr>
                <th>Extension</th>
                <th>Count</th>
            </tr>
$(
    $fileTypeRows = ""
    foreach ($type in $script:lastAnalysisResults.FileTypes.Keys | Sort-Object) {
        $count = $script:lastAnalysisResults.FileTypes[$type]
        $fileTypeRows += "            <tr><td>$type</td><td>$count</td></tr>`n"
    }
    $fileTypeRows
)
        </table>
    </div>
    
    <h2>Large Files (>10MB)</h2>
    <div class="largefiles">
        <table>
            <tr>
                <th>File Path</th>
                <th>Size (MB)</th>
            </tr>
$(
    $largeFileRows = ""
    foreach ($file in $script:lastAnalysisResults.LargeFiles | Sort-Object -Property Size -Descending) {
        $largeFileRows += "            <tr><td>$($file.Path)</td><td>$($file.SizeInMB)</td></tr>`n"
    }
    if ([string]::IsNullOrEmpty($largeFileRows)) {
        $largeFileRows = "            <tr><td colspan='2'>No large files found</td></tr>`n"
    }
    $largeFileRows
)
        </table>
    </div>
</body>
</html>
"@
                    $htmlContent | Out-File -FilePath $outputPath -Encoding utf8
                }
                ".csv" {
                    # Generate CSV export of results
                    $summaryPath = [System.IO.Path]::ChangeExtension($outputPath, "summary.csv")
                    $summary = [PSCustomObject]@{
                        FolderPath = $script:lastAnalysisResults.FolderPath
                        AnalysisDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalFiles = $script:lastAnalysisResults.TotalFiles
                        SubfolderCount = $script:lastAnalysisResults.SubfolderCount
                        AnalysisDuration = ($script:lastAnalysisResults.EndTime - $script:lastAnalysisResults.StartTime).TotalSeconds
                    }
                    $summary | Export-Csv -Path $summaryPath -NoTypeInformation
                    
                    # Now export file types
                    $typesList = @()
                    foreach ($type in $script:lastAnalysisResults.FileTypes.Keys) {
                        $typesList += [PSCustomObject]@{
                            Extension = $type
                            Count = $script:lastAnalysisResults.FileTypes[$type]
                        }
                    }
                    $typesList | Export-Csv -Path $outputPath -NoTypeInformation
                    
                    # Also export large files if any
                    if ($script:lastAnalysisResults.LargeFiles.Count -gt 0) {
                        $largeFilesPath = [System.IO.Path]::ChangeExtension($outputPath, "largefiles.csv")
                        $script:lastAnalysisResults.LargeFiles | Export-Csv -Path $largeFilesPath -NoTypeInformation
                    }
                }
                default {
                    # Default to text output
                    $textContent = $script:txtResults.Text
                    $textContent | Out-File -FilePath $outputPath -Encoding utf8
                }
            }
            
            [System.Windows.Forms.MessageBox]::Show("Analysis results saved to:`n$outputPath", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        Write-DLALog -Message "Error saving analysis results: $_" -Level ERROR -Component "AnalysisTab"
        [System.Windows.Forms.MessageBox]::Show("Error saving analysis results: $_", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Export functions
Export-ModuleMember -Function New-AnalysisTab, Start-Analysis, Save-AnalysisResults