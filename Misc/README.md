# Misc - Helper Functions and Utilities

This directory contains additional helper modules and utilities that complement the main Collateral-RedmineDB PowerShell module.

## Overview

The Misc folder provides extended functionality including comprehensive logging, data processing, file operations, and utility functions that enhance the core Redmine database operations.

## Contents

### logging.psm1 🆕
A comprehensive, enterprise-grade logging module providing structured logging capabilities with multiple output targets, log levels, and advanced features.

#### Key Features
- **Multiple Log Levels**: Trace, Debug, Information, Warning, Error, Critical, None
- **Multiple Output Targets**: Console (with color coding), File, Windows Event Log
- **Structured Logging**: Timestamped messages with source information and caller detection
- **Exception Handling**: Detailed exception logging with stack traces
- **File Management**: Automatic log rotation, configurable file sizes, and directory creation
- **Runtime Configuration**: Change log levels and targets on-the-fly
- **Production Ready**: Thread-safe operations with comprehensive error handling

### helper.psm1
A comprehensive PowerShell module providing advanced Excel (XLSX) and CSV data processing capabilities, plus robust HTTP client functionality.

#### Key Features
- **HTTP Client**: Robust HTTP request function with retry logic and comprehensive error handling for REST APIs
- **Excel Integration**: Full Microsoft Excel COM object support for reading and writing XLSX files
- **Advanced CSV Processing**: Enhanced CSV import/export with custom delimiters, encoding, and validation
- **Data Comparison**: Compare CSV files and identify differences
- **File Conversion**: Convert between CSV and Excel formats
- **Data Validation**: Comprehensive validation for CSV file structure and content

## Functions Reference

### HTTP Communication Functions

#### `Send-HTTPRequest`
Robust HTTP client function with comprehensive retry logic and error handling for REST API communication.

**Purpose:**
Provides a reliable wrapper around PowerShell's `Invoke-RestMethod` and `Invoke-WebRequest` with built-in retry mechanisms, proper error handling, and support for various HTTP scenarios commonly encountered when working with REST APIs like Redmine.

**Parameters:**
- `Uri` - Target URL for the HTTP request (required)
- `Method` - HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS) - default: GET
- `Headers` - Hashtable of custom HTTP headers
- `Body` - Request body content (automatically converts hashtables/objects to JSON)
- `ContentType` - Content type for request body (default: application/json)
- `WebSession` - Web session object for maintaining cookies/state
- `TimeoutSec` - Request timeout in seconds (default: 30)
- `MaxRetries` - Maximum retry attempts for failed requests (default: 3)
- `RetryDelay` - Delay between retry attempts in seconds (default: 2)
- `UseBasicParsing` - Use basic parsing instead of IE DOM parser
- `PassThru` - Return full response object instead of just content
- `Credential` - PSCredential object for authentication
- `UserAgent` - Custom User-Agent string (default: PowerShell-RedmineDB/1.0.1)

**Key Features:**
- **Intelligent Retry Logic**: Automatically retries transient failures while avoiding retries for client errors (4xx)
- **Error Classification**: Distinguishes between authentication errors, client errors, server errors, and network issues
- **Session Management**: Supports web sessions for maintaining authentication state
- **Flexible Body Handling**: Automatically converts PowerShell objects to JSON when appropriate
- **Comprehensive Logging**: Verbose and debug output for troubleshooting
- **Timeout Management**: Configurable timeouts with proper exception handling

**Examples:**

```powershell
# Simple GET request
$data = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json"

# Authenticated request with custom headers
$headers = @{
    'X-Redmine-API-Key' = 'your-api-key-here'
    'Accept' = 'application/json'
}
$issues = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Headers $headers

# POST request with JSON body
$newIssue = @{
    issue = @{
        project_id = 1
        subject = "New Issue"
        description = "Issue description"
        priority_id = 4
    }
}
$result = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Method POST -Body $newIssue -Headers $headers

# Request with custom retry settings for unreliable endpoints
$data = Send-HTTPRequest -Uri "https://external-api.com/data" -MaxRetries 5 -RetryDelay 3

# Using web session for authentication flow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginData = @{ username = "user"; password = "pass" }
Send-HTTPRequest -Uri "https://app.com/login" -Method POST -Body $loginData -WebSession $session
$protectedData = Send-HTTPRequest -Uri "https://app.com/protected" -WebSession $session

# Get full response object with status codes and headers
$response = Send-HTTPRequest -Uri "https://api.example.com/status" -PassThru
Write-Host "Status: $($response.StatusCode)"
Write-Host "Headers: $($response.Headers | ConvertTo-Json)"
```

**Error Handling:**
- **401/403 Errors**: Authentication/authorization failures - no retry
- **4xx Client Errors**: Generally no retry except for 408 (timeout) and 429 (rate limit)
- **5xx Server Errors**: Automatic retry with exponential backoff
- **Network Issues**: Automatic retry for connectivity problems
- **Timeouts**: Configurable timeout with retry logic

**Integration with Redmine:**
This function is specifically designed to work seamlessly with Redmine REST API endpoints and handles common Redmine authentication patterns, API key management, and response formats.

### Logging Functions 🆕

The logging module provides enterprise-grade logging capabilities that are automatically integrated into the main Collateral-RedmineDB module.

#### Core Logging Functions

##### `Write-LogTrace`, `Write-LogDebug`, `Write-LogInfo`, `Write-LogWarn`, `Write-LogError`, `Write-LogCritical`
Write messages at different log levels with optional exception details and custom source information.

**Parameters:**
- `Message` - The log message (required)
- `Exception` - Exception object to include in log (optional)
- `Source` - Custom source identifier (optional, auto-detected if not provided)

**Examples:**
```powershell
# Basic logging at different levels
Write-LogInfo "Application started successfully"
Write-LogWarn "Configuration file not found, using defaults"
Write-LogError "Database connection failed"

# Exception logging
try {
    # Some operation that might fail
    Connect-Database
}
catch {
    Write-LogError "Failed to connect to database" -Exception $_.Exception
}

# Custom source
Write-LogInfo "Processing batch job" -Source "BatchProcessor"
```

#### Configuration Functions

##### `Initialize-Logger`
Initialize the global logger with custom settings.

**Parameters:**
- `Source` - Logger source name (default: "Collateral-RedmineDB")
- `MinimumLevel` - Minimum log level (default: Information)
- `Targets` - Output targets (default: Console)
- `LogFilePath` - Custom log file path (optional)
- `EnableColorOutput` - Enable color-coded console output (default: true)

**Example:**
```powershell
# Initialize with custom settings
Initialize-Logger -Source "MyApp" -MinimumLevel Debug -Targets Console
```

##### `Set-LogLevel`
Change the minimum log level at runtime.

**Example:**
```powershell
Set-LogLevel -Level Debug  # Show debug messages
Set-LogLevel -Level Error  # Show only errors and critical messages
```

##### `Get-LogConfiguration`
Retrieve current logging configuration.

**Example:**
```powershell
$config = Get-LogConfiguration
Write-Host "Current log level: $($config.MinimumLevel)"
Write-Host "Log file: $($config.LogFilePath)"
```

#### Helper Functions for Easy Configuration 🆕

##### `Enable-FileLogging` / `Disable-FileLogging`
Easily enable or disable file logging.

**Examples:**
```powershell
# Enable file logging with default path
Enable-FileLogging

# Enable with custom path
Enable-FileLogging -LogFilePath "C:\MyApp\logs\app.log"

# Disable file logging
Disable-FileLogging
```

##### `Enable-ConsoleLogging` / `Disable-ConsoleLogging`
Control console output.

**Examples:**
```powershell
Enable-ConsoleLogging   # Show messages in console
Disable-ConsoleLogging  # Suppress console output (useful for automated scripts)
```

##### `Set-LogFile`
Change the log file path.

**Example:**
```powershell
Set-LogFile -Path "C:\MyApp\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
```

#### Advanced Logging Features

**Structured Log Format:**
```
[2025-09-09 22:46:28.921] [INFORMATION] [Source] Message content
```

**Automatic Caller Detection:**
The logging system automatically detects the calling function and file for source information.

**Exception Details:**
Exception logging includes the full exception message and optionally stack traces.

**Color-Coded Output:**
- Trace: Gray
- Debug: Cyan
- Information: White
- Warning: Yellow
- Error: Red
- Critical: Magenta

### Excel Functions

#### `Import-ExcelData`
Imports data from Excel files with advanced options.

**Parameters:**
- `Path` - Path to Excel file (required)
- `WorksheetName` - Name of worksheet to import
- `WorksheetIndex` - Index of worksheet (1-based)
- `StartRow/EndRow` - Row range for import
- `StartColumn/EndColumn` - Column range for import
- `HeaderRow` - Row containing headers (default: 1)
- `NoHeader` - Skip header processing
- `AsDataTable` - Return as DataTable object

**Example:**
```powershell
# Import specific worksheet with custom range
$data = Import-ExcelData -Path "C:\reports\data.xlsx" -WorksheetName "Summary" -StartRow 2 -HeaderRow 1
```

#### `Export-ExcelData`
Exports PowerShell objects to Excel with formatting options.

**Parameters:**
- `Data` - Objects to export (required)
- `Path` - Output Excel file path (required)
- `WorksheetName` - Name for worksheet (default: "Sheet1")
- `AutoFit` - Auto-adjust column widths
- `FreezeTopRow` - Freeze header row
- `TableStyle` - Apply Excel table styling (Light1-3, Medium1-3, Dark1-3)
- `ShowGridLines` - Show/hide gridlines
- `Append` - Add to existing file

**Example:**
```powershell
# Export with formatting
$users | Export-ExcelData -Path "C:\reports\users.xlsx" -AutoFit -FreezeTopRow -TableStyle "Medium2"
```

### CSV Functions

#### `Import-CsvData`
Enhanced CSV import with validation and processing options.

**Parameters:**
- `Path` - CSV file path (required)
- `Delimiter` - Field delimiter (default: comma)
- `Encoding` - File encoding (UTF8, ASCII, Unicode, etc.)
- `Header` - Custom header names
- `SkipRows` - Skip rows at file beginning
- `MaxRows` - Limit imported rows
- `ValidateHeaders` - Validate header existence
- `TrimWhitespace` - Remove leading/trailing spaces
- `EmptyStringAsNull` - Convert empty strings to null

**Example:**
```powershell
# Import with custom delimiter and validation
$data = Import-CsvData -Path "C:\data\export.csv" -Delimiter ";" -TrimWhitespace -ValidateHeaders
```

#### `Export-CsvData`
Advanced CSV export with formatting and sorting options.

**Parameters:**
- `Data` - Objects to export (required)
- `Path` - Output CSV file path (required)
- `Delimiter` - Field delimiter
- `Encoding` - File encoding
- `NoTypeInformation` - Exclude PowerShell type info
- `Properties` - Specific properties to export
- `SortBy` - Sort data before export
- `Append` - Add to existing file

**Example:**
```powershell
# Export specific properties sorted by name
Export-CsvData -Data $users -Path "C:\reports\users.csv" -Properties @("Name", "Email", "Department") -SortBy "Name"
```

#### `Compare-CsvData`
Compares two CSV files and identifies differences.

**Parameters:**
- `ReferencePath` - Baseline CSV file (required)
- `DifferencePath` - Comparison CSV file (required)
- `KeyProperty` - Unique identifier column (required)
- `IncludeEqual` - Include unchanged rows
- `Delimiter` - Field delimiter

**Example:**
```powershell
# Compare user files using ID as key
$changes = Compare-CsvData -ReferencePath "old_users.csv" -DifferencePath "new_users.csv" -KeyProperty "UserID"

# View only additions and deletions
$changes | Where-Object { $_.ChangeType -in @("Added", "Deleted") }
```

## Integration with Main Module

### Automatic Logging Integration 🆕

The logging module is automatically imported and initialized when you import the main Collateral-RedmineDB module:

```powershell
# Import module (logging auto-initializes)
Import-Module Collateral-RedmineDB

# Logging is immediately available
Write-LogInfo "Starting Redmine operations"

# Configure logging as needed
Set-LogLevel -Level Debug
Enable-FileLogging
```

### Enhanced Error Tracking

The main module now includes comprehensive logging throughout its operations:

```powershell
# All module operations are automatically logged
Connect-Redmine -Server "https://redmine.company.com" -Credential $cred
# Logs: "Using credential-based authentication"
# Logs: "Successfully connected to Redmine server"

Get-RedmineDB -Id 12345
# Logs: "Successfully retrieved DB entry with ID: 12345"

# Errors are automatically captured with details
try {
    Connect-Redmine -Server "invalid-url"
}
catch {
    # Automatic error logging with exception details
    # Manual additional context can be added
    Write-LogError "Failed during initial connection attempt" -Exception $_.Exception
}
```

### Data Processing with Logging

```powershell
# Combined data processing and logging workflow
Write-LogInfo "Starting batch data processing"

try {
    # Import data with logging
    Write-LogDebug "Importing CSV data from file"
    $data = Import-CsvData -Path "input.csv" -TrimWhitespace -ValidateHeaders
    Write-LogInfo "Successfully imported $($data.Count) records"
    
    # Process each record with progress logging
    $processed = 0
    $errors = 0
    
    foreach ($record in $data) {
        try {
            # Process record
            Set-RedmineDB -Data $record
            $processed++
            
            if ($processed % 100 -eq 0) {
                Write-LogInfo "Progress: $processed/$($data.Count) records processed"
            }
        }
        catch {
            $errors++
            Write-LogError "Failed to process record ID: $($record.Id)" -Exception $_.Exception
        }
    }
    
    # Export results with logging
    Write-LogDebug "Exporting results to Excel"
    $data | Export-ExcelData -Path "results.xlsx" -AutoFit -TableStyle "Medium1"
    
    Write-LogInfo "Batch processing completed. Processed: $processed, Errors: $errors"
}
catch {
    Write-LogCritical "Batch processing failed critically" -Exception $_.Exception
}
```

### HTTP + Data Processing Integration

The helper.psm1 module combines HTTP client functionality with data processing capabilities for comprehensive workflows:

```powershell
# Import the main module and helper functions
Import-Module .\Collateral-RedmineDB.psd1
Import-Module .\Misc\helper.psm1

# Use Send-HTTPRequest for custom Redmine API calls
$headers = @{ 'X-Redmine-API-Key' = 'your-api-key' }
$issues = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Headers $headers

# Export Redmine data to Excel with formatting
$issues.issues | Export-ExcelData -Path "C:\reports\redmine_issues.xlsx" -AutoFit -TableStyle "Medium1"

# Compare current vs previous Redmine exports
$previousData = Import-CsvData -Path "previous_redmine_export.csv"
$currentData = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Headers $headers
$currentData.issues | Export-CsvData -Path "current_redmine_export.csv"

$comparison = Compare-CsvData -ReferencePath "previous_redmine_export.csv" -DifferencePath "current_redmine_export.csv" -KeyProperty "id"

# Create comprehensive report with HTTP data and Excel formatting
$reportData = $comparison | Where-Object { $_.ChangeType -ne 'Equal' }
$reportData | Export-ExcelData -Path "redmine_changes_report.xlsx" -WorksheetName "Changes" -AutoFit -FreezeTopRow
```

### Advanced HTTP + Data Processing Workflow
```powershell
# Multi-step data processing with error handling and logging
Write-LogInfo "Starting comprehensive Redmine data sync workflow"

try {
    # Fetch data from multiple Redmine endpoints
    Write-LogInfo "Fetching data from Redmine API endpoints"
    $projects = Send-HTTPRequest -Uri "https://redmine.company.com/projects.json" -Headers $headers -MaxRetries 5
    Write-LogInfo "Retrieved $($projects.projects.Count) projects"
    
    $users = Send-HTTPRequest -Uri "https://redmine.company.com/users.json" -Headers $headers -MaxRetries 5
    Write-LogInfo "Retrieved $($users.users.Count) users"
    
    $issues = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Headers $headers -MaxRetries 5
    Write-LogInfo "Retrieved $($issues.issues.Count) issues"
    
    # Export each dataset to separate worksheets with logging
    Write-LogInfo "Exporting data to Excel workbook"
    $projects.projects | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Projects" -AutoFit
    $users.users | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Users" -AutoFit -Append
    $issues.issues | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Issues" -AutoFit -Append
    
    Write-LogInfo "Redmine data successfully exported to redmine_data.xlsx"
} catch {
    Write-LogError "Failed to process Redmine data" -Exception $_.Exception
}
```

## Logging Best Practices 🆕

### 1. Use Appropriate Log Levels
```powershell
Write-LogTrace "Entering function with parameters: $($params | ConvertTo-Json)"  # Very detailed
Write-LogDebug "Processing item: $($item.Name)"                                  # Debug info
Write-LogInfo "User login successful: $username"                                 # Normal operations  
Write-LogWarn "Configuration setting missing, using default"                     # Potential issues
Write-LogError "Database operation failed"                                       # Errors
Write-LogCritical "System cannot continue, shutting down"                       # Critical failures
```

### 2. Include Context in Messages
```powershell
# Good: Include relevant context
Write-LogError "Failed to process order ID: $orderId for customer: $customerId" -Exception $_.Exception

# Better: Include operation context
Write-LogInfo "Database backup completed successfully. Size: $($backupSize)MB, Duration: $($duration.TotalMinutes) minutes"
```

### 3. Configure for Environment
```powershell
# Development: Verbose logging to console
Set-LogLevel -Level Debug
Enable-ConsoleLogging

# Production: Info+ to file, Error+ to event log  
Set-LogLevel -Level Information
Enable-FileLogging -LogFilePath "C:\Logs\RedmineDB\app.log"
# Event log requires administrator privileges to set up
```

### 4. Structure for Searchability
```powershell
# Use consistent formatting for searchable logs
Write-LogInfo "OPERATION_START: User authentication for: $username"
Write-LogInfo "OPERATION_END: User authentication successful for: $username, Duration: $($timer.ElapsedMilliseconds)ms"
```

## Requirements

### System Requirements
- PowerShell 5.1 or later
- Microsoft Excel (for Excel functions)
- Windows (for COM object support and Event Log)

### Dependencies
- No external PowerShell modules required
- Excel functions require Microsoft Office/Excel installation
- CSV functions work on any PowerShell-supported platform
- Event log logging requires administrator privileges for initial setup

## Error Handling

All functions include comprehensive error handling:
- Parameter validation with descriptive error messages
- File existence and accessibility checks
- COM object cleanup and memory management
- Graceful handling of Excel application failures
- Automatic logging of errors and exceptions

## Performance Considerations

### Logging Performance 🆕
- Logging operations are optimized for minimal performance impact
- Log level filtering prevents expensive string operations for suppressed levels
- File I/O uses buffered streams with auto-flush
- Color output can be disabled for improved performance in automated scenarios

### Excel Operations
- Large files (>10,000 rows) may take longer to process
- COM object creation has overhead - batch operations when possible
- Auto-fit and styling options increase processing time

### CSV Operations
- Memory usage scales with file size
- Use `MaxRows` parameter for large file sampling
- Stream processing not implemented - entire files loaded into memory

## Examples and Use Cases

### Production Application with Comprehensive Logging 🆕
```powershell
# Initialize application with production logging
Initialize-Logger -Source "RedmineSync" -MinimumLevel Information
Enable-FileLogging -LogFilePath "C:\Logs\RedmineSync\sync-$(Get-Date -Format 'yyyy-MM-dd').log"

Write-LogInfo "RedmineSync application starting - Version 1.0.3"

try {
    # Application startup
    Write-LogInfo "Loading configuration from environment"
    $config = Import-RedmineEnv
    
    Write-LogInfo "Connecting to Redmine server: $($config.Server)"
    Connect-Redmine -Server $config.Server -ApiKey $config.ApiKey
    
    # Data processing with progress tracking
    Write-LogInfo "Starting synchronization process"
    $items = Get-RedmineDB
    Write-LogInfo "Retrieved $($items.Count) items for synchronization"
    
    $startTime = Get-Date
    $processed = 0
    $errors = 0
    
    foreach ($item in $items) {
        try {
            # Process item
            $processed++
            Write-LogDebug "Processing item: $($item.Name) (ID: $($item.Id))"
            
            # Log progress every 50 items
            if ($processed % 50 -eq 0) {
                $elapsed = (Get-Date) - $startTime
                $rate = $processed / $elapsed.TotalMinutes
                Write-LogInfo "Progress: $processed/$($items.Count) items processed ($([math]::Round($rate, 1)) items/min)"
            }
        }
        catch {
            $errors++
            Write-LogError "Failed to process item: $($item.Name)" -Exception $_.Exception
        }
    }
    
    $totalTime = (Get-Date) - $startTime
    Write-LogInfo "Synchronization completed. Processed: $processed, Errors: $errors, Duration: $($totalTime.TotalMinutes) minutes"
    
    # Generate report
    Write-LogInfo "Generating synchronization report"
    # ... report generation logic ...
    
    Write-LogInfo "RedmineSync application completed successfully"
}
catch {
    Write-LogCritical "RedmineSync application failed" -Exception $_.Exception
    exit 1
}
```

### Data Migration Workflow with Logging 🆕
```powershell
Write-LogInfo "Starting data migration workflow"

try {
    # 1. Export current Redmine data
    Write-LogInfo "Exporting current Redmine data"
    $currentIssues = Get-RedmineIssues
    $currentIssues | Export-CsvData -Path "current_issues.csv"
    Write-LogInfo "Exported $($currentIssues.Count) current issues to CSV"

    # 2. Compare with previous export
    Write-LogInfo "Comparing with previous export"
    if (Test-Path "previous_issues.csv") {
        $changes = Compare-CsvData -ReferencePath "previous_issues.csv" -DifferencePath "current_issues.csv" -KeyProperty "id"
        Write-LogInfo "Found $($changes.Count) changes since last export"
        
        # 3. Generate Excel report of changes
        Write-LogInfo "Generating change report"
        $changes | Export-ExcelData -Path "issue_changes_report.xlsx" -AutoFit -TableStyle "Light1"
        Write-LogInfo "Change report saved to issue_changes_report.xlsx"
    } else {
        Write-LogWarn "No previous export found for comparison"
    }
    
    Write-LogInfo "Data migration workflow completed successfully"
}
catch {
    Write-LogError "Data migration workflow failed" -Exception $_.Exception
}
```

## Troubleshooting

### Common Logging Issues 🆕

1. **File Logging Not Working**
   ```powershell
   # Check current configuration
   $config = Get-LogConfiguration
   Write-Host "Targets: $($config.Targets)"
   Write-Host "Log file: $($config.LogFilePath)"
   
   # Verify directory exists and is writable
   $logDir = Split-Path $config.LogFilePath
   Test-Path $logDir  # Should return True
   ```

2. **Performance Issues**
   ```powershell
   # Reduce log level for production
   Set-LogLevel -Level Warning  # Only warnings, errors, and critical
   
   # Disable color output for automated scripts
   $logger = Get-Logger
   $logger.EnableColorOutput($false)
   ```

3. **Event Log Issues**
   ```powershell
   # Event log requires administrator privileges
   # Check if running as administrator
   $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
   $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
   Write-Host "Running as administrator: $isAdmin"
   ```

### Log File Management 🆕
```powershell
# Check log file size and manage rotation
$config = Get-LogConfiguration
if (Test-Path $config.LogFilePath) {
    $logFile = Get-Item $config.LogFilePath
    Write-Host "Log file size: $([math]::Round($logFile.Length / 1MB, 2)) MB"
    Write-Host "Created: $($logFile.CreationTime)"
    Write-Host "Last modified: $($logFile.LastWriteTime)"
}

# Archive old logs
$archiveDate = (Get-Date).AddDays(-30)
Get-ChildItem (Split-Path $config.LogFilePath) -Filter "*.log" | 
    Where-Object { $_.LastWriteTime -lt $archiveDate } |
    Compress-Archive -DestinationPath "old_logs_$(Get-Date -Format 'yyyy-MM').zip"
```

The Misc directory now provides a complete suite of utilities for enterprise-grade logging, data processing, and file operations that work seamlessly with the main Collateral-RedmineDB module!
# Validate imported CSV before processing
$validation = Test-CsvData -Path "import_data.csv" -RequiredHeaders @("Name", "Priority", "Status")

if ($validation.IsValid) {
    $data = Import-CsvData -Path "import_data.csv" -TrimWhitespace
    # Process validated data...
} else {
    Write-Error "Data validation failed: $($validation.Errors -join '; ')"
}
```

## Version History

### v1.0.0 (September 9, 2025)
- Initial release with Excel and CSV helper functions
- Full COM object integration for Excel operations
- Comprehensive validation and error handling
- Advanced comparison and conversion utilities

## Contributing

When adding new functions to the helper module:
1. Follow the established parameter naming conventions
2. Include comprehensive comment-based help
3. Implement proper error handling and validation
4. Add examples to this README
5. Test with various file sizes and formats

## Support

For issues or questions regarding the helper functions:
1. Check the function help: `Get-Help <FunctionName> -Full`
2. Review error messages for specific validation failures
3. Ensure Excel is properly installed for XLSX operations
4. Verify file permissions and accessibility