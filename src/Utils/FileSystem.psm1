# DiagLog Analyzer - File System Utilities
# This module provides file system related functions

# Import dependencies
try {
    $loggingPath = Join-Path -Path $PSScriptRoot -ChildPath "Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -ErrorAction Stop
    } else {
        throw "Logging module not found at: $loggingPath"
    }
} catch {
    Write-Error "Failed to import required module: $_"
    exit 1
}

function Test-CabFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    # Check file extension first as a quick filter
    if (-not ($FilePath -match '\.cab$')) {
        return $false
    }
    
    try {
        # Read the first 8 bytes to check the CAB file signature
        $stream = [System.IO.File]::OpenRead($FilePath)
        $buffer = New-Object byte[] 8
        $bytesRead = $stream.Read($buffer, 0, 8)
        $stream.Close()
        
        # CAB file signature starts with "MSCF" (0x4D, 0x53, 0x43, 0x46)
        if ($buffer[0] -eq 0x4D -and $buffer[1] -eq 0x53 -and $buffer[2] -eq 0x43 -and $buffer[3] -eq 0x46) {
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log -Message "Error checking if $FilePath is a CAB file: $_" -Level ERROR -Component "FileSystem"
        return $false
    }
}

function Format-FileSize {
    param (
        [Parameter(Mandatory=$true)]
        [long]$SizeInBytes
    )
    
    if ($SizeInBytes -lt 1KB) {
        return "$SizeInBytes B"
    }
    elseif ($SizeInBytes -lt 1MB) {
        return "{0:N2} KB" -f ($SizeInBytes / 1KB)
    }
    elseif ($SizeInBytes -lt 1GB) {
        return "{0:N2} MB" -f ($SizeInBytes / 1MB)
    }
    else {
        return "{0:N2} GB" -f ($SizeInBytes / 1GB)
    }
}

function Get-FileTempPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OriginalFilePath,
        
        [string]$SubDir = ""
    )
    
    $fileName = [System.IO.Path]::GetFileName($OriginalFilePath)
    $tempDir = [System.IO.Path]::GetTempPath()
    
    if (-not [string]::IsNullOrEmpty($SubDir)) {
        $tempDir = Join-Path -Path $tempDir -ChildPath $SubDir
        if (-not (Test-Path -Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
    }
    
    return Join-Path -Path $tempDir -ChildPath $fileName
}

function Get-FileType {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        # Handle no extension case
        if ([string]::IsNullOrEmpty($extension)) {
            # Try to determine type by examining file content
            $content = Get-Content -Path $FilePath -Raw -TotalCount 1KB -ErrorAction SilentlyContinue
            
            if ($null -eq $content) {
                return "binary"
            }
            
            # Check for common file signatures or patterns
            if ($content -match "^<\?xml") {
                return "xml"
            }
            elseif ($content -match "^<!DOCTYPE html" -or $content -match "<html") {
                return "html"
            }
            elseif ($content -match "^\{.*\}$" -or $content -match "^\[.*\]$") {
                return "json"
            }
            else {
                # Default to text if it contains mostly printable ASCII
                $printableCount = ($content -replace "[^\x20-\x7E]", "").Length
                if ($printableCount / $content.Length -gt 0.8) {
                    return "text"
                }
                else {
                    return "binary"
                }
            }
        }
        
        # Known extensions
        $textExtensions = @(".txt", ".log", ".xml", ".html", ".htm", ".json", ".csv", ".ps1", ".psm1", ".psd1", ".cfg", ".config", ".ini")
        $imageExtensions = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".ico")
        $archiveExtensions = @(".zip", ".rar", ".7z", ".cab", ".tar", ".gz", ".tgz")
        
        if ($textExtensions -contains $extension) {
            return "text"
        }
        elseif ($imageExtensions -contains $extension) {
            return "image"
        }
        elseif ($archiveExtensions -contains $extension) {
            return "archive"
        }
        elseif ($extension -eq ".exe" -or $extension -eq ".dll") {
            return "executable"
        }
        else {
            # For unknown extensions, try to determine if it's text or binary
            try {
                $content = Get-Content -Path $FilePath -Raw -TotalCount 1KB -ErrorAction Stop
                
                # Check if the content is mostly printable ASCII
                $printableCount = ($content -replace "[^\x20-\x7E]", "").Length
                if ($printableCount / $content.Length -gt 0.8) {
                    return "text"
                }
                else {
                    return "binary"
                }
            }
            catch {
                return "binary"
            }
        }
    }
    catch {
        Write-Log -Message "Error determining file type for $FilePath : $_" -Level ERROR -Component "FileSystem"
        return "unknown"
    }
}

function Get-SafeFilePath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [int]$MaxLength = 260
    )
    
    if ($FilePath.Length -le $MaxLength) {
        return $FilePath
    }
    
    # Shorten path while preserving filename
    $dirName = [System.IO.Path]::GetDirectoryName($FilePath)
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    
    # Calculate available space for directory
    $availableLength = $MaxLength - $fileName.Length - 1  # -1 for path separator
    
    if ($availableLength -le 0) {
        # Filename itself is too long, truncate it
        $extension = [System.IO.Path]::GetExtension($FilePath)
        $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        $maxBaseLength = $MaxLength - $extension.Length - 3  # -3 for "..." 
        $truncatedFileName = $baseFileName.Substring(0, $maxBaseLength) + "..." + $extension
        
        return Join-Path -Path $dirName -ChildPath $truncatedFileName
    }
    else {
        # Truncate directory part
        $truncatedDir = $dirName.Substring(0, $availableLength - 3) + "..."
        return Join-Path -Path $truncatedDir -ChildPath $fileName
    }
}