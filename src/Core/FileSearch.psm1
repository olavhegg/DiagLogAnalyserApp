# DiagLog Analyzer - File Search Module
# This module handles searching through files for specific text

# Import dependencies using relative paths from module root
$modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Import required modules
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Utils\Logging.psm1") -Force
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Utils\FileSystem.psm1") -Force
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Config\Settings.psm1") -Force

# Function to search for text in a single file
function Search-TextInFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchText,
        
        [int]$ContextLinesBefore = 2,
        
        [int]$ContextLinesAfter = 2,
        
        [switch]$CaseSensitive = $false
    )
    
    try {
        # Check if file exists
        if (-not (Test-Path -Path $FilePath)) {
            return $null
        }
        
        # Get file size and check if it's too large
        $fileInfo = Get-Item -Path $FilePath
        $maxFileSize = Get-AppSetting -Name "MaxFileSizeForTextSearch"
        
        if ($fileInfo.Length -gt $maxFileSize) {
            Write-Log -Message "Skipping large file ($($fileInfo.Length) bytes): $FilePath" -Level INFO -Component "FileSearch"
            return [PSCustomObject]@{
                FilePath = $FilePath
                Matches = @()
                MatchCount = 0
                Skipped = $true
                SkipReason = "File too large"
            }
        }
        
        # Check if it's a binary file
        $fileType = Get-FileType -FilePath $FilePath
        if ($fileType -ne "text") {
            Write-Log -Message "Skipping non-text file ($fileType): $FilePath" -Level INFO -Component "FileSearch"
            return [PSCustomObject]@{
                FilePath = $FilePath
                Matches = @()
                MatchCount = 0
                Skipped = $true
                SkipReason = "Non-text file"
            }
        }
        
        # Read file content
        $content = Get-Content -Path $FilePath -ErrorAction Stop
        
        # Prepare regex options
        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
        if (-not $CaseSensitive) {
            $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }
        
        # Escape the search text for regex
        $searchPattern = [regex]::Escape($SearchText)
        
        # Find all matches with line numbers
        $matchingLines = @()
        $totalMatches = 0
        
        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i]
            
            if ($line -match $searchPattern) {
                $totalMatches++
                
                # Get context lines before
                $beforeLines = @()
                for ($j = [Math]::Max(0, $i - $ContextLinesBefore); $j -lt $i; $j++) {
                    $beforeLines += [PSCustomObject]@{
                        LineNumber = $j + 1
                        Text = $content[$j]
                        IsMatch = $false
                    }
                }
                
                # Current matching line
                $matchLine = [PSCustomObject]@{
                    LineNumber = $i + 1
                    Text = $line
                    IsMatch = $true
                }
                
                # Get context lines after
                $afterLines = @()
                for ($j = $i + 1; $j -lt [Math]::Min($content.Count, $i + 1 + $ContextLinesAfter); $j++) {
                    $afterLines += [PSCustomObject]@{
                        LineNumber = $j + 1
                        Text = $content[$j]
                        IsMatch = $false
                    }
                }
                
                # Create match context object
                $matchContext = [PSCustomObject]@{
                    MatchLineNumber = $i + 1
                    MatchLine = $line
                    BeforeContext = $beforeLines
                    AfterContext = $afterLines
                    AllLines = ($beforeLines + $matchLine + $afterLines)
                }
                
                $matchingLines += $matchContext
                
                # Limit results to avoid overwhelming with too many matches
                if ($matchingLines.Count -ge 100) {
                    Write-Log -Message "Reached maximum match limit (100) for file: $FilePath" -Level INFO -Component "FileSearch"
                    break
                }
            }
        }
        
        return [PSCustomObject]@{
            FilePath = $FilePath
            Matches = $matchingLines
            MatchCount = $totalMatches
            Skipped = $false
            SkipReason = $null
        }
    }
    catch {
        Write-Log -Message "Error searching file $FilePath : $_" -Level ERROR -Component "FileSearch"
        return [PSCustomObject]@{
            FilePath = $FilePath
            Matches = @()
            MatchCount = 0
            Skipped = $true
            SkipReason = "Error: $_"
        }
    }
}

# Function to search for text in multiple files
function Search-TextInFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FilePaths,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchText,
        
        [string[]]$FileTypesToInclude = @(),
        
        [string[]]$FileTypesToExclude = @(),
        
        [int]$ContextLinesBefore = 2,
        
        [int]$ContextLinesAfter = 2,
        
        [switch]$CaseSensitive = $false,
        
        [switch]$IncludeSkipped = $false
    )
    
    Write-Log -Message "Searching for '$SearchText' in $($FilePaths.Count) files" -Level INFO -Component "FileSearch"
    
    $results = @()
    $fileCount = 0
    $matchCount = 0
    $skippedCount = 0
    
    foreach ($file in $FilePaths) {
        # Check file extension against inclusion/exclusion lists
        $extension = [System.IO.Path]::GetExtension($file).ToLower()
        
        if ($FileTypesToInclude.Count -gt 0 -and $extension -notin $FileTypesToInclude) {
            $skippedCount++
            continue
        }
        
        if ($FileTypesToExclude.Count -gt 0 -and $extension -in $FileTypesToExclude) {
            $skippedCount++
            continue
        }
        
        $fileCount++
        
        # Search the file
        $searchResult = Search-TextInFile -FilePath $file -SearchText $SearchText `
            -ContextLinesBefore $ContextLinesBefore -ContextLinesAfter $ContextLinesAfter `
            -CaseSensitive:$CaseSensitive
        
        if ($null -ne $searchResult) {
            if ($searchResult.Skipped) {
                $skippedCount++
                if ($IncludeSkipped) {
                    $results += $searchResult
                }
            }
            elseif ($searchResult.MatchCount -gt 0) {
                $matchCount += $searchResult.MatchCount
                $results += $searchResult
            }
        }
    }
    
    Write-Log -Message "Search completed. Found $matchCount matches in $($results.Count) files. Skipped $skippedCount files." -Level INFO -Component "FileSearch"
    
    return [PSCustomObject]@{
        SearchText = $SearchText
        TotalFiles = $FilePaths.Count
        FilesProcessed = $fileCount
        FilesWithMatches = ($results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 }).Count
        FilesSkipped = $skippedCount
        TotalMatches = $matchCount
        Results = $results
    }
}

# Function to search in analysis results
function Search-AnalysisResults {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$AnalysisResults,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchText,
        
        [string[]]$ExtensionsToInclude = @(),
        
        [string[]]$ExtensionsToExclude = @(),
        
        [string[]]$FileTypesToInclude = @(),
        
        [string[]]$FileTypesToExclude = @(),
        
        [int]$ContextLinesBefore = 2,
        
        [int]$ContextLinesAfter = 2,
        
        [switch]$CaseSensitive = $false,
        
        [switch]$IncludeExtractedCabs = $true
    )
    
    Write-Log -Message "Starting search in analysis results for: $SearchText" -Level INFO -Component "FileSearch"
    
    # Get all files to search
    $filesToSearch = @()
    
    # Add files from the main analysis
    $allFiles = Get-ChildItem -Path $AnalysisResults.SourcePath -Recurse -File
    
    foreach ($file in $allFiles) {
        $extension = $file.Extension.ToLower()
        
        # Apply extension filters
        if ($ExtensionsToInclude.Count -gt 0 -and $extension -notin $ExtensionsToInclude) {
            continue
        }
        
        if ($ExtensionsToExclude.Count -gt 0 -and $extension -in $ExtensionsToExclude) {
            continue
        }
        
        # Add to search list
        $filesToSearch += $file.FullName
    }
    
    # Also search in extracted CAB files if requested
    if ($IncludeExtractedCabs) {
        foreach ($cabFile in $AnalysisResults.CabFiles) {
            if ($cabFile.Processed -and $cabFile.ExtractionSuccess -and $null -ne $cabFile.ExtractedPath) {
                $extractedFiles = Get-ChildItem -Path $cabFile.ExtractedPath -Recurse -File
                
                foreach ($file in $extractedFiles) {
                    $extension = $file.Extension.ToLower()
                    
                    # Apply extension filters
                    if ($ExtensionsToInclude.Count -gt 0 -and $extension -notin $ExtensionsToInclude) {
                        continue
                    }
                    
                    if ($ExtensionsToExclude.Count -gt 0 -and $extension -in $ExtensionsToExclude) {
                        continue
                    }
                    
                    # Add to search list
                    $filesToSearch += $file.FullName
                }
            }
        }
    }
    
    Write-Log -Message "Prepared search list with $($filesToSearch.Count) files" -Level INFO -Component "FileSearch"
    
    # Execute search
    $searchResults = Search-TextInFiles -FilePaths $filesToSearch -SearchText $SearchText `
        -FileTypesToInclude $FileTypesToInclude -FileTypesToExclude $FileTypesToExclude `
        -ContextLinesBefore $ContextLinesBefore -ContextLinesAfter $ContextLinesAfter `
        -CaseSensitive:$CaseSensitive
    
    return $searchResults
}

# Function to highlight search text in a string
function Format-SearchTextHighlight {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchText,
        
        [switch]$CaseSensitive = $false,
        
        [string]$HighlightPrefix = "<span class='highlight'>",
        
        [string]$HighlightSuffix = "</span>"
    )
    
    if ([string]::IsNullOrEmpty($Text) -or [string]::IsNullOrEmpty($SearchText)) {
        return $Text
    }
    
    $comparisonType = if ($CaseSensitive) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
    $pattern = [regex]::Escape($SearchText)
    
    if ($CaseSensitive) {
        return [regex]::Replace($Text, $pattern, "$HighlightPrefix`$&$HighlightSuffix")
    }
    else {
        return [regex]::Replace($Text, $pattern, "$HighlightPrefix`$&$HighlightSuffix", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
}