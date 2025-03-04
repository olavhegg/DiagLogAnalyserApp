# DiagLog Analyzer

A PowerShell-based application for analyzing Windows diagnostic log files, with a focus on handling complex diagnostic data capture structures such as those found in MDM diagnostics.

## Features

- **Folder Structure Analysis**: Quickly scan and understand complex diagnostic log directory structures
- **Intelligent CAB Extraction**: Automatically extract CAB files while preserving their context and relationship to original files
- **Smart Content Search**: Search across multiple files with filtering by file type, pattern matching, and context display
- **Visual Reporting**: Generate interactive HTML reports of analysis findings and search results
- **Intuitive GUI Interface**: Easy-to-use interface that guides users through the analysis process

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- .NET Framework 4.7.2 or later

## Installation

No installation required. Simply clone or download this repository and run the Start-Analysis.ps1 script.

## Usage

1. Run Start-Analysis.ps1 to launch the application
2. Select a DiagLogs root folder to analyze
3. Choose an output folder for results
4. Use the integrated tools to analyze structure, extract CAB files, and search content

## Key Components

- **Structure Analysis**: Scan directory trees to understand file relationships and types
- **CAB Extraction**: Extract and index CAB files while maintaining references to source locations
- **Content Search**: Search across multiple file types with context-aware results
- **Reporting Engine**: Generate HTML reports with interactive elements

## Development

This application uses a modular architecture:

- src/Core/ - Core analysis functionality
- src/GUI/ - User interface components
- src/Utils/ - Utility functions and helpers
- src/Config/ - Configuration management

## License

MIT License

## Acknowledgments

- YSoft SafeQ diagnostic tools which inspired this application's approach to log analysis
