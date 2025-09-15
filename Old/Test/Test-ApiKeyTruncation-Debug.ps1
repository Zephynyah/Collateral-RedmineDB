# Test script to demonstrate API key truncation in logs at Debug level
try {
    # Load the Collateral-RedmineDB module
    Import-Module .\Collateral-RedmineDB.psm1 -Force

    # Set log level to Debug to see debug messages
    Set-LogLevel -Level Debug
    
    # Test the logging with a fake API key to see truncation
    Write-LogInfo "Testing API key truncation functionality at Debug level"
    
    # Simulate what would happen with actual API calls by logging sample URLs with keys
    $testUrls = @(
        "https://redmine.example.com/db/18721.json?key=b9124a018b48bbd9f837f7180e84b1eaa05ec9ea",
        "https://redmine.example.com/db.json?limit=10&key=a1b2c3d4e5f6789012345678901234567890abcd",
        "https://redmine.example.com/db/search.json?type=workstation&key=1234567890abcdef1234567890abcdef12345678"
    )
    
    foreach ($url in $testUrls) {
        Write-LogDebug "API request URL: $url"
        Write-LogInfo "Processing request to: $url"
        Write-LogWarn "Warning for URL: $url"
    }
    
    Write-LogInfo "API key truncation test completed successfully"
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    Remove-Module Collateral-RedmineDB -Force -ErrorAction SilentlyContinue
}
