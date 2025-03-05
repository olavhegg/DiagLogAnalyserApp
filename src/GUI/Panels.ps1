. (Join-Path -Path $PSScriptRoot -ChildPath "Controls.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "EventHandlers.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "Helpers.ps1")

# Panel creation functions

function New-AnalysisPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(10)

    # Source folder controls
    $panel.Controls.Add((New-SourcePathControls))

    # Analysis options
    $panel.Controls.Add((New-AnalysisOptionsGroup))

    # Action buttons
    $panel.Controls.Add((New-ActionButtonsGroup))

    # Results area
    $panel.Controls.Add((New-ResultsTextBox))

    return $panel
}

function New-SearchPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(10)

    # Search controls
    $panel.Controls.Add((New-SearchControls))
    
    # File type filter
    $panel.Controls.Add((New-FileTypeFilter))
    
    # Results area
    $panel.Controls.Add((New-ResultsTextBox))

    return $panel
}

# ... Add other panel creation functions
