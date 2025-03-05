# DiagLog Analyzer - Main Form
# This module implements the main application form

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Directly import settings functions from Settings.psm1
$settingsPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "src\Config\Settings.psm1"
if (Test-Path $settingsPath) {
    Import-Module $settingsPath -Force
}

# Script-level variables
$script:MainForm = $null
$script:StatusBar = $null
$script:TabControl = $null

# Safe wrapper for Get-AppSetting in case it's not available
function Get-AppSettingSafe {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null
    )
    
    try {
        # Try the normal function first
        if (Get-Command -Name Get-AppSetting -ErrorAction SilentlyContinue) {
            return Get-AppSetting -Name $Name -DefaultValue $DefaultValue
        }
        
        # Try direct access to global variable
        if ($null -ne $Global:AppSettings -and 
            $Global:AppSettings.PSObject.Properties.Name -contains $Name) {
            return $Global:AppSettings.$Name
        }
    }
    catch {
        # Just return default if we encounter an error
        Write-Host "Error accessing setting $Name, using default value: $DefaultValue"
    }
    
    # Return default value as fallback
    return $DefaultValue
}

# Safe wrapper for logging
function Write-LogSafe {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "MainForm"
    )
    
    try {
        if (Get-Command -Name Write-DLALog -ErrorAction SilentlyContinue) {
            Write-DLALog -Message $Message -Level $Level -Component $Component
        }
        else {
            # Basic fallback to Write-Host
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] [$Level] [$Component] $Message"
        }
    }
    catch {
        # Ultimate fallback
        Write-Host "[$Level] [$Component] $Message"
    }
}

# Function to create and show the main form
function Show-MainForm {
    Write-LogSafe -Message "Creating main application form" -Level INFO
    
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DiagLog Analyzer"
    
    # Set form size from settings
    $width = Get-AppSettingSafe -Name "MainFormWidth" -DefaultValue 900
    $height = Get-AppSettingSafe -Name "MainFormHeight" -DefaultValue 700
    
    $form.Size = New-Object System.Drawing.Size($width, $height)
    $form.StartPosition = "CenterScreen"
    $form.Icon = $null  # You can add an icon later
    
    # Store reference
    $script:MainForm = $form
    
    # Create status bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "Ready"
    $statusBar.Items.Add($statusLabel)
    $form.Controls.Add($statusBar)
    
    # Store reference
    $script:StatusBar = $statusBar
    
    # Create tab control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Fill"
    $tabControl.Name = "MainTabControl"
    
    # Store reference
    $script:TabControl = $tabControl
    
    # Add tab pages
    try {
        # Try to add Analysis tab
        if (Get-Command -Name New-AnalysisTab -ErrorAction SilentlyContinue) {
            $analysisTab = New-AnalysisTab
            $tabControl.TabPages.Add($analysisTab)
        }
        
        # Try to add Search tab
        if (Get-Command -Name New-SearchTab -ErrorAction SilentlyContinue) {
            $searchTab = New-SearchTab
            $tabControl.TabPages.Add($searchTab)
        }
        
        # Try to add CAB extraction tab
        if (Get-Command -Name New-CabExtractionTab -ErrorAction SilentlyContinue) {
            $cabTab = New-CabExtractionTab
            $tabControl.TabPages.Add($cabTab)
        }
        
        # Try to add Reports tab
        if (Get-Command -Name New-ReportsTab -ErrorAction SilentlyContinue) {
            $reportsTab = New-ReportsTab
            $tabControl.TabPages.Add($reportsTab)
        }
        
        # Try to add Settings tab
        if (Get-Command -Name New-SettingsTab -ErrorAction SilentlyContinue) {
            $settingsTab = New-SettingsTab
            $tabControl.TabPages.Add($settingsTab)
        }
        
        # Try to add About tab
        if (Get-Command -Name New-AboutTab -ErrorAction SilentlyContinue) {
            $aboutTab = New-AboutTab
            $tabControl.TabPages.Add($aboutTab)
        }
    }
    catch {
        Write-LogSafe -Message "Error adding tab pages: $_" -Level ERROR
        
        [System.Windows.Forms.MessageBox]::Show(
            "Error adding tab pages: $_", 
            "DiagLog Analyzer", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    
    # Add tab control to form
    $form.Controls.Add($tabControl)
    
    # Add method to handle analysis completion
    $form | Add-Member -MemberType ScriptMethod -Name OnAnalysisComplete -Value {
        param($analysisResults)
        
        # Enable search tab
        $tabControl = $this.Controls["MainTabControl"]
        if ($tabControl) {
            $searchTab = $tabControl.TabPages["SearchTab"]
            if ($searchTab) {
                $searchTab.Enabled = $true
                Write-LogSafe -Message "Enabled Search tab" -Level INFO
            }
        }
        
        # Update status
        $statusBar = $this.Controls | Where-Object { $_ -is [System.Windows.Forms.StatusStrip] } | Select-Object -First 1
        if ($statusBar -and $statusBar.Items.Count -gt 0) {
            $statusBar.Items[0].Text = "Analysis complete - Found $($analysisResults.TotalFiles) files"
        }
    }
    
    # Set up form event handlers
    $form.Add_FormClosing({
        # Save settings on close
        try {
            if (Get-Command -Name Save-AppSettings -ErrorAction SilentlyContinue) {
                Save-AppSettings
            }
            Write-LogSafe -Message "Application closing" -Level INFO
        }
        catch {
            # Nothing to do if this fails
        }
    })
    
    # Show the form
    $form.Add_Shown({
        $statusLabel.Text = "Application ready"
    })
    
    # Show the form
    [void]$form.ShowDialog()
    
    return $true
}

# Directly define and export required functions from Settings module
# This ensures they're available even if the module load fails
if (-not (Get-Command -Name Get-AppSetting -ErrorAction SilentlyContinue)) {
    function Get-AppSetting {
        param (
            [Parameter(Mandatory=$true)]
            [string]$Name,
            
            [Parameter(Mandatory=$false)]
            $DefaultValue = $null
        )
        
        if ($null -ne $Global:AppSettings -and 
            $Global:AppSettings.PSObject.Properties.Name -contains $Name) {
            return $Global:AppSettings.$Name
        }
        
        return $DefaultValue
    }
}

# Export functions
Export-ModuleMember -Function Show-MainForm, Get-AppSetting