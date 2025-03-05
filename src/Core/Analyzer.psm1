# DiagLog Analyzer - Core Analysis Module
# This module handles the analysis of diagnostic log folders

# Function to start folder analysis
function Start-FolderAnalysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSubFolders = $true
    )
    
    try {
        Write-DLALog -Message "Starting folder analysis for: $FolderPath" -Level INFO -Component "Analyzer"
        Write-DLALog -Message "Include subfolders: $IncludeSubFolders" -Level INFO -Component "Analyzer"
        
        # Initialize results object
        $results = [PSCustomObject]@{
            FolderPath = $FolderPath
            StartTime = Get-Date
            EndTime = $null
            TotalFiles = 0
            SubfolderCount = 0
            FileTypes = @{}
            FilePaths = @()
            LargeFiles = @()
            FilesByExtension = @{}
            DiagnosticFileInfo = @{}
        }
        
        # Get subfolders if requested
        $folders = @($FolderPath)
        if ($IncludeSubFolders) {
            $subfolders = Get-ChildItem -Path $FolderPath -Directory -Recurse | Select-Object -ExpandProperty FullName
            $folders += $subfolders
            $results.SubfolderCount = $subfolders.Count
        }
        
        Write-DLALog -Message "Found $($results.SubfolderCount) subfolders" -Level INFO -Component "Analyzer"
        
        # Initialize counters
        $totalFiles = 0
        $fileTypes = @{}
        $filePaths = @()
        $largeFiles = @()
        $filesByExtension = @{}
        
        # Process each folder
        foreach ($folder in $folders) {
            $files = Get-ChildItem -Path $folder -File
            
            foreach ($file in $files) {
                $totalFiles++
                $filePaths += $file.FullName
                
                # Track file types (extensions)
                $extension = $file.Extension.ToLower()
                if ([string]::IsNullOrEmpty($extension)) {
                    $extension = "(no extension)"
                }
                
                if ($fileTypes.ContainsKey($extension)) {
                    $fileTypes[$extension]++
                }
                else {
                    $fileTypes[$extension] = 1
                }
                
                # Group files by extension
                if (-not $filesByExtension.ContainsKey($extension)) {
                    $filesByExtension[$extension] = @()
                }
                $filesByExtension[$extension] += $file.FullName
                
                # Track large files (over 10MB)
                if ($file.Length -gt 10MB) {
                    $largeFiles += [PSCustomObject]@{
                        Path = $file.FullName
                        Size = $file.Length
                        SizeInMB = [Math]::Round($file.Length / 1MB, 2)
                    }
                }
                
                # Special handling for common diagnostic file types
                switch ($extension) {
                    ".log" {
                        # Process log files
                        ProcessLogFile -FilePath $file.FullName -Results $results
                    }
                    ".evt" {
                        # Process event files
                        ProcessEventFile -FilePath $file.FullName -Results $results
                    }
                    ".etl" {
                        # Process ETL files
                        ProcessEtlFile -FilePath $file.FullName -Results $results
                    }
                    ".reg" {
                        # Process registry files
                        ProcessRegFile -FilePath $file.FullName -Results $results
                    }
                }
            }
        }
        
        # Update results
        $results.TotalFiles = $totalFiles
        $results.FileTypes = $fileTypes
        $results.FilePaths = $filePaths
        $results.LargeFiles = $largeFiles
        $results.FilesByExtension = $filesByExtension
        $results.EndTime = Get-Date
        
        # Log success
        $duration = ($results.EndTime - $results.StartTime).TotalSeconds
        Write-DLALog -Message "Analysis completed in $duration seconds. Found $totalFiles files." -Level INFO -Component "Analyzer"
        
        return $results
    }
    catch {
        Write-DLALog -Message "Error in Start-FolderAnalysis: $_" -Level ERROR -Component "Analyzer"
        throw $_
    }
}

# Helper function to process log files
function ProcessLogFile {
    param (
        [string]$FilePath,
        [PSCustomObject]$Results
    )
    
    # TODO: Add specific log file processing logic
    # This is just a placeholder - you would add actual log parsing code here
    
    # Add to diagnostic file info if not already tracked
    if (-not $Results.DiagnosticFileInfo.ContainsKey("LogFiles")) {
        $Results.DiagnosticFileInfo["LogFiles"] = @()
    }
    
    $Results.DiagnosticFileInfo["LogFiles"] += $FilePath
}

# Helper function to process event files
function ProcessEventFile {
    param (
        [string]$FilePath,
        [PSCustomObject]$Results
    )
    
    # TODO: Add specific event file processing logic
    
    # Add to diagnostic file info if not already tracked
    if (-not $Results.DiagnosticFileInfo.ContainsKey("EventFiles")) {
        $Results.DiagnosticFileInfo["EventFiles"] = @()
    }
    
    $Results.DiagnosticFileInfo["EventFiles"] += $FilePath
}

# Helper function to process ETL files
function ProcessEtlFile {
    param (
        [string]$FilePath,
        [PSCustomObject]$Results
    )
    
    # TODO: Add specific ETL file processing logic
    
    # Add to diagnostic file info if not already tracked
    if (-not $Results.DiagnosticFileInfo.ContainsKey("EtlFiles")) {
        $Results.DiagnosticFileInfo["EtlFiles"] = @()
    }
    
    $Results.DiagnosticFileInfo["EtlFiles"] += $FilePath
}

# Helper function to process registry files
function ProcessRegFile {
    param (
        [string]$FilePath,
        [PSCustomObject]$Results
    )
    
    # TODO: Add specific registry file processing logic
    
    # Add to diagnostic file info if not already tracked
    if (-not $Results.DiagnosticFileInfo.ContainsKey("RegFiles")) {
        $Results.DiagnosticFileInfo["RegFiles"] = @()
    }
    
    $Results.DiagnosticFileInfo["RegFiles"] += $FilePath
}

# Function to get analysis summary
function Get-AnalysisSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AnalysisResults
    )
    
    try {
        $summary = "Analysis Results for: $($AnalysisResults.FolderPath)`r`n"
        $summary += "======================================================`r`n`r`n"
        
        # Add basic stats
        $duration = ($AnalysisResults.EndTime - $AnalysisResults.StartTime).TotalSeconds
        $summary += "Analysis Duration: $([Math]::Round($duration, 2)) seconds`r`n"
        $summary += "Total Files: $($AnalysisResults.TotalFiles)`r`n"
        $summary += "Subfolder Count: $($AnalysisResults.SubfolderCount)`r`n`r`n"
        
        # Add file types
        $summary += "File Types Summary:`r`n"
        $summary += "---------------------`r`n"
        foreach ($type in $AnalysisResults.FileTypes.Keys | Sort-Object) {
            $count = $AnalysisResults.FileTypes[$type]
            $summary += "  $type : $count files`r`n"
        }
        
        # Add large files
        if ($AnalysisResults.LargeFiles.Count -gt 0) {
            $summary += "`r`nLarge Files (>10MB):`r`n"
            $summary += "---------------------`r`n"
            foreach ($file in $AnalysisResults.LargeFiles | Sort-Object -Property Size -Descending) {
                $summary += "  $($file.Path) - $($file.SizeInMB) MB`r`n"
            }
        }
        
        # Add diagnostic file info
        $summary += "`r`nDiagnostic File Summary:`r`n"
        $summary += "---------------------`r`n"
        
        foreach ($category in $AnalysisResults.DiagnosticFileInfo.Keys | Sort-Object) {
            $files = $AnalysisResults.DiagnosticFileInfo[$category]
            $summary += "  $category : $($files.Count) files`r`n"
        }
        
        return $summary
    }
    catch {
        Write-DLALog -Message "Error in Get-AnalysisSummary: $_" -Level ERROR -Component "Analyzer"
        return "Error generating analysis summary: $_"
    }
}

# Export functions
Export-ModuleMember -Function Start-FolderAnalysis, Get-AnalysisSummary