# Test Set-RedmineDB fix
try {
    # Load the Collateral-RedmineDB module
    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # Use a mock API key
    $key = "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
    Write-LogInfo "Testing Set-RedmineDB function fix"

    # Connect to Redmine server
    Connect-Redmine -Server "http://localhost:3000" -Key $key

    # Test creating a resource object using Set-RedmineDB
    Write-LogInfo "Testing Set-RedmineDB object creation..."
    $testResource = Set-RedmineDB -name "TEST-001" -type "Workstation" -systemMake "Dell" -systemModel "Latitude 7420"
    
    if ($testResource) {
        Write-LogInfo "✓ Set-RedmineDB object creation successful"
        Write-LogInfo "  - Name: $($testResource.Name)"
        Write-LogInfo "  - Type: $($testResource.Type)"
    } else {
        Write-LogError "✗ Set-RedmineDB object creation failed"
    }
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}
