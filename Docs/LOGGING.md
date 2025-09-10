# Logging Module Documentation

## Overview

The Collateral-RedmineDB logging module provides comprehensive logging functionality for the PowerShell module. It supports multiple log levels, output targets, and advanced features like file rotation, color-coded console output, and Windows Event Log integration.

## Features

### Log Levels
- **Trace** (0): Detailed trace information (rarely used in production)
- **Debug** (1): Debug information for troubleshooting
- **Information** (2): General informational messages (default)
- **Warning** (3): Warning messages for potentially harmful situations
- **Error** (4): Error messages for failures
- **Critical** (5): Critical error messages for serious failures
- **None** (6): Disables all logging

### Output Targets
- **Console**: Colored console output
- **File**: Persistent file logging with rotation
- **EventLog**: Windows Event Log integration
- **All**: All targets combined

### Key Features
- **Automatic file rotation** when log files exceed size limits
- **Color-coded console output** for different log levels
- **Exception tracking** with stack traces (configurable)
- **Caller information** automatically included
- **Thread-safe operations**
- **Configurable formatting** with timestamps, levels, and source info

## Quick Start

### Basic Usage

```powershell
# Import the module (logging is automatically initialized)
Import-Module Collateral-RedmineDB

# Log messages at different levels
Write-LogInfo "Application started"
Write-LogWarn "This is a warning"
Write-LogError "An error occurred"

# Log with exception information
try {
    # Some operation that might fail
    throw "Something went wrong"
}
catch {
    Write-LogError "Operation failed" -Exception $_.Exception
}
```

### Configuration

```powershell
# Initialize logger with custom settings
Initialize-Logger -Source "MyApp" -MinimumLevel Debug -Targets ([LogTarget]::Console -bor [LogTarget]::File)

# Change log level at runtime
Set-LogLevel -Level Debug

# Enable file and console logging
Set-LogTargets -Targets ([LogTarget]::Console -bor [LogTarget]::File)

# Get current configuration
$config = Get-LogConfiguration
Write-Host "Current log level: $($config.MinimumLevel)"
Write-Host "Log file: $($config.LogFilePath)"
```

## Functions Reference

### Core Logging Functions

#### `Write-LogTrace`
```powershell
Write-LogTrace -Message "Detailed trace information" [-Exception <Exception>] [-Source <String>]
```

#### `Write-LogDebug`
```powershell
Write-LogDebug -Message "Debug information" [-Exception <Exception>] [-Source <String>]
```

#### `Write-LogInfo`
```powershell
Write-LogInfo -Message "Informational message" [-Exception <Exception>] [-Source <String>]
```

#### `Write-LogWarn`
```powershell
Write-LogWarn -Message "Warning message" [-Exception <Exception>] [-Source <String>]
```

#### `Write-LogError`
```powershell
Write-LogError -Message "Error message" [-Exception <Exception>] [-Source <String>]
```

#### `Write-LogCritical`
```powershell
Write-LogCritical -Message "Critical error" [-Exception <Exception>] [-Source <String>]
```

### Configuration Functions

#### `Initialize-Logger`
```powershell
Initialize-Logger [-Source <String>] [-MinimumLevel <LogLevel>] [-Targets <LogTarget>] [-LogFilePath <String>] [-EnableColorOutput <Boolean>]
```

#### `Set-LogLevel`
```powershell
Set-LogLevel -Level <LogLevel>
```

#### `Set-LogTargets`
```powershell
Set-LogTargets -Targets <LogTarget>
```

#### `Get-LogConfiguration`
```powershell
Get-LogConfiguration
```

#### `Get-Logger`
```powershell
Get-Logger
```

## Advanced Usage

### Custom Logger Instance

```powershell
# Create a custom logger configuration
$config = [LoggerConfig]::new()
$config.MinimumLevel = [LogLevel]::Debug
$config.LogFilePath = "C:\MyApp\Logs\custom.log"
$config.MaxLogFileSize = 50MB
$config.MaxLogFiles = 10

# Create logger with custom config
$logger = [Logger]::new("MyCustomApp", $config)

# Use the custom logger
$logger.Info("Custom logger message")
$logger.Error("Custom error message")
```

### File Logging Configuration

```powershell
# Configure file logging
$logger = Get-Logger
$logger.SetLogFilePath("C:\MyApp\Logs\app.log")
$logger.Config.MaxLogFileSize = 25MB
$logger.Config.MaxLogFiles = 7
```

### Event Log Integration

```powershell
# Enable Windows Event Log (requires administrator privileges)
Set-LogTargets -Targets ([LogTarget]::Console -bor [LogTarget]::EventLog)

# Messages will appear in Windows Event Viewer under:
# Applications and Services Logs > Application > Source: Collateral-RedmineDB
```

## Integration with Existing Code

The logging module is designed to complement existing PowerShell logging patterns. Throughout the Collateral-RedmineDB module, traditional `Write-Verbose`, `Write-Warning`, and `Write-Error` calls are enhanced with corresponding logging calls:

```powershell
# Traditional PowerShell logging
Write-Verbose "Operation completed successfully"
Write-Warning "Resource not found, using default"
Write-Error "Failed to connect to server"

# Enhanced with structured logging
Write-Verbose "Operation completed successfully"
if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
    Write-LogInfo "Operation completed successfully"
}
```

## Log Format

Default log format includes:
```
[2025-09-09 14:30:25.123] [INFO] [Source] Message content
```

Components:
- **Timestamp**: Precise timestamp with milliseconds
- **Level**: Log level (TRACE, DEBUG, INFO, WARN, ERROR, CRITICAL)
- **Source**: Source module/function name
- **Message**: The actual log message

## File Rotation

Automatic file rotation occurs when:
- Log file exceeds the configured maximum size (default: 10MB)
- Rotated files are numbered sequentially (.1, .2, .3, etc.)
- Oldest files are automatically deleted when the maximum number is reached

## Performance Considerations

- Logging operations are optimized for minimal performance impact
- File I/O uses buffered streams with auto-flush
- Conditional checks prevent unnecessary string formatting when below minimum log level
- Color output can be disabled for performance in automated scenarios

## Troubleshooting

### Common Issues

1. **Event Log Source Creation Fails**
   - Requires administrator privileges
   - Event Log logging will be automatically disabled

2. **File Logging Fails**
   - Check directory permissions
   - Verify disk space availability
   - File logging will be automatically disabled on failure

3. **Performance Issues**
   - Consider raising the minimum log level
   - Disable color output in automated scenarios
   - Use file logging instead of console for high-volume scenarios

### Diagnostic Commands

```powershell
# Check current configuration
Get-LogConfiguration

# Test file permissions
$config = Get-LogConfiguration
Test-Path (Split-Path $config.LogFilePath)

# Monitor log file growth
$config = Get-LogConfiguration
if (Test-Path $config.LogFilePath) {
    Get-Item $config.LogFilePath | Select-Object Name, Length, LastWriteTime
}
```

## Best Practices

1. **Use appropriate log levels**:
   - Info for normal operations
   - Warn for recoverable issues
   - Error for failures that don't stop execution
   - Critical for failures that require immediate attention

2. **Include context in messages**:
   ```powershell
   Write-LogError "Failed to process record ID: $recordId" -Exception $_.Exception
   ```

3. **Use structured logging for searchability**:
   ```powershell
   Write-LogInfo "Database operation completed successfully. Records processed: $count, Duration: $($duration.TotalSeconds)s"
   ```

4. **Configure appropriate targets for environment**:
   - Development: Console + File
   - Production: File + EventLog
   - Automated: File only

5. **Monitor log file sizes** in production environments and adjust rotation settings as needed.

## Examples

### Basic Application Logging

```powershell
# Application startup
Write-LogInfo "Collateral-RedmineDB application starting"

# Configuration loading
try {
    $config = Import-RedmineEnv
    Write-LogInfo "Configuration loaded successfully"
}
catch {
    Write-LogError "Failed to load configuration" -Exception $_.Exception
    exit 1
}

# Database operations
Write-LogDebug "Connecting to Redmine server: $($config.Server)"
try {
    Connect-Redmine -Server $config.Server -Credential $cred
    Write-LogInfo "Successfully connected to Redmine server"
}
catch {
    Write-LogCritical "Failed to connect to Redmine server" -Exception $_.Exception
    exit 1
}
```

### Batch Processing with Progress Logging

```powershell
$items = Get-RedmineDB
Write-LogInfo "Starting batch processing of $($items.Count) items"

$processed = 0
$errors = 0

foreach ($item in $items) {
    try {
        # Process item
        Write-LogDebug "Processing item: $($item.Name)"
        # ... processing logic ...
        $processed++
        
        if ($processed % 100 -eq 0) {
            Write-LogInfo "Progress: $processed/$($items.Count) items processed"
        }
    }
    catch {
        $errors++
        Write-LogError "Failed to process item: $($item.Name)" -Exception $_.Exception
    }
}

Write-LogInfo "Batch processing completed. Processed: $processed, Errors: $errors"
```
