# DiagLog Analyzer - About Tab
# This module implements the About tab functionality

# Import dependencies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Safe version of Get-AppSetting to handle missing function
function Get-AppSettingSafe {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null
    )
    
    try {
        # Try the normal function
        if (Get-Command -Name Get-AppSetting -ErrorAction SilentlyContinue) {
            return Get-AppSetting -Name $Name -DefaultValue $DefaultValue
        }
        # Try direct access to global variable
        elseif ($null -ne $Global:AppSettings -and $Global:AppSettings.PSObject.Properties.Name -contains $Name) {
            return $Global:AppSettings.$Name
        }
    }
    catch {
        # Just return the default if any error occurs
    }
    
    return $DefaultValue
}

# Safe logging wrapper
function Write-LogSafe {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "AboutTab"
    )
    
    try {
        Write-DLALog -Message $Message -Level $Level -Component $Component
    }
    catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] [$Component] $Message"
    }
}

# Create the About Tab
function New-AboutTab {
    Write-LogSafe -Message "Creating About tab" -Level INFO
    
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = "About"
    $tab.Name = "AboutTab"
    
    # Create main panel for the tab
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.AutoScroll = $true
    
    # Application name and version
    try {
        # Create custom label if function exists
        if (Get-Command -Name New-DLALabel -ErrorAction SilentlyContinue) {
            $lblAppName = New-DLALabel -Text "DiagLog Analyzer" -X 10 -Y 15
            $lblAppName.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
            
            $version = Get-AppSettingSafe -Name "Version" -DefaultValue "1.0.0"
            $lblVersion = New-DLALabel -Text "Version $version" -X 10 -Y 50
            $lblVersion.Font = New-Object System.Drawing.Font("Arial", 10)
        }
        else {
            # Create standard labels
            $lblAppName = New-Object System.Windows.Forms.Label
            $lblAppName.Text = "DiagLog Analyzer"
            $lblAppName.Location = New-Object System.Drawing.Point(10, 15)
            $lblAppName.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
            $lblAppName.AutoSize = $true
            
            $version = Get-AppSettingSafe -Name "Version" -DefaultValue "1.0.0"
            $lblVersion = New-Object System.Windows.Forms.Label
            $lblVersion.Text = "Version $version"
            $lblVersion.Location = New-Object System.Drawing.Point(10, 50)
            $lblVersion.Font = New-Object System.Drawing.Font("Arial", 10)
            $lblVersion.AutoSize = $true
        }
    }
    catch {
        Write-LogSafe -Message "Using standard controls: $_" -Level WARNING
        
        $lblAppName = New-Object System.Windows.Forms.Label
        $lblAppName.Text = "DiagLog Analyzer"
        $lblAppName.Location = New-Object System.Drawing.Point(10, 15)
        $lblAppName.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
        $lblAppName.AutoSize = $true
        
        $lblVersion = New-Object System.Windows.Forms.Label
        $lblVersion.Text = "Version 1.0.0"
        $lblVersion.Location = New-Object System.Drawing.Point(10, 50)
        $lblVersion.Font = New-Object System.Drawing.Font("Arial", 10)
        $lblVersion.AutoSize = $true
    }
    
    # Description section
    $lblDescription = New-Object System.Windows.Forms.Label
    $lblDescription.Text = "Description"
    $lblDescription.Location = New-Object System.Drawing.Point(10, 90)
    $lblDescription.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $lblDescription.AutoSize = $true
    
    $txtDescription = New-Object System.Windows.Forms.TextBox
    $txtDescription.Multiline = $true
    $txtDescription.ReadOnly = $true
    $txtDescription.ScrollBars = "Vertical"
    $txtDescription.BackColor = $panel.BackColor
    $txtDescription.BorderStyle = "None"
    $txtDescription.Location = New-Object System.Drawing.Point(10, 120)
    $txtDescription.Size = New-Object System.Drawing.Size(860, 100)
    $txtDescription.Text = @"
DiagLog Analyzer is a PowerShell-based application for analyzing Windows diagnostic log files, with a focus on handling complex diagnostic data capture structures such as those found in MDM diagnostics.

The application helps you quickly scan and understand complex diagnostic log directory structures, automatically extract CAB files while preserving their context, search across multiple files with filtering by file type, and generate interactive reports of analysis findings.
"@
    
    # Features section
    $lblFeatures = New-Object System.Windows.Forms.Label
    $lblFeatures.Text = "Key Features"
    $lblFeatures.Location = New-Object System.Drawing.Point(10, 230)
    $lblFeatures.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $lblFeatures.AutoSize = $true
    
    $txtFeatures = New-Object System.Windows.Forms.TextBox
    $txtFeatures.Multiline = $true
    $txtFeatures.ReadOnly = $true
    $txtFeatures.ScrollBars = "Vertical"
    $txtFeatures.BackColor = $panel.BackColor
    $txtFeatures.BorderStyle = "None"
    $txtFeatures.Location = New-Object System.Drawing.Point(10, 260)
    $txtFeatures.Size = New-Object System.Drawing.Size(860, 150)
    $txtFeatures.Text = @"
• Folder Structure Analysis: Quickly scan and understand complex diagnostic log directory structures
• Intelligent CAB Extraction: Automatically extract CAB files while preserving their context and relationship to original files
• Smart Content Search: Search across multiple files with filtering by file type, pattern matching, and context display
• Visual Reporting: Generate interactive HTML reports of analysis findings and search results
• Intuitive GUI Interface: Easy-to-use interface that guides users through the analysis process
"@
    
    # System requirements section
    $lblRequirements = New-Object System.Windows.Forms.Label
    $lblRequirements.Text = "System Requirements"
    $lblRequirements.Location = New-Object System.Drawing.Point(10, 420)
    $lblRequirements.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $lblRequirements.AutoSize = $true
    
    $txtRequirements = New-Object System.Windows.Forms.TextBox
    $txtRequirements.Multiline = $true
    $txtRequirements.ReadOnly = $true
    $txtRequirements.ScrollBars = "Vertical"
    $txtRequirements.BackColor = $panel.BackColor
    $txtRequirements.BorderStyle = "None"
    $txtRequirements.Location = New-Object System.Drawing.Point(10, 450)
    $txtRequirements.Size = New-Object System.Drawing.Size(860, 80)
    $txtRequirements.Text = @"
• Windows 10/11
• PowerShell 5.1 or later
• .NET Framework 4.7.2 or later
"@
    
    # Author and contact info
    $lblAuthor = New-Object System.Windows.Forms.Label
    $lblAuthor.Text = "Author"
    $lblAuthor.Location = New-Object System.Drawing.Point(10, 540)
    $lblAuthor.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $lblAuthor.AutoSize = $true
    
    $txtAuthor = New-Object System.Windows.Forms.TextBox
    $txtAuthor.Multiline = $true
    $txtAuthor.ReadOnly = $true
    $txtAuthor.ScrollBars = "Vertical"
    $txtAuthor.BackColor = $panel.BackColor
    $txtAuthor.BorderStyle = "None"
    $txtAuthor.Location = New-Object System.Drawing.Point(10, 570)
    $txtAuthor.Size = New-Object System.Drawing.Size(860, 50)
    $txtAuthor.Text = "Created by Olav Heggelund"
    
    # Add button to open README
    $btnReadme = New-Object System.Windows.Forms.Button
    $btnReadme.Text = "View Full README"
    $btnReadme.Location = New-Object System.Drawing.Point(10, 630)
    $btnReadme.Size = New-Object System.Drawing.Size(120, 30)
    $btnReadme.Add_Click({
        $readmePath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\README.md"
        if (Test-Path $readmePath) {
            try {
                Start-Process $readmePath
            }
            catch {
                try {
                    if (Get-Command -Name Show-DLADialog -ErrorAction SilentlyContinue) {
                        Show-DLADialog -Message "Could not open README file: $_" -Type Warning
                    }
                    else {
                        [System.Windows.Forms.MessageBox]::Show("Could not open README file: $_", "DiagLog Analyzer", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Warning)
                    }
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Could not open README file: $_", "DiagLog Analyzer", 
                        [System.Windows.Forms.MessageBoxButtons]::OK, 
                        [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
            }
        }
        else {
            try {
                if (Get-Command -Name Show-DLADialog -ErrorAction SilentlyContinue) {
                    Show-DLADialog -Message "README file not found" -Type Warning
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show("README file not found", "DiagLog Analyzer", 
                        [System.Windows.Forms.MessageBoxButtons]::OK, 
                        [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("README file not found", "DiagLog Analyzer", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        }
    })
    
    # Add all controls to the panel
    $panel.Controls.AddRange(@(
        $lblAppName, $lblVersion,
        $lblDescription, $txtDescription,
        $lblFeatures, $txtFeatures,
        $lblRequirements, $txtRequirements,
        $lblAuthor, $txtAuthor,
        $btnReadme
    ))
    
    # Add panel to tab
    $tab.Controls.Add($panel)
    
    return $tab
}

# Export functions
Export-ModuleMember -Function New-AboutTab