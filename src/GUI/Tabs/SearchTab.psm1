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
    
    # Search guidance label
    $lblSearchGuide = New-Object System.Windows.Forms.Label
    $lblSearchGuide.Text = "Search Guide:"
    $lblSearchGuide.Location = New-Object System.Drawing.Point(10, 40)
    $lblSearchGuide.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $lblSearchGuide.AutoSize = $true
    
    $txtSearchHelp = New-Object System.Windows.Forms.TextBox
    $txtSearchHelp.Location = New-Object System.Drawing.Point(10, 65)
    $txtSearchHelp.ForeColor = [System.Drawing.Color]::Gray

    $txtSearchHelp.Width = 860
    $txtSearchHelp.Height = 80
    $txtSearchHelp.Multiline = $true
    $txtSearchHelp.ReadOnly = $true
    $txtSearchHelp.Text = @"
    Search Features:
    - IMPORTANT: You must run Analysis first before searching
    - Enter single or multiple search terms separated by commas
    - Example: "error, warning, network"
    - Searches are case-insensitive by default
    - Check 'Case Sensitive' for exact matching
    - Searches across all files in the analyzed folder
    - Provides file path, match count, and first match context
"@
    
    # Basic search controls
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Search Text:"
    $lblSearch.Location = New-Object System.Drawing.Point(10, 160)
    $lblSearch.AutoSize = $true
    
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(120, 157)
    $txtSearch.Width = 400
    $txtSearch.Name = "SearchText"
    $txtSearch.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtSearch.ForeColor = [System.Drawing.Color]::Gray
    $txtSearch.Text = "Enter search terms (comma-separated)"
    
    $txtSearch.Add_Enter({
        if ($txtSearch.Text -eq "Enter search terms (comma-separated)") {
            $txtSearch.Text = ""
            $txtSearch.ForeColor = [System.Drawing.Color]::Black
        }
    })
    
    $txtSearch.Add_Leave({
        if ([string]::IsNullOrWhiteSpace($txtSearch.Text)) {
            $txtSearch.Text = "Enter search terms (comma-separated)"
            $txtSearch.ForeColor = [System.Drawing.Color]::Gray
        }
    })
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
    $btnSearch.Location = New-Object System.Drawing.Point(530, 155)
    $btnSearch.Width = 80
    $btnSearch.Add_Click({ Start-Search })
    # Store reference at script level
    $script:btnSearch = $btnSearch
    
    # Add search options - case sensitivity
    $chkCaseSensitive = New-Object System.Windows.Forms.CheckBox
    $chkCaseSensitive.Text = "Case Sensitive"
    $chkCaseSensitive.Location = New-Object System.Drawing.Point(620, 157)
    $chkCaseSensitive.AutoSize = $true
    $chkCaseSensitive.Name = "CaseSensitive"
    # Store reference at script level for later access
    $script:chkCaseSensitive = $chkCaseSensitive
    
    # Results text box
    $txtResults = New-Object System.Windows.Forms.TextBox
    $txtResults.Location = New-Object System.Drawing.Point(10, 190)
    $txtResults.Size = New-Object System.Drawing.Size(860, 435)
    $txtResults.Multiline = $true
    $txtResults.ScrollBars = "Both"
    $txtResults.ReadOnly = $true
    $txtResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtResults.Name = "ResultsText"
    $txtResults.BackColor = [System.Drawing.Color]::White  # Set the background color to white
    # Store reference at script level
    $script:txtResults = $txtResults
    
    # Add controls to the tab
    $tab.Controls.AddRange(@(
        $lblSearchGuide, 
        $txtSearchHelp, 
        $lblSearch, 
        $txtSearch, 
        $btnSearch, 
        $chkCaseSensitive, 
        $txtResults
    ))
    
    return $tab
}

# Separate function to handle search (helps with scope issues)
function Start-Search {
    # Parameters to make the function more flexible
    param(
        $Form = $null,
        $AnalysisResults = $null,
        $SearchTextBox = $null,
        $ResultsTextBox = $null,
        $SearchButton = $null,
        $CaseSensitiveCheckBox = $null
    )

    try {
        # Diagnostic logging
        Write-LogSafe -Message "Start-Search called with parameters" -Level INFO
        Write-LogSafe -Message "Form is null: $($null -eq $Form)" -Level DEBUG
        
        # If no form is provided, try to find the active form
        if ($null -eq $Form) {
            $Form = [System.Windows.Forms.Form]::ActiveForm
            Write-LogSafe -Message "Attempted to get active form. Form is null: $($null -eq $Form)" -Level DEBUG
        }

        # Try to get AnalysisResults from the form if not provided
        if ($null -eq $AnalysisResults -and $Form) {
            try {
                $AnalysisResults = $Form.AnalysisResults
                Write-LogSafe -Message "Retrieved AnalysisResults from form. Results is null: $($null -eq $AnalysisResults)" -Level DEBUG
            }
            catch {
                Write-LogSafe -Message "Error retrieving AnalysisResults from form: $_" -Level ERROR
            }
        }

        # Validate AnalysisResults
        if ($null -eq $AnalysisResults) {
            [System.Windows.Forms.MessageBox]::Show(
                "No analysis results found. Please run an analysis first.", 
                "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        # Use provided controls or fall back to script-level variables
        $txtSearch = if ($SearchTextBox) { $SearchTextBox } else { $script:txtSearch }
        $txtResults = if ($ResultsTextBox) { $ResultsTextBox } else { $script:txtResults }
        $btnSearch = if ($SearchButton) { $SearchButton } else { $script:btnSearch }
        $chkCaseSensitive = if ($CaseSensitiveCheckBox) { $CaseSensitiveCheckBox } else { $script:chkCaseSensitive }

        # Validate controls
        if ($null -eq $txtSearch -or $null -eq $txtResults -or $null -eq $btnSearch) {
            Write-LogSafe -Message "One or more controls are null" -Level ERROR
            Write-LogSafe -Message "txtSearch is null: $($null -eq $txtSearch)" -Level ERROR
            Write-LogSafe -Message "txtResults is null: $($null -eq $txtResults)" -Level ERROR
            Write-LogSafe -Message "btnSearch is null: $($null -eq $btnSearch)" -Level ERROR
            Write-LogSafe -Message "chkCaseSensitive is null: $($null -eq $chkCaseSensitive)" -Level ERROR
            
            [System.Windows.Forms.MessageBox]::Show(
                "Error: Unable to find search controls. Please restart the application.", 
                "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
        
        # Get search text and handle the placeholder text
        $searchText = $txtSearch.Text
        if ($searchText -eq "Enter search terms (comma-separated)" -or [string]::IsNullOrWhiteSpace($searchText)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a search term!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Clear the results text box at the start of the search
        $txtResults.Clear()
        
        # Split search text into terms, trim whitespace
        $searchTerms = $searchText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        
        # Validate search terms
        if ($searchTerms.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please enter valid search terms!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Update UI
        Write-LogSafe -Message "Searching for terms: $($searchTerms -join ', ')" -Level INFO
        $btnSearch.Enabled = $false
        $txtResults.Text = "Search in progress, please wait..."
        
        try {
            # Set up parameters for search function - IMPORTANT: Use SearchTerms as the parameter
            $searchParams = @{
                AnalysisResults = $AnalysisResults
                SearchTerms = $searchTerms  # This matches the expected parameter in Search-AnalysisResults
            }
            
            # Add case sensitivity parameter if checkbox is checked
            if ($chkCaseSensitive -and $chkCaseSensitive.Checked) {
                $searchParams.Add('CaseSensitive', $true)
                Write-LogSafe -Message "Search is case-sensitive" -Level INFO
            }
            
            # Define progress handler
            $progressHandler = {
                param($percentComplete)
                # This is where you would update a progress bar if you had one
                Write-LogSafe -Message "Search progress: $percentComplete%" -Level DEBUG
            }
            $searchParams.Add('ProgressHandler', $progressHandler)
            
            # Check if the function exists
            if (Get-Command -Name Search-AnalysisResults -ErrorAction SilentlyContinue) {
                # Call existing Search-AnalysisResults function
                $searchResults = Search-AnalysisResults @searchParams
                
                # Format results
                $resultsText = "Search Results for: $($searchTerms -join ', ')`r`n"
                $resultsText += "Files With Matches: $($searchResults.FilesWithMatches)`r`n"
                $resultsText += "Total Matches: $($searchResults.TotalMatches)`r`n"
                
                if ($searchResults.FilesSearched) {
                    $resultsText += "Total Files Searched: $($searchResults.FilesSearched)`r`n"
                }
                
                $resultsText += "`r`n"
                
                if ($searchResults.TotalMatches -eq 0) {
                    $resultsText += "No matches found for the search terms.`r`n`r`n"
                    $resultsText += "Suggestions:`r`n"
                    $resultsText += "- Check your spelling`r`n"
                    $resultsText += "- Try using partial words`r`n"
                    $resultsText += "- Search is case-sensitive if checkbox is checked`r`n"
                    $resultsText += "- The analyzed folder might not contain these terms`r`n"
                } else {
                    # Add file results
                    $matchingFiles = $searchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 }
                    
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
                
                # Update results textbox
                $txtResults.Text = $resultsText
                Write-LogSafe -Message "Search completed with $($searchResults.TotalMatches) matches" -Level INFO
            } else {
                Write-LogSafe -Message "Search-AnalysisResults function not found" -Level ERROR
                $txtResults.Text = "ERROR: Required function 'Search-AnalysisResults' not found. Please check your installation."
            }
        }
        catch {
            Write-LogSafe -Message "Error during search: $_" -Level ERROR
            $txtResults.Text = "Error during search: $_"
        }
        finally {
            $btnSearch.Enabled = $true
        }
    }
    catch {
        Write-LogSafe -Message "Unexpected error in Start-Search: $_" -Level ERROR
        Write-LogSafe -Message "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
        
        [System.Windows.Forms.MessageBox]::Show(
            "An unexpected error occurred during search: $_", 
            "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        # Make sure button is re-enabled
        if ($script:btnSearch) {
            $script:btnSearch.Enabled = $true
        }
    }
}

# Export functions
Export-ModuleMember -Function New-SearchTab, Start-Search