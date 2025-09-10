# Helper functions for log levels and targets

function Get-LogLevels {
    return @{
        Trace = 0
        Debug = 1
        Information = 2
        Warning = 3
        Error = 4
        Critical = 5
        None = 6
    }
}

function Get-LogTargets {
    return @{
        Console = 1
        File = 2
        EventLog = 4
        All = 7
    }
}

# Easy access to constants
$script:LogLevelConstants = Get-LogLevels
$script:LogTargetConstants = Get-LogTargets

Export-ModuleMember -Function @('Get-LogLevels', 'Get-LogTargets')
