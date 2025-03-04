# DiagLog Analyzer - Reporting Module
# This module handles generation of HTML reports

# Import dependencies
. (Join-Path -Path $PSScriptRoot -ChildPath "Logging.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "FileSystem.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\FileSearch.ps1")

function New-AnalysisReport {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$AnalysisResults,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = $null
    )
    
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $OutputPath = Join-Path -Path (Get-AppSetting -Name "DefaultOutputPath") -ChildPath "AnalysisReport-$timestamp.html"
    }
    
    Write-Log -Message "Generating analysis report: $OutputPath" -Level INFO -Component "Reporting"
    
    # Create HTML header with styles
    $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog Analysis Report</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; color: #333; line-height: 1.6; }
        h1 { color: #0066cc; border-bottom: 1px solid #eee; padding-bottom: 10px; }
        h2 { color: #0066cc; margin-top: 30px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
        h3 { color: #0066cc; }
        .summary { background-color: #f8f9fa; padding: 15px; margin-bottom: 20px; border-radius: 5px; border-left: 4px solid #0066cc; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th { background-color: #0066cc; color: white; text-align: left; padding: 8px; position: sticky; top: 0; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        tr:hover { background-color: #e6f2ff; }
        .scrollable { max-height: 600px; overflow-y: auto; margin-bottom: 30px; }
        .filter-container { margin-bottom: 20px; }
        .filter-container label { margin-right: 10px; }
        .chart-container { height: 400px; margin-bottom: 40px; }
        .flex-container { display: flex; flex-wrap: wrap; gap: 20px; }
        .flex-item { flex: 1; min-width: 300px; }
        .timestamp { color: #666; font-size: 0.9em; }
        .pill { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.85em; font-weight: bold; }
        .pill-text { background-color: #c3e6cb; color: #155724; }
        .pill-binary { background-color: #f5c6cb; color: #721c24; }
        .pill-archive { background-color: #bee5eb; color: #0c5460; }
        .pill-image { background-color: #ffeeba; color: #856404; }
        .pill-other { background-color: #d6d8db; color: #383d41; }
        
        /* Add responsive design */
        @media (max-width: 768px) {
            .flex-item { min-width: 100%; }
        }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        function filterTable(tableId) {
            var input = document.getElementById(tableId + 'Filter');
            var table = document.getElementById(tableId);
            var filter = input.value.toUpperCase();
            var rows = table.getElementsByTagName('tr');
            
            for (var i = 1; i < rows.length; i++) {
                var visible = false;
                var cells = rows[i].getElementsByTagName('td');
                for (var j = 0; j < cells.length; j++) {
                    var cell = cells[j];
                    if (cell) {
                        if (cell.textContent.toUpperCase().indexOf(filter) > -1) {
                            visible = true;
                            break;
                        }
                    }
                }
                rows[i].style.display = visible ? '' : 'none';
            }
        }
    </script>
</head>
<body>
    <h1>DiagLog Analysis Report</h1>
    <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
"@
    
    # Create summary section
    $htmlSummary = @"
    <div class="summary">
        <h2>Analysis Summary</h2>
        <p><strong>Source Path:</strong> $($AnalysisResults.SourcePath)</p>
        <p><strong>Analysis Time:</strong> $($AnalysisResults.AnalysisTime)</p>
        <p><strong>Total Items:</strong> $($AnalysisResults.TotalItems)</p>
        <p><strong>Files:</strong> $($AnalysisResults.Files)</p>
        <p><strong>Directories:</strong> $($AnalysisResults.Directories)</p>
        <p><strong>Total Size:</strong> $(Format-FileSize -SizeInBytes $AnalysisResults.TotalSize)</p>
        <p><strong>Directory Depth:</strong> $($AnalysisResults.DirectoryDepth)</p>
        <p><strong>CAB Files:</strong> $($AnalysisResults.CabFiles.Count)</p>
    </div>
    
    <div class="flex-container">
        <div class="flex-item">
            <h2>File Type Distribution</h2>
            <canvas id="fileTypeChart"></canvas>
        </div>
        <div class="flex-item">
            <h2>File Size Distribution</h2>
            <canvas id="fileSizeChart"></canvas>
        </div>
    </div>
"@
    
    # Create extensions section
    $htmlExtensions = @"
    <h2>File Extensions</h2>
    <div class="filter-container">
        <label for="extensionsTableFilter">Filter:</label>
        <input type="text" id="extensionsTableFilter" onkeyup="filterTable('extensionsTable')" placeholder="Search for extensions...">
    </div>
    <div class="scrollable">
        <table id="extensionsTable">
            <tr>
                <th>Extension</th>
                <th>Count</th>
                <th>Total Size</th>
                <th>Average Size</th>
                <th>Type</th>
            </tr>
"@
    
    # Add extension rows
    foreach ($ext in $AnalysisResults.Extensions.GetEnumerator() | Sort-Object -Property {$_.Value.Count} -Descending) {
        $extension = $ext.Key
        $stats = $ext.Value
        $avgSize = if ($stats.Count -gt 0) { $stats.TotalSize / $stats.Count } else { 0 }
        
        # Determine type for the extension
        $fileType = "text"
        if ($stats.SampleFiles.Count -gt 0) {
            $fileType = Get-FileType -FilePath $stats.SampleFiles[0]
        }
        
        $typeClass = "pill-other"
        switch ($fileType) {
            "text" { $typeClass = "pill-text" }
            "binary" { $typeClass = "pill-binary" }
            "archive" { $typeClass = "pill-archive" }
            "image" { $typeClass = "pill-image" }
        }
        
        $htmlExtensions += @"
            <tr>
                <td>$extension</td>
                <td>$($stats.Count)</td>
                <td>$(Format-FileSize -SizeInBytes $stats.TotalSize)</td>
                <td>$(Format-FileSize -SizeInBytes $avgSize)</td>
                <td><span class="pill $typeClass">$fileType</span></td>
            </tr>
"@
    }
    
    $htmlExtensions += @"
        </table>
    </div>
"@
    
    # Create CAB files section
    $htmlCabFiles = @"
    <h2>CAB Files</h2>
"@
    
    if ($AnalysisResults.CabFiles.Count -gt 0) {
        $htmlCabFiles += @"
    <div class="filter-container">
        <label for="cabTableFilter">Filter:</label>
        <input type="text" id="cabTableFilter" onkeyup="filterTable('cabTable')" placeholder="Search for CAB files...">
    </div>
    <div class="scrollable">
        <table id="cabTable">
            <tr>
                <th>File</th>
                <th>Size</th>
                <th>Extracted</th>
                <th>Extraction Path</th>
            </tr>
"@
        
        foreach ($cab in $AnalysisResults.CabFiles) {
            $htmlCabFiles += @"
            <tr>
                <td>$($cab.RelativePath)</td>
                <td>$(Format-FileSize -SizeInBytes $cab.Size)</td>
                <td>$($cab.Processed -and $cab.ExtractionSuccess)</td>
                <td>$($cab.ExtractedPath)</td>
            </tr>
"@
        }
        
        $htmlCabFiles += @"
        </table>
    </div>
"@
    }
    else {
        $htmlCabFiles += @"
    <p>No CAB files found in the analyzed directory.</p>
"@
    }
    
    # Create largest files section
    $htmlLargestFiles = @"
    <h2>Largest Files</h2>
    <div class="scrollable">
        <table id="largeFilesTable">
            <tr>
                <th>File</th>
                <th>Size</th>
                <th>Type</th>
            </tr>
"@
    
    foreach ($file in $AnalysisResults.LargestFiles | Select-Object -First 20) {
        $relPath = $file.Path.Substring($AnalysisResults.SourcePath.Length + 1)
        $typeClass = "pill-other"
        switch ($file.Type) {
            "text" { $typeClass = "pill-text" }
            "binary" { $typeClass = "pill-binary" }
            "archive" { $typeClass = "pill-archive" }
            "image" { $typeClass = "pill-image" }
        }
        
        $htmlLargestFiles += @"
            <tr>
                <td>$relPath</td>
                <td>$(Format-FileSize -SizeInBytes $file.Size)</td>
                <td><span class="pill $typeClass">$($file.Type)</span></td>
            </tr>
"@
    }
    
    $htmlLargestFiles += @"
        </table>
    </div>
"@
    
    # Create JavaScript for charts
    $htmlCharts = @"
    <script>
        // File type distribution chart
        var fileTypeChartCtx = document.getElementById('fileTypeChart').getContext('2d');
        var fileTypeData = {
            labels: $(($AnalysisResults.FileTypes.Keys | ConvertTo-Json)),
            datasets: [{
                data: $(($AnalysisResults.FileTypes.Values | ForEach-Object { $_.Count } | ConvertTo-Json)),
                backgroundColor: [
                    'rgba(54, 162, 235, 0.7)',
                    'rgba(255, 99, 132, 0.7)',
                    'rgba(255, 206, 86, 0.7)',
                    'rgba(75, 192, 192, 0.7)',
                    'rgba(153, 102, 255, 0.7)'
                ]
            }]
        };
        var fileTypeChart = new Chart(fileTypeChartCtx, {
            type: 'doughnut',
            data: fileTypeData,
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        position: 'right'
                    },
                    title: {
                        display: true,
                        text: 'File Types'
                    }
                }
            }
        });
        
        // File size distribution chart (top extensions by size)
        var fileSizeChartCtx = document.getElementById('fileSizeChart').getContext('2d');
        var extensionsBySize = $(
            ($AnalysisResults.Extensions.GetEnumerator() | 
            Sort-Object -Property {$_.Value.TotalSize} -Descending | 
            Select-Object -First 10 | 
            ForEach-Object { 
                [PSCustomObject]@{ 
                    Extension = $_.Key
                    Size = $_.Value.TotalSize
                } 
            } | ConvertTo-Json)
        );
        
        var fileSizeData = {
            labels: extensionsBySize.map(item => item.Extension),
            datasets: [{
                label: 'Total Size',
                data: extensionsBySize.map(item => item.Size),
                backgroundColor: 'rgba(54, 162, 235, 0.7)',
                borderColor: 'rgba(54, 162, 235, 1)',
                borderWidth: 1
            }]
        };
        
        var fileSizeChart = new Chart(fileSizeChartCtx, {
            type: 'bar',
            data: fileSizeData,
            options: {
                responsive: true,
                maintainAspectRatio: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            // Format byte values
                            callback: function(value) {
                                const units = ['B', 'KB', 'MB', 'GB', 'TB'];
                                let unitIndex = 0;
                                let scaledValue = value;
                                
                                while (scaledValue >= 1024 && unitIndex < units.length - 1) {
                                    unitIndex++;
                                    scaledValue /= 1024;
                                }
                                
                                return scaledValue.toFixed(2) + ' ' + units[unitIndex];
                            }
                        }
                    }
                },
                plugins: {
                    title: {
                        display: true,
                        text: 'Top 10 Extensions by Size'
                    }
                }
            }
        });
    </script>
"@
    
    # Create HTML footer
    $htmlFooter = @"
</body>
</html>
"@
    
    # Combine all HTML parts
    $htmlReport = $htmlHeader + $htmlSummary + $htmlExtensions + $htmlCabFiles + $htmlLargestFiles + $htmlCharts + $htmlFooter
    
    # Save the HTML report
    $htmlReport | Out-File -FilePath $OutputPath -Encoding utf8
    
    Write-Log -Message "Analysis report saved to $OutputPath" -Level INFO -Component "Reporting"
    
    return $OutputPath
}

function New-SearchReport {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SearchResults,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = $null,
        
        [switch]$HighlightMatches = $true
    )
    
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $OutputPath = Join-Path -Path (Get-AppSetting -Name "DefaultOutputPath") -ChildPath "SearchReport-$timestamp.html"
    }
    
    Write-Log -Message "Generating search report: $OutputPath" -Level INFO -Component "Reporting"
    
    # Create HTML header with styles
    $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>DiagLog Search Results</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; color: #333; line-height: 1.6; }
        h1 { color: #0066cc; border-bottom: 1px solid #eee; padding-bottom: 10px; }
        h2 { color: #0066cc; margin-top: 30px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
        h3 { color: #0066cc; }
        .summary { background-color: #f8f9fa; padding: 15px; margin-bottom: 20px; border-radius: 5px; border-left: 4px solid #0066cc; }
        .file-result { background-color: #f8f9fa; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
        .match-context { background-color: white; padding: 10px; margin: 10px 0; border-radius: 3px; border: 1px solid #ddd; }
        .match-line { background-color: #FFEB3B; padding: 2px; }
        .line-number { color: #999; margin-right: 10px; user-select: none; }
        pre { margin: 0; font-family: Consolas, monospace; white-space: pre-wrap; }
        .highlight { background-color: #FFEB3B; font-weight: bold; }
        .filter-container { margin-bottom: 20px; }
        .filter-input { padding: 8px; width: 300px; }
        .timestamp { color: #666; font-size: 0.9em; }
        .file-path { word-break: break-all; }
        
        /* Collapsible sections */
        .collapsible { cursor: pointer; }
        .content { display: none; overflow: hidden; }
        .active { display: block; }
        
/* Responsive design */
        @media (max-width: 768px) {
            .filter-input { width: 100%; }
        }
    </style>
    <script>
        function filterResults() {
            var input = document.getElementById('resultsFilter');
            var filter = input.value.toUpperCase();
            var fileResults = document.getElementsByClassName('file-result');
            
            for (var i = 0; i < fileResults.length; i++) {
                var fileResult = fileResults[i];
                var fileContent = fileResult.textContent || fileResult.innerText;
                
                if (fileContent.toUpperCase().indexOf(filter) > -1) {
                    fileResult.style.display = '';
                } else {
                    fileResult.style.display = 'none';
                }
            }
        }
        
        function toggleCollapsible(element) {
            var content = element.nextElementSibling;
            content.classList.toggle('active');
        }
        
        function expandAll() {
            var contents = document.getElementsByClassName('content');
            for (var i = 0; i < contents.length; i++) {
                contents[i].classList.add('active');
            }
        }
        
        function collapseAll() {
            var contents = document.getElementsByClassName('content');
            for (var i = 0; i < contents.length; i++) {
                contents[i].classList.remove('active');
            }
        }
    </script>
</head>
<body>
    <h1>DiagLog Search Results</h1>
    <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
"@
    
    # Create summary section
    $htmlSummary = @"
    <div class="summary">
        <h2>Search Summary</h2>
        <p><strong>Search Text:</strong> $($SearchResults.SearchText)</p>
        <p><strong>Total Files Processed:</strong> $($SearchResults.FilesProcessed)</p>
        <p><strong>Files With Matches:</strong> $($SearchResults.FilesWithMatches)</p>
        <p><strong>Files Skipped:</strong> $($SearchResults.FilesSkipped)</p>
        <p><strong>Total Matches:</strong> $($SearchResults.TotalMatches)</p>
    </div>
    
    <div class="filter-container">
        <input type="text" id="resultsFilter" onkeyup="filterResults()" class="filter-input" placeholder="Filter results...">
        <button onclick="expandAll()">Expand All</button>
        <button onclick="collapseAll()">Collapse All</button>
    </div>
"@
    
    # Create results section
    $htmlResults = ""
    
    $matchingResults = $SearchResults.Results | Where-Object { -not $_.Skipped -and $_.MatchCount -gt 0 } | Sort-Object -Property MatchCount -Descending
    
    foreach ($fileResult in $matchingResults) {
        $relativePath = $fileResult.FilePath
        
        $htmlResults += @"
    <div class="file-result">
        <h3 class="collapsible" onclick="toggleCollapsible(this)">$($relativePath) ($($fileResult.MatchCount) matches)</h3>
        <div class="content">
"@
        
        foreach ($match in $fileResult.Matches) {
            $htmlResults += @"
            <div class="match-context">
                <p>Line $($match.MatchLineNumber):</p>
"@
            
            # Add context lines before match
            foreach ($line in $match.BeforeContext) {
                $htmlResults += @"
                <pre><span class="line-number">$($line.LineNumber)</span>$($line.Text)</pre>
"@
            }
            
            # Add the matching line with highlighting
            $matchText = $match.MatchLine
            if ($HighlightMatches) {
                $matchText = Highlight-SearchText -Text $match.MatchLine -SearchText $SearchResults.SearchText
            }
            
            $htmlResults += @"
                <pre class="match-line"><span class="line-number">$($match.MatchLineNumber)</span>$matchText</pre>
"@
            
            # Add context lines after match
            foreach ($line in $match.AfterContext) {
                $htmlResults += @"
                <pre><span class="line-number">$($line.LineNumber)</span>$($line.Text)</pre>
"@
            }
            
            $htmlResults += @"
            </div>
"@
        }
        
        $htmlResults += @"
        </div>
    </div>
"@
    }
    
    # If no results, add message
    if ($matchingResults.Count -eq 0) {
        $htmlResults += @"
    <div class="file-result">
        <p>No matches found for the search term.</p>
    </div>
"@
    }
    
    # Create skipped files section
    $htmlSkipped = ""
    
    $skippedResults = $SearchResults.Results | Where-Object { $_.Skipped }
    
    if ($skippedResults.Count -gt 0) {
        $htmlSkipped = @"
    <h2 class="collapsible" onclick="toggleCollapsible(this)">Skipped Files ($($skippedResults.Count))</h2>
    <div class="content">
        <table>
            <tr>
                <th>File</th>
                <th>Reason</th>
            </tr>
"@
        
        foreach ($skipped in $skippedResults) {
            $htmlSkipped += @"
            <tr>
                <td class="file-path">$($skipped.FilePath)</td>
                <td>$($skipped.SkipReason)</td>
            </tr>
"@
        }
        
        $htmlSkipped += @"
        </table>
    </div>
"@
    }
    
    # Create HTML footer
    $htmlFooter = @"
</body>
</html>
"@
    
    # Combine all HTML parts
    $htmlReport = $htmlHeader + $htmlSummary + $htmlResults + $htmlSkipped + $htmlFooter
    
    # Save the HTML report
    $htmlReport | Out-File -FilePath $OutputPath -Encoding utf8
    
    Write-Log -Message "Search report saved to $OutputPath" -Level INFO -Component "Reporting"
    
    return $OutputPath
}