# Misc - Helper Functions and Utilities

This directory contains additional helper modules and utilities that complement the main Collateral-RedmineDB PowerShell module.

## Overview

The Misc folder provides extended functionality for data processing, file operations, and utility functions that enhance the core Redmine database operations.

## Contents

### Send-HTTPRequest.ps1
A robust HTTP client function with comprehensive retry logic and error handling, specifically designed for REST API communication including Redmine APIs.

#### Key Features
- **Intelligent Retry Logic**: Automatic retry for transient failures with smart error classification
- **Authentication Support**: Multiple authentication methods including API keys and sessions
- **Error Handling**: Comprehensive error categorization and handling strategies
- **Session Management**: Web session support for maintaining authentication state
- **Flexible Request Handling**: Support for all HTTP methods with automatic JSON conversion

### helper.psm1
A comprehensive PowerShell module providing advanced Excel (XLSX) and CSV data processing capabilities.

#### Key Features
- **Excel Integration**: Full Microsoft Excel COM object support for reading and writing XLSX files
- **Advanced CSV Processing**: Enhanced CSV import/export with custom delimiters, encoding, and validation
- **Data Comparison**: Compare CSV files and identify differences
- **File Conversion**: Convert between CSV and Excel formats
- **Data Validation**: Comprehensive validation for CSV file structure and content

## Functions Reference

### HTTP Communication Functions

#### `Send-HTTPRequest`
Robust HTTP client function with retry logic and comprehensive error handling.

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

### Utility Functions

#### `ConvertTo-Excel`
Converts CSV files to Excel format with optional styling.

**Example:**
```powershell
ConvertTo-Excel -CsvPath "data.csv" -ExcelPath "data.xlsx" -AutoFit -TableStyle "Light2"
```

#### `Test-CsvData`
Validates CSV file structure and content against business rules.

**Parameters:**
- `Path` - CSV file to validate (required)
- `RequiredHeaders` - Array of required column names
- `DataTypes` - Hashtable of column data types
- `ValidationRules` - Custom validation scriptblock

**Example:**
```powershell
# Define validation rules
$rules = { 
    param($row) 
    if ([string]::IsNullOrEmpty($row.Email)) { 
        return "Email is required" 
    }
    if ($row.Age -lt 0 -or $row.Age -gt 120) {
        return "Age must be between 0 and 120"
    }
}

# Validate CSV structure and data
$validation = Test-CsvData -Path "users.csv" -RequiredHeaders @("Name", "Email", "Age") -ValidationRules $rules

if (-not $validation.IsValid) {
    Write-Host "Validation Errors:" -ForegroundColor Red
    $validation.Errors | ForEach-Object { Write-Host "  - $_" }
}
```

## Integration with Main Module

The helper functions can be used alongside the main Collateral-RedmineDB module for enhanced data processing and HTTP communication:

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
# Multi-step data processing with error handling
try {
    # Fetch data from multiple Redmine endpoints
    $projects = Send-HTTPRequest -Uri "https://redmine.company.com/projects.json" -Headers $headers -MaxRetries 5
    $users = Send-HTTPRequest -Uri "https://redmine.company.com/users.json" -Headers $headers -MaxRetries 5
    $issues = Send-HTTPRequest -Uri "https://redmine.company.com/issues.json" -Headers $headers -MaxRetries 5
    
    # Export each dataset to separate worksheets
    $projects.projects | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Projects" -AutoFit
    $users.users | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Users" -AutoFit -Append
    $issues.issues | Export-ExcelData -Path "redmine_data.xlsx" -WorksheetName "Issues" -AutoFit -Append
    
    Write-Host "Redmine data successfully exported to redmine_data.xlsx"
} catch {
    Write-Error "Failed to process Redmine data: $($_.Exception.Message)"
}
```

## Requirements

### System Requirements
- PowerShell 5.1 or later
- Microsoft Excel (for Excel functions)
- Windows (for COM object support)

### Dependencies
- No external PowerShell modules required
- Excel functions require Microsoft Office/Excel installation
- CSV functions work on any PowerShell-supported platform

## Error Handling

All functions include comprehensive error handling:
- Parameter validation with descriptive error messages
- File existence and accessibility checks
- COM object cleanup and memory management
- Graceful handling of Excel application failures

## Performance Considerations

### Excel Operations
- Large files (>10,000 rows) may take longer to process
- COM object creation has overhead - batch operations when possible
- Auto-fit and styling options increase processing time

### CSV Operations
- Memory usage scales with file size
- Use `MaxRows` parameter for large file sampling
- Stream processing not implemented - entire files loaded into memory

## Examples and Use Cases

### Data Migration Workflow
```powershell
# 1. Export current Redmine data
$currentIssues = Get-RedmineIssues
$currentIssues | Export-CsvData -Path "current_issues.csv"

# 2. Compare with previous export
$changes = Compare-CsvData -ReferencePath "previous_issues.csv" -DifferencePath "current_issues.csv" -KeyProperty "id"

# 3. Generate Excel report of changes
$changes | Export-ExcelData -Path "issue_changes_report.xlsx" -AutoFit -TableStyle "Light1"
```

### Data Validation Pipeline
```powershell
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