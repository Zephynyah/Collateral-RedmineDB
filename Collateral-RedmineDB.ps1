try {

    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # $key = Get-ApiKey -Server 'http://localhost:3000'

    $key = '65b130d568c62f9e5a967f1cafde04ee1685d837'


    # Connect-Redmine -Server "http://localhost:8080" -Key $key
    Connect-Redmine -Server "http://localhost:3000" -Key $key


    Set-LogLevel -Level Debug


    # # Get Redmine Asset by ID
    # Get-RedmineDB -Id 18721 -AsJson


    # # Get Redmine Asset by Name
    # Get-RedmineDB -Name "00-008584"

    # New state hashtable usage
    # $states = Get-SettingsData -DataName "DBvalidState"
    # $states['CA']  # Returns "California"

    Search-RedmineDB -Field serialnumber -Keyword 'BL05KQ3' 

}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An error occurred: $_"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    # Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}

