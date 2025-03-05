# DiagLog Analyzer - Event Handlers Module
# This module provides centralized event handling functions

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Namespace for custom events
$global:DLAEvents = New-Object -TypeName PSObject

# Global state variables
$script:ProgressDialog = $null

# Browse button click handler
function BrowseButtonClick {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Windows.Forms.Control.ControlCollection]$Controls,
        [string]$Description = "Select DiagLogs folder"
    )
    
    Write-DLALog -Message "Browse button clicked" -Level DEBUG -Component "EventHandlers"
    
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Description
    
    if ($folderBrowser.ShowDialog() -eq 'OK') {
        $textbox = $Controls | Where-Object { $_ -is [System.Windows.Forms.TextBox] -and $_.Name -eq "SourcePath" }
        if ($textbox) {
            $textbox.Text = $folderBrowser.SelectedPath
            Write-DLALog -Message "Folder selected: $($folderBrowser.SelectedPath)" -Level INFO -Component "EventHandlers"
        }
        else {
            Write-DLALog -Message "SourcePath textbox not found in controls collection" -Level WARNING -Component "EventHandlers"
        }
        
        return $folderBrowser.SelectedPath
    }
    
    return $null
}

# Analyze button click handler
function AnalyzeButtonClick {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Windows.Forms.Control.ControlCollection]$Controls,
        [System.Windows.Forms.Control]$ResultsControl,
        [scriptblock]$OnComplete = $null
    )
    
    Write-DLALog -Message "Analyze button clicked" -Level INFO -Component "EventHandlers"
    
    # Find the source path textbox
    $textbox = $Controls | Where-Object { $_ -is [System.Windows.Forms.TextBox] -and $_.Name -eq "SourcePath" }
    if (-not $textbox) {
        Show-DLADialog -Message "SourcePath textbox not found" -Type Error
        return $null
    }
    
    $sourcePath = $textbox.Text
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        Show-DLADialog -Message "Please select a DiagLogs folder!" -Type Warning
        return $null
    }
    
    # Verify folder exists
    if (-not (Test-Path -Path $sourcePath -PathType Container)) {
        Show-DLADialog -Message "The selected folder does not exist!" -Type Error
        return $null
    }
    
    # Update UI
    if ($Button) {
        $Button.Enabled = $false
    }
    
    if ($ResultsControl) {
        $ResultsControl.Text = "Analysis in progress, please wait..."
    }
    
    Update-Status "Analyzing folder structure..."
    
    # Start analysis in background
    $params = @{
        FolderPath = $sourcePath
        IncludeSubFolders = $true
    }
    
    try {
        # Try to find a recursive checkbox
        $recursiveBox = $Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] -and ($_.Text -like "*Subfolder*" -or $_.Name -like "*Recursive*") }
        if ($recursiveBox) {
            $params.IncludeSubFolders = $recursiveBox.Checked
        }
        
        # Check if there's a CAB extraction checkbox
        $cabBox = $Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] -and $_.Text -like "*CAB*" }
        if ($cabBox) {
            $params.ExtractCabs = $cabBox.Checked
        }
        
        # Run the analysis with progress dialog
        $analysisResults = Show-ProgressDialog -Title "Analysis" -Message "Analyzing folder structure..." -ScriptBlock {
            param($p)
            return Start-FolderAnalysis @p
        } -ArgumentList $params
        
        # Update results control
        if ($ResultsControl -and $analysisResults) {
            try {
                $summaryText = Get-AnalysisSummary -AnalysisResults $analysisResults
                $ResultsControl.Text = $summaryText
            }
            catch {
                Write-DLALog -Message "Error getting analysis summary: $_" -Level ERROR -Component "EventHandlers"
                $ResultsControl.Text = "Analysis completed, but could not generate summary: $_"
            }
        }
        
        # Update status
        Update-Status "Analysis completed. Found $($analysisResults.Files) files in $($analysisResults.Directories) directories."
        
        # Call the completion callback if provided
        if ($OnComplete -and $analysisResults) {
            try {
                $OnComplete.Invoke($analysisResults)
            }
            catch {
                Write-DLALog -Message "Error in analysis completion callback: $_" -Level ERROR -Component "EventHandlers"
            }
        }
        
        return $analysisResults
    }
    catch {
        Write-DLALog -Message "Error during analysis: $_" -Level ERROR -Component "EventHandlers"
        
        if ($ResultsControl) {
            $ResultsControl.Text = "Error during analysis: $_"
        }
        
        Update-Status "Analysis failed."
        Show-DLADialog -Message "Error during analysis: $_" -Type Error
        return $null
    }
    finally {
        if ($Button) {
            $Button.Enabled = $true
        }
    }
}

# Search button click handler
function SearchButtonClick {
    param(
        [System.Windows.Forms.Button]$Button,
        [hashtable]$ControlsMap,
        [hashtable]$AnalysisResults,
        [scriptblock]$OnComplete = $null
    )
    
    Write-DLALog -Message "Search button clicked" -Level INFO -Component "EventHandlers"
    
    try {
        if ($null -eq $AnalysisResults) {
            Show-DLADialog -Message "Please analyze a folder first!" -Type Warning
            return $null
        }
        
        # Get search text
        $textbox = $ControlsMap["SearchText"]
        if (-not $textbox) {
            Show-DLADialog -Message "Search text control not found" -Type Error
            return $null
        }
        
        $searchText = $textbox.Text
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            Show-DLADialog -Message "Please enter a search term!" -Type Warning
            return $null
        }
        
        # Get file extensions to include
        $extensions = @()
        if ($ControlsMap.ContainsKey("Extensions") -and $ControlsMap["Extensions"]) {
            $extensionsText = $ControlsMap["Extensions"].Text
            if (-not [string]::IsNullOrWhiteSpace($extensionsText)) {
                $extensions = $extensionsText.Split(',', ';') | ForEach-Object { $_.Trim() }
            }
        }
        
        # Get case sensitivity
        $caseSensitive = $false
        if ($ControlsMap.ContainsKey("CaseSensitive") -and $ControlsMap["CaseSensitive"]) {
            $caseSensitive = $ControlsMap["CaseSensitive"].Checked
        }
        
        # Get context lines
        $contextLines = 2
        if ($ControlsMap.ContainsKey("ContextLines") -and $ControlsMap["ContextLines"]) {
            $contextLines = [int]$ControlsMap["ContextLines"].Value
        }
        
        # Update UI
        if ($Button) {
            $Button.Enabled = $false
        }
        
        if ($ControlsMap.ContainsKey("Results") -and $ControlsMap["Results"]) {
            $ControlsMap["Results"].Text = "Search in progress, please wait..."
        }
        
        Update-Status "Searching for '$searchText'..."
        
        # Start search in background
        $params = @{
            AnalysisResults = $AnalysisResults
            SearchText = $searchText
            ExtensionsToInclude = $extensions
            ContextLinesBefore = $contextLines
            ContextLinesAfter = $contextLines
            CaseSensitive = $caseSensitive
        }
        
        # Run the search with progress dialog
        $searchResults = Show-ProgressDialog -Title "Search" -Message "Searching for '$searchText'..." -ScriptBlock {
            param($p)
            return Search-AnalysisResults @p
        } -ArgumentList $params
        
        # Update results control
        if ($ControlsMap.ContainsKey("Results") -and $ControlsMap["Results"] -and $searchResults) {
            try {
                $resultText = Format-SearchResults -SearchResults $searchResults
                $ControlsMap["Results"].Text = $resultText
            }
            catch {
                Write-DLALog -Message "Error formatting search results: $_" -Level ERROR -Component "EventHandlers"
                $ControlsMap["Results"].Text = "Search completed, but could not format results: $_"
            }
        }
        
        # Update status
        Update-Status "Search completed. Found $($searchResults.TotalMatches) matches in $($searchResults.FilesWithMatches) files."
        
        # Call the completion callback if provided
        if ($OnComplete -and $searchResults) {
            try {
                $OnComplete.Invoke($searchResults)
            }
            catch {
                Write-DLALog -Message "Error in search completion callback: $_" -Level ERROR -Component "EventHandlers"
            }
        }
        
        return $searchResults
    }
    catch {
        Write-DLALog -Message "Error during search: $_" -Level ERROR -Component "EventHandlers"
        
        if ($ControlsMap.ContainsKey("Results") -and $ControlsMap["Results"]) {
            $ControlsMap["Results"].Text = "Error during search: $_"
        }
        
        Update-Status "Search failed."
        Show-DLADialog -Message "Error during search: $_" -Type Error
        return $null
    }
    finally {
        if ($Button) {
            $Button.Enabled = $true
        }
    }
}

# Progress dialog helper
function Show-ProgressDialog {
    param(
        [string]$Title = "Processing",
        [string]$Message = "Please wait...",
        [scriptblock]$ScriptBlock,
        [object]$ArgumentList = $null
    )
    
    Write-DLALog -Message "Showing progress dialog: $Title" -Level DEBUG -Component "EventHandlers"
    
    # Create progress form
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = $Title
    $progressForm.Size = New-Object System.Drawing.Size(400, 150)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.ControlBox = $false
    
    # Message label
    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Location = New-Object System.Drawing.Point(10, 20)
    $lblMessage.Size = New-Object System.Drawing.Size(380, 20)
    $lblMessage.Text = $Message
    $progressForm.Controls.Add($lblMessage)
    
    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 50)
    $progressBar.Size = New-Object System.Drawing.Size(380, 20)
    $progressBar.Style = "Marquee"
    $progressForm.Controls.Add($progressBar)
    
    # Status label
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Location = New-Object System.Drawing.Point(10, 80)
    $lblStatus.Size = New-Object System.Drawing.Size(380, 20)
    $lblStatus.Text = "Starting..."
    $progressForm.Controls.Add($lblStatus)
    
    # Store reference
    $script:ProgressDialog = @{
        Form = $progressForm
        Label = $lblMessage
        ProgressBar = $progressBar
        StatusLabel = $lblStatus
    }
    
    # Create job to run in background
    $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    
    # Show form
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        if ($job.State -eq "Completed") {
            $timer.Stop()
            $progressForm.Close()
        }
        else {
            $lblStatus.Text = "Processing..." + (Get-Date).ToString("HH:mm:ss")
        }
    })
    
    $timer.Start()
    [void]$progressForm.ShowDialog()
    
    # Get results
    $result = $null
    if ($job.State -eq "Completed") {
        try {
            $result = Receive-Job -Job $job
        }
        catch {
            Write-DLALog -Message "Error receiving job results: $_" -Level ERROR -Component "EventHandlers"
        }
    }
    
    # Clean up
    Remove-Job -Job $job -Force
    $script:ProgressDialog = $null
    
    return $result
}

# Format search results for display
function Format-SearchResults {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SearchResults
    )
    
    $resultText = "Search Results for '$($SearchResults.SearchText)'`r`n"
    $resultText += "Total Files: $($SearchResults.TotalFiles)`r`n"
    $resultText += "Files With Matches: $($SearchResults.FilesWithMatches)`r`n"
    $resultText += "Total Matches: $($SearchResults.TotalMatches)`r`n`r`n"
    
    foreach ($result in $SearchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 }) {
        $resultText += "File: $($result.FilePath)`r`n"
        $resultText += "Matches: $($result.MatchCount)`r`n"
        
        foreach ($match in $result.Matches) {
            $resultText += "`r`n  Line $($match.MatchLineNumber): $($match.MatchLine)`r`n"
            
            # Add context lines before
            if ($match.BeforeContext) {
                foreach ($line in $match.BeforeContext) {
                    $resultText += "    $($line.LineNumber): $($line.Text)`r`n"
                }
            }
            
            # Add context lines after
            if ($match.AfterContext) {
                foreach ($line in $match.AfterContext) {
                    $resultText += "    $($line.LineNumber): $($line.Text)`r`n"
                }
            }
            
            $resultText += "`r`n"
        }
        
        $resultText += "-----------------------------------`r`n"
    }
    
    return $resultText
}

# Helper function to update the status
function Update-Status {
    param([string]$Message)
    
    Write-DLALog -Message $Message -Level INFO -Component "EventHandlers"
    
    # Try to call the main form's Update-Status function
    $parentForm = [System.Windows.Forms.Form]::ActiveForm
    if ($parentForm -and ($parentForm | Get-Member -MemberType ScriptMethod -Name "Update-Status")) {
        $parentForm.UpdateStatus($Message)
    }
}

# Export module members
Export-ModuleMember -Function BrowseButtonClick, 
                            AnalyzeButtonClick, 
                            SearchButtonClick, 
                            Show-ProgressDialog,
                            Format-SearchResults,
                            Update-Status