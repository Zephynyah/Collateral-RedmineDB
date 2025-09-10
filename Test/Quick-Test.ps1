# Quick test script to validate mock API integration
param(
    [switch] $EnableDebug
)

if ($EnableDebug) {
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
}


Clear-Host


Write-Host "=== Mock API Integration Test ===" -ForegroundColor Cyan

try {
    # Clean start
    Write-Host "1. Removing existing modules..." -ForegroundColor Yellow
    Get-Module Collateral-RedmineDB, mock-api | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Import mock API
    Write-Host "2. Importing mock API..." -ForegroundColor Yellow
    Import-Module .\Misc\mock-api.psm1 -Force
    
    # Initialize with data
    Write-Host "3. Initializing mock data..." -ForegroundColor Yellow
    $result = Initialize-MockAPI -DataPath "Data\db-small.json"
    if ($result) {
        Write-Host "   ✓ Mock API initialized" -ForegroundColor Green
    } else {
        throw "Failed to initialize mock API"
    }
    
    # Import main module
    Write-Host "4. Importing main module..." -ForegroundColor Yellow
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    Write-Host "   ✓ Main module imported" -ForegroundColor Green
    
    # Test connection
    Write-Host "5. Testing connection..." -ForegroundColor Yellow
    Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
    Write-Host "   ✓ Connection established" -ForegroundColor Green
    
    # Check if classes are available
    Write-Host "6. Checking class availability..." -ForegroundColor Yellow
    # Try to access the script-scoped Redmine variable through the module
    try {
        $testResult = Get-RedmineDB -Id 18721 -ErrorAction Stop
        Write-Host "   ✓ Redmine connection working" -ForegroundColor Green
        Write-Host "   ✓ DB object accessible through Get-RedmineDB" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Redmine variable/DB not accessible: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test simple API call
    Write-Host "7. Testing direct API call..." -ForegroundColor Yellow
    try {
        $directResult = Invoke-RestMethod -Uri "http://localhost:8080/db/18721.json" -Headers @{'X-Redmine-API-Key' = 'mock-api-key-12345-67890-abcdef-ghijkl40'}
        Write-Host "   ✓ Direct API call successful" -ForegroundColor Green
        Write-Host "   → Entry name: $($directResult.db_entry.name)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ Direct API call failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test full function  
    Write-Host "8. Testing Get-RedmineDB function..." -ForegroundColor Yellow
    try {
        $entry = Get-RedmineDB -Id "18721"
        Write-Host "   ✓ Get-RedmineDB successful" -ForegroundColor Green
        Write-Host "   → Entry: $($entry.Name) - $($entry.Type)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ Get-RedmineDB failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "=== Test Complete ===" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    # Cleanup
    try {
        Disconnect-Redmine -ErrorAction SilentlyContinue
        Disable-MockAPI -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }
}
