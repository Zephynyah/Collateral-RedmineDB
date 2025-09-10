<#
.SYNOPSIS
    Test script for the Collateral-RedmineDB logging module
.DESCRIPTION
    This script demonstrates the logging functionality of the Collateral-RedmineDB module
.EXAMPLE
    .\Test-Logging.ps1
#>

# Import the module
Import-Module ".\Collateral-RedmineDB.psd1" -Force

Write-Host "=== Collateral-RedmineDB Logging Module Test ===" -ForegroundColor Green

# Test 1: Default logger initialization
Write-Host "`n1. Testing default logger initialization..." -ForegroundColor Yellow
$config = Get-LogConfiguration
Write-Host "Current log level: $($config.MinimumLevel)" -ForegroundColor Cyan
Write-Host "Current log targets: $($config.Targets)" -ForegroundColor Cyan
Write-Host "Log file path: $($config.LogFilePath)" -ForegroundColor Cyan

# Test 2: Different log levels
Write-Host "`n2. Testing different log levels..." -ForegroundColor Yellow
Write-LogTrace "This is a trace message"
Write-LogDebug "This is a debug message"
Write-LogInfo "This is an info message"
Write-LogWarn "This is a warning message"
Write-LogError "This is an error message"
Write-LogCritical "This is a critical message"

# Test 3: Change log level
Write-Host "`n3. Testing log level changes..." -ForegroundColor Yellow
Write-Host "Setting log level to Debug..." -ForegroundColor Cyan
Set-LogLevel -Level Debug

Write-LogTrace "This trace should NOT appear (below Debug level)"
Write-LogDebug "This debug message should appear"
Write-LogInfo "This info message should appear"

# Test 4: Enable file logging
Write-Host "`n4. Testing file logging..." -ForegroundColor Yellow
Write-Host "Enabling file logging..." -ForegroundColor Cyan
Set-LogTargets -Targets ([LogTarget]::Console -bor [LogTarget]::File)

Write-LogInfo "This message should appear in both console and file"
Write-LogWarn "This warning should be logged to file"

$config = Get-LogConfiguration
Write-Host "Log file location: $($config.LogFilePath)" -ForegroundColor Cyan

if (Test-Path $config.LogFilePath) {
    Write-Host "Log file exists! Last few lines:" -ForegroundColor Green
    Get-Content $config.LogFilePath | Select-Object -Last 3 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} else {
    Write-Host "Log file not found!" -ForegroundColor Red
}

# Test 5: Exception logging
Write-Host "`n5. Testing exception logging..." -ForegroundColor Yellow
try {
    throw "This is a test exception"
}
catch {
    Write-LogError "Caught an exception" -Exception $_.Exception
}

# Test 6: Reset to console only
Write-Host "`n6. Resetting to console-only logging..." -ForegroundColor Yellow
Set-LogTargets -Targets Console
Set-LogLevel -Level Information

Write-LogInfo "Logging module test completed successfully!"

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
Write-Host "The logging module is ready for use!" -ForegroundColor Green
