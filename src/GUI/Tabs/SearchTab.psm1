# DiagLog Analyzer - Search Tab
# This module implements a simple Search tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Script-level variables to maintain references
$script:txtSearch = $null
$script:txtResults = $null
$script:btnSearch = $null
$script:chkCaseSensitive = $null

# Safe logging wrapper
function Write-LogSafe {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "SearchTab"
    )
    
    try {
        Write-DLALog -Message $Message -Level $Level -Component $Component
    }
    catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] [$Component] $Message"
    }
}

# Create the Search Tab
function New-SearchTab {
    Write-LogSafe -Message "Creating Search tab" -Level INFO
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Search"
    $tab.Name = "SearchTab"
    $tab.Enabled = $false  # Initially disabled until analysis is complete
    
    # Basic search controls
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Search Text:"
    $lblSearch.Location = New-Object System.Drawing.Point(10, 15)
    $lblSearch.AutoSize = $true
    
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(120, 12)
    $txtSearch.Width = 400
    $txtSearch.Name = "SearchText"
    # Enable pressing Enter to trigger search
    $txtSearch.Add_KeyPress({
        if ($_.KeyChar -eq [char]13) {  # Enter key
            $_.Handled = $true  # Prevent beep
            Start-Search
        }
    })
    # Store reference at script level
    $script:txtSearch = $txtSearch
    
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Text = "Search"
    $btnSearch.Location = New-Object System.Drawing.Point(530, 10)
    $btnSearch.Width = 80
    $btnSearch.Add_Click({ Start-Search })
    # Store reference at script level
    $script:btnSearch = $btnSearch
    
    # Add search options - case sensitivity
    $chkCaseSensitive = New-Object System.Windows.Forms.CheckBox
    $chkCaseSensitive.Text = "Case Sensitive"
    $chkCaseSensitive.Location = New-Object System.Drawing.Point(620, 12)
    $chkCaseSensitive.AutoSize = $true
    $chkCaseSensitive.Name = "CaseSensitive"
    # Store reference at script level for later access
    $script:chkCaseSensitive = $chkCaseSensitive
    
    # Results text box
    $txtResults = New-Object System.Windows.Forms.TextBox
    $txtResults.Location = New-Object System.Drawing.Point(10, 50)
    $txtResults.Size = New-Object System.Drawing.Size(860, 575)
    $txtResults.Multiline = $true
    $txtResults.ScrollBars = "Both"
    $txtResults.ReadOnly = $true
    $txtResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtResults.Name = "ResultsText"
    # Store reference at script level
    $script:txtResults = $txtResults
    
    # Add controls to the tab
    $tab.Controls.AddRange(@($lblSearch, $txtSearch, $btnSearch, $chkCaseSensitive, $txtResults))
    
    return $tab
}

# Separate function to handle search (helps with scope issues)
function Start-Search {
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
    
    # Get search text
    $searchText = $script:txtSearch.Text
    if ([string]::IsNullOrWhiteSpace($searchText)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a search term!", "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Update UI
    Write-LogSafe -Message "Searching for '$searchText'" -Level INFO
    $script:btnSearch.Enabled = $false
    $script:txtResults.Text = "Search in progress, please wait..."
    
    try {
        # Check if Search-AnalysisResults exists
        if (Get-Command -Name Search-AnalysisResults -ErrorAction SilentlyContinue) {
            # Debug: Check what parameters the function accepts
            $functionParams = (Get-Command -Name Search-AnalysisResults).Parameters
            Write-LogSafe -Message "Search-AnalysisResults params: $($functionParams.Keys -join ', ')" -Level DEBUG
            
            # Set up parameters for search function
            $searchParams = @{
                AnalysisResults = $analysisResults
                SearchTerms = $searchText
            }
            
            # Add case sensitivity parameter if checkbox is checked
            if ($script:chkCaseSensitive -and $script:chkCaseSensitive.Checked) {
                $searchParams.Add('CaseSensitive', $true)
                Write-LogSafe -Message "Search is case-sensitive" -Level DEBUG
            }
            
            # Call existing Search-AnalysisResults function using parameters
            Write-LogSafe -Message "Calling Search-AnalysisResults with params: $($searchParams.Keys -join ', ')" -Level DEBUG
            $searchResults = Search-AnalysisResults @searchParams
            
            # More detailed debugging about search results
            Write-LogSafe -Message "Search returned. FilesWithMatches: $($searchResults.FilesWithMatches), TotalMatches: $($searchResults.TotalMatches)" -Level INFO
            Write-LogSafe -Message "Results object has $($searchResults.Results.Count) total result entries" -Level DEBUG
            
            # Format results
            $resultsText = "Search Results for '$searchText'`r`n"
            $resultsText += "Files With Matches: $($searchResults.FilesWithMatches)`r`n"
            $resultsText += "Total Matches: $($searchResults.TotalMatches)`r`n"
            $resultsText += "Total Files Searched: $($searchResults.FilesSearched)`r`n`r`n"
            
            if ($searchResults.TotalMatches -eq 0) {
                $resultsText += "No matches found for '$searchText'.`r`n`r`n"
                $resultsText += "Suggestions:`r`n"
                $resultsText += "- Check your spelling`r`n"
                $resultsText += "- Try using partial words`r`n"
                $resultsText += "- Search is case-sensitive by default - try lowercase`r`n"
                $resultsText += "- The analyzed folder might not contain this text`r`n"
            } else {
                # Add file results
                $matchingFiles = $searchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 }
                Write-LogSafe -Message "Found $($matchingFiles.Count) matching files to display" -Level DEBUG
                
                foreach ($file in $matchingFiles) {
                    $resultsText += "File: $($file.FilePath)`r`n"
                    $resultsText += "Matches: $($file.MatchCount)`r`n"
                    
                    # Show sample matches if available
                    if ($file.Matches -and $file.Matches.Count -gt 0) {
                        $resultsText += "First match: Line $($file.Matches[0].LineNumber)`r`n"
                        $resultsText += "Context: $($file.Matches[0].Line)`r`n"
                    }
                    
                    $resultsText += "-----------------------------------`r`n"
                }
            }
        }
        else {
            Write-LogSafe -Message "Search-AnalysisResults function not found, attempting to load module" -Level WARNING
            
            # Try to load the FileSearch module
            $searchModule = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "src\Core\FileSearch.psm1"
            if (Test-Path -Path $searchModule) {
                Import-Module $searchModule -Force
                
                # Try again with the correct parameter name
                if (Get-Command -Name Search-AnalysisResults -ErrorAction SilentlyContinue) {
                    # Set up parameters for search function
                    $searchParams = @{
                        AnalysisResults = $analysisResults
                        SearchTerms = $searchText
                    }
                    
                    # Add case sensitivity parameter if checkbox is checked
                    if ($script:chkCaseSensitive -and $script:chkCaseSensitive.Checked) {
                        $searchParams.Add('CaseSensitive', $true)
                        Write-LogSafe -Message "Search is case-sensitive" -Level DEBUG
                    }
                    
                    # Call existing Search-AnalysisResults function using parameters
                    Write-LogSafe -Message "Calling Search-AnalysisResults with params: $($searchParams.Keys -join ', ')" -Level DEBUG
                    $searchResults = Search-AnalysisResults @searchParams
                    
                    # Format results
                    $resultsText = "Search Results for '$searchText'`r`n"
                    $resultsText += "Files With Matches: $($searchResults.FilesWithMatches)`r`n"
                    $resultsText += "Total Matches: $($searchResults.TotalMatches)`r`n`r`n"
                    
                    # Add file results
                    $matchingFiles = $searchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 }
                    foreach ($file in $matchingFiles) {
                        $resultsText += "File: $($file.FilePath)`r`n"
                        $resultsText += "Matches: $($file.MatchCount)`r`n"
                        $resultsText += "-----------------------------------`r`n"
                    }
                }
                else {
                    $resultsText = "Search function not available. The FileSearch module could not be loaded properly."
                    Write-LogSafe -Message "Search-AnalysisResults function still not found after loading module" -Level ERROR
                }
            }
            else {
                $resultsText = "Search function not available. The FileSearch module could not be found."
                Write-LogSafe -Message "FileSearch module not found at expected path: $searchModule" -Level ERROR
            }
        }
        
        # Update results textbox
        $script:txtResults.Text = $resultsText
        Write-LogSafe -Message "Search completed" -Level INFO
    }
    catch {
        Write-LogSafe -Message "Error during search: $_" -Level ERROR
        $script:txtResults.Text = "Error during search: $_"
    }
    finally {
        $script:btnSearch.Enabled = $true
    }
}

# Export functions
Export-ModuleMember -Function New-SearchTab, Start-Search