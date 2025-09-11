try {

    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # $key = Get-ApiKey -Server 'http://localhost:3000'

    $key = '4ba82d31cadab05300df6c21d8cefb320e9116d5'


    # Connect-Redmine -Server "http://localhost:8080" -Key $key
    Connect-Redmine -Server "http://localhost:52794" -Key $key


    # Get Redmine Asset by ID
    Get-RedmineDB -Id 18721 -AsJson


    # Get Redmine Asset by Name
    Get-RedmineDB -Name "00-008584"

    # New state hashtable usage
    # $states = Get-SettingsData -DataName "DBvalidState"
    # $states['CA']  # Returns "California"

}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An error occurred: $_"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    # Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}

