# DiagLog Analyzer - FileSearch Module
# This module implements functions for searching files in analysis results

# Import FileTypeHandler module if not already loaded
if (-not (Get-Module -Name FileTypeHandler)) {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath "FileTypeHandler.psm1") -ErrorAction SilentlyContinue
}

# Function to search through analysis results
function Search-AnalysisResults {
    param (
        [Parameter(Mandatory=$true)]
        [object]$AnalysisResults,
        
        [Parameter(Mandatory=$true)]
        [string[]]$SearchTerms,
        
        [Parameter(Mandatory=$false)]
        [string[]]$FileExtensions,
        
        [Parameter(Mandatory=$false)]
        [switch]$CaseSensitive,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseRegex,
        
        [Parameter(Mandatory=$false)]
        [switch]$MatchWholeWord,
        
        [Parameter(Mandatory=$false)]
        [int]$ContextLines = 3,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$ProgressHandler = { param($percentComplete) }
    )
    
    # Create results object
    $searchResults = @{
        SearchTerms = $SearchTerms
        StartTime = Get-Date
        FilesSearched = 0
        FilesWithMatches = 0
        FilesSkipped = 0
        TotalMatches = 0
        Results = @()
        EndTime = $null
    }
    
    try {
        Write-DLALog -Message "Starting search with terms: $($SearchTerms -join ', ')" -Level INFO -Component "FileSearch"
        
        # Get all files from analysis results
        $allFiles = $AnalysisResults.FileList
        Write-DLALog -Message "Total files in analysis results: $($allFiles.Count)" -Level INFO -Component "FileSearch"
        
        # Check if FileList is empty or null
        if ($null -eq $allFiles -or $allFiles.Count -eq 0) {
            Write-DLALog -Message "FileList is empty or null. Checking if we need to use a different property." -Level WARNING -Component "FileSearch"
            
            # Try to find files through other means
            if ($AnalysisResults.PSObject.Properties.Name -contains "Files") {
                $allFiles = $AnalysisResults.Files
                Write-DLALog -Message "Using Files property instead. Found $($allFiles.Count) files." -Level INFO -Component "FileSearch"
            }
            elseif ($AnalysisResults.PSObject.Properties.Name -contains "AllFiles") {
                $allFiles = $AnalysisResults.AllFiles
                Write-DLALog -Message "Using AllFiles property instead. Found $($allFiles.Count) files." -Level INFO -Component "FileSearch"
            }
            else {
                # As a last resort, try to derive a file list from FileTypes
                Write-DLALog -Message "No explicit file list found. Attempting to reconstruct from available information." -Level WARNING -Component "FileSearch"
                
                $reconstructedFiles = @()
                $rootPath = $AnalysisResults.FolderPath
                
                Write-DLALog -Message "Root folder path: $rootPath" -Level INFO -Component "FileSearch"
                if (Test-Path -Path $rootPath -PathType Container) {
                    $reconstructedFiles = Get-ChildItem -Path $rootPath -File -Recurse | Select-Object -ExpandProperty FullName
                    Write-DLALog -Message "Reconstructed file list with $($reconstructedFiles.Count) files." -Level INFO -Component "FileSearch"
                    $allFiles = $reconstructedFiles
                }
            }
        }
        
        # Filter by extension if specified
        if ($PSBoundParameters.ContainsKey('FileExtensions') -and $FileExtensions.Count -gt 0) {
            $allFiles = $allFiles | Where-Object {
                $ext = [System.IO.Path]::GetExtension($_)
                $FileExtensions -contains $ext
            }
            
            Write-DLALog -Message "Filtered to $($allFiles.Count) files with extensions: $($FileExtensions -join ', ')" -Level INFO -Component "FileSearch"
        }
        
        # Initialize progress
        $totalFiles = $allFiles.Count
        $filesProcessed = 0
        
        Write-DLALog -Message "Beginning search through $totalFiles files" -Level INFO -Component "FileSearch"
        
        # Process each file
        foreach ($file in $allFiles) {
            $filesProcessed++
            
            # Update progress
            $progressPercent = [Math]::Floor(($filesProcessed / $totalFiles) * 100)
            & $ProgressHandler $progressPercent
            
            if ($filesProcessed % 50 -eq 0 -or $filesProcessed -eq 1 -or $filesProcessed -eq $totalFiles) {
                Write-DLALog -Message "Searching file $filesProcessed of $totalFiles" -Level INFO -Component "FileSearch"
            }
            
            # First check if file exists
            if (-not (Test-Path -Path $file -PathType Leaf)) {
                Write-DLALog -Message "File does not exist, skipping: $file" -Level WARNING -Component "FileSearch"
                
                # Add to results with skip status
                $fileResult = @{
                    FilePath = $file
                    FileSize = 0
                    LastModified = $null
                    FileType = [System.IO.Path]::GetExtension($file)
                    MatchCount = 0
                    Matches = @()
                    Skipped = $true
                    SkipReason = "File does not exist"
                }
                
                $searchResults.Results += $fileResult
                $searchResults.FilesSkipped++
                continue
            }
            
            # Check if it's a binary file - we should implement some basic file type detection
            try {
                $fileExt = [System.IO.Path]::GetExtension($file).ToLower()
                $isBinary = $false
                
                # Quick check for common binary extensions
                $binaryExtensions = @('.exe', '.dll', '.pdb', '.bin', '.cab', '.zip', '.msi', '.sys', '.tmp', '.wim', '.pfx', '.etl')
                if ($binaryExtensions -contains $fileExt) {
                    $isBinary = $true
                }
                
                # If binary, add to results with skip status
                if ($isBinary) {
                    Write-DLALog -Message "Skipping binary file: $file" -Level DEBUG -Component "FileSearch"
                    
                    $fileResult = @{
                        FilePath = $file
                        FileSize = (Get-Item -Path $file).Length
                        LastModified = (Get-Item -Path $file).LastWriteTime
                        FileType = $fileExt
                        MatchCount = 0
                        Matches = @()
                        Skipped = $true
                        SkipReason = "Binary file"
                    }
                    
                    $searchResults.Results += $fileResult
                    $searchResults.FilesSkipped++
                    continue
                }
                
                # Get file info
                $fileInfo = Get-Item -Path $file
                $fileResult = @{
                    FilePath = $file
                    FileSize = $fileInfo.Length
                    LastModified = $fileInfo.LastWriteTime
                    FileType = $fileExt
                    MatchCount = 0
                    Matches = @()
                    Skipped = $false
                    SkipReason = $null
                }
                
                # Check if file is too large
                if ($fileInfo.Length -gt 10MB) {
                    Write-DLALog -Message "File is large ($(($fileInfo.Length/1MB).ToString('0.00')) MB), might take longer: $file" -Level DEBUG -Component "FileSearch"
                }
                
                # Read file content - implement a more robust approach
                try {
                    # First try to read all text
                    $content = Get-Content -Path $file -Raw -ErrorAction Stop
                    $lines = $content -split "`r?`n"
                    
                    # Search for each term
                    $matchesFound = 0
                    $matchDetails = @()
                    
                    foreach ($term in $SearchTerms) {
                        Write-DLALog -Message "Searching for '$term' in $file" -Level DEBUG -Component "FileSearch"
                        
                        for ($i = 0; $i -lt $lines.Count; $i++) {
                            $line = $lines[$i]
                            $found = $false
                            
                            if ($CaseSensitive) {
                                $found = $line.Contains($term)
                            } else {
                                $found = $line.ToLower().Contains($term.ToLower())
                            }
                            
                            if ($found) {
                                $matchesFound++
                                
                                # Get context lines
                                $contextStart = [Math]::Max(0, $i - $ContextLines)
                                $contextEnd = [Math]::Min($lines.Count - 1, $i + $ContextLines)
                                $context = @()
                                
                                for ($j = $contextStart; $j -le $contextEnd; $j++) {
                                    $context += @{
                                        LineNumber = $j + 1  # Line numbers are 1-based
                                        Content = $lines[$j]
                                    }
                                }
                                
                                $matchDetails += @{
                                    LineNumber = $i + 1  # Line numbers are 1-based
                                    Line = $line
                                    Context = $context
                                    Term = $term
                                }
                                
                                # For large files, don't capture too many matches
                                if ($matchesFound -ge 100 -and $fileInfo.Length -gt 1MB) {
                                    Write-DLALog -Message "Many matches found in large file, limiting to 100: $file" -Level WARNING -Component "FileSearch"
                                    break
                                }
                            }
                        }
                        
                        # Limit search to first term if we found too many matches
                        if ($matchesFound -ge 100 -and $fileInfo.Length -gt 1MB) {
                            break
                        }
                    }
                    
                    # Update file result with matches
                    $fileResult.MatchCount = $matchesFound
                    $fileResult.Matches = $matchDetails
                    
                    # Update search results
                    if ($matchesFound -gt 0) {
                        $searchResults.FilesWithMatches++
                        $searchResults.TotalMatches += $matchesFound
                        Write-DLALog -Message "Found $matchesFound matches in $file" -Level DEBUG -Component "FileSearch"
                    }
                }
                catch {
                    Write-DLALog -Message "Error reading file content: $file - $($_.Exception.Message)" -Level ERROR -Component "FileSearch"
                    
                    # Update file result with error
                    $fileResult.Skipped = $true
                    $fileResult.SkipReason = "Error reading file: $($_.Exception.Message)"
                    $searchResults.FilesSkipped++
                }
                
                # Add file result to results
                $searchResults.Results += $fileResult
                $searchResults.FilesSearched++
            }
            catch {
                Write-DLALog -Message "Error processing file: $file - $($_.Exception.Message)" -Level ERROR -Component "FileSearch"
                
                # Add to results with error status
                $fileResult = @{
                    FilePath = $file
                    FileSize = 0
                    LastModified = $null
                    FileType = [System.IO.Path]::GetExtension($file)
                    MatchCount = 0
                    Matches = @()
                    Skipped = $true
                    SkipReason = "Error: $($_.Exception.Message)"
                }
                
                $searchResults.Results += $fileResult
                $searchResults.FilesSkipped++
            }
        }
        
        # Simple file search function in case Search-File isn't available
        function Search-File {
            param (
                [Parameter(Mandatory=$true)]
                [string]$FilePath,
                
                [Parameter(Mandatory=$true)]
                [string[]]$SearchTerms,
                
                [Parameter(Mandatory=$false)]
                [switch]$CaseSensitive,
                
                [Parameter(Mandatory=$false)]
                [switch]$UseRegex,
                
                [Parameter(Mandatory=$false)]
                [switch]$MatchWholeWord,
                
                [Parameter(Mandatory=$false)]
                [int]$ContextLines = 3,
                
                [Parameter(Mandatory=$false)]
                [scriptblock]$ProgressHandler = { param($pc) }
            )
            
            # Default result structure
            $result = @{
                FilePath = $FilePath
                FileSize = 0
                LastModified = $null
                FileType = [System.IO.Path]::GetExtension($FilePath)
                MatchCount = 0
                Matches = @()
                Skipped = $false
                SkipReason = $null
            }
            
            try {
                # Get file info
                $fileInfo = Get-Item -Path $FilePath
                $result.FileSize = $fileInfo.Length
                $result.LastModified = $fileInfo.LastWriteTime
                
                # Check if file is too large
                if ($fileInfo.Length -gt 10MB) {
                    Write-DLALog -Message "File is large, might take longer: $FilePath" -Level DEBUG -Component "FileSearch"
                }
                
                # Read file content
                $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
                $lines = $content -split "`r?`n"
                
                # Search for each term
                $matchesFound = 0
                $matchDetails = @()
                
                foreach ($term in $SearchTerms) {
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        $found = $false
                        
                        if ($CaseSensitive) {
                            $found = $line.Contains($term)
                        } else {
                            $found = $line.ToLower().Contains($term.ToLower())
                        }
                        
                        if ($found) {
                            $matchesFound++
                            
                            # Get context lines
                            $contextStart = [Math]::Max(0, $i - $ContextLines)
                            $contextEnd = [Math]::Min($lines.Count - 1, $i + $ContextLines)
                            $context = @()
                            
                            for ($j = $contextStart; $j -le $contextEnd; $j++) {
                                $context += @{
                                    LineNumber = $j + 1  # Line numbers are 1-based
                                    Content = $lines[$j]
                                }
                            }
                            
                            $matchDetails += @{
                                LineNumber = $i + 1  # Line numbers are 1-based
                                Line = $line
                                Context = $context
                                Term = $term
                            }
                            
                            # For large files, don't capture too many matches
                            if ($matchesFound -ge 100 -and $fileInfo.Length -gt 1MB) {
                                break
                            }
                        }
                    }
                    
                    # Limit search to first term if we found too many matches
                    if ($matchesFound -ge 100 -and $fileInfo.Length -gt 1MB) {
                        break
                    }
                }
                
                # Update result with matches
                $result.MatchCount = $matchesFound
                $result.Matches = $matchDetails
            }
            catch {
                Write-DLALog -Message "Error searching file: $FilePath - $($_.Exception.Message)" -Level ERROR -Component "FileSearch"
                
                # Update result with error
                $result.Skipped = $true
                $result.SkipReason = "Error: $($_.Exception.Message)"
            }
            
            return $result
        }
        
        # Finalize results
        $searchResults.EndTime = Get-Date
        $duration = $searchResults.EndTime - $searchResults.StartTime
        
        Write-DLALog -Message "Search completed in $($duration.TotalSeconds.ToString('0.00')) seconds. Found $($searchResults.TotalMatches) matches in $($searchResults.FilesWithMatches) files." -Level INFO -Component "FileSearch"
        
        return $searchResults
    }
    catch {
        Write-DLALog -Message "Error during search: $($_.Exception.Message)" -Level ERROR -Component "FileSearch"
        
        # Complete results with error info
        $searchResults.EndTime = Get-Date
        $searchResults.Error = $_.Exception.Message
        
        return $searchResults
    }
}

# Function to register a search report with the Reports tab
function Register-SearchReport {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReportPath,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchTerms
    )
    
    try {
        # Check if the form has a Reports registry
        $form = [System.Windows.Forms.Form]::ActiveForm
        
        if ($form -and ($form | Get-Member -Name "RegisterReport" -MemberType ScriptMethod)) {
            # Call the form's method to register the report
            $form.RegisterReport(
                [PSCustomObject]@{
                    Type = "Search"
                    Path = $ReportPath
                    Name = "Search: $SearchTerms"
                    CreatedDate = Get-Date
                    Description = "Search results for terms: $SearchTerms"
                }
            )
            
            Write-DLALog -Message "Registered search report: $ReportPath" -Level INFO -Component "FileSearch"
            return $true
        }
        
        # Fall back to direct tab update if available
        $tabControl = $form.Controls["MainTabControl"]
        if ($tabControl) {
            $reportsTab = $tabControl.TabPages["ReportsTab"]
            if ($reportsTab -and ($reportsTab | Get-Member -Name "AddReport" -MemberType ScriptMethod)) {
                $reportsTab.AddReport(
                    [PSCustomObject]@{
                        Type = "Search"
                        Path = $ReportPath
                        Name = "Search: $SearchTerms"
                        CreatedDate = Get-Date
                        Description = "Search results for terms: $SearchTerms"
                    }
                )
                
                Write-DLALog -Message "Added search report to Reports tab: $ReportPath" -Level INFO -Component "FileSearch"
                return $true
            }
        }
        
        # Couldn't register
        Write-DLALog -Message "No method available to register report with Reports tab" -Level WARNING -Component "FileSearch"
        return $false
    }
    catch {
        Write-DLALog -Message "Error registering search report: $($_.Exception.Message)" -Level ERROR -Component "FileSearch"
        return $false
    }
}

# Function to create an HTML search report
function New-HtmlSearchReport {
    param (
        [Parameter(Mandatory=$true)]
        $SearchResults,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchTerms
    )
    
    # Get current date/time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Start building HTML
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog Analyzer - Search Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2, h3 { color: #2c3e50; }
        .summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .file-section { margin-bottom: 30px; border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        .file-header { background-color: #f1f1f1; padding: 10px; margin-bottom: 15px; border-radius: 3px; }
        .match { margin-bottom: 15px; border-left: 3px solid #3498db; padding-left: 10px; }
        .match-line { background-color: #e8f4f8; padding: 5px; font-family: Consolas, monospace; white-space: pre-wrap; }
        .context-line { font-family: Consolas, monospace; padding: 5px; white-space: pre-wrap; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .highlight { background-color: #ffeb3b; font-weight: bold; }
    </style>
</head>
<body>
    <h1>DiagLog Analyzer - Search Report</h1>
    <p>Generated: $timestamp</p>
    
    <div class="summary">
        <h2>Search Summary</h2>
        <p><strong>Search Terms:</strong> $SearchTerms</p>
        <p><strong>Total Files Searched:</strong> $($SearchResults.FilesSearched)</p>
        <p><strong>Files With Matches:</strong> $($SearchResults.FilesWithMatches)</p>
        <p><strong>Total Matches:</strong> $($SearchResults.TotalMatches)</p>
        <p><strong>Files Skipped:</strong> $($SearchResults.FilesSkipped)</p>
        <p><strong>Search Duration:</strong> $(($SearchResults.EndTime - $SearchResults.StartTime).TotalSeconds.ToString('0.00')) seconds</p>
    </div>
    
    <h2>Matching Files</h2>
    <table>
        <tr>
            <th>File</th>
            <th>Matches</th>
            <th>File Type</th>
            <th>Size (KB)</th>
            <th>Last Modified</th>
        </tr>
"@

    # Add table rows for matching files
    $matchingFiles = $SearchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 } | Sort-Object -Property MatchCount -Descending
    
    foreach ($file in $matchingFiles) {
        $fileName = Split-Path -Path $file.FilePath -Leaf
        $fileSizeKB = [Math]::Round($file.FileSize / 1KB, 2)
        $lastModified = $file.LastModified
        
        $html += @"
        <tr>
            <td>$([System.Web.HttpUtility]::HtmlEncode($fileName))</td>
            <td>$($file.MatchCount)</td>
            <td>$($file.FileType)</td>
            <td>$fileSizeKB</td>
            <td>$lastModified</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
    
    <h2>Match Details</h2>
"@

    # Add detailed sections for each file
    foreach ($file in $matchingFiles) {
        $fileName = Split-Path -Path $file.FilePath -Leaf
        $filePath = $file.FilePath
        $fileSizeKB = [Math]::Round($file.FileSize / 1KB, 2)
        
        $html += @"
    <div class="file-section">
        <div class="file-header">
            <h3>$([System.Web.HttpUtility]::HtmlEncode($fileName))</h3>
            <p><strong>Path:</strong> $([System.Web.HttpUtility]::HtmlEncode($filePath))</p>
            <p><strong>Matches:</strong> $($file.MatchCount) | <strong>File Type:</strong> $($file.FileType) | <strong>Size:</strong> $fileSizeKB KB</p>
        </div>
"@

        # Add match details
        if ($file.Matches -and $file.Matches.Count -gt 0) {
            foreach ($match in $file.Matches) {
                $html += @"
        <div class="match">
            <p><strong>Match at line $($match.LineNumber)</strong></p>
"@

                if ($match.Context -and $match.Context.Count -gt 0) {
                    foreach ($line in $match.Context) {
                        if ($line.LineNumber -eq $match.LineNumber) {
                            # Highlight the matching line
                            $html += "            <div class='match-line'>$([System.Web.HttpUtility]::HtmlEncode($line.Content))</div>`n"
                        } else {
                            $html += "            <div class='context-line'>$([System.Web.HttpUtility]::HtmlEncode($line.Content))</div>`n"
                        }
                    }
                } else {
                    # Just show the match line if no context
                    $html += "            <div class='match-line'>$([System.Web.HttpUtility]::HtmlEncode($match.Line))</div>`n"
                }

                $html += "        </div>`n"
            }
        } else {
            $html += "        <p>No detailed match information available.</p>`n"
        }
        
        $html += "    </div>`n"
    }
    
    # Close HTML
    $html += @"
</body>
</html>
"@

    return $html
}

# Function to create a text search report
function New-TextSearchReport {
    param (
        [Parameter(Mandatory=$true)]
        $SearchResults,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchTerms
    )
    
    # Get current date/time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Start building text report
    $text = @"
DiagLog Analyzer - Search Report
===============================
Generated: $timestamp

Search Summary
-------------
Search Terms: $SearchTerms
Total Files Searched: $($SearchResults.FilesSearched)
Files With Matches: $($SearchResults.FilesWithMatches)
Total Matches: $($SearchResults.TotalMatches)
Files Skipped: $($SearchResults.FilesSkipped)
Search Duration: $(($SearchResults.EndTime - $SearchResults.StartTime).TotalSeconds.ToString('0.00')) seconds

Matching Files
-------------
"@

    # Add matching files summary
    $matchingFiles = $SearchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 } | Sort-Object -Property MatchCount -Descending
    
    foreach ($file in $matchingFiles) {
        $fileName = Split-Path -Path $file.FilePath -Leaf
        $fileSizeKB = [Math]::Round($file.FileSize / 1KB, 2)
        
        $text += @"
File: $fileName
Path: $($file.FilePath)
Matches: $($file.MatchCount) | Type: $($file.FileType) | Size: $fileSizeKB KB | Modified: $($file.LastModified)

"@
    }
    
    $text += @"

Match Details
============

"@

    # Add detailed sections for each file
    foreach ($file in $matchingFiles) {
        $fileName = Split-Path -Path $file.FilePath -Leaf
        
        $text += @"
FILE: $fileName
===============================
Path: $($file.FilePath)
Matches: $($file.MatchCount)

"@

        # Add match details
        if ($file.Matches -and $file.Matches.Count -gt 0) {
            foreach ($match in $file.Matches) {
                $text += @"
Match at line $($match.LineNumber):
-------------------------------

"@

                if ($match.Context -and $match.Context.Count -gt 0) {
                    foreach ($line in $match.Context) {
                        if ($line.LineNumber -eq $match.LineNumber) {
                            # Mark the matching line
                            $text += "> $($line.Content)`n"
                        } else {
                            $text += "  $($line.Content)`n"
                        }
                    }
                } else {
                    # Just show the match line if no context
                    $text += "> $($match.Line)`n"
                }

                $text += "`n"
            }
        } else {
            $text += "No detailed match information available.`n"
        }
        
        $text += "`n-------------------------------`n`n"
    }
    
    return $text
}

# Function to create a CSV search report
function New-CsvSearchReport {
    param (
        [Parameter(Mandatory=$true)]
        $SearchResults,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    # Create directory if needed
    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    # Create a summary report
    $summaryPath = [System.IO.Path]::ChangeExtension($OutputPath, "summary.csv")
    
    $summary = [PSCustomObject]@{
        SearchTerms = ($SearchResults.SearchTerms -join ", ")
        StartTime = $SearchResults.StartTime
        EndTime = $SearchResults.EndTime
        DurationSeconds = ($SearchResults.EndTime - $SearchResults.StartTime).TotalSeconds
        FilesSearched = $SearchResults.FilesSearched
        FilesWithMatches = $SearchResults.FilesWithMatches
        TotalMatches = $SearchResults.TotalMatches
        FilesSkipped = $SearchResults.FilesSkipped
    }
    
    $summary | Export-Csv -Path $summaryPath -NoTypeInformation
    
    # Create file matches report
    $matchingFiles = $SearchResults.Results | Where-Object { -not $_.Skipped } | ForEach-Object {
        [PSCustomObject]@{
            FilePath = $_.FilePath
            FileName = Split-Path -Path $_.FilePath -Leaf
            MatchCount = $_.MatchCount
            FileType = $_.FileType
            FileSize = $_.FileSize
            FileSizeKB = [Math]::Round($_.FileSize / 1KB, 2)
            LastModified = $_.LastModified
            Skipped = $_.Skipped
            SkipReason = $_.SkipReason
        }
    }
    
    $matchingFiles | Export-Csv -Path $OutputPath -NoTypeInformation
    
    # Create detailed matches report for files with matches
    $matchesPath = [System.IO.Path]::ChangeExtension($OutputPath, "details.csv")
    
    $matchDetails = @()
    foreach ($file in ($SearchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 })) {
        $fileName = Split-Path -Path $file.FilePath -Leaf
        
        foreach ($match in $file.Matches) {
            $matchDetails += [PSCustomObject]@{
                FilePath = $file.FilePath
                FileName = $fileName
                LineNumber = $match.LineNumber
                Line = $match.Line
                FileType = $file.FileType
                SearchTerm = $match.Term
            }
        }
    }
    
    if ($matchDetails.Count -gt 0) {
        $matchDetails | Export-Csv -Path $matchesPath -NoTypeInformation
    }
    
    # Optional: Return an object with all export paths for reference
    return [PSCustomObject]@{
        SummaryReport = $summaryPath
        FileMatchesReport = $OutputPath
        MatchDetailsReport = $matchesPath
    }
}

# Export the functions
Export-ModuleMember -Function @(
    'Search-AnalysisResults',
    'Register-SearchReport',
    'New-HtmlSearchReport',
    'New-TextSearchReport',
    'New-CsvSearchReport'
)