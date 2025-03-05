# DiagLog Analyzer - GUI Controls Module
# This module provides common GUI controls with consistent styling

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import required modules
$settingsModule = Join-Path -Path $PSScriptRoot -ChildPath "..\Config\Settings.psm1"
Import-Module $settingsModule -Force

function New-DLAButton {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [int]$Width = 100,
        [int]$Height = 30,
        [int]$X = 0,
        [int]$Y = 0,
        
        [scriptblock]$OnClick
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.UseVisualStyleBackColor = $true
    
    if ($OnClick) {
        $button.Add_Click($OnClick)
    }
    
    return $button
}

function New-DLATextBox {
    param (
        [string]$Text = "",
        [int]$Width = 200,
        [int]$Height = 20,
        [int]$X = 0,
        [int]$Y = 0,
        [switch]$Multiline,
        [switch]$ReadOnly
    )
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Text = $Text
    $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    $textBox.Multiline = $Multiline
    $textBox.ReadOnly = $ReadOnly
    
    if ($Multiline) {
        $textBox.ScrollBars = "Vertical"
    }
    
    return $textBox
}

function New-DLALabel {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [int]$Width = 100,
        [int]$Height = 20,
        [int]$X = 0,
        [int]$Y = 0
    )
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.AutoSize = $true
    
    return $label
}

function New-DLAProgressBar {
    param (
        [int]$Width = 200,
        [int]$Height = 20,
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Minimum = 0,
        [int]$Maximum = 100
    )
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size($Width, $Height)
    $progressBar.Location = New-Object System.Drawing.Point($X, $Y)
    $progressBar.Minimum = $Minimum
    $progressBar.Maximum = $Maximum
    $progressBar.Style = "Continuous"
    
    return $progressBar
}

function New-DLAListView {
    param (
        [int]$Width = 400,
        [int]$Height = 300,
        [int]$X = 0,
        [int]$Y = 0,
        [string[]]$Columns
    )
    
    $listView = New-Object System.Windows.Forms.ListView
    $listView.Size = New-Object System.Drawing.Size($Width, $Height)
    $listView.Location = New-Object System.Drawing.Point($X, $Y)
    $listView.View = [System.Windows.Forms.View]::Details
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    
    if ($Columns) {
        foreach ($col in $Columns) {
            $listView.Columns.Add($col) | Out-Null
        }
        $listView.Columns | ForEach-Object { $_.Width = ($Width - 25) / $Columns.Count }
    }
    
    return $listView
}

function Show-DLADialog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [string]$Title = "DiagLog Analyzer",
        [ValidateSet("Info", "Warning", "Error", "Question")]
        [string]$Type = "Info"
    )
    
    $icon = switch ($Type) {
        "Info" { [System.Windows.Forms.MessageBoxIcon]::Information }
        "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
        "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
        "Question" { [System.Windows.Forms.MessageBoxIcon]::Question }
    }
    
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
}

function New-TabControl {
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Fill"
    $tabControl.Name = "MainTabControl"
    
    # Create and add all tabs
    $tabControl.TabPages.AddRange(@(
        (New-AnalysisTab),
        (New-SearchTab),
        (New-ResultsTab),
        (New-SettingsTab)
    ))
    
    return $tabControl
}

function New-AnalysisTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Analysis"
    $tab.Name = "AnalysisTab"
    
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = "Fill"
    $panel.ColumnCount = 2
    $panel.RowCount = 3
    
    # Source folder selection
    $lblSource = New-Object System.Windows.Forms.Label
    $lblSource.Text = "Source Folder:"
    $txtSource = New-Object System.Windows.Forms.TextBox
    $txtSource.Name = "SourcePath"
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Browse..."
    
    # Analysis options group
    $groupOptions = New-Object System.Windows.Forms.GroupBox
    $groupOptions.Text = "Analysis Options"
    $chkRecursive = New-Object System.Windows.Forms.CheckBox
    $chkRecursive.Text = "Include Subfolders"
    $groupOptions.Controls.Add($chkRecursive)
    
    # Start button
    $btnAnalyze = New-Object System.Windows.Forms.Button
    $btnAnalyze.Text = "Start Analysis"
    $btnAnalyze.Dock = "Bottom"
    
    # Add controls to panel
    $panel.Controls.AddRange(@($lblSource, $txtSource, $btnBrowse, $groupOptions, $btnAnalyze))
    $tab.Controls.Add($panel)
    
    return $tab
}

function New-SearchTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Search"
    $tab.Name = "SearchTab"
    
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = "Fill"
    
    # Search controls
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Name = "SearchText"
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Text = "Search"
    
    # Results grid
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.AutoSizeColumnsMode = "Fill"
    
    $panel.Controls.AddRange(@($txtSearch, $btnSearch, $grid))
    $tab.Controls.Add($panel)
    
    return $tab
}

function New-ResultsTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Results"
    $tab.Name = "ResultsTab"
    
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = "Fill"
    
    # Results view
    $resultsView = New-Object System.Windows.Forms.RichTextBox
    $resultsView.Dock = "Fill"
    $resultsView.ReadOnly = $true
    
    $panel.Controls.Add($resultsView)
    $tab.Controls.Add($panel)
    
    return $tab
}

function New-SettingsTab {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "Settings"
    $tab.Name = "SettingsTab"
    
    $panel = New-Object System.Windows.Forms.PropertyGrid
    $panel.Dock = "Fill"
    $tab.Controls.Add($panel)
    
    return $tab
}

function New-StatusStrip {
    $status = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Name = "StatusLabel"
    $statusLabel.Text = "Ready"
    $status.Items.Add($statusLabel)
    return $status
}

# Export all the control creation functions
Export-ModuleMember -Function New-DLAButton, 
                            New-DLATextBox, 
                            New-DLALabel, 
                            New-DLAProgressBar, 
                            New-DLAListView, 
                            Show-DLADialog,
                            New-TabControl,
                            New-StatusStrip