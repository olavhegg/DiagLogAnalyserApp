# DiagLog Analyzer - CAB Extraction Module
# This module handles the extraction of CAB files from diagnostic logs

# Function to start CAB extraction
function Start-CabExtraction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSubFolders = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ExtractToOriginalLocation = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$DeleteAfterExtraction = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$SkipAlreadyExtracted = $true
    )
    
    try {
        Write-DLALog -Message "Starting CAB extraction for: $FolderPath" -Level INFO -Component "CabExtractor"
        Write-DLALog -Message "Include subfolders: $IncludeSubFolders" -Level INFO -Component "CabExtractor"
        Write-DLALog -Message "Extract to original location: $ExtractToOriginalLocation" -Level INFO -Component "CabExtractor"
        Write-DLALog -Message "Delete after extraction: $DeleteAfterExtraction" -Level INFO -Component "CabExtractor"
        Write-DLALog -Message "Skip already extracted: $SkipAlreadyExtracted" -Level INFO -Component "CabExtractor"
        
        # Initialize results
        $results = [PSCustomObject]@{
            FolderPath = $FolderPath
            StartTime = Get-Date
            EndTime = $null
            TotalCabFiles = 0
            SkippedCabFiles = 0
            SuccessfulExtractions = 0
            FailedExtractions = 0
            ExtractedFiles = @()
            Errors = @()
        }
        
        # Get CAB files
        $cabFiles = @()
        if ($IncludeSubFolders) {
            $cabFiles = Get-ChildItem -Path $FolderPath -Filter "*.cab" -Recurse -File
        }
        else {
            $cabFiles = Get-ChildItem -Path $FolderPath -Filter "*.cab" -File
        }
        
        $results.TotalCabFiles = $cabFiles.Count
        Write-DLALog -Message "Found $($results.TotalCabFiles) CAB files" -Level INFO -Component "CabExtractor"
        
        # Process each CAB file
        foreach ($cabFile in $cabFiles) {
            Write-DLALog -Message "Processing CAB file: $($cabFile.FullName)" -Level INFO -Component "CabExtractor"
            
            try {
                # Determine extraction location
                $extractPath = ""
                if ($ExtractToOriginalLocation) {
                    $extractPath = $cabFile.DirectoryName
                }
                else {
                    $relativePath = $cabFile.FullName.Replace($FolderPath, "").TrimStart("\")
                    $extractPath = Join-Path -Path (Join-Path -Path $FolderPath -ChildPath "_ExtractedCABs") -ChildPath $relativePath
                    $extractPath = Split-Path -Path $extractPath -Parent
                }
                
                # Ensure extraction directory exists
                if (-not (Test-Path -Path $extractPath -PathType Container)) {
                    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
                }
                
                # Check if already extracted by looking for a marker file
                $markerFilePath = Join-Path -Path $extractPath -ChildPath ".$($cabFile.BaseName).extracted"
                $alreadyExtracted = (Test-Path -Path $markerFilePath) -and $SkipAlreadyExtracted
                
                if ($alreadyExtracted) {
                    Write-DLALog -Message "Skipping already extracted CAB file" -Level INFO -Component "CabExtractor"
                    $results.SkippedCabFiles++
                    continue
                }
                
                Write-DLALog -Message "Extracting to: $extractPath" -Level INFO -Component "CabExtractor"
                
                # Extract the CAB file
                $expandProcess = Start-Process -FilePath "expand.exe" -ArgumentList "`"$($cabFile.FullName)`" -F:* `"$extractPath`"" -PassThru -Wait -NoNewWindow
                
                if ($expandProcess.ExitCode -eq 0) {
                    Write-DLALog -Message "Successfully extracted CAB file" -Level INFO -Component "CabExtractor"
                    $results.SuccessfulExtractions++
                    
                    # Create marker file to indicate this CAB has been extracted
                    Set-Content -Path $markerFilePath -Value (Get-Date) -Force
                    
                    # Identify extracted files
                    $newFiles = Get-ChildItem -Path $extractPath -File | Where-Object { 
                        # Exclude marker files and consider files newer than the CAB or with the same timestamp
                        -not $_.Name.StartsWith(".") -and 
                        -not $_.Name.EndsWith(".extracted") -and 
                        $_.LastWriteTime -ge $cabFile.LastWriteTime
                    }
                    
                    foreach ($file in $newFiles) {
                        $results.ExtractedFiles += [PSCustomObject]@{
                            SourceCab = $cabFile.FullName
                            ExtractedFile = $file.FullName
                            Size = $file.Length
                        }
                    }
                    
                    # Delete CAB file if requested
                    if ($DeleteAfterExtraction) {
                        Remove-Item -Path $cabFile.FullName -Force
                        Write-DLALog -Message "Deleted CAB file after extraction" -Level INFO -Component "CabExtractor"
                    }
                }
                else {
                    $errorMessage = "Failed to extract CAB file (Exit code: $($expandProcess.ExitCode))"
                    Write-DLALog -Message $errorMessage -Level ERROR -Component "CabExtractor"
                    $results.FailedExtractions++
                    $results.Errors += "$($cabFile.FullName): $errorMessage"
                }
            }
            catch {
                Write-DLALog -Message "Error extracting CAB file: $_" -Level ERROR -Component "CabExtractor"
                $results.FailedExtractions++
                $results.Errors += "$($cabFile.FullName): $_"
            }
        }
        
        $results.EndTime = Get-Date
        $duration = ($results.EndTime - $results.StartTime).TotalSeconds
        Write-DLALog -Message "CAB extraction completed in $duration seconds. Successful: $($results.SuccessfulExtractions), Skipped: $($results.SkippedCabFiles), Failed: $($results.FailedExtractions)" -Level INFO -Component "CabExtractor"
        
        return $results
    }
    catch {
        Write-DLALog -Message "Error in Start-CabExtraction: $_" -Level ERROR -Component "CabExtractor"
        throw $_
    }
}

# Export functions
Export-ModuleMember -Function Start-CabExtraction