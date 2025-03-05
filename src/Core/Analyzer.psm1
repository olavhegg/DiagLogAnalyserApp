# DiagLog Analyzer - Core Analyzer Module
# This module handles file structure analysis

# Import required modules properly
$modulesToImport = @(
    (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\Logging.psm1"),
    (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\FileSystem.psm1")
)

foreach ($module in $modulesToImport) {
    Import-Module $module -Force
}

# Function to analyze folder structure
function Start-FolderAnalysis {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        
        [switch]$IncludeSubFolders = $true
    )
    
    Write-Log -Message "Starting folder analysis for $FolderPath" -Level INFO -Component "Analyzer"
    
    # Initialize results structure
    $analysisResults = @{
        SourcePath = $FolderPath
        AnalysisTime = Get-Date
        TotalItems = 0
        Files = 0
        Directories = 0
        TotalSize = 0
        Extensions = @{}
        FileTypes = @{}
        LargestFiles = @()
        CabFiles = @()
        DirectoryDepth = 0
    }
    
    try {
        # Get child items based on recursion option
        $itemParams = @{
            Path = $FolderPath
            Force = $true
            ErrorAction = "SilentlyContinue"
        }
        
        if ($IncludeSubFolders) {
            $itemParams.Recurse = $true
        }
        
        $allItems = Get-ChildItem @itemParams
        
        # Process items
        foreach ($item in $allItems) {
            $analysisResults.TotalItems++
            
            if ($item.PSIsContainer) {
                $analysisResults.Directories++
                
                # Calculate directory depth
                $relativePath = $item.FullName.Substring($FolderPath.Length)
                $depth = ($relativePath -replace '[^\\]').Length
                if ($depth -gt $analysisResults.DirectoryDepth) {
                    $analysisResults.DirectoryDepth = $depth
                }
            }
            else {
                $analysisResults.Files++
                $analysisResults.TotalSize += $item.Length
                
                # Process extension
                $extension = $item.Extension.ToLower()
                if ([string]::IsNullOrEmpty($extension)) {
                    $extension = "(no extension)"
                }
                
                if (-not $analysisResults.Extensions.ContainsKey($extension)) {
                    $analysisResults.Extensions[$extension] = @{
                        Count = 0
                        TotalSize = 0
                        SampleFiles = @()
                    }
                }
                
                $analysisResults.Extensions[$extension].Count++
                $analysisResults.Extensions[$extension].TotalSize += $item.Length
                
                # Keep up to 5 sample files per extension
                if ($analysisResults.Extensions[$extension].SampleFiles.Count -lt 5) {
                    $analysisResults.Extensions[$extension].SampleFiles += $item.FullName
                }
                
                # Determine file type
                $fileType = Get-FileType -FilePath $item.FullName
                
                if (-not $analysisResults.FileTypes.ContainsKey($fileType)) {
                    $analysisResults.FileTypes[$fileType] = @{
                        Count = 0
                        TotalSize = 0
                    }
                }
                
                $analysisResults.FileTypes[$fileType].Count++
                $analysisResults.FileTypes[$fileType].TotalSize += $item.Length
                
                # Track largest files (keep top 50)
                $analysisResults.LargestFiles += [PSCustomObject]@{
                    Path = $item.FullName
                    Size = $item.Length
                    Extension = $extension
                    Type = $fileType
                }
                
                # Keep only top 50 largest files
                if ($analysisResults.LargestFiles.Count -gt 50) {
                    $analysisResults.LargestFiles = $analysisResults.LargestFiles | 
                        Sort-Object -Property Size -Descending | 
                        Select-Object -First 50
                }
                
                # Check if it's a CAB file
                if (Test-CabFile -FilePath $item.FullName) {
                    $analysisResults.CabFiles += [PSCustomObject]@{
                        Path = $item.FullName
                        Size = $item.Length
                        RelativePath = $item.FullName.Substring($FolderPath.Length + 1)
                        Processed = $false
                        ExtractedPath = $null
                    }
                }
            }
        }
        
        Write-Log -Message "Folder analysis completed: $($analysisResults.Files) files, $($analysisResults.Directories) directories" -Level INFO -Component "Analyzer"
        return $analysisResults
    }
    catch {
        Write-Log -Message "Error during folder analysis: $_" -Level ERROR -Component "Analyzer"
        throw $_
    }
}

# Function to get analysis summary as a string
function Get-AnalysisSummary {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$AnalysisResults
    )
    
    $summary = @"
Analysis Summary
---------------
Source Path: $($AnalysisResults.SourcePath)
Analysis Time: $($AnalysisResults.AnalysisTime)

Total Items: $($AnalysisResults.TotalItems)
Files: $($AnalysisResults.Files)
Directories: $($AnalysisResults.Directories)
Total Size: $(Format-FileSize -SizeInBytes $AnalysisResults.TotalSize)
Directory Depth: $($AnalysisResults.DirectoryDepth)
CAB Files: $($AnalysisResults.CabFiles.Count)

File Extensions:
$(
    $AnalysisResults.Extensions.GetEnumerator() | 
    Sort-Object -Property {$_.Value.Count} -Descending | 
    ForEach-Object {
        "  $($_.Key): $($_.Value.Count) files, $(Format-FileSize -SizeInBytes $_.Value.TotalSize)"
    } | Out-String
)

File Types:
$(
    $AnalysisResults.FileTypes.GetEnumerator() | 
    Sort-Object -Property {$_.Value.Count} -Descending | 
    ForEach-Object {
        "  $($_.Key): $($_.Value.Count) files, $(Format-FileSize -SizeInBytes $_.Value.TotalSize)"
    } | Out-String
)

Largest Files:
$(
    $AnalysisResults.LargestFiles | 
    Select-Object -First 10 | 
    ForEach-Object {
        "  $(Format-FileSize -SizeInBytes $_.Size): $($_.Path)"
    } | Out-String
)
"@
    
    return $summary
}

function Start-LogAnalysis {
    param(
        [string]$LogPath
    )
    Write-Log "Starting analysis of: $LogPath"
    # Add analysis logic here
}

Export-ModuleMember -Function Start-LogAnalysis