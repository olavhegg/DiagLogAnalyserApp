# DiagLog Analyzer - Search Tab
# This module implements a simple Search tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
    
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Text = "Search"
    $btnSearch.Location = New-Object System.Drawing.Point(530, 10)
    $btnSearch.Width = 80
    $btnSearch.Add_Click({
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
        $searchText = $txtSearch.Text
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a search term!", "DiagLog Analyzer", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Update UI
        Write-LogSafe -Message "Searching for '$searchText'" -Level INFO
        $btnSearch.Enabled = $false
        $txtResults.Text = "Search in progress, please wait..."
        
        try {
            # Check if Search-AnalysisResults exists
            if (Get-Command -Name Search-AnalysisResults -ErrorAction SilentlyContinue) {
                # Call existing Search-AnalysisResults function
                $searchResults = Search-AnalysisResults -AnalysisResults $analysisResults -SearchText $searchText
                
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
                Write-LogSafe -Message "Search-AnalysisResults function not found, attempting to load module" -Level WARNING
                
                # Try to load the FileSearch module
                $searchModule = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "src\Core\FileSearch.psm1"
                if (Test-Path -Path $searchModule) {
                    Import-Module $searchModule -Force
                    
                    # Try again
                    if (Get-Command -Name Search-AnalysisResults -ErrorAction SilentlyContinue) {
                        $searchResults = Search-AnalysisResults -AnalysisResults $analysisResults -SearchText $searchText
                        
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
            $txtResults.Text = $resultsText
            Write-LogSafe -Message "Search completed" -Level INFO
        }
        catch {
            Write-LogSafe -Message "Error during search: $_" -Level ERROR
            $txtResults.Text = "Error during search: $_"
        }
        finally {
            $btnSearch.Enabled = $true
        }
    })
    
    # Results text box
    $txtResults = New-Object System.Windows.Forms.TextBox
    $txtResults.Location = New-Object System.Drawing.Point(10, 50)
    $txtResults.Size = New-Object System.Drawing.Size(860, 575)
    $txtResults.Multiline = $true
    $txtResults.ScrollBars = "Both"
    $txtResults.ReadOnly = $true
    $txtResults.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtResults.Name = "ResultsText"
    
    # Add controls to the tab
    $tab.Controls.AddRange(@($lblSearch, $txtSearch, $btnSearch, $txtResults))
    
    return $tab
}

# Export functions
Export-ModuleMember -Function New-SearchTab