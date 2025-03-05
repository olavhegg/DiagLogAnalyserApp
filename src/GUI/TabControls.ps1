# Tab Controls Module

function New-TabControl {
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Fill"
    $tabControl.Name = "MainTabControl"
    
    $tabControl.TabPages.AddRange(@(
        (New-AnalysisTab),
        (New-SearchTab),
        (New-ExtractTab),
        (New-SettingsTab),
        (New-AboutTab)
    ))
    
    return $tabControl
}

function New-AnalysisTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Analysis"
    $tab.Name = "AnalysisTab"
    
    # Add controls
    $panel = New-AnalysisPanel
    $tab.Controls.Add($panel)
    
    return $tab
}

function New-SearchTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Search"
    $tab.Name = "SearchTab"
    $tab.Enabled = $false
    
    # Add controls
    $panel = New-SearchPanel
    $tab.Controls.Add($panel)
    
    return $tab
}

# ... Continue with other tab creation functions
