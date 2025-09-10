try {

    Import-Module .\Collateral-RedmineDB.psm1 -Force

    $key = "c5fc2de08e46b51bbd8c0a448c0b08f35e99004d"

    Connect-Redmine -Server "http://localhost:8080" -Key $key
    
    # New state hashtable usage
    $states = Get-SettingsData -DataName "DBvalidState"
    $states['CA']  # Returns "California"

    # Direct variable access
    $DBvalidState['CA']  # "Massachusetts" -> "California"

    # Check if state exists
    if ($DBvalidState.ContainsKey('TX')) {
        Write-Host "Texas: $($DBvalidState['TX'])"
    }
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An error occurred: $_"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    # Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}

