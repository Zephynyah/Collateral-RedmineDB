<#
	===========================================================================
	 Module Name:       logging.psm1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        9/9/2025
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          logging.psm1
	 Description:       Comprehensive logging module for Collateral-RedmineDB
	 Version:           1.0.0
	 Last Modified:     2025-09-09
	-------------------------------------------------------------------------
	 Copyright (c) 2025 Jason Hickey. All rights reserved.
	 Licensed under the MIT License.
	===========================================================================
#>

#Requires -Version 5.0

# Logging levels enumeration
enum LogLevel {
    Trace = 0
    Debug = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
    None = 6
}

# Log output targets enumeration
enum LogTarget {
    Console = 1
    File = 2
    EventLog = 4
    All = 7
}

# Logger configuration class
class LoggerConfig {
    [LogLevel]$MinimumLevel = [LogLevel]::Information
    [LogTarget]$Targets = [LogTarget]::Console
    [string]$LogFilePath = ""
    [string]$LogFileFormat = "yyyy-MM-dd_HH-mm-ss"
    [bool]$IncludeTimestamp = $true
    [bool]$IncludeLevel = $true
    [bool]$IncludeSource = $true
    [bool]$IncludeStackTrace = $false
    [int]$MaxLogFileSize = 10MB
    [int]$MaxLogFiles = 5
    [string]$DateTimeFormat = "yyyy-MM-dd HH:mm:ss.fff"
    [string]$EventLogSource = "Collateral-RedmineDB"
    [string]$EventLogName = "Application"
    [bool]$EnableColorOutput = $true
    [hashtable]$LevelColors = @{
        'Trace' = 'Gray'
        'Debug' = 'Cyan'
        'Information' = 'White'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Critical' = 'Magenta'
    }

    LoggerConfig() {
        $this.SetDefaultLogPath()
    }

    [void] SetDefaultLogPath() {
        $logDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Collateral-RedmineDB\Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $this.LogFilePath = Join-Path -Path $logDir -ChildPath "redmine-db.log"
    }
}

# Main Logger class
class Logger {
    [LoggerConfig]$Config
    [string]$Source
    hidden [System.IO.StreamWriter]$FileWriter
    hidden [bool]$EventLogAvailable

    Logger([string]$source) {
        $this.Config = [LoggerConfig]::new()
        $this.Source = $source
        $this.EventLogAvailable = $this.InitializeEventLog()
        $this.InitializeFileLogging()
    }

    Logger([string]$source, [LoggerConfig]$config) {
        $this.Config = $config
        $this.Source = $source
        $this.EventLogAvailable = $this.InitializeEventLog()
        $this.InitializeFileLogging()
    }

    # Initialize event log source
    hidden [bool] InitializeEventLog() {
        try {
            if ($this.Config.Targets -band [LogTarget]::EventLog) {
                if (-not [System.Diagnostics.EventLog]::SourceExists($this.Config.EventLogSource)) {
                    # Only create if running as administrator
                    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
                    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        [System.Diagnostics.EventLog]::CreateEventSource($this.Config.EventLogSource, $this.Config.EventLogName)
                    }
                    else {
                        Write-Warning "Cannot create EventLog source '$($this.Config.EventLogSource)' without administrator privileges. EventLog logging disabled."
                        return $false
                    }
                }
                return $true
            }
        }
        catch {
            Write-Warning "Failed to initialize EventLog: $($_.Exception.Message). EventLog logging disabled."
        }
        return $false
    }

    # Initialize file logging
    hidden [void] InitializeFileLogging() {
        if ($this.Config.Targets -band [LogTarget]::File) {
            try {
                $this.RotateLogFileIfNeeded()
                $logDir = Split-Path -Path $this.Config.LogFilePath -Parent
                if (-not (Test-Path $logDir)) {
                    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                }
                $this.FileWriter = [System.IO.StreamWriter]::new($this.Config.LogFilePath, $true, [System.Text.Encoding]::UTF8)
                $this.FileWriter.AutoFlush = $true
            }
            catch {
                Write-Warning "Failed to initialize file logging: $($_.Exception.Message). File logging disabled."
                $this.Config.Targets = $this.Config.Targets -band (-bnot [LogTarget]::File)
            }
        }
    }

    # Rotate log file if it exceeds maximum size
    hidden [void] RotateLogFileIfNeeded() {
        if (Test-Path $this.Config.LogFilePath) {
            $fileInfo = Get-Item $this.Config.LogFilePath
            if ($fileInfo.Length -gt $this.Config.MaxLogFileSize) {
                $this.RotateLogFiles()
            }
        }
    }

    # Rotate log files
    hidden [void] RotateLogFiles() {
        try {
            $logDir = Split-Path -Path $this.Config.LogFilePath -Parent
            $logName = [System.IO.Path]::GetFileNameWithoutExtension($this.Config.LogFilePath)
            $logExt = [System.IO.Path]::GetExtension($this.Config.LogFilePath)

            # Close current file writer
            if ($this.FileWriter) {
                $this.FileWriter.Close()
                $this.FileWriter.Dispose()
            }

            # Remove oldest log files
            for ($i = $this.Config.MaxLogFiles - 1; $i -gt 0; $i--) {
                $oldFile = Join-Path -Path $logDir -ChildPath "$logName.$i$logExt"
                $newFile = Join-Path -Path $logDir -ChildPath "$logName.$($i + 1)$logExt"
                
                if (Test-Path $oldFile) {
                    if (Test-Path $newFile) {
                        Remove-Item -Path $newFile -Force
                    }
                    Move-Item -Path $oldFile -Destination $newFile -Force
                }
            }

            # Move current log to .1
            $backupFile = Join-Path -Path $logDir -ChildPath "$logName.1$logExt"
            if (Test-Path $this.Config.LogFilePath) {
                Move-Item -Path $this.Config.LogFilePath -Destination $backupFile -Force
            }
        }
        catch {
            Write-Warning "Failed to rotate log files: $($_.Exception.Message)"
        }
    }

    # Format log message
    hidden [string] FormatMessage([LogLevel]$level, [string]$message, [string]$source) {
        $parts = @()

        if ($this.Config.IncludeTimestamp) {
            $parts += "[$(Get-Date -Format $this.Config.DateTimeFormat)]"
        }

        if ($this.Config.IncludeLevel) {
            $parts += "[$($level.ToString().ToUpper())]"
        }

        if ($this.Config.IncludeSource -and $source) {
            $parts += "[$source]"
        }

        $parts += $message

        return $parts -join " "
    }

    # Get caller information
    hidden [string] GetCallerInfo() {
        try {
            $callStack = Get-PSCallStack
            if ($callStack.Count -gt 2) {
                $caller = $callStack[2]
                $functionName = if ($caller.FunctionName -ne '<ScriptBlock>') { $caller.FunctionName } else { 'Script' }
                $fileName = Split-Path -Leaf $caller.ScriptName
                return "$fileName::$functionName"
            }
        }
        catch {
            # Ignore errors in getting caller info
        }
        return $this.Source
    }

    # Core logging method
    hidden [void] WriteLog([LogLevel]$level, [string]$message, [Exception]$exception, [string]$source) {
        # Check if logging level meets minimum threshold
        if ($level -lt $this.Config.MinimumLevel) {
            return
        }

        # Use provided source or get caller info
        $logSource = if ($source) { $source } else { $this.GetCallerInfo() }

        # Format the message
        $fullMessage = $message
        if ($exception) {
            $fullMessage += " Exception: $($exception.Message)"
            if ($this.Config.IncludeStackTrace) {
                $fullMessage += "`nStackTrace: $($exception.StackTrace)"
            }
        }

        $formattedMessage = $this.FormatMessage($level, $fullMessage, $logSource)

        # Write to console
        if ($this.Config.Targets -band [LogTarget]::Console) {
            $this.WriteToConsole($level, $formattedMessage)
        }

        # Write to file
        if (($this.Config.Targets -band [LogTarget]::File) -and $this.FileWriter) {
            try {
                $this.FileWriter.WriteLine($formattedMessage)
            }
            catch {
                Write-Warning "Failed to write to log file: $($_.Exception.Message)"
            }
        }

        # Write to event log
        if (($this.Config.Targets -band [LogTarget]::EventLog) -and $this.EventLogAvailable) {
            $this.WriteToEventLog($level, $fullMessage)
        }
    }

    # Write to console with color coding
    hidden [void] WriteToConsole([LogLevel]$level, [string]$message) {
        if ($this.Config.EnableColorOutput -and $this.Config.LevelColors.ContainsKey($level.ToString())) {
            $color = $this.Config.LevelColors[$level.ToString()]
            Write-Host $message -ForegroundColor $color
        }
        else {
            Write-Host $message
        }
    }

    # Write to Windows Event Log
    hidden [void] WriteToEventLog([LogLevel]$level, [string]$message) {
        try {
            $eventType = switch ($level) {
                ([LogLevel]::Error) { [System.Diagnostics.EventLogEntryType]::Error }
                ([LogLevel]::Critical) { [System.Diagnostics.EventLogEntryType]::Error }
                ([LogLevel]::Warning) { [System.Diagnostics.EventLogEntryType]::Warning }
                default { [System.Diagnostics.EventLogEntryType]::Information }
            }

            $eventId = [int]$level * 100 + 1
            [System.Diagnostics.EventLog]::WriteEntry($this.Config.EventLogSource, $message, $eventType, $eventId)
        }
        catch {
            Write-Warning "Failed to write to EventLog: $($_.Exception.Message)"
        }
    }

    # Public logging methods
    [void] Trace([string]$message) { $this.Trace($message, $null, $null) }
    [void] Trace([string]$message, [string]$source) { $this.Trace($message, $null, $source) }
    [void] Trace([string]$message, [Exception]$exception) { $this.Trace($message, $exception, $null) }
    [void] Trace([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Trace, $message, $exception, $source)
    }

    [void] Debug([string]$message) { $this.Debug($message, $null, $null) }
    [void] Debug([string]$message, [string]$source) { $this.Debug($message, $null, $source) }
    [void] Debug([string]$message, [Exception]$exception) { $this.Debug($message, $exception, $null) }
    [void] Debug([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Debug, $message, $exception, $source)
    }

    [void] Info([string]$message) { $this.Info($message, $null, $null) }
    [void] Info([string]$message, [string]$source) { $this.Info($message, $null, $source) }
    [void] Info([string]$message, [Exception]$exception) { $this.Info($message, $exception, $null) }
    [void] Info([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Information, $message, $exception, $source)
    }

    [void] Warn([string]$message) { $this.Warn($message, $null, $null) }
    [void] Warn([string]$message, [string]$source) { $this.Warn($message, $null, $source) }
    [void] Warn([string]$message, [Exception]$exception) { $this.Warn($message, $exception, $null) }
    [void] Warn([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Warning, $message, $exception, $source)
    }

    [void] Error([string]$message) { $this.Error($message, $null, $null) }
    [void] Error([string]$message, [string]$source) { $this.Error($message, $null, $source) }
    [void] Error([string]$message, [Exception]$exception) { $this.Error($message, $exception, $null) }
    [void] Error([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Error, $message, $exception, $source)
    }

    [void] Critical([string]$message) { $this.Critical($message, $null, $null) }
    [void] Critical([string]$message, [string]$source) { $this.Critical($message, $null, $source) }
    [void] Critical([string]$message, [Exception]$exception) { $this.Critical($message, $exception, $null) }
    [void] Critical([string]$message, [Exception]$exception, [string]$source) {
        $this.WriteLog([LogLevel]::Critical, $message, $exception, $source)
    }

    # Utility methods
    [void] SetLogLevel([LogLevel]$level) {
        $this.Config.MinimumLevel = $level
    }

    [LogLevel] GetLogLevel() {
        return $this.Config.MinimumLevel
    }

    [void] SetLogTargets([LogTarget]$targets) {
        $this.Config.Targets = $targets
        if ($targets -band [LogTarget]::File) {
            $this.InitializeFileLogging()
        }
    }

    [LogTarget] GetLogTargets() {
        return $this.Config.Targets
    }

    [void] EnableColorOutput([bool]$enable) {
        $this.Config.EnableColorOutput = $enable
    }

    [string] GetLogFilePath() {
        return $this.Config.LogFilePath
    }

    [void] SetLogFilePath([string]$path) {
        $this.Config.LogFilePath = $path
        if ($this.Config.Targets -band [LogTarget]::File) {
            if ($this.FileWriter) {
                $this.FileWriter.Close()
                $this.FileWriter.Dispose()
            }
            $this.InitializeFileLogging()
        }
    }

    # Cleanup resources
    [void] Dispose() {
        if ($this.FileWriter) {
            $this.FileWriter.Close()
            $this.FileWriter.Dispose()
        }
    }
}

# Global logger instance
$script:GlobalLogger = $null

# Initialize global logger
function Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Source = "Collateral-RedmineDB",
        
        [Parameter(Mandatory = $false)]
        [LogLevel]$MinimumLevel = [LogLevel]::Information,
        
        [Parameter(Mandatory = $false)]
        [LogTarget]$Targets = [LogTarget]::Console,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableColorOutput = $true
    )

    $config = [LoggerConfig]::new()
    $config.MinimumLevel = $MinimumLevel
    $config.Targets = $Targets
    $config.EnableColorOutput = $EnableColorOutput
    
    if ($LogFilePath) {
        $config.LogFilePath = $LogFilePath
    }

    $script:GlobalLogger = [Logger]::new($Source, $config)
    
    Write-Host "Logger initialized with level: $MinimumLevel, targets: $Targets" -ForegroundColor Green
}

# Get global logger instance
function Get-Logger {
    [CmdletBinding()]
    param()
    
    if (-not $script:GlobalLogger) {
        Initialize-Logger
    }
    
    return $script:GlobalLogger
}

# Convenience functions for global logger
function Write-LogTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Trace($Message, $Exception, $Source)
}

function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Debug($Message, $Exception, $Source)
}

function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Info($Message, $Exception, $Source)
}

function Write-LogWarn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Warn($Message, $Exception, $Source)
}

function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Error($Message, $Exception, $Source)
}

function Write-LogCritical {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logger = Get-Logger
    $logger.Critical($Message, $Exception, $Source)
}

function Set-LogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [LogLevel]$Level
    )
    
    $logger = Get-Logger
    $logger.SetLogLevel($Level)
    Write-Host "Log level set to: $Level" -ForegroundColor Green
}

function Set-LogTargets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [LogTarget]$Targets
    )
    
    $logger = Get-Logger
    $logger.SetLogTargets($Targets)
    Write-Host "Log targets set to: $Targets" -ForegroundColor Green
}

function Get-LogConfiguration {
    [CmdletBinding()]
    param()
    
    $logger = Get-Logger
    return [PSCustomObject]@{
        MinimumLevel = $logger.GetLogLevel()
        Targets = $logger.GetLogTargets()
        LogFilePath = $logger.GetLogFilePath()
        EnableColorOutput = $logger.Config.EnableColorOutput
        Source = $logger.Source
    }
}

# Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($script:GlobalLogger) {
        $script:GlobalLogger.Dispose()
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Get-Logger',
    'Write-LogTrace',
    'Write-LogDebug', 
    'Write-LogInfo',
    'Write-LogWarn',
    'Write-LogError',
    'Write-LogCritical',
    'Set-LogLevel',
    'Set-LogTargets',
    'Get-LogConfiguration'
)

# Export enums and classes using different syntax for PowerShell 5.1 compatibility
$exportScript = @'
# Make enums and classes available globally
if (-not ([System.Management.Automation.PSTypeName]'LogLevel').Type) {
    Add-Type -TypeDefinition @"
        public enum LogLevel {
            Trace = 0,
            Debug = 1,
            Information = 2,
            Warning = 3,
            Error = 4,
            Critical = 5,
            None = 6
        }
"@
}

if (-not ([System.Management.Automation.PSTypeName]'LogTarget').Type) {
    Add-Type -TypeDefinition @"
        [System.Flags]
        public enum LogTarget {
            Console = 1,
            File = 2,
            EventLog = 4,
            All = 7
        }
"@
}
'@

Invoke-Expression $exportScript
