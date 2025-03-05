# DiagLog Analyzer - FileTypeHandler Module
# This module handles different file types for reading and searching operations

# Set strict mode
Set-StrictMode -Version Latest

# Function to get proper parser for a given file
function Get-FileParser {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    # Get the file extension (or identify files without extension)
    $extension = if ([String]::IsNullOrEmpty([System.IO.Path]::GetExtension($FilePath))) {
        "(no extension)"
    } else {
        [System.IO.Path]::GetExtension($FilePath).ToLower()
    }
    
    # Return the appropriate parser based on file extension
    switch ($extension) {
        ".log" { return "Read-LogFile" }
        ".txt" { return "Read-TextFile" }
        ".etl" { 
            # Check if it's a text-based ETL or binary
            if (Test-TextFile -FilePath $FilePath) {
                return "Read-TextFile"
            } else {
                return "Read-BinaryEtlFile"
            }
        }
        ".evtx" { return "Read-EvtxFile" }
        ".cab" { return "Read-CabFile" }
        ".reg" { return "Read-RegFile" }
        ".xml" { return "Read-XmlFile" }
        ".json" { return "Read-JsonFile" }
        ".html" { return "Read-HtmlFile" }
        ".csv" { return "Read-CsvFile" }
        ".bin" { return "Read-BinaryFile" }
        ".dat" { 
            # Check if it's a text-based DAT or binary
            if (Test-TextFile -FilePath $FilePath) {
                return "Read-TextFile"
            } else {
                return "Read-BinaryFile"
            }
        }
        # Handle numbered extensions like .001, .002, etc.
        { $_ -match "^\.\d{3}$" } { return "Read-SplitFile" }
        # Handle other special cases like the hash extension
        default {
            # Check if it's likely a text file
            if (Test-TextFile -FilePath $FilePath) {
                return "Read-TextFile"
            } else {
                return "Read-BinaryFile"
            }
        }
    }
}

# Function to test if a file is text or binary
function Test-TextFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        # Read the first 4KB of the file to determine if it's text
        $bytes = Get-Content -Path $FilePath -Encoding Byte -TotalCount 4KB -ErrorAction Stop
        
        # Count the occurrence of common binary markers (especially null bytes)
        $nullByteCount = 0
        $highByteCount = 0
        
        foreach ($byte in $bytes) {
            if ($byte -eq 0) {
                $nullByteCount++
            } elseif ($byte -gt 127) {
                $highByteCount++
            }
        }
        
        # If there are too many null bytes or high bytes, it's likely binary
        if ($nullByteCount -gt 1 -or ($highByteCount / $bytes.Count) -gt 0.3) {
            return $false
        }
        
        return $true
    }
    catch {
        Write-DLALog -Message "Error testing if file is text: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        # Default to false (binary) on error
        return $false
    }
}

# Function to read a standard log or text file
function Read-TextFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading text file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Read file line by line with proper encoding detection
        Get-Content -Path $FilePath -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            $lineNumber++
            $processedLine = & $LineProcessor $_ $lineNumber
            if ($null -ne $processedLine) {
                $lines += $processedLine
            }
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "Text"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading text file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Text"
        }
    }
}

# Alias for standard log files
function Read-LogFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor
    )
    
    return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
}

# Function to handle Windows Event Log files (.evtx)
function Read-EvtxFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading EVTX file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Check if we can use wevtutil for direct evtx file reading
        if (Get-Command -Name wevtutil -ErrorAction SilentlyContinue) {
            # Use wevtutil to export the event log as XML
            $tempFile = [System.IO.Path]::GetTempFileName() + ".xml"
            
            try {
                # Execute wevtutil and redirect output
                $null = & wevtutil export-log $FilePath $tempFile /overwrite:true 2>&1
                
                # Read the exported XML
                if (Test-Path $tempFile) {
                    # Process the XML file
                    [xml]$eventsXml = Get-Content -Path $tempFile -Encoding UTF8
                    
                    # Convert events to text format
                    if ($eventsXml -and $eventsXml.Events -and $eventsXml.Events.Event) {
                        foreach ($event in $eventsXml.Events.Event) {
                            $lineNumber++
                            
                            # Create a text representation of the event
                            $eventId = $event.System.EventID.'#text'
                            $timeCreated = $event.System.TimeCreated.SystemTime
                            $level = $event.System.Level
                            $provider = $event.System.Provider.Name
                            
                            $eventData = ""
                            if ($event.EventData -and $event.EventData.Data) {
                                foreach ($data in $event.EventData.Data) {
                                    if ($data.Name) {
                                        $eventData += "$($data.Name): $($data.'#text')`n"
                                    } else {
                                        $eventData += "$($data.'#text')`n"
                                    }
                                }
                            }
                            
                            $eventLine = "Event ID: $eventId | Time: $timeCreated | Level: $level | Provider: $provider`nData: $eventData"
                            
                            $processedLine = & $LineProcessor $eventLine $lineNumber
                            if ($null -ne $processedLine) {
                                $lines += $processedLine
                            }
                        }
                    }
                } else {
                    throw "Failed to export event log to XML"
                }
            }
            finally {
                # Clean up temporary file
                if (Test-Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        } else {
            # Fallback: Try to extract some text using event log cmdlets
            $lines += "WARNING: wevtutil not available. Limited event log parsing available."
            $lineNumber++
            
            try {
                # Use Get-WinEvent if available (PowerShell 3.0+)
                if (Get-Command -Name Get-WinEvent -ErrorAction SilentlyContinue) {
                    $events = Get-WinEvent -Path $FilePath -ErrorAction Stop
                    
                    foreach ($event in $events) {
                        $lineNumber++
                        $eventLine = "Event ID: $($event.Id) | Time: $($event.TimeCreated) | Level: $($event.Level) | Provider: $($event.ProviderName)`nMessage: $($event.Message)"
                        
                        $processedLine = & $LineProcessor $eventLine $lineNumber
                        if ($null -ne $processedLine) {
                            $lines += $processedLine
                        }
                    }
                } else {
                    $lines += "ERROR: Neither wevtutil nor Get-WinEvent is available for EVTX parsing"
                    $lineNumber++
                }
            }
            catch {
                $lines += "ERROR: Failed to parse EVTX with PowerShell cmdlets: $($_.Exception.Message)"
                $lineNumber++
            }
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "Event Log (EVTX)"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading EVTX file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Event Log (EVTX)"
        }
    }
}

# Function to handle Registry export files (.reg)
function Read-RegFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading Registry file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        # REG files are just text files with a specific format
        return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
    }
    catch {
        Write-DLALog -Message "Error reading REG file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Registry"
        }
    }
}

# Function to handle XML files
function Read-XmlFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading XML file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Try to parse as XML first
        try {
            [xml]$xmlContent = Get-Content -Path $FilePath -Encoding UTF8
            
            # Format the XML with indentation
            $stringWriter = New-Object System.IO.StringWriter
            $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)
            $xmlWriter.Formatting = [System.Xml.Formatting]::Indented
            $xmlContent.WriteTo($xmlWriter)
            $xmlWriter.Flush()
            $formattedXml = $stringWriter.ToString() -split "`n"
            
            # Process each line
            foreach ($line in $formattedXml) {
                $lineNumber++
                $processedLine = & $LineProcessor $line $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
        }
        catch {
            # If XML parsing fails, fall back to text mode
            Write-DLALog -Message "XML parsing failed, falling back to text mode: $($_.Exception.Message)" -Level WARNING -Component "FileTypeHandler"
            return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "XML"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading XML file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "XML"
        }
    }
}

# Function to handle JSON files
function Read-JsonFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading JSON file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Try to parse as JSON first
        try {
            $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
            
            # Format the JSON with indentation (PowerShell 5+)
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                $formattedJson = $jsonContent | ConvertTo-Json -Depth 10
            } else {
                # Simple formatting for earlier PowerShell versions
                $formattedJson = $jsonContent | ConvertTo-Json
            }
            
            # Process each line
            foreach ($line in $formattedJson -split "`n") {
                $lineNumber++
                $processedLine = & $LineProcessor $line $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
        }
        catch {
            # If JSON parsing fails, fall back to text mode
            Write-DLALog -Message "JSON parsing failed, falling back to text mode: $($_.Exception.Message)" -Level WARNING -Component "FileTypeHandler"
            return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "JSON"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading JSON file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "JSON"
        }
    }
}

# Function to handle HTML files
function Read-HtmlFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading HTML file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        # HTML files are just text files with specific formatting
        return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
    }
    catch {
        Write-DLALog -Message "Error reading HTML file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "HTML"
        }
    }
}

# Function to handle CSV files
function Read-CsvFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading CSV file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Try to parse as CSV
        try {
            $csvData = Import-Csv -Path $FilePath
            
            # Add header row
            if ($csvData.Count -gt 0) {
                $properties = $csvData[0].PSObject.Properties.Name
                $header = $properties -join ","
                $lineNumber++
                $processedLine = & $LineProcessor $header $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
            
            # Add data rows
            foreach ($row in $csvData) {
                $values = @()
                foreach ($prop in $row.PSObject.Properties) {
                    $values += $prop.Value
                }
                $line = $values -join ","
                $lineNumber++
                $processedLine = & $LineProcessor $line $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
        }
        catch {
            # If CSV parsing fails, fall back to text mode
            Write-DLALog -Message "CSV parsing failed, falling back to text mode: $($_.Exception.Message)" -Level WARNING -Component "FileTypeHandler"
            return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "CSV"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading CSV file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "CSV"
        }
    }
}

# Function to handle CAB archive files
function Read-CabFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading CAB file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Check if the CAB extraction module is available
        if (Get-Command -Name Get-CabFileContents -ErrorAction SilentlyContinue) {
            # Use the module to get the contents
            $cabContents = Get-CabFileContents -CabFilePath $FilePath
            
            foreach ($fileEntry in $cabContents) {
                $lineNumber++
                $line = "File: $($fileEntry.Name) | Size: $($fileEntry.Size) bytes | Date: $($fileEntry.Date)"
                
                $processedLine = & $LineProcessor $line $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
        } else {
            # Fallback: Use expand.exe if available
            if (Get-Command -Name expand -ErrorAction SilentlyContinue) {
                # Create a temporary directory for extraction
                $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                
                try {
                    # First, list the contents
                    $cabList = expand -D $FilePath
                    
                    foreach ($line in $cabList) {
                        if ($line -match "^[\s\-]+(.+)$") {
                            $fileName = $matches[1].Trim()
                            $lineNumber++
                            $processedLine = & $LineProcessor "File: $fileName" $lineNumber
                            if ($null -ne $processedLine) {
                                $lines += $processedLine
                            }
                        }
                    }
                }
                finally {
                    # Clean up
                    if (Test-Path $tempDir) {
                        Remove-Item -Path $tempDir -Recurse -Force
                    }
                }
            } else {
                # No CAB extraction available
                $lineNumber++
                $lines += "CAB extraction not available. Install expand.exe or implement Get-CabFileContents."
            }
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "CAB Archive"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading CAB file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "CAB Archive"
        }
    }
}

# Function to handle binary ETL (Event Trace Log) files
function Read-BinaryEtlFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading binary ETL file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Check if tracerpt.exe is available for ETL parsing
        if (Get-Command -Name tracerpt -ErrorAction SilentlyContinue) {
            # Create temporary file for output
            $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
            $tempCsv = Join-Path -Path $tempDir -ChildPath "etl_output.csv"
            
            try {
                # Create temp directory
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                
                # Convert ETL to CSV using tracerpt
                $null = & tracerpt $FilePath -o $tempCsv -of CSV 2>&1
                
                # Read CSV if it was created
                if (Test-Path $tempCsv) {
                    $csvData = Import-Csv -Path $tempCsv
                    
                    # Process the CSV data
                    foreach ($row in $csvData) {
                        $lineNumber++
                        
                        # Format a line from the CSV data
                        $line = "Time: $($row.Time) | Provider: $($row.Provider) | Task: $($row.Task) | Opcode: $($row.Opcode)"
                        
                        if ($row.PSObject.Properties.Name -contains "Text") {
                            $line += " | Text: $($row.Text)"
                        }
                        
                        $processedLine = & $LineProcessor $line $lineNumber
                        if ($null -ne $processedLine) {
                            $lines += $processedLine
                        }
                    }
                } else {
                    # Conversion failed, add error message
                    $lineNumber++
                    $processedLine = & $LineProcessor "Failed to convert ETL file to readable format" $lineNumber
                    if ($null -ne $processedLine) {
                        $lines += $processedLine
                    }
                }
            }
            finally {
                # Clean up temporary files
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            # No conversion tool available
            $lineNumber++
            $processedLine = & $LineProcessor "ETL file processing requires tracerpt.exe which is not available" $lineNumber
            if ($null -ne $processedLine) {
                $lines += $processedLine
            }
            
            # Add basic file info
            $fileInfo = Get-Item -Path $FilePath
            $lineNumber++
            $infoLine = "ETL File: $($fileInfo.Name) | Size: $($fileInfo.Length) bytes | Last Modified: $($fileInfo.LastWriteTime)"
            $processedLine = & $LineProcessor $infoLine $lineNumber
            if ($null -ne $processedLine) {
                $lines += $processedLine
            }
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "Event Trace Log (ETL)"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading ETL file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Event Trace Log (ETL)"
        }
    }
}

# Function to handle generic binary files
function Read-BinaryFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading binary file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        $lines = @()
        $lineNumber = 0
        
        # Get basic file info
        $fileInfo = Get-Item -Path $FilePath
        $lineNumber++
        $infoLine = "Binary File: $($fileInfo.Name) | Size: $($fileInfo.Length) bytes | Last Modified: $($fileInfo.LastWriteTime)"
        $processedLine = & $LineProcessor $infoLine $lineNumber
        if ($null -ne $processedLine) {
            $lines += $processedLine
        }
        
        # Try to do a hex dump of the first part of the file
        try {
            $bytes = Get-Content -Path $FilePath -Encoding Byte -TotalCount 256
            
            $hexDump = ""
            $asciiDump = ""
            $byteCount = 0
            
            foreach ($byte in $bytes) {
                # Add byte to hex dump
                $hexDump += "{0:X2} " -f $byte
                
                # Add corresponding character to ASCII dump (if printable)
                if ($byte -ge 32 -and $byte -le 126) {
                    $asciiDump += [char]$byte
                } else {
                    $asciiDump += "."
                }
                
                $byteCount++
                
                # Format in 16-byte rows
                if ($byteCount % 16 -eq 0) {
                    $lineNumber++
                    $line = "{0:X8}: {1,-48} {2}" -f ($byteCount - 16), $hexDump, $asciiDump
                    $processedLine = & $LineProcessor $line $lineNumber
                    if ($null -ne $processedLine) {
                        $lines += $processedLine
                    }
                    
                    $hexDump = ""
                    $asciiDump = ""
                }
            }
            
            # Add any remaining bytes
            if ($hexDump -ne "") {
                $lineNumber++
                $line = "{0:X8}: {1,-48} {2}" -f ([Math]::Floor($byteCount / 16) * 16), $hexDump, $asciiDump
                $processedLine = & $LineProcessor $line $lineNumber
                if ($null -ne $processedLine) {
                    $lines += $processedLine
                }
            }
            
            # Add note about binary file
            $lineNumber++
            $noteLine = "NOTE: This is a binary file. Only the first 256 bytes are shown in hex format."
            $processedLine = & $LineProcessor $noteLine $lineNumber
            if ($null -ne $processedLine) {
                $lines += $processedLine
            }
        }
        catch {
            $lineNumber++
            $errorLine = "Error generating hex dump: $($_.Exception.Message)"
            $processedLine = & $LineProcessor $errorLine $lineNumber
            if ($null -ne $processedLine) {
                $lines += $processedLine
            }
        }
        
        return @{
            Success = $true
            Lines = $lines
            FileType = "Binary"
            LineCount = $lineNumber
        }
    }
    catch {
        Write-DLALog -Message "Error reading binary file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Binary"
        }
    }
}

# Function to handle split files (e.g. .001, .002, etc.)
function Read-SplitFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$LineProcessor = { param($line, $lineNumber) return $line }
    )
    
    try {
        Write-DLALog -Message "Reading split file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        # First, check if it's a text file
        if (Test-TextFile -FilePath $FilePath) {
            return Read-TextFile -FilePath $FilePath -LineProcessor $LineProcessor
        }
        
        # Otherwise, treat as binary
        return Read-BinaryFile -FilePath $FilePath -LineProcessor $LineProcessor
    }
    catch {
        Write-DLALog -Message "Error reading split file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FileType = "Split File"
        }
    }
}

# Function to search a file using the appropriate file handler
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
        [scriptblock]$ProgressHandler = { param($percentComplete) }
    )
    
    try {
        Write-DLALog -Message "Searching file: $FilePath" -Level DEBUG -Component "FileTypeHandler"
        
        # Get file info
        $fileInfo = Get-Item -Path $FilePath
        $fileSize = $fileInfo.Length
        $lastModified = $fileInfo.LastWriteTime
        $fileType = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        # Create results object
        $results = @{
            FilePath = $FilePath
            FileName = $fileInfo.Name
            FileSize = $fileSize
            LastModified = $lastModified
            FileType = $fileType
            MatchCount = 0
            Matches = @()
            Skipped = $false
        }
        
        # Get the appropriate parser for this file type
        $parserName = Get-FileParser -FilePath $FilePath
        
        # Check file size limit (skip files larger than 100MB by default)
        $fileSizeLimitMB = 100
        if ($fileSize -gt ($fileSizeLimitMB * 1MB)) {
            Write-DLALog -Message "File is larger than $fileSizeLimitMB MB, skipping: $FilePath" -Level WARNING -Component "FileTypeHandler"
            $results.Skipped = $true
            $results.SkipReason = "File size exceeds limit ($([Math]::Round($fileSize / 1MB, 2)) MB)"
            return $results
        }
        
        # Create a line processor for the search
        $lineProcessor = {
            param($line, $lineNumber)
            
            # Report progress periodically
            if ($lineNumber % 100 -eq 0 -and $fileSize -gt 0) {
                $position = [Math]::Min([Math]::Round(($lineNumber / ($fileSize / 100)) * 100), 100)
                & $ProgressHandler $position
            }
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                return $line
            }
            
            $matchFound = $false
            $matchDetails = @()
            
            # Process each search term
            foreach ($term in $SearchTerms) {
                $match = $null
                
                # Different search methods based on options
                if ($UseRegex) {
                    # Regex search
                    $regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
                    if (-not $CaseSensitive) {
                        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                    }
                    
                    try {
                        $regex = [regex]::new($term, $regexOptions)
                        $match = $regex.Match($line)
                        
                        if ($match.Success) {
                            $matchFound = $true
                            $matchDetails += @{
                                Term = $term
                                Index = $match.Index
                                Length = $match.Length
                                Value = $match.Value
                            }
                        }
                    }
                    catch {
                        Write-DLALog -Message "Invalid regex pattern '$term': $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
                    }
                }
                elseif ($MatchWholeWord) {
                    # Whole word search
                    $wordPattern = "\b$([regex]::Escape($term))\b"
                    $regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
                    if (-not $CaseSensitive) {
                        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                    }
                    
                    try {
                        $regex = [regex]::new($wordPattern, $regexOptions)
                        $match = $regex.Match($line)
                        
                        if ($match.Success) {
                            $matchFound = $true
                            $matchDetails += @{
                                Term = $term
                                Index = $match.Index
                                Length = $match.Length
                                Value = $match.Value
                            }
                        }
                    }
                    catch {
                        Write-DLALog -Message "Error in whole word search for '$term': $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
                    }
                }
                else {
                    # Simple string search
                    $comparisonType = [StringComparison]::OrdinalIgnoreCase
                    if ($CaseSensitive) {
                        $comparisonType = [StringComparison]::Ordinal
                    }
                    
                    $index = $line.IndexOf($term, $comparisonType)
                    if ($index -ge 0) {
                        $matchFound = $true
                        $matchDetails += @{
                            Term = $term
                            Index = $index
                            Length = $term.Length
                            Value = $line.Substring($index, $term.Length)
                        }
                    }
                }
            }
            
            # If match found, add to results
            if ($matchFound) {
                $results.MatchCount++
                $results.Matches += @{
                    LineNumber = $lineNumber
                    Line = $line
                    Matches = $matchDetails
                }
            }
            
            return $line
        }
        
        # Create a line buffer for context
        $lineBuffer = @()
        $lineCount = 0
        
        # Create a context processor that wraps the search processor
        $contextProcessor = {
            param($line, $lineNumber)
            
            $lineCount++
            
            # Keep track of lines for context
            $lineBuffer += @{
                LineNumber = $lineNumber
                Content = $line
            }
            
            # Keep only the needed lines in buffer
            if ($lineBuffer.Count -gt ($ContextLines * 2 + 1)) {
                $lineBuffer = $lineBuffer | Select-Object -Last ($ContextLines * 2 + 1)
            }
            
            # Process current line for search
            $processed = & $lineProcessor $line $lineNumber
            
            # If this was a match and we need context, update the match object
            if ($processed -and $results.Matches.Count -gt 0) {
                $lastMatchIndex = $results.Matches.Count - 1
                
                # If this is a new match
                if ($results.Matches[$lastMatchIndex].LineNumber -eq $lineNumber) {
                    # Calculate context range
                    $startLine = [Math]::Max(1, $lineNumber - $ContextLines)
                    $endLine = $lineNumber + $ContextLines
                    
                    # Get context lines
                    $contextLines = $lineBuffer | Where-Object { 
                        $_.LineNumber -ge $startLine -and $_.LineNumber -le $endLine 
                    } | Sort-Object -Property LineNumber
                    
                    # Add context to match
                    $results.Matches[$lastMatchIndex].Context = $contextLines
                }
            }
            
            return $processed
        }
        
        # Invoke appropriate parser with context processor
        $parserFunction = Get-Command -Name $parserName -ErrorAction SilentlyContinue
        
        if ($parserFunction) {
            $parseResult = & $parserName -FilePath $FilePath -LineProcessor $contextProcessor
            
            # Update results with file type information
            if ($parseResult.FileType) {
                $results.FileType = $parseResult.FileType
            }
            
            # Handle parsing errors
            if (-not $parseResult.Success) {
                $results.Skipped = $true
                $results.SkipReason = "Parsing error: $($parseResult.Error)"
            }
        }
        else {
            Write-DLALog -Message "Parser function '$parserName' not found for $FilePath" -Level ERROR -Component "FileTypeHandler"
            $results.Skipped = $true
            $results.SkipReason = "No parser available for this file type"
        }
        
        # Return search results
        return $results
    }
    catch {
        Write-DLALog -Message "Error searching file $FilePath`: $($_.Exception.Message)" -Level ERROR -Component "FileTypeHandler"
        return @{
            FilePath = $FilePath
            FileName = (Split-Path -Path $FilePath -Leaf)
            FileSize = 0
            LastModified = [DateTime]::Now
            FileType = "Unknown"
            MatchCount = 0
            Matches = @()
            Skipped = $true
            SkipReason = "Error: $($_.Exception.Message)"
        }
    }
}

# Export the public functions
Export-ModuleMember -Function @(
    'Get-FileParser',
    'Test-TextFile',
    'Read-TextFile',
    'Read-LogFile',
    'Read-EvtxFile',
    'Read-RegFile',
    'Read-XmlFile',
    'Read-JsonFile',
    'Read-HtmlFile',
    'Read-CsvFile',
    'Read-CabFile',
    'Read-BinaryEtlFile',
    'Read-BinaryFile',
    'Read-SplitFile',
    'Search-File'
)