# DiagLog Analyzer - CAB Extractor Module
# This module handles extraction of CAB files

# Import dependencies using relative paths from module root
$modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Import required modules
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Utils\Logging.psm1") -Force
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Utils\FileSystem.psm1") -Force
Import-Module (Join-Path -Path $modulePath -ChildPath "src\Config\Settings.psm1") -Force

# Function to extract a single CAB file
function Expand-CabFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CabFilePath,
        
        [Parameter(Mandatory=$false)]
        [string]$DestinationPath = $null,
        
        [switch]$SkipIfExists = $true,
        
        [switch]$ValidateExtraction = $true,
        
        [switch]$CleanupOnFailure = $true
    )
    
    try {
        # Verify the cab file exists and is valid
        if (-not (Test-Path -Path $CabFilePath -PathType Leaf)) {
            throw "CAB file not found or is not a file: $CabFilePath"
        }

        # Verify file extension
        if ([System.IO.Path]::GetExtension($CabFilePath) -ne '.cab') {
            throw "File is not a CAB file: $CabFilePath"
        }

        # Create destination path if not specified
        if ([string]::IsNullOrEmpty($DestinationPath)) {
            $cabFileName = [System.IO.Path]::GetFileName($CabFilePath)
            $cabDirectory = [System.IO.Path]::GetDirectoryName($CabFilePath)
            $extractFolderName = [System.IO.Path]::GetFileNameWithoutExtension($cabFileName)
            $DestinationPath = Join-Path -Path $cabDirectory -ChildPath "$extractFolderName"
        }
        
        # Get expected contents before extraction
        $expectedContents = Get-CabContents -CabFilePath $CabFilePath
        if ($null -eq $expectedContents) {
            throw "Failed to read CAB contents"
        }
        
        # Check if destination already exists
        if ((Test-Path -Path $DestinationPath) -and $SkipIfExists) {
            Write-Log -Message "Skipping CAB extraction, folder already exists: $DestinationPath" -Level INFO -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $true
                CabPath = $CabFilePath
                ExtractedPath = $DestinationPath
                Message = "Extraction skipped, folder already exists"
                Files = $expectedContents
            }
        }
        
        # Create the destination directory
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        
        Write-Log -Message "Extracting CAB file: $CabFilePath to $DestinationPath" -Level INFO -Component "CabExtractor"
        
        # Use expand.exe with better output capture
        $expandCmd = "expand.exe -F:* `"$CabFilePath`" `"$DestinationPath`""
        $output = & cmd.exe /c $expandCmd 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            if ($ValidateExtraction) {
                # Verify extracted files
                $extractedFiles = Get-ChildItem -Path $DestinationPath -Recurse -File
                $missingFiles = $expectedContents | Where-Object {
                    -not (Test-Path (Join-Path -Path $DestinationPath -ChildPath $_.Name))
                }
                
                if ($missingFiles) {
                    throw "Extraction validation failed. Missing files: $($missingFiles.Name -join ', ')"
                }
            }
            
            Write-Log -Message "CAB extraction completed successfully: $CabFilePath" -Level INFO -Component "CabExtractor"
            return [PSCustomObject]@{
                Success = $true
                CabPath = $CabFilePath
                ExtractedPath = $DestinationPath
                Message = "Extraction successful"
                Files = $expectedContents
                Output = $output
            }
        }
        else {
            throw "Expand.exe failed with exit code $exitCode. Output: $($output -join "`n")"
        }
    }
    catch {
        Write-Log -Message "Exception during CAB extraction: $_" -Level ERROR -Component "CabExtractor"
        
        # Cleanup on failure if requested
        if ($CleanupOnFailure -and (Test-Path -Path $DestinationPath)) {
            Write-Log -Message "Cleaning up failed extraction directory: $DestinationPath" -Level INFO -Component "CabExtractor"
            Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return [PSCustomObject]@{
            Success = $false
            CabPath = $CabFilePath
            ExtractedPath = $null
            Message = "Exception: $_"
            Output = $output
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
        if (-not (Test-Path -Path $CabFilePath -PathType Leaf)) {
            throw "CAB file not found or is not a file: $CabFilePath"
        }
        
        Write-Log -Message "Listing CAB file contents: $CabFilePath" -Level DEBUG -Component "CabExtractor"
        
        # Use expand.exe with -D option to list contents
        $expandCmd = "expand.exe -D `"$CabFilePath`""
        $output = & cmd.exe /c $expandCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list CAB contents. Exit code: $LASTEXITCODE. Output: $($output -join "`n")"
        }
        
        # Parse the output to extract file listing with improved regex
        $files = @()
        foreach ($line in $output) {
            if ($line -match '^\s*(.+?)\s+(\d+)\s*$') {
                $fileName = $matches[1].Trim()
                $fileSize = [int]$matches[2]
                
                # Skip if fileName is empty or contains only whitespace
                if ([string]::IsNullOrWhiteSpace($fileName)) {
                    continue
                }
                
                $files += [PSCustomObject]@{
                    Name = $fileName
                    Size = $fileSize
                    Path = $fileName # Full path within the CAB
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