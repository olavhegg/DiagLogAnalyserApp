# PowerShell Script to Collect Code Lines from a Directory and Subdirectories

# Define parameters
$Directory = Get-Location
$OutputFile = "CodeLines.txt"

# Ensure output file is empty or create it
Set-Content -Path $OutputFile -Value ""  

# Get all files recursively, excluding 'results' and 'logs' directories
$files = Get-ChildItem -Path $Directory -Recurse -File | Where-Object {
    ($_.FullName -notlike "*\results\*") -and ($_.FullName -notlike "*\logs\*")
}

foreach ($file in $files) {
    # Write file name as a header
    Add-Content -Path $OutputFile -Value "### File: $($file.FullName) ###"
    
    # Read file content and write each line
    $lines = Get-Content -Path $file.FullName
    foreach ($line in $lines) {
        Add-Content -Path $OutputFile -Value $line
    }
    
    # Add a separator for clarity
    Add-Content -Path $OutputFile -Value "`n--------------------`n"
}

Write-Host "Code lines collected and stored in $OutputFile"
