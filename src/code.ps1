function Collect-SourceCode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "$PSScriptRoot\src",

        [Parameter(Mandatory = $false)]
        [string]$OutputFile = "$PSScriptRoot\results\SourceCodeCollection.txt",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileName = $true
    )

    begin {
        # Ensure the output directory exists
        $outputDir = Split-Path -Path $OutputFile -Parent
        if (-not (Test-Path -Path $outputDir)) {
            Write-Verbose "Creating output directory: $outputDir"
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Initialize the output file with a header
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $header = @"
# DiagLogAnalyzerApp Source Code Collection
# Generated: $timestamp
# Source Path: $SourcePath

"@
        Set-Content -Path $OutputFile -Value $header -Force
    }

    process {
        # Get all PowerShell files recursively
        $psFiles = Get-ChildItem -Path $SourcePath -Include *.ps1, *.psm1, *.psd1 -Recurse -File

        $totalFiles = $psFiles.Count
        Write-Verbose "Found $totalFiles PowerShell files to process"

        $fileCounter = 0
        foreach ($file in $psFiles) {
            $fileCounter++
            Write-Progress -Activity "Collecting Source Code" -Status "Processing file $fileCounter of $totalFiles" -PercentComplete ($fileCounter / $totalFiles * 100)
            
            $relativePath = $file.FullName.Replace("$SourcePath\", "")
            $fileContent = Get-Content -Path $file.FullName -Raw

            # Add file separator and name to the output file
            $fileSeparator = @"
#------------------------------------------------------------------------------
# File: $relativePath
#------------------------------------------------------------------------------

"@
            
            if ($IncludeFileName) {
                Add-Content -Path $OutputFile -Value $fileSeparator
            }
            
            # Add the file content
            Add-Content -Path $OutputFile -Value $fileContent
            
            # Add a newline after each file
            Add-Content -Path $OutputFile -Value "`n`n"
        }
    }

    end {
        Write-Verbose "Source code collection completed. Output saved to: $OutputFile"
        return $OutputFile
    }
}

# Example usage:
# Collect-SourceCode -Verbose
# Or with custom parameters:
# Collect-SourceCode -SourcePath "C:\Path\To\DiagLogAnalyserApp\src" -OutputFile "C:\Path\To\Output\AllSourceCode.txt"