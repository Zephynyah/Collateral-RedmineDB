try {

    # Load the Collateral-RedmineDB module
    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # $key = Get-ApiKey -Server 'http://localhost:3000'
    $key = Get-ApiKey -Server 'http://localhost:3000'

    # Connect to Redmine server
    Connect-Redmine -Server "http://localhost:3000" -Key $key


    . .\Examples\Read-Example.ps1


}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An error occurred: $_"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}