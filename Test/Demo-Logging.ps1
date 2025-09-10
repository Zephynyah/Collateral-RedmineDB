<#
.SYNOPSIS
    Working demonstration of the Collateral-RedmineDB logging module
.DESCRIPTION
    This script demonstrates the currently working logging functionality
.EXAMPLE
    .\Demo-Logging.ps1
#>

Write-Host "=== Collateral-RedmineDB Logging Module Demo ===" -ForegroundColor Green

# The module automatically initializes logging when imported
Write-Host "`n1. Current Configuration:" -ForegroundColor Yellow
$config = Get-LogConfiguration
Write-Output "Log Level: $($config.MinimumLevel)"
Write-Output "Targets: $($config.Targets)"
Write-Output "Log File: $($config.LogFilePath)"
Write-Output "Color Output: $($config.EnableColorOutput)"

# Test different log levels
Write-Host "`n2. Testing Log Levels (current level: $($config.MinimumLevel)):" -ForegroundColor Yellow
Write-LogTrace "Trace message (may not appear)"
Write-LogDebug "Debug message (may not appear)"
Write-LogInfo "Information message"
Write-LogWarn "Warning message"
Write-LogError "Error message"
Write-LogCritical "Critical message"

# Change log level
Write-Host "`n3. Changing Log Level to Debug:" -ForegroundColor Yellow
Set-LogLevel -Level Debug

Write-LogTrace "Trace message (still may not appear - below Debug)"
Write-LogDebug "Debug message (should now appear)"
Write-LogInfo "Information message"

# Test exception logging
Write-Host "`n4. Testing Exception Logging:" -ForegroundColor Yellow
try {
    throw "This is a test exception for demonstration"
}
catch {
    Write-LogError "Caught test exception" -Exception $_.Exception
}

# Test with custom source
Write-Host "`n5. Testing Custom Source:" -ForegroundColor Yellow
Write-LogInfo "Message with custom source" -Source "DemoScript"

# Show final configuration
Write-Host "`n6. Final Configuration:" -ForegroundColor Yellow
$finalConfig = Get-LogConfiguration
Write-Output "Current Log Level: $($finalConfig.MinimumLevel)"

# Test if log file exists
if (Test-Path $finalConfig.LogFilePath) {
    Write-Host "`nLog file exists but file logging is not currently enabled." -ForegroundColor Yellow
    Write-Host "File location: $($finalConfig.LogFilePath)" -ForegroundColor Cyan
} else {
    Write-Host "`nNo log file created (file logging not enabled)" -ForegroundColor Yellow
}

Write-Host "`n=== Demo Complete ===" -ForegroundColor Green
Write-Host "The logging module is working and ready for use!" -ForegroundColor Green

# Reset to default level
Set-LogLevel -Level Information
Write-LogInfo "Logging module demo completed successfully!"
