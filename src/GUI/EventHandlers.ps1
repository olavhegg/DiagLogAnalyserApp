# Event Handlers Module

function Handle-BrowseButtonClick {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Windows.Forms.Control.ControlCollection]$Controls
    )
    
    $folderPath = Show-FolderPicker -Description "Select DiagLogs folder"
    if ($folderPath) {
        $Controls["SourcePath"].Text = $folderPath
    }
}

function Handle-AnalyzeButtonClick {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Windows.Forms.Control.ControlCollection]$Controls
    )
    
    $sourcePath = $Controls["SourcePath"].Text
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        Show-Error "Please select a DiagLogs folder!"
        return
    }

    # Update status
    Update-Status "Analyzing folder structure..."

    # Start analysis in background
    $params = @{
        FolderPath = $sourcePath
        IncludeSubFolders = $true
    }

    Show-ProgressDialog -Title "Analysis" -Message "Analyzing folder structure..." -ScriptBlock {
        param($p)
        return Start-FolderAnalysis @p
    } -ArgumentList $params
}

function Handle-SearchButtonClick {
    param(
        [System.Windows.Forms.Button]$button,
        [hashtable]$controls
    )
    
    try {
        if ($null -eq $script:AnalysisResults) {
            Show-Error "Please analyze a folder first!"
            return
        }
        
        # ... Rest of search button click handler
    }
    catch {
        Show-Error "Error during search: $_"
    }
}

# ... Continue with other event handlers
