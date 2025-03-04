# DiagLog Analyzer - Custom Controls
# This file contains custom control definitions and extensions

# No custom controls defined yet, placeholder for future expansion

# Function to create a progress dialog
function Show-ProgressDialog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [object[]]$ArgumentList = @()
    )
    
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Create message label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(370, 40)
    $label.Text = $Message
    $form.Controls.Add($label)
    
    # Create progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 70)
    $progressBar.Size = New-Object System.Drawing.Size(370, 20)
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 20
    $form.Controls.Add($progressBar)
    
    # Run the script on a background thread
    $result = $null
    $error1 = $null
    
    $thread = [System.Threading.Thread]::new({
        try {
            $result = & $ScriptBlock @ArgumentList
        }
        catch {
            $error1 = $_
        }
        finally {
            $form.Invoke([Action]{$form.Close()})
        }
    })
    
    # Start thread and show form
    $thread.Start()
    [void]$form.ShowDialog()
    
    # Return result
    if ($null -ne $error1) {
        throw $error1
    }
    
    return $result
}

# Function to show a custom file picker
function Show-FilePicker {
    param(
        [string]$Title = "Select Files",
        [string]$Filter = "All Files (*.*)|*.*",
        [string]$InitialDirectory = [Environment]::GetFolderPath("MyDocuments"),
        [switch]$Multiselect = $false
    )
    
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.InitialDirectory = $InitialDirectory
    $dialog.Multiselect = $Multiselect
    
    if ($dialog.ShowDialog() -eq 'OK') {
        if ($Multiselect) {
            return $dialog.FileNames
        }
        else {
            return $dialog.FileName
        }
    }
    
    return $null
}

# Function to show a folder picker dialog
function Show-FolderPicker {
    param(
        [string]$Description = "Select Folder",
        [string]$InitialDirectory = $null,
        [switch]$ShowNewFolderButton = $true
    )
    
    try {
        # Create the folder browser dialog
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = $Description
        $folderBrowser.ShowNewFolderButton = $ShowNewFolderButton
        
        # Set initial directory with better null handling
        if (-not [string]::IsNullOrEmpty($InitialDirectory) -and 
            (Test-Path -Path $InitialDirectory -ErrorAction SilentlyContinue)) {
            $folderBrowser.SelectedPath = $InitialDirectory
        }
        
        # Show dialog and handle result
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            # Double-check that we have a valid path
            if (-not [string]::IsNullOrEmpty($folderBrowser.SelectedPath) -and 
                (Test-Path -Path $folderBrowser.SelectedPath -ErrorAction SilentlyContinue)) {
                return $folderBrowser.SelectedPath
            }
        }
        
        return $null
    }
    catch {
        Write-Warning "Error in folder picker: $_"
        return $null
    }
}

# Extension method to create a simple context menu for text boxes
function Add-TextBoxContextMenu {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TextBox]$TextBox
    )
    
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    
    $copyMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $copyMenuItem.Text = "Copy"
    $copyMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::C
    $copyMenuItem.Add_Click({ $TextBox.Copy() })
    $contextMenu.Items.Add($copyMenuItem)
    
    $selectAllMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $selectAllMenuItem.Text = "Select All"
    $selectAllMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::A
    $selectAllMenuItem.Add_Click({ $TextBox.SelectAll() })
    $contextMenu.Items.Add($selectAllMenuItem)
    
    if (-not $TextBox.ReadOnly) {
        $cutMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
        $cutMenuItem.Text = "Cut"
        $cutMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::X
        $cutMenuItem.Add_Click({ $TextBox.Cut() })
        $contextMenu.Items.Insert(0, $cutMenuItem)
        
        $pasteMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
        $pasteMenuItem.Text = "Paste"
        $pasteMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::V
        $pasteMenuItem.Add_Click({ $TextBox.Paste() })
        $contextMenu.Items.Add($pasteMenuItem)
    }
    
    $TextBox.ContextMenuStrip = $contextMenu
}