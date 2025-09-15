try {

    # Load the Collateral-RedmineDB module
    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # Use a mock API key to bypass rate limiting for testing
    $key = "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
    Write-LogInfo "Using mock API key for testing examples"

    # Connect to Redmine server
    Connect-Redmine -Server "http://localhost:3000/api" -Key $key

    # ((Get-RedmineDB).Values.ToPSObject() | Where-Object { $_.'Host Name' -ne $null } | Get-Random).'Host Name'

    # Write-LogInfo "Running Read-Example.ps1..."
    . .\Examples\Read-Example.ps1
    
    Write-LogInfo "Running Update-Example.ps1..."
    # . .\Examples\Update-Example.ps1
    
    # Write-LogInfo "Running Destroy-Example.ps1..."
    # . .\Examples\Destroy-Example.ps1
    
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An error occurred: $_"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}