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

No installation required. Simply clone or download this repository and run the Launch-DiagLogAnalyzer.ps1 script.

## Usage

1. Run Launch-DiagLogAnalyzer.ps1 to start the application
   - This script performs prerequisite checks and initializes the environment
   - It then launches the main application interface
2. Select a DiagLogs root folder to analyze
3. Choose an output folder for results
4. Use the integrated tools to analyze structure, extract CAB files, and search content

## Key Components

- **Structure Analysis**: Scan directory trees to understand file relationships and types
- **CAB Extraction**: Extract and index CAB files while maintaining references to source locations
- **Content Search**: Search across multiple file types with context-aware results
- **Reporting Engine**: Generate HTML reports with interactive elements

## Application Architecture

The application uses a modular architecture:

- **Launch-DiagLogAnalyzer.ps1**: Entry point that handles prerequisites and initializes the environment
- **Start-Analysis.ps1**: Main application script that loads all modules and launches the GUI
- **src/Config/**: Configuration management modules
- **src/Core/**: Core analysis functionality modules
- **src/GUI/**: User interface components
- **src/Utils/**: Utility functions and helpers

## Development

### Building a Standalone Application

To build a standalone executable:

1. Install the PS2EXE module:
   ```powershell
   Install-Module -Name ps2exe
   ```

2. Use the following command:
   ```powershell
   Invoke-ps2exe -InputFile "Launch-DiagLogAnalyzer.ps1" -OutputFile "DiagLogAnalyzer.exe" -NoConsole
   ```

### File Structure

```
DiagLogAnalyzerApp/
├── Launch-DiagLogAnalyzer.ps1    # Application launcher
├── Start-Analysis.ps1            # Main application script
├── settings.json                 # Settings file (auto-generated)
├── README.md                     # Documentation
├── logs/                         # Log directory (auto-created)
├── results/                      # Results directory (auto-created)
└── src/
    ├── Config/
    │   └── Settings.ps1          # Settings management
    ├── Core/
    │   ├── Analyzer.ps1          # Core analysis functionality
    │   ├── CabExtractor.ps1      # CAB extraction utilities
    │   └── FileSearch.ps1        # File search utilities
    ├── GUI/
    │   ├── MainForm.ps1          # Main application form
    │   └── Controls.ps1          # Custom controls
    └── Utils/
        ├── FileSystem.ps1        # File system utilities
        ├── Logging.ps1           # Logging utilities
        └── Reporting.ps1         # Reporting utilities
```

## Troubleshooting

If you encounter issues:

1. Check the log files in the `logs` directory
2. Verify settings.json is not corrupted
3. Try running the script with administrator privileges
4. Use the Test-Settings.ps1 script to test configuration

## License

MIT License

## Acknowledgments

- YSoft SafeQ diagnostic tools which inspired this application's approach to log analysis