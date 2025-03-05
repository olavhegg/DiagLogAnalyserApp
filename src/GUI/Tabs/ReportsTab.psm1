# DiagLog Analyzer - Reports Tab
# This module implements a simple Reports tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the Reports Tab
function New-ReportsTab {
    Write-DLALog -Message "Creating Reports tab" -Level INFO -Component "ReportsTab"
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Reports"
    $tab.Name = "ReportsTab"
    $tab.Enabled = $false  # Initially disabled until analysis is complete
    
    # Report type selection
    $lblReportType = New-Object System.Windows.Forms.Label
    $lblReportType.Text = "Report Type:"
    $lblReportType.Location = New-Object System.Drawing.Point(10, 15)
    $lblReportType.AutoSize = $true
    
    $cboReportType = New-Object System.Windows.Forms.ComboBox
    $cboReportType.Location = New-Object System.Drawing.Point(120, 12)
    $cboReportType.Width = 300
    $cboReportType.DropDownStyle = "DropDownList"
    
    # Add report types
    $cboReportType.Items.AddRange(@("Analysis Summary", "File Extensions", "CAB Files", "Search Results"))
    $cboReportType.SelectedIndex = 0
    
    # Output folder selection
    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Text = "Output Folder:"
    $lblOutput.Location = New-Object System.Drawing.Point(10, 45)
    $lblOutput.AutoSize = $true
    
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(120, 42)
    $txtOutput.Width = 400
    $txtOutput.Name = "OutputPath"
    
    # Try to set default output path
    try {
        $outputPath = Get-AppSetting -Name "DefaultOutputPath" -DefaultValue "results"
        $txtOutput.Text = $outputPath
    }
    catch {
        $txtOutput.Text = "results"
    }
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Browse..."
    $btnBrowse.Location = New-Object System.Drawing.Point(530, 40)
    $btnBrowse.Width = 80
    $btnBrowse.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select output folder for reports"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtOutput.Text = $folderBrowser.SelectedPath
        }
    })
    
    # Format selection
    $lblFormat = New-Object System.Windows.Forms.Label
    $lblFormat.Text = "Report Format:"
    $lblFormat.Location = New-Object System.Drawing.Point(10, 75)
    $lblFormat.AutoSize = $true
    
    $cboFormat = New-Object System.Windows.Forms.ComboBox
    $cboFormat.Location = New-Object System.Drawing.Point(120, 72)
    $cboFormat.Width = 150
    $cboFormat.DropDownStyle = "DropDownList"
    
    # Add format types
    $cboFormat.Items.AddRange(@("HTML", "Text", "CSV"))
    $cboFormat.SelectedIndex = 0
    
    # Generate button
    $btnGenerate = New-Object System.Windows.Forms.Button
    $btnGenerate.Text = "Generate Report"
    $btnGenerate.Location = New-Object System.Drawing.Point(10, 110)
    $btnGenerate.Width = 150
    $btnGenerate.Add_Click({
        # Get the form and analysis results
        $form = [System.Windows.Forms.Form]::ActiveForm
        $analysisResults = $null
        
        if ($form -and ($form | Get-Member -Name "AnalysisResults")) {
            $analysisResults = $form.AnalysisResults
        }
        
        # Check if we have analysis results
        if ($null -eq $analysisResults) {
            [System.Windows.Forms.MessageBox]::Show("Please analyze a folder first!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Get output path
        $outputPath = $txtOutput.Text
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $outputPath = "results"
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
        
        # Get report options
        $reportType = $cboReportType.SelectedItem.ToString()
        $format = $cboFormat.SelectedItem.ToString()
        
        # Generate timestamp for filename
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $reportFileName = "report-$timestamp"
        
        # Add file extension based on format
        $fileExtension = switch ($format) {
            "HTML" { ".html" }
            "Text" { ".txt" }
            "CSV" { ".csv" }
            default { ".html" }
        }
        
        $reportPath = Join-Path -Path $outputPath -ChildPath "$reportFileName$fileExtension"
        
        # Update UI
        Write-DLALog -Message "Generating $reportType report in $format format" -Level INFO -Component "ReportsTab"
        $btnGenerate.Enabled = $false
        $txtResults.Text = "Generating report, please wait..."
        
        try {
            # Generate report based on type
            switch ($reportType) {
                "Analysis Summary" {
                    if ($format -eq "HTML") {
                        # Try to call existing report function
                        try {
                            $reportPath = New-AnalysisReport -AnalysisResults $analysisResults -OutputPath $reportPath
                        }
                        catch {
                            # Basic fallback if function not available
                            Write-DLALog -Message "Error calling New-AnalysisReport: $_" -Level WARNING -Component "ReportsTab"
                            
                            # Create simple HTML report
                            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        .summary { background-color: #f8f9fa; padding: 15px; margin-bottom: 20px; border-left: 4px solid #0066cc; }
    </style>
</head>
<body>
    <h1>DiagLog Analysis Report</h1>
    <div class="summary">
        <h2>Analysis Summary</h2>
        <p><strong>Source Path:</strong> $($analysisResults.SourcePath)</p>
        <p><strong>Analysis Time:</strong> $($analysisResults.AnalysisTime)</p>
        <p><strong>Total Items:</strong> $($analysisResults.TotalItems)</p>
        <p><strong>Files:</strong> $($analysisResults.Files)</p>
        <p><strong>Directories:</strong> $($analysisResults.Directories)</p>
    </div>
</body>
</html>
"@
                            $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
                        }
                    }
                    else {
                        # Text format (simple)
                        $reportContent = Get-AnalysisSummary -AnalysisResults $analysisResults
                        $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
                    }
                }
                
                "File Extensions" {
                    if ($format -eq "HTML") {
                        # Simple HTML report
                        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog File Extensions Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        table { width: 100%; border-collapse: collapse; }
        th { background-color: #0066cc; color: white; text-align: left; padding: 8px; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>File Extensions Report</h1>
    <table>
        <tr>
            <th>Extension</th>
            <th>Count</th>
            <th>Total Size</th>
        </tr>
"@
                        # Add extensions
                        foreach ($ext in $analysisResults.Extensions.GetEnumerator() | Sort-Object -Property {$_.Value.Count} -Descending) {
                            $extension = $ext.Key
                            $stats = $ext.Value
                            $totalSizeMB = [math]::Round($stats.TotalSize / 1MB, 2)
                            
                            $htmlContent += @"
        <tr>
            <td>$extension</td>
            <td>$($stats.Count)</td>
            <td>$totalSizeMB MB</td>
        </tr>
"@
                        }
                        
                        $htmlContent += @"
    </table>
</body>
</html>
"@
                        $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
                    }
                    elseif ($format -eq "CSV") {
                        # CSV format
                        $csvData = foreach ($ext in $analysisResults.Extensions.GetEnumerator()) {
                            [PSCustomObject]@{
                                Extension = $ext.Key
                                Count = $ext.Value.Count
                                TotalSizeMB = [math]::Round($ext.Value.TotalSize / 1MB, 2)
                            }
                        }
                        $csvData | Export-Csv -Path $reportPath -NoTypeInformation
                    }
                    else {
                        # Text format
                        $txtContent = "File Extensions Report`r`n"
                        $txtContent += "=====================`r`n`r`n"
                        
                        foreach ($ext in $analysisResults.Extensions.GetEnumerator() | Sort-Object -Property {$_.Value.Count} -Descending) {
                            $extension = $ext.Key
                            $stats = $ext.Value
                            $totalSizeMB = [math]::Round($stats.TotalSize / 1MB, 2)
                            
                            $txtContent += "$extension : $($stats.Count) files, $totalSizeMB MB`r`n"
                        }
                        
                        $txtContent | Out-File -FilePath $reportPath -Encoding UTF8
                    }
                }
                
                # Additional report types would go here
                default {
                    $txtContent = "Report type '$reportType' not implemented yet"
                    $txtContent | Out-File -FilePath $reportPath -Encoding UTF8
                }
            }
            
            # Update results
            $txtResults.Text = "Report generated successfully!`r`n`r`nReport saved to: $reportPath"
            
            Write-DLALog -Message "Report generated successfully at $reportPath" -Level INFO -Component "ReportsTab"
        }
        catch {
            Write-DLALog -Message "Error generating report: $_" -Level ERROR -Component "ReportsTab"
            $txtResults.Text = "Error generating report: $_"
        }
        finally {
            $btnGenerate.Enabled = $true
        }
    })
    
    # View button
    $btnView = New-Object System.Windows.Forms.Button
    $btnView.Text = "View Last Report"
    $btnView.Location = New-Object System.Drawing.Point(170, 110)
    $btnView.Width = 150
    $btnView.Add_Click({
        # Get output path
        $outputPath = $txtOutput.Text
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $outputPath = "results"
        }
        
        # Check if directory exists
        if (-not (Test-Path -Path $outputPath)) {
            [System.Windows.Forms.MessageBox]::Show("Output directory does not exist!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Get most recent report file
        $format = $cboFormat.SelectedItem.ToString()
        $extension = switch ($format) {
            "HTML" { "*.html" }
            "Text" { "*.txt" }
            "CSV" { "*.csv" }
            default { "*.*" }
        }
        
        $latestReport = Get-ChildItem -Path $outputPath -Filter $extension | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
            
        if ($null -eq $latestReport) {
            [System.Windows.Forms.MessageBox]::Show("No reports found in output directory", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Open the report
        try {
            Start-Process $latestReport.FullName
            Write-DLALog -Message "Opened report: $($latestReport.FullName)" -Level INFO -Component "ReportsTab"
        }
        catch {
            Write-DLALog -Message "Error opening report: $_" -Level ERROR -Component "ReportsTab"
            [System.Windows.Forms.MessageBox]::Show("Error opening report: $_", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    
    # Results text box
    $txtResults = New-Object System.Windows.Forms.TextBox
    $txtResults.Location = New-Object System.Drawing.Point(10, 150)
    $txtResults.Size = New-Object System.Drawing.Size(860, 475)
    $txtResults.Multiline = $true
    $txtResults.ScrollBars = "Both"
    $txtResults.ReadOnly = $true
    $txtResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtResults.Name = "ResultsText"
    
    # Add controls to the tab
    $tab.Controls.AddRange(@(
        $lblReportType, $cboReportType,
        $lblOutput, $txtOutput, $btnBrowse,
        $lblFormat, $cboFormat,
        $btnGenerate, $btnView,
        $txtResults
    ))
    
    return $tab
}

# Export functions
Export-ModuleMember -Function New-ReportsTab