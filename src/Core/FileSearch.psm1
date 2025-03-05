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
        
        # Process each file
        foreach ($file in $allFiles) {
            $filesProcessed++
            
            # Update progress
            $progressPercent = [Math]::Floor(($filesProcessed / $totalFiles) * 100)
            & $ProgressHandler $progressPercent
            
            Write-DLALog -Message "Searching file $filesProcessed of $totalFiles : $file" -Level DEBUG -Component "FileSearch"
            
            # Search the file
            $fileResults = Search-File -FilePath $file -SearchTerms $SearchTerms `
                -CaseSensitive:$CaseSensitive -UseRegex:$UseRegex -MatchWholeWord:$MatchWholeWord `
                -ContextLines $ContextLines -ProgressHandler { param($pc) }
            
            # Add to results
            $searchResults.Results += $fileResults
            $searchResults.FilesSearched++
            
            # Update counters
            if ($fileResults.Skipped) {
                $searchResults.FilesSkipped++
            }
            elseif ($fileResults.MatchCount -gt 0) {
                $searchResults.FilesWithMatches++
                $searchResults.TotalMatches += $fileResults.MatchCount
            }
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
            }
        }
    }
    
    if ($matchDetails.Count -gt 0) {
        $matchDetails | Export-Csv -Path $matchesPath -NoTypeInformation
    }
    
    return $true
}

# Export the functions
Export-ModuleMember -Function @(
    'Search-AnalysisResults',
    'Register-SearchReport',
    'New-HtmlSearchReport',
    'New-TextSearchReport',
    'New-CsvSearchReport'
)