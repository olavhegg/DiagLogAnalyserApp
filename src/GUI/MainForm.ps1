# DiagLog Analyzer - Main Form
# This file contains the main application window and UI logic

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

# Import modules
. (Join-Path -Path $PSScriptRoot -ChildPath "Controls.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\FileSystem.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\Analyzer.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\CabExtractor.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\FileSearch.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\Reporting.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Config\Settings.ps1")

# Global variables
$script:AnalysisResults = $null
$script:MainForm = $null

function Show-MainForm {
    param(
        [string]$PowerShellPath = "$PSHOME\powershell.exe"
    )
    
    # Create the main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DiagLog Analyzer"
    $form.Size = New-Object System.Drawing.Size ((Get-AppSetting -Name "MainFormWidth"), (Get-AppSetting -Name "MainFormHeight"))
    $form.StartPosition = "CenterScreen"
    
    # Try to set the icon if the path exists
    if ($PowerShellPath -and (Test-Path $PowerShellPath)) {
        try {
            $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PowerShellPath)
        } catch {
            Write-Log -Message "Could not load icon from $PowerShellPath : $_" -Level WARNING -Component "GUI"
            # Continue without an icon
        }
    }
    
    
    # Store reference to the form
    $script:MainForm = $form
    
    # Create tab control for main sections
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Fill"
    $tabControl.Name = "MainTabControl"
    
    # Create tabs
    $tabAnalysis = New-Object System.Windows.Forms.TabPage
    $tabAnalysis.Text = "Analysis"
    $tabAnalysis.Name = "AnalysisTab"
    
    $tabSearch = New-Object System.Windows.Forms.TabPage
    $tabSearch.Text = "Search"
    $tabSearch.Name = "SearchTab"
    $tabSearch.Enabled = $false # Disabled until analysis is complete
    
    $tabExtract = New-Object System.Windows.Forms.TabPage
    $tabExtract.Text = "CAB Extraction"
    $tabExtract.Name = "ExtractTab"
    $tabExtract.Enabled = $false # Disabled until analysis is complete
    
    $tabSettings = New-Object System.Windows.Forms.TabPage
    $tabSettings.Text = "Settings"
    $tabSettings.Name = "SettingsTab"
    
    $tabAbout = New-Object System.Windows.Forms.TabPage
    $tabAbout.Text = "About"
    $tabAbout.Name = "AboutTab"
    
    # Add tabs to tab control
    $tabControl.TabPages.Add($tabAnalysis)
    $tabControl.TabPages.Add($tabSearch)
    $tabControl.TabPages.Add($tabExtract)
    $tabControl.TabPages.Add($tabSettings)
    $tabControl.TabPages.Add($tabAbout)
    
    # Add tab control to form
    $form.Controls.Add($tabControl)
    
    # Create status strip for messages
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "Ready"
    $statusLabel.Name = "StatusLabel"
    $statusStrip.Items.Add($statusLabel)
    $form.Controls.Add($statusStrip)
    
    # Setup tab contents
    Setup-AnalysisTab -TabPage $tabAnalysis
    Setup-SearchTab -TabPage $tabSearch
    Setup-ExtractTab -TabPage $tabExtract
    Setup-SettingsTab -TabPage $tabSettings
    Setup-AboutTab -TabPage $tabAbout
    
    # Set form close event
    $form.Add_FormClosing({
        # Save settings before closing
        Save-AppSettings
    })
    
    # Show the form
    [void]$form.ShowDialog()
}

function Setup-AnalysisTab {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TabPage]$TabPage
    )
    
    # Create container panel
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    # Create folder selection controls
    $lblSource = New-Object System.Windows.Forms.Label
    $lblSource.Location = New-Object System.Drawing.Point(10, 20)
    $lblSource.Size = New-Object System.Drawing.Size(150, 20)
    $lblSource.Text = "DiagLogs Folder:"
    $panel.Controls.Add($lblSource)
    
    $txtSource = New-Object System.Windows.Forms.TextBox
    $txtSource.Location = New-Object System.Drawing.Point(10, 40)
    $txtSource.Size = New-Object System.Drawing.Size(500, 20)
    $txtSource.Name = "SourcePath"
    $panel.Controls.Add($txtSource)
    
    $btnSource = New-Object System.Windows.Forms.Button
    $btnSource.Location = New-Object System.Drawing.Point(520, 40)
    $btnSource.Size = New-Object System.Drawing.Size(80, 20)
    $btnSource.Text = "Browse..."
    $btnSource.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select DiagLogs folder"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            # Use $this to find the control in the parent panel
            $txtBox = $this.Parent.Controls["SourcePath"]
            $txtBox.Text = $folderBrowser.SelectedPath
        }
    })
    $panel.Controls.Add($btnSource)
    
    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Location = New-Object System.Drawing.Point(10, 70)
    $lblOutput.Size = New-Object System.Drawing.Size(150, 20)
    $lblOutput.Text = "Output Folder:"
    $panel.Controls.Add($lblOutput)
    
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(10, 90)
    $txtOutput.Size = New-Object System.Drawing.Size(500, 20)
    $txtOutput.Text = (Get-AppSetting -Name "DefaultOutputPath")
    $txtOutput.Name = "OutputPath"
    $panel.Controls.Add($txtOutput)
    
    $btnOutput = New-Object System.Windows.Forms.Button
    $btnOutput.Location = New-Object System.Drawing.Point(520, 90)
    $btnOutput.Size = New-Object System.Drawing.Size(80, 20)
    $btnOutput.Text = "Browse..."
    $btnOutput.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select output folder"
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtOutput.Text = $folderBrowser.SelectedPath
        }
    })
    $panel.Controls.Add($btnOutput)
    
    # Create analysis options
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Location = New-Object System.Drawing.Point(10, 130)
    $grpOptions.Size = New-Object System.Drawing.Size(590, 80)
    $grpOptions.Text = "Analysis Options"
    $panel.Controls.Add($grpOptions)
    
    $chkSubfolders = New-Object System.Windows.Forms.CheckBox
    $chkSubfolders.Location = New-Object System.Drawing.Point(20, 20)
    $chkSubfolders.Size = New-Object System.Drawing.Size(200, 20)
    $chkSubfolders.Text = "Include Subfolders"
    $chkSubfolders.Checked = $true
    $grpOptions.Controls.Add($chkSubfolders)
    
    $chkExtractCabs = New-Object System.Windows.Forms.CheckBox
    $chkExtractCabs.Location = New-Object System.Drawing.Point(20, 50)
    $chkExtractCabs.Size = New-Object System.Drawing.Size(200, 20)
    $chkExtractCabs.Text = "Extract CAB Files Automatically"
    $chkExtractCabs.Checked = (Get-AppSetting -Name "ExtractCabsAutomatically")
    $grpOptions.Controls.Add($chkExtractCabs)
    
    $chkSkipExisting = New-Object System.Windows.Forms.CheckBox
    $chkSkipExisting.Location = New-Object System.Drawing.Point(230, 50)
    $chkSkipExisting.Size = New-Object System.Drawing.Size(200, 20)
    $chkSkipExisting.Text = "Skip Existing CAB Extracts"
    $chkSkipExisting.Checked = (Get-AppSetting -Name "SkipExistingCabExtracts")
    $grpOptions.Controls.Add($chkSkipExisting)
    
    # Create action buttons
    $btnAnalyze = New-Object System.Windows.Forms.Button
    $btnAnalyze.Location = New-Object System.Drawing.Point(10, 230)
    $btnAnalyze.Size = New-Object System.Drawing.Size(120, 30)
    $btnAnalyze.Text = "Analyze Structure"
    $btnAnalyze.Add_Click({
        # Validate inputs
        if (-not (Test-Path $txtSource.Text)) {
            [System.Windows.MessageBox]::Show("Please select a valid DiagLogs folder!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        if (-not (Test-Path $txtOutput.Text)) {
            try {
                New-Item -Path $txtOutput.Text -ItemType Directory -Force | Out-Null
            }
            catch {
                [System.Windows.MessageBox]::Show("Unable to create output folder: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                return
            }
        }
        
        # Update status
        $statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
        $statusLabel.Text = "Analyzing folder structure..."
        $rtbResults.Clear()
        $rtbResults.AppendText("Starting analysis of $($txtSource.Text)...$([Environment]::NewLine)")
        
        # Disable buttons during analysis
        $btnAnalyze.Enabled = $false
        $btnReport.Enabled = $false
        
        # Update settings
        Set-AppSetting -Name "ExtractCabsAutomatically" -Value $chkExtractCabs.Checked
        Set-AppSetting -Name "SkipExistingCabExtracts" -Value $chkSkipExisting.Checked
        
        # Run analysis in background
        $analysisParams = @{
            FolderPath = $txtSource.Text
            IncludeSubFolders = $chkSubfolders.Checked
        }
        
        # Start background job
        Start-ThreadJob -ScriptBlock {
            param($params)
            . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Core\Analyzer.ps1")
            . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
            Start-FolderAnalysis @params
        } -ArgumentList $analysisParams -StreamingHost $Host | Out-Null
        
        # Timer to check job progress
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            $job = Get-Job -State Running | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
            
            if ($null -eq $job) {
                # Job completed, get results
                $job = Get-Job -State Completed | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
                
                if ($null -ne $job) {
                    $script:AnalysisResults = Receive-Job -Job $job
                    $job | Remove-Job
                    
                    # Update UI with results
                    $rtbResults.AppendText("Analysis completed.$([Environment]::NewLine)$([Environment]::NewLine)")
                    $rtbResults.AppendText((Get-AnalysisSummary -AnalysisResults $script:AnalysisResults))
                    
                    # Enable search and extract tabs
                    $tabControl = $script:MainForm.Controls["MainTabControl"]
                    $tabControl.TabPages["SearchTab"].Enabled = $true
                    $tabControl.TabPages["ExtractTab"].Enabled = ($script:AnalysisResults.CabFiles.Count -gt 0)
                    
                    # Update extract tab with CAB files
                    if ($script:AnalysisResults.CabFiles.Count -gt 0) {
                        $lstCabFiles = $tabControl.TabPages["ExtractTab"].Controls["CabFilesList"]
                        $lstCabFiles.Items.Clear()
                        
                        foreach ($cab in $script:AnalysisResults.CabFiles) {
                            $lstCabFiles.Items.Add($cab.RelativePath)
                        }
                        
                        # Auto-extract if enabled
                        if ($chkExtractCabs.Checked) {
                            # Switch to extract tab
                            $tabControl.SelectedTab = $tabControl.TabPages["ExtractTab"]
                            
                            # Click the extract button
                            $btnExtractAll = $tabControl.TabPages["ExtractTab"].Controls["ExtractAllButton"]
                            $btnExtractAll.PerformClick()
                        }
                    }
                    
                    # Update search tab with file types
                    $clbFileTypes = $tabControl.TabPages["SearchTab"].Controls["FileTypesList"]
                    $clbFileTypes.Items.Clear()
                    
                    foreach ($ext in $script:AnalysisResults.Extensions.Keys) {
                        $clbFileTypes.Items.Add($ext, $true)
                    }
                    
                    # Enable buttons
                    $btnAnalyze.Enabled = $true
                    $btnReport.Enabled = $true
                    
                    # Update status
                    $statusLabel.Text = "Analysis complete. Found $($script:AnalysisResults.Files) files, $($script:AnalysisResults.Directories) directories."
                }
                else {
                    # No completed job found
                    $rtbResults.AppendText("Analysis failed.$([Environment]::NewLine)")
                    $btnAnalyze.Enabled = $true
                    $btnReport.Enabled = $true
                    $statusLabel.Text = "Analysis failed."
                }
                
                $timer.Stop()
                $timer.Dispose()
            }
        })
        $timer.Start()
    })
    $panel.Controls.Add($btnAnalyze)
    
    $btnReport = New-Object System.Windows.Forms.Button
    $btnReport.Location = New-Object System.Drawing.Point(140, 230)
    $btnReport.Size = New-Object System.Drawing.Size(120, 30)
    $btnReport.Text = "Generate Report"
    $btnReport.Enabled = $false
    $btnReport.Add_Click({
        if ($null -eq $script:AnalysisResults) {
            [System.Windows.MessageBox]::Show("Please analyze a folder first!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        $statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
        $statusLabel.Text = "Generating report..."
        
        # Generate report
        $reportPath = New-AnalysisReport -AnalysisResults $script:AnalysisResults -OutputPath (Join-Path -Path $txtOutput.Text -ChildPath "AnalysisReport.html")
        
        # Open report
        Start-Process $reportPath
        
        $statusLabel.Text = "Report generated and opened."
    })
    $panel.Controls.Add($btnReport)
    
    # Create results area
    $rtbResults = New-Object System.Windows.Forms.RichTextBox
    $rtbResults.Location = New-Object System.Drawing.Point(10, 270)
    $rtbResults.Size = New-Object System.Drawing.Size(570, 200)
    $rtbResults.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $rtbResults.ReadOnly = $true

    try {
        $fontFamily = Get-AppSetting -Name "ResultsFontFamily"
        $fontSize = Get-AppSetting -Name "ResultsFontSize"
        
        # Verify font family is valid
        if ([string]::IsNullOrEmpty($fontFamily)) {
            $fontFamily = "Consolas" # Default fallback
        }
        
        # Check if the font family actually exists on the system
        $fontExists = $false
        foreach ($family in [System.Drawing.FontFamily]::Families) {
            if ($family.Name -eq $fontFamily) {
                $fontExists = $true
                break
            }
        }
        
        # If the configured font doesn't exist, use a system font that should be available
        if (-not $fontExists) {
            $fontFamily = "Arial" # Widely available system font
        }
        
        # Ensure font size is valid
        if ($null -eq $fontSize -or -not ($fontSize -is [int]) -or $fontSize -lt 8 -or $fontSize -gt 72) {
            $fontSize = 9 # Default fallback size
        }
        
        # Now create the font with validated values
        $rtbResults.Font = New-Object System.Drawing.Font($fontFamily, $fontSize)
    }
    catch {
        # If anything goes wrong, use a basic system font
        Write-Host "Error setting custom font: $_" -ForegroundColor Yellow
        $rtbResults.Font = New-Object System.Drawing.Font("Arial", 9)
    }

    $rtbResults.BackColor = [System.Drawing.Color]::White
    $rtbResults.MultiLine = $true
    $rtbResults.ScrollBars = "Both"
    $rtbResults.WordWrap = $false
    $rtbResults.Name = "ResultsTextBox"
    $panel.Controls.Add($rtbResults)
    
    # Add panel to tab page
    $TabPage.Controls.Add($panel)
}

function Setup-SearchTab {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TabPage]$TabPage
    )
    
    # Create container panel
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    # Create search controls
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Location = New-Object System.Drawing.Point(10, 20)
    $lblSearch.Size = New-Object System.Drawing.Size(150, 20)
    $lblSearch.Text = "Search Text:"
    $panel.Controls.Add($lblSearch)
    
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(10, 40)
    $txtSearch.Size = New-Object System.Drawing.Size(400, 20)
    $txtSearch.Name = "SearchText"
    $panel.Controls.Add($txtSearch)
    
    $chkCaseSensitive = New-Object System.Windows.Forms.CheckBox
    $chkCaseSensitive.Location = New-Object System.Drawing.Point(420, 40)
    $chkCaseSensitive.Size = New-Object System.Drawing.Size(150, 20)
    $chkCaseSensitive.Text = "Case Sensitive"
    $panel.Controls.Add($chkCaseSensitive)
    
    # Create file type selection
    $lblFileTypes = New-Object System.Windows.Forms.Label
    $lblFileTypes.Location = New-Object System.Drawing.Point(10, 70)
    $lblFileTypes.Size = New-Object System.Drawing.Size(150, 20)
    $lblFileTypes.Text = "File Types to Search:"
    $panel.Controls.Add($lblFileTypes)
    
    $clbFileTypes = New-Object System.Windows.Forms.CheckedListBox
    $clbFileTypes.Location = New-Object System.Drawing.Point(10, 90)
    $clbFileTypes.Size = New-Object System.Drawing.Size(200, 120)
    $clbFileTypes.CheckOnClick = $true
    $clbFileTypes.Name = "FileTypesList"
    $panel.Controls.Add($clbFileTypes)
    
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Location = New-Object System.Drawing.Point(10, 220)
    $btnSelectAll.Size = New-Object System.Drawing.Size(95, 25)
    $btnSelectAll.Text = "Select All"
    $btnSelectAll.Add_Click({
        for ($i = 0; $i -lt $clbFileTypes.Items.Count; $i++) {
            $clbFileTypes.SetItemChecked($i, $true)
        }
    })
    $panel.Controls.Add($btnSelectAll)
    
    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Location = New-Object System.Drawing.Point(115, 220)
    $btnSelectNone.Size = New-Object System.Drawing.Size(95, 25)
    $btnSelectNone.Text = "Select None"
    $btnSelectNone.Add_Click({
        for ($i = 0; $i -lt $clbFileTypes.Items.Count; $i++) {
            $clbFileTypes.SetItemChecked($i, $false)
        }
    })
    $panel.Controls.Add($btnSelectNone)
    
    # Create search options
    $grpOptions = New-Object System.Windows.Forms.GroupBox
    $grpOptions.Location = New-Object System.Drawing.Point(230, 90)
    $grpOptions.Size = New-Object System.Drawing.Size(350, 120)
    $grpOptions.Text = "Search Options"
    $panel.Controls.Add($grpOptions)
    
    $lblContextBefore = New-Object System.Windows.Forms.Label
    $lblContextBefore.Location = New-Object System.Drawing.Point(10, 20)
    $lblContextBefore.Size = New-Object System.Drawing.Size(150, 20)
    $lblContextBefore.Text = "Context Lines Before:"
    $grpOptions.Controls.Add($lblContextBefore)
    
    $numContextBefore = New-Object System.Windows.Forms.NumericUpDown
    $numContextBefore.Location = New-Object System.Drawing.Point(160, 20)
    $numContextBefore.Size = New-Object System.Drawing.Size(60, 20)
    $numContextBefore.Minimum = 0
    $numContextBefore.Maximum = 10
    $numContextBefore.Value = 2
    $grpOptions.Controls.Add($numContextBefore)
    
    $lblContextAfter = New-Object System.Windows.Forms.Label
    $lblContextAfter.Location = New-Object System.Drawing.Point(10, 50)
    $lblContextAfter.Size = New-Object System.Drawing.Size(150, 20)
    $lblContextAfter.Text = "Context Lines After:"
    $grpOptions.Controls.Add($lblContextAfter)
    
    $numContextAfter = New-Object System.Windows.Forms.NumericUpDown
    $numContextAfter.Location = New-Object System.Drawing.Point(160, 50)
    $numContextAfter.Size = New-Object System.Drawing.Size(60, 20)
    $numContextAfter.Minimum = 0
    $numContextAfter.Maximum = 10
    $numContextAfter.Value = 2
    $grpOptions.Controls.Add($numContextAfter)
    
    $chkIncludeCabs = New-Object System.Windows.Forms.CheckBox
    $chkIncludeCabs.Location = New-Object System.Drawing.Point(10, 80)
    $chkIncludeCabs.Size = New-Object System.Drawing.Size(250, 20)
    $chkIncludeCabs.Text = "Include Extracted CAB Files in Search"
    $chkIncludeCabs.Checked = $true
    $grpOptions.Controls.Add($chkIncludeCabs)
    
    # Create search button
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Location = New-Object System.Drawing.Point(230, 220)
    $btnSearch.Size = New-Object System.Drawing.Size(120, 30)
    $btnSearch.Text = "Search"
    $btnSearch.Add_Click({
        if ($null -eq $script:AnalysisResults) {
            [System.Windows.MessageBox]::Show("Please analyze a folder first!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($txtSearch.Text)) {
            [System.Windows.MessageBox]::Show("Please enter text to search for!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
# Get selected file types
$selectedTypes = @()
for ($i = 0; $i -lt $clbFileTypes.Items.Count; $i++) {
    if ($clbFileTypes.GetItemChecked($i)) {
        $selectedTypes += $clbFileTypes.Items[$i]
    }
}

if ($selectedTypes.Count -eq 0) {
    [System.Windows.MessageBox]::Show("Please select at least one file type to search in!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    return
}

# Update status
$statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
$statusLabel.Text = "Searching..."
$rtbResults.Clear()
$rtbResults.AppendText("Searching for '$($txtSearch.Text)' in selected file types...$([Environment]::NewLine)")

# Disable buttons during search
$btnSearch.Enabled = $false
$btnSearchReport.Enabled = $false

# Search parameters
$searchParams = @{
    AnalysisResults = $script:AnalysisResults
    SearchText = $txtSearch.Text
    ExtensionsToInclude = $selectedTypes
    ContextLinesBefore = [int]$numContextBefore.Value
    ContextLinesAfter = [int]$numContextAfter.Value
    CaseSensitive = $chkCaseSensitive.Checked
    IncludeExtractedCabs = $chkIncludeCabs.Checked
}

# Start background job
Start-ThreadJob -ScriptBlock {
    param($params)
    # Load required modules
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Core\FileSearch.ps1")
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
    
    # Execute search
    $searchResults = Search-AnalysisResults @params
    return $searchResults
} -ArgumentList $searchParams -StreamingHost $Host | Out-Null

# Timer to check job progress
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $job = Get-Job -State Running | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
    
    if ($null -eq $job) {
        # Job completed, get results
        $job = Get-Job -State Completed | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
        
        if ($null -ne $job) {
            $searchResults = Receive-Job -Job $job
            $job | Remove-Job
            
            # Store results globally for report generation
            $script:SearchResults = $searchResults
            
            # Update UI with results
            $rtbResults.AppendText("Search complete: Found $($searchResults.TotalMatches) matches in $($searchResults.FilesWithMatches) files.$([Environment]::NewLine)$([Environment]::NewLine)")
            
            $matchingResults = $searchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 } | Sort-Object -Property MatchCount -Descending
            
            foreach ($fileResult in $matchingResults) {
                $rtbResults.AppendText("File: $($fileResult.FilePath) ($($fileResult.MatchCount) matches)$([Environment]::NewLine)")
                
                foreach ($match in $fileResult.Matches) {
                    $rtbResults.AppendText("  Line $($match.MatchLineNumber): $($match.MatchLine.Trim())$([Environment]::NewLine)")
                }
                
                $rtbResults.AppendText("$([Environment]::NewLine)")
            }
            
            if ($matchingResults.Count -eq 0) {
                $rtbResults.AppendText("No matches found for the search term.$([Environment]::NewLine)")
            }
            
            # Enable buttons
            $btnSearch.Enabled = $true
            $btnSearchReport.Enabled = $true
            
            # Update status
            $statusLabel.Text = "Search complete. Found $($searchResults.TotalMatches) matches in $($searchResults.FilesWithMatches) files."
        }
        else {
            # No completed job found
            $rtbResults.AppendText("Search failed.$([Environment]::NewLine)")
            $btnSearch.Enabled = $true
            $btnSearchReport.Enabled = $false
            $statusLabel.Text = "Search failed."
        }
        
        $timer.Stop()
        $timer.Dispose()
    }
})
$timer.Start()
})
$panel.Controls.Add($btnSearch)

$btnSearchReport = New-Object System.Windows.Forms.Button
$btnSearchReport.Location = New-Object System.Drawing.Point(360, 220)
$btnSearchReport.Size = New-Object System.Drawing.Size(120, 30)
$btnSearchReport.Text = "Generate Report"
$btnSearchReport.Enabled = $false
$btnSearchReport.Add_Click({
if ($null -eq $script:SearchResults) {
    [System.Windows.MessageBox]::Show("Please perform a search first!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    return
}

$statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
$statusLabel.Text = "Generating search report..."

# Get output path from analysis tab
$txtOutput = $script:MainForm.Controls["MainTabControl"].TabPages["AnalysisTab"].Controls["OutputPath"]

# Generate report
$reportPath = New-SearchReport -SearchResults $script:SearchResults -OutputPath (Join-Path -Path $txtOutput.Text -ChildPath "SearchReport.html")

# Open report
Start-Process $reportPath

$statusLabel.Text = "Search report generated and opened."
})
$panel.Controls.Add($btnSearchReport)

# Create results area
$rtbResults = New-Object System.Windows.Forms.RichTextBox
$rtbResults.Location = New-Object System.Drawing.Point(10, 260)
$rtbResults.Size = New-Object System.Drawing.Size(570, 210)
$rtbResults.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$rtbResults.ReadOnly = $true

try {
    $fontFamily = Get-AppSetting -Name "ResultsFontFamily"
    $fontSize = Get-AppSetting -Name "ResultsFontSize"
    
    # Verify font family is valid
    if ([string]::IsNullOrEmpty($fontFamily)) {
        $fontFamily = "Consolas" # Default fallback
    }
    
    # Check if the font family actually exists on the system
    $fontExists = $false
    foreach ($family in [System.Drawing.FontFamily]::Families) {
        if ($family.Name -eq $fontFamily) {
            $fontExists = $true
            break
        }
    }
    
    # If the configured font doesn't exist, use a system font that should be available
    if (-not $fontExists) {
        $fontFamily = "Arial" # Widely available system font
    }
    
    # Ensure font size is valid
    if ($null -eq $fontSize -or -not ($fontSize -is [int]) -or $fontSize -lt 8 -or $fontSize -gt 72) {
        $fontSize = 9 # Default fallback size
    }
    
    # Now create the font with validated values
    $rtbResults.Font = New-Object System.Drawing.Font($fontFamily, $fontSize)
}
catch {
    # If anything goes wrong, use a basic system font
    Write-Host "Error setting custom font: $_" -ForegroundColor Yellow
    $rtbResults.Font = New-Object System.Drawing.Font("Arial", 9)
}
$rtbResults.BackColor = [System.Drawing.Color]::White
$rtbResults.MultiLine = $true
$rtbResults.ScrollBars = "Both"
$rtbResults.WordWrap = $false
$rtbResults.Name = "SearchResultsTextBox"
$panel.Controls.Add($rtbResults)

# Add panel to tab page
$TabPage.Controls.Add($panel)
}

function Setup-ExtractTab {
param(
[Parameter(Mandatory=$true)]
[System.Windows.Forms.TabPage]$TabPage
)

# Create container panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)

# Create CAB files list
$lblCabFiles = New-Object System.Windows.Forms.Label
$lblCabFiles.Location = New-Object System.Drawing.Point(10, 20)
$lblCabFiles.Size = New-Object System.Drawing.Size(150, 20)
$lblCabFiles.Text = "CAB Files:"
$panel.Controls.Add($lblCabFiles)

$lstCabFiles = New-Object System.Windows.Forms.ListBox
$lstCabFiles.Location = New-Object System.Drawing.Point(10, 40)
$lstCabFiles.Size = New-Object System.Drawing.Size(450, 150)
$lstCabFiles.SelectionMode = "MultiExtended"
$lstCabFiles.Name = "CabFilesList"
$panel.Controls.Add($lstCabFiles)

# Create extraction options
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Location = New-Object System.Drawing.Point(10, 200)
$grpOptions.Size = New-Object System.Drawing.Size(450, 60)
$grpOptions.Text = "Extraction Options"
$panel.Controls.Add($grpOptions)

$chkSkipExisting = New-Object System.Windows.Forms.CheckBox
$chkSkipExisting.Location = New-Object System.Drawing.Point(10, 20)
$chkSkipExisting.Size = New-Object System.Drawing.Size(200, 20)
$chkSkipExisting.Text = "Skip Existing Extractions"
$chkSkipExisting.Checked = (Get-AppSetting -Name "SkipExistingCabExtracts")
$grpOptions.Controls.Add($chkSkipExisting)

# Create extraction buttons
$btnExtractSelected = New-Object System.Windows.Forms.Button
$btnExtractSelected.Location = New-Object System.Drawing.Point(10, 270)
$btnExtractSelected.Size = New-Object System.Drawing.Size(150, 30)
$btnExtractSelected.Text = "Extract Selected"
$btnExtractSelected.Add_Click({
if ($lstCabFiles.SelectedItems.Count -eq 0) {
    [System.Windows.MessageBox]::Show("Please select at least one CAB file to extract!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    return
}

# Get output path from analysis tab
$txtOutput = $script:MainForm.Controls["MainTabControl"].TabPages["AnalysisTab"].Controls["OutputPath"]

# Update status
$statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
$statusLabel.Text = "Extracting CAB files..."
$rtbResults.Clear()
$rtbResults.AppendText("Extracting $($lstCabFiles.SelectedItems.Count) selected CAB files...$([Environment]::NewLine)")

# Disable buttons during extraction
$btnExtractSelected.Enabled = $false
$btnExtractAll.Enabled = $false

# Get selected CAB files
$selectedCabs = @()
foreach ($item in $lstCabFiles.SelectedItems) {
    $cab = $script:AnalysisResults.CabFiles | Where-Object { $_.RelativePath -eq $item } | Select-Object -First 1
    if ($null -ne $cab) {
        $selectedCabs += $cab
    }
}

# Extraction parameters
$extractParams = @{
    AnalysisResults = @{
        CabFiles = $selectedCabs
    }
    SkipExisting = $chkSkipExisting.Checked
}

# Start background job
Start-ThreadJob -ScriptBlock {
    param($params)
    # Load required modules
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Core\CabExtractor.ps1")
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
    
    # Execute extraction
    $extractionResults = Expand-AnalysisCabFiles @params
    return $extractionResults
} -ArgumentList $extractParams -StreamingHost $Host | Out-Null

# Timer to check job progress
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $job = Get-Job -State Running | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
    
    if ($null -eq $job) {
        # Job completed, get results
        $job = Get-Job -State Completed | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
        
        if ($null -ne $job) {
            $extractionResults = Receive-Job -Job $job
            $job | Remove-Job
            
            # Update UI with results
            $rtbResults.AppendText("Extraction complete.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.ExtractedCount) files extracted.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.SkippedCount) files skipped.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.FailedCount) files failed.$([Environment]::NewLine)$([Environment]::NewLine)")
            
            foreach ($result in $extractionResults.Results) {
                $rtbResults.AppendText("$($result.CabPath): $($result.Message)$([Environment]::NewLine)")
            }
            
            # Update CAB files in analysis results
            foreach ($cab in $selectedCabs) {
                $resultForCab = $extractionResults.Results | Where-Object { $_.CabPath -eq $cab.Path } | Select-Object -First 1
                if ($null -ne $resultForCab) {
                    $cab.Processed = $true
                    $cab.ExtractedPath = $resultForCab.ExtractedPath
                    $cab.ExtractionSuccess = $resultForCab.Success
                    $cab.ExtractionMessage = $resultForCab.Message
                }
            }
            
            # Enable buttons
            $btnExtractSelected.Enabled = $true
            $btnExtractAll.Enabled = $true
            
            # Update status
            $statusLabel.Text = "Extraction complete. $($extractionResults.ExtractedCount) extracted, $($extractionResults.SkippedCount) skipped, $($extractionResults.FailedCount) failed."
        }
        else {
            # No completed job found
            $rtbResults.AppendText("Extraction failed.$([Environment]::NewLine)")
            $btnExtractSelected.Enabled = $true
            $btnExtractAll.Enabled = $true
            $statusLabel.Text = "Extraction failed."
        }
        
        $timer.Stop()
        $timer.Dispose()
    }
})
$timer.Start()
})
$panel.Controls.Add($btnExtractSelected)

$btnExtractAll = New-Object System.Windows.Forms.Button
$btnExtractAll.Location = New-Object System.Drawing.Point(170, 270)
$btnExtractAll.Size = New-Object System.Drawing.Size(150, 30)
$btnExtractAll.Text = "Extract All"
$btnExtractAll.Name = "ExtractAllButton"
$btnExtractAll.Add_Click({
if ($script:AnalysisResults.CabFiles.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No CAB files found to extract!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    return
}

# Update status
$statusLabel = $script:MainForm.Controls["StatusStrip"].Items["StatusLabel"]
$statusLabel.Text = "Extracting all CAB files..."
$rtbResults.Clear()
$rtbResults.AppendText("Extracting all $($script:AnalysisResults.CabFiles.Count) CAB files...$([Environment]::NewLine)")

# Disable buttons during extraction
$btnExtractSelected.Enabled = $false
$btnExtractAll.Enabled = $false

# Extraction parameters
$extractParams = @{
    AnalysisResults = $script:AnalysisResults
    SkipExisting = $chkSkipExisting.Checked
}

# Start background job
Start-ThreadJob -ScriptBlock {
    param($params)
    # Load required modules
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Core\CabExtractor.ps1")
    . (Join-Path -Path $using:PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
    
    # Execute extraction
    $extractionResults = Expand-AnalysisCabFiles @params
    return $extractionResults
} -ArgumentList $extractParams -StreamingHost $Host | Out-Null

# Timer to check job progress
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $job = Get-Job -State Running | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
    
    if ($null -eq $job) {
        # Job completed, get results
        $job = Get-Job -State Completed | Where-Object { $_.Name -like "ThreadJob*" } | Select-Object -First 1
        
        if ($null -ne $job) {
            $extractionResults = Receive-Job -Job $job
            $job | Remove-Job
            
            # Update UI with results
            $rtbResults.AppendText("Extraction complete.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.ExtractedCount) files extracted.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.SkippedCount) files skipped.$([Environment]::NewLine)")
            $rtbResults.AppendText("$($extractionResults.FailedCount) files failed.$([Environment]::NewLine)$([Environment]::NewLine)")
            
            foreach ($result in $extractionResults.Results) {
                $rtbResults.AppendText("$($result.CabPath): $($result.Message)$([Environment]::NewLine)")
            }
            
            # Enable buttons
            $btnExtractSelected.Enabled = $true
            $btnExtractAll.Enabled = $true
            
            # Update status
            $statusLabel.Text = "Extraction complete. $($extractionResults.ExtractedCount) extracted, $($extractionResults.SkippedCount) skipped, $($extractionResults.FailedCount) failed."
        }
        else {
            # No completed job found
            $rtbResults.AppendText("Extraction failed.$([Environment]::NewLine)")
            $btnExtractSelected.Enabled = $true
            $btnExtractAll.Enabled = $true
            $statusLabel.Text = "Extraction failed."
        }
        
        $timer.Stop()
        $timer.Dispose()
    }
})
$timer.Start()
})
$panel.Controls.Add($btnExtractAll)

# Create results area
$rtbResults = New-Object System.Windows.Forms.RichTextBox
$rtbResults.Location = New-Object System.Drawing.Point(10, 310)
$rtbResults.Size = New-Object System.Drawing.Size(570, 160)
$rtbResults.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$rtbResults.ReadOnly = $true

try {
    $fontFamily = Get-AppSetting -Name "ResultsFontFamily"
    $fontSize = Get-AppSetting -Name "ResultsFontSize"
    
    # Verify font family is valid
    if ([string]::IsNullOrEmpty($fontFamily)) {
        $fontFamily = "Consolas" # Default fallback
    }
    
    # Check if the font family actually exists on the system
    $fontExists = $false
    foreach ($family in [System.Drawing.FontFamily]::Families) {
        if ($family.Name -eq $fontFamily) {
            $fontExists = $true
            break
        }
    }
    
    # If the configured font doesn't exist, use a system font that should be available
    if (-not $fontExists) {
        $fontFamily = "Arial" # Widely available system font
    }
    
    # Ensure font size is valid
    if ($null -eq $fontSize -or -not ($fontSize -is [int]) -or $fontSize -lt 8 -or $fontSize -gt 72) {
        $fontSize = 9 # Default fallback size
    }
    
    # Now create the font with validated values
    $rtbResults.Font = New-Object System.Drawing.Font($fontFamily, $fontSize)
}
catch {
    # If anything goes wrong, use a basic system font
    Write-Host "Error setting custom font: $_" -ForegroundColor Yellow
    $rtbResults.Font = New-Object System.Drawing.Font("Arial", 9)
}
$rtbResults.BackColor = [System.Drawing.Color]::White
$rtbResults.MultiLine = $true
$rtbResults.ScrollBars = "Both"
$rtbResults.WordWrap = $false
$panel.Controls.Add($rtbResults)

# Add panel to tab page
$TabPage.Controls.Add($panel)
}

function Setup-SettingsTab {
param(
[Parameter(Mandatory=$true)]
[System.Windows.Forms.TabPage]$TabPage
)

# Create container panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)

# Create settings groups
$grpGeneral = New-Object System.Windows.Forms.GroupBox
$grpGeneral.Location = New-Object System.Drawing.Point(10, 20)
$grpGeneral.Size = New-Object System.Drawing.Size(570, 120)
$grpGeneral.Text = "General Settings"
$panel.Controls.Add($grpGeneral)

$lblDefaultOutput = New-Object System.Windows.Forms.Label
$lblDefaultOutput.Location = New-Object System.Drawing.Point(10, 30)
$lblDefaultOutput.Size = New-Object System.Drawing.Size(150, 20)
$lblDefaultOutput.Text = "Default Output Path:"
$grpGeneral.Controls.Add($lblDefaultOutput)

$txtDefaultOutput = New-Object System.Windows.Forms.TextBox
$txtDefaultOutput.Location = New-Object System.Drawing.Point(160, 30)
$txtDefaultOutput.Size = New-Object System.Drawing.Size(300, 20)
$txtDefaultOutput.Text = (Get-AppSetting -Name "DefaultOutputPath")
$grpGeneral.Controls.Add($txtDefaultOutput)

$btnDefaultOutput = New-Object System.Windows.Forms.Button
$btnDefaultOutput.Location = New-Object System.Drawing.Point(470, 30)
$btnDefaultOutput.Size = New-Object System.Drawing.Size(80, 20)
$btnDefaultOutput.Text = "Browse..."
$btnDefaultOutput.Add_Click({
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Select default output folder"
if ($folderBrowser.ShowDialog() -eq 'OK') {
    $txtDefaultOutput.Text = $folderBrowser.SelectedPath
}
})
$grpGeneral.Controls.Add($btnDefaultOutput)

$lblMaxFileSize = New-Object System.Windows.Forms.Label
$lblMaxFileSize.Location = New-Object System.Drawing.Point(10, 60)
$lblMaxFileSize.Size = New-Object System.Drawing.Size(150, 20)
$lblMaxFileSize.Text = "Max File Size for Search (MB):"
$grpGeneral.Controls.Add($lblMaxFileSize)

$numMaxFileSize = New-Object System.Windows.Forms.NumericUpDown
$numMaxFileSize.Location = New-Object System.Drawing.Point(160, 60)
$numMaxFileSize.Size = New-Object System.Drawing.Size(60, 20)
$numMaxFileSize.Minimum = 1
$numMaxFileSize.Maximum = 1000
$numMaxFileSize.Value = ((Get-AppSetting -Name "MaxFileSizeForTextSearch") / 1MB)
$grpGeneral.Controls.Add($numMaxFileSize)

$lblLogLevel = New-Object System.Windows.Forms.Label
$lblLogLevel.Location = New-Object System.Drawing.Point(10, 90)
$lblLogLevel.Size = New-Object System.Drawing.Size(150, 20)
$lblLogLevel.Text = "Logging Level:"
$grpGeneral.Controls.Add($lblLogLevel)

$cboLogLevel = New-Object System.Windows.Forms.ComboBox
$cboLogLevel.Location = New-Object System.Drawing.Point(160, 90)
$cboLogLevel.Size = New-Object System.Drawing.Size(120, 20)
$cboLogLevel.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

# Add log levels to the dropdown
$cboLogLevel.Items.Add("DEBUG")
$cboLogLevel.Items.Add("INFO")
$cboLogLevel.Items.Add("WARNING")
$cboLogLevel.Items.Add("ERROR")

# Set current value based on settings
$currentLogLevel = Get-AppSetting -Name "LogLevelName"
if ([string]::IsNullOrEmpty($currentLogLevel)) {
    $currentLogLevel = "INFO"
}

$levelIndex = $cboLogLevel.Items.IndexOf($currentLogLevel)
if ($levelIndex -ge 0) {
    $cboLogLevel.SelectedIndex = $levelIndex
} else {
    $cboLogLevel.SelectedIndex = 1  # Default to INFO (index 1)
}

$grpGeneral.Controls.Add($cboLogLevel)

$grpUI = New-Object System.Windows.Forms.GroupBox
$grpUI.Location = New-Object System.Drawing.Point(10, 150)
$grpUI.Size = New-Object System.Drawing.Size(570, 120)
$grpUI.Text = "UI Settings"
$panel.Controls.Add($grpUI)

$lblFontFamily = New-Object System.Windows.Forms.Label
$lblFontFamily.Location = New-Object System.Drawing.Point(10, 30)
$lblFontFamily.Size = New-Object System.Drawing.Size(150, 20)
$lblFontFamily.Text = "Results Font Family:"
$grpUI.Controls.Add($lblFontFamily)

$cboFontFamily = New-Object System.Windows.Forms.ComboBox
$cboFontFamily.Location = New-Object System.Drawing.Point(160, 30)
$cboFontFamily.Size = New-Object System.Drawing.Size(200, 20)
$cboFontFamily.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

# Add system monospace fonts
$fonts = [System.Drawing.FontFamily]::Families | Where-Object { $_.IsStyleAvailable([System.Drawing.FontStyle]::Regular) }
$monospaceFonts = $fonts | Where-Object { 
    try {
        $font = New-Object System.Drawing.Font($_.Name, 10)
        # Get character width rather than height
        $iWidth = [System.Windows.Forms.TextRenderer]::MeasureText("i", $font).Width
        $WWidth = [System.Windows.Forms.TextRenderer]::MeasureText("W", $font).Width
        $result = ($iWidth -eq $WWidth)
        $font.Dispose()
        $result
    }
    catch {
        # Skip fonts that cause errors
        $false
    }
} | Select-Object -ExpandProperty Name

foreach ($font in $monospaceFonts) {
$cboFontFamily.Items.Add($font)
}

# Set current value
$currentFont = Get-AppSetting -Name "ResultsFontFamily"
$fontIndex = $cboFontFamily.Items.IndexOf($currentFont)
if ($fontIndex -ge 0) {
$cboFontFamily.SelectedIndex = $fontIndex
}
else {
$cboFontFamily.SelectedIndex = $cboFontFamily.Items.IndexOf("Consolas")
}

$grpUI.Controls.Add($cboFontFamily)

$lblFontSize = New-Object System.Windows.Forms.Label
$lblFontSize.Location = New-Object System.Drawing.Point(10, 60)
$lblFontSize.Size = New-Object System.Drawing.Size(150, 20)
$lblFontSize.Text = "Results Font Size:"
$grpUI.Controls.Add($lblFontSize)

$numFontSize = New-Object System.Windows.Forms.NumericUpDown
$numFontSize.Location = New-Object System.Drawing.Point(160, 60)
$numFontSize.Size = New-Object System.Drawing.Size(60, 20)
$numFontSize.Minimum = 8
$numFontSize.Maximum = 16
$numFontSize.Value = (Get-AppSetting -Name "ResultsFontSize")
$grpUI.Controls.Add($numFontSize)

# Save settings button
$btnSaveSettings = New-Object System.Windows.Forms.Button
$btnSaveSettings.Location = New-Object System.Drawing.Point(10, 280)
$btnSaveSettings.Size = New-Object System.Drawing.Size(150, 30)
$btnSaveSettings.Text = "Save Settings"
$btnSaveSettings.Add_Click({
    # Update settings
    Set-AppSetting -Name "DefaultOutputPath" -Value $txtDefaultOutput.Text
    Set-AppSetting -Name "MaxFileSizeForTextSearch" -Value ($numMaxFileSize.Value * 1MB)
    Set-AppSetting -Name "ResultsFontFamily" -Value $cboFontFamily.SelectedItem
    Set-AppSetting -Name "ResultsFontSize" -Value $numFontSize.Value
    
    if ($null -ne $cboLogLevel.SelectedItem) {
        $selectedLogLevel = $cboLogLevel.SelectedItem.ToString()
        Set-AppSetting -Name "LogLevelName" -Value $selectedLogLevel
        
        # Update the active log level
        try {
            Set-LogLevel -Level $selectedLogLevel
        } catch {
            Write-Host "Note: Log level will be applied on next application start"
        }
    }

    # Save settings to file
    $success = Save-AppSettings

    if ($success) {
        [System.Windows.MessageBox]::Show("Settings saved successfully. Some changes may require restarting the application.", "Settings Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
    else {
        [System.Windows.MessageBox]::Show("Failed to save settings.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$panel.Controls.Add($btnSaveSettings)

# Add panel to tab page
$TabPage.Controls.Add($panel)
}

function Setup-AboutTab {
param(
[Parameter(Mandatory=$true)]
[System.Windows.Forms.TabPage]$TabPage
)

# Create container panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)

# Create about information
$lblAppName = New-Object System.Windows.Forms.Label
$lblAppName.Location = New-Object System.Drawing.Point(10, 20)
$lblAppName.Size = New-Object System.Drawing.Size(570, 30)
$lblAppName.Text = "DiagLog Analyzer"
$lblAppName.Font = New-Object System.Drawing.Font($lblAppName.Font.FontFamily, 16, [System.Drawing.FontStyle]::Bold)
$panel.Controls.Add($lblAppName)

$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Location = New-Object System.Drawing.Point(10, 50)
$lblVersion.Size = New-Object System.Drawing.Size(570, 20)
$lblVersion.Text = "Version " + (Get-AppSetting -Name "Version")
$panel.Controls.Add($lblVersion)

$lblDescription = New-Object System.Windows.Forms.Label
$lblDescription.Location = New-Object System.Drawing.Point(10, 80)
$lblDescription.Size = New-Object System.Drawing.Size(570, 40)
$lblDescription.Text = "A PowerShell-based application for analyzing diagnostic log files, with a focus on handling complex diagnostic data capture structures."
$panel.Controls.Add($lblDescription)

$lblFeatures = New-Object System.Windows.Forms.Label
$lblFeatures.Location = New-Object System.Drawing.Point(10, 130)
$lblFeatures.Size = New-Object System.Drawing.Size(570, 20)
$lblFeatures.Text = "Features:"
$lblFeatures.Font = New-Object System.Drawing.Font($lblFeatures.Font.FontFamily, $lblFeatures.Font.Size, [System.Drawing.FontStyle]::Bold)
$panel.Controls.Add($lblFeatures)

$txtFeatures = New-Object System.Windows.Forms.TextBox
$txtFeatures.Location = New-Object System.Drawing.Point(10, 150)
$txtFeatures.Size = New-Object System.Drawing.Size(570, 100)
$txtFeatures.Multiline = $true
$txtFeatures.ReadOnly = $true
$txtFeatures.ScrollBars = "Vertical"
$txtFeatures.Text = @"
- Folder Structure Analysis: Quickly scan and understand complex diagnostic log directory structures
- Intelligent CAB Extraction: Automatically extract CAB files while preserving their context
- Smart Content Search: Search across multiple files with filtering by file type
- Visual Reporting: Generate interactive HTML reports of analysis findings and search results
- Intuitive GUI Interface: Easy-to-use interface that guides users through the analysis process
"@
    $panel.Controls.Add($txtFeatures)
    
    $lblLogPath = New-Object System.Windows.Forms.Label
    $lblLogPath.Location = New-Object System.Drawing.Point(10, 260)
    $lblLogPath.Size = New-Object System.Drawing.Size(150, 20)
    $lblLogPath.Text = "Log File:"
    $panel.Controls.Add($lblLogPath)
    
    $txtLogPath = New-Object System.Windows.Forms.TextBox
    $txtLogPath.Location = New-Object System.Drawing.Point(160, 260)
    $txtLogPath.Size = New-Object System.Drawing.Size(320, 20)
    $txtLogPath.ReadOnly = $true
    $txtLogPath.Text = (Get-LogFile)
    $panel.Controls.Add($txtLogPath)
    
    $btnOpenLog = New-Object System.Windows.Forms.Button
    $btnOpenLog.Location = New-Object System.Drawing.Point(490, 260)
    $btnOpenLog.Size = New-Object System.Drawing.Size(90, 20)
    $btnOpenLog.Text = "Open Log"
    $btnOpenLog.Add_Click({
        $logFile = Get-LogFile
        if (Test-Path $logFile) {
            Start-Process $logFile
        }
        else {
            [System.Windows.MessageBox]::Show("Log file not found.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $panel.Controls.Add($btnOpenLog)
    
    $lblCopyright = New-Object System.Windows.Forms.Label
    $lblCopyright.Location = New-Object System.Drawing.Point(10, 300)
    $lblCopyright.Size = New-Object System.Drawing.Size(570, 20)
    $lblCopyright.Text = "© " + (Get-Date).Year + ". All rights reserved."
    $lblCopyright.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($lblCopyright)
    
    # Add panel to tab page
    $TabPage.Controls.Add($panel)
}