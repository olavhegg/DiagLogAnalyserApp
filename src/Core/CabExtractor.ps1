# DiagLog Analyzer - CAB Extractor Module
# This module handles extraction of CAB files

# Import dependencies
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\Logging.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Utils\FileSystem.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Config\Settings.ps1")

# Function to extract a single CAB file
function Expand-CabFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CabFilePath,
        
        [Parameter(Mandatory=$false)]
        [string]$DestinationPath = $null,
        
        [switch]$SkipIfExists = $true
    )
    
    try {
        # Verify the cab file exists
        if (-not (Test-Path -Path $CabFilePath)) {
            Write-Log -Message "CAB file not found: $CabFilePath" -Level ERROR -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $false
                CabPath = $CabFilePath
                ExtractedPath = $null
                Message = "CAB file not found"
            }
        }
        
        # Create destination path if not specified
        if ([string]::IsNullOrEmpty($DestinationPath)) {
            $cabFileName = [System.IO.Path]::GetFileName($CabFilePath)
            $cabDirectory = [System.IO.Path]::GetDirectoryName($CabFilePath)
            $extractFolderName = [System.IO.Path]::GetFileNameWithoutExtension($cabFileName)
            $DestinationPath = Join-Path -Path $cabDirectory -ChildPath "$extractFolderName"
        }
        
        # Check if destination already exists
        if ((Test-Path -Path $DestinationPath) -and $SkipIfExists) {
            Write-Log -Message "Skipping CAB extraction, folder already exists: $DestinationPath" -Level INFO -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $true
                CabPath = $CabFilePath
                ExtractedPath = $DestinationPath
                Message = "Extraction skipped, folder already exists"
            }
        }
        
        # Create the destination directory
        if (-not (Test-Path -Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        
        Write-Log -Message "Extracting CAB file: $CabFilePath to $DestinationPath" -Level INFO -Component "CabExtractor"
        
        # Use expand.exe to extract CAB files (native Windows tool)
        $expandCmd = "expand.exe -F:* `"$CabFilePath`" `"$DestinationPath`""
        $result = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $expandCmd" -NoNewWindow -Wait -PassThru
        
        if ($result.ExitCode -eq 0) {
            Write-Log -Message "CAB extraction completed successfully: $CabFilePath" -Level INFO -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $true
                CabPath = $CabFilePath
                ExtractedPath = $DestinationPath
                Message = "Extraction successful"
            }
        }
        else {
            Write-Log -Message "CAB extraction failed with exit code $($result.ExitCode): $CabFilePath" -Level ERROR -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $false
                CabPath = $CabFilePath
                ExtractedPath = $null
                Message = "Extraction failed with exit code: $($result.ExitCode)"
            }
        }
    }
    catch {
        Write-Log -Message "Exception during CAB extraction: $_" -Level ERROR -Component "CabExtractor"
        return [PSCustomObject]@{
            Success = $false
            CabPath = $CabFilePath
            ExtractedPath = $null
            Message = "Exception: $_"
        }
    }
}

# Function to extract all CAB files from analysis results
function Expand-AnalysisCabFiles {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$AnalysisResults,
        
        [switch]$SkipExisting = $true
    )
    
    $extractionResults = @()
    $extractedCount = 0
    $skippedCount = 0
    $failedCount = 0
    
    Write-Log -Message "Beginning extraction of $($AnalysisResults.CabFiles.Count) CAB files" -Level INFO -Component "CabExtractor"
    
    foreach ($cabFile in $AnalysisResults.CabFiles) {
        $extractResult = Expand-CabFile -CabFilePath $cabFile.Path -SkipIfExists:$SkipExisting
        
        # Update the cab file object with extraction results
        $cabFile.Processed = $true
        $cabFile.ExtractedPath = $extractResult.ExtractedPath
        $cabFile.ExtractionSuccess = $extractResult.Success
        $cabFile.ExtractionMessage = $extractResult.Message
        
        # Track statistics
        if ($extractResult.Success) {
            if ($extractResult.Message -like "*skipped*") {
                $skippedCount++
            }
            else {
                $extractedCount++
            }
        }
        else {
            $failedCount++
        }
        
        $extractionResults += $extractResult
    }
    
    Write-Log -Message "CAB extraction completed: $extractedCount extracted, $skippedCount skipped, $failedCount failed" -Level INFO -Component "CabExtractor"
    
    return [PSCustomObject]@{
        TotalCabs = $AnalysisResults.CabFiles.Count
        ExtractedCount = $extractedCount
        SkippedCount = $skippedCount
        FailedCount = $failedCount
        Results = $extractionResults
    }
}

# Function to get the list of files inside a CAB without extracting
function Get-CabContents {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CabFilePath
    )
    
    try {
        # Verify the cab file exists
        if (-not (Test-Path -Path $CabFilePath)) {
            Write-Log -Message "CAB file not found: $CabFilePath" -Level ERROR -Component "CabExtractor"
            return $null
        }
        
        Write-Log -Message "Listing CAB file contents: $CabFilePath" -Level INFO -Component "CabExtractor"
        
        # Use expand.exe with -D option to list contents
        $expandCmd = "expand.exe -D `"$CabFilePath`""
        $output = & cmd.exe /c $expandCmd 2>&1
        
        # Parse the output to extract file listing
        $files = @()
        foreach ($line in $output) {
            if ($line -match '^\s*(.+?)\s+(\d+)\s*$') {
                $fileName = $matches[1].Trim()
                $fileSize = [int]$matches[2]
                
                $files += [PSCustomObject]@{
                    Name = $fileName
                    Size = $fileSize
                }
            }
        }
        
        return $files
    }
    catch {
        Write-Log -Message "Error listing CAB contents: $_" -Level ERROR -Component "CabExtractor"
        return $null
    }
}