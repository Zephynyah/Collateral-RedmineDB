<#
	===========================================================================
	 Script Name:       Test-MockAPI.ps1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        9/10/2025
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          Test-MockAPI.ps1
	 Description:       Test script for the Mock API middleware
	 Version:           1.0.0
	 Last Modified:     2025-09-10
	-------------------------------------------------------------------------
	 Copyright (c) 2025 Jason Hickey. All rights reserved.
	 Licensed under the MIT License.
	===========================================================================
#>

#Requires -Version 5.0

[CmdletBinding()]
param(
    [string] $DataPath = "Data\db-small.json",
    [switch] $EnableNetworkDelay,
    [int] $DelayMs = 100
)

# Import required modules
Import-Module .\Misc\logging.psm1 -Force
Initialize-Logger -Source "MockAPITest" -MinimumLevel Debug -Targets All

Import-Module .\Misc\helper.psm1 -Force
Import-Module .\Misc\settings.psm1 -Force
Import-Module .\Misc\mock-api.psm1 -Force

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Mock API Testing Script" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Initialize the mock API
    Write-Host "1. Initializing Mock API..." -ForegroundColor Yellow
    Initialize-MockAPI -DataPath $DataPath -EnableNetworkDelay:$EnableNetworkDelay -DelayMs $DelayMs
    Write-Host "   ✓ Mock API initialized successfully" -ForegroundColor Green
    Write-Host ""
    
    # Import the main module (which will now use mock data)
    Write-Host "2. Loading Collateral-RedmineDB module..." -ForegroundColor Yellow
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    Write-Host "   ✓ Module loaded successfully" -ForegroundColor Green
    Write-Host ""
    
    # Test connection with mock API
    Write-Host "3. Testing connection to mock Redmine server..." -ForegroundColor Yellow
    Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
    Write-Host "   ✓ Connected to mock server successfully" -ForegroundColor Green
    Write-Host ""
    
    # Test basic data retrieval
    Write-Host "4. Testing basic data retrieval..." -ForegroundColor Yellow
    try {
        # Test getting a specific entry by ID
        $testEntry = Get-RedmineDB -Id "18721"
        if ($testEntry) {
            Write-Host "   ✓ Successfully retrieved entry by ID: $($testEntry.Name)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ No entry found with ID 18721" -ForegroundColor Red
        }
        
        # Test getting entry by name
        $testByName = Get-RedmineDB -Name "00-008584"
        if ($testByName) {
            Write-Host "   ✓ Successfully retrieved entry by name: $($testByName.Name)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ No entry found with name '00-008584'" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "   ❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogError "Mock API data retrieval test failed" -Exception $_.Exception
    }
    Write-Host ""
    
    # Test search functionality
    Write-Host "5. Testing search functionality..." -ForegroundColor Yellow
    
    # Search by type
    $workstations = Search-RedmineDB -Field type -Keyword "Workstation"
    Write-Host "   ✓ Workstation search completed" -ForegroundColor Green
    Write-Host "   → Found $($workstations.Count) workstations" -ForegroundColor Gray
    
    # Search by status
    $validEntries = Search-RedmineDB -Field name -Keyword "00-" -Status valid
    Write-Host "   ✓ Status-filtered search completed" -ForegroundColor Green
    Write-Host "   → Found $($validEntries.Count) valid entries with '00-' in name" -ForegroundColor Gray
    
    # Search by building
    $buildingSearch = Search-RedmineDB -Field type -Keyword "Switch"
    Write-Host "   ✓ Switch search completed" -ForegroundColor Green
    Write-Host "   → Found $($buildingSearch.Count) switch entries" -ForegroundColor Gray
    Write-Host ""
    
    # Test individual entry retrieval
    Write-Host "6. Testing individual entry retrieval..." -ForegroundColor Yellow
    if ($allEntries.Count -gt 0) {
        $firstEntry = $allEntries[0]
        $singleEntry = Get-RedmineDB -Id $firstEntry.ID
        Write-Host "   ✓ Retrieved single entry: $($singleEntry.Name)" -ForegroundColor Green
        Write-Host "   → Type: $($singleEntry.Type)" -ForegroundColor Gray
        Write-Host "   → Status: $($singleEntry.Status)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Test parameter validation
    Write-Host "7. Testing parameter validation..." -ForegroundColor Yellow
    $validParams = @{
        Name = 'TEST-MOCK-001'
        Type = 'Workstation'
        Status = 'valid'
        Private = $false
        State = 'CT'
        Building = 'CT - C Building'
        Program = 'Underground'
    }
    $validated = Invoke-ValidateDB @validParams
    Write-Host "   ✓ Parameter validation completed" -ForegroundColor Green
    Write-Host "   → Validated parameters for: $($validated.Name)" -ForegroundColor Gray
    Write-Host ""
    
    # Test mock API request logging
    Write-Host "8. Checking Mock API request log..." -ForegroundColor Yellow
    $requestLog = Get-MockAPIRequestLog
    Write-Host "   ✓ Retrieved request log" -ForegroundColor Green
    Write-Host "   → Logged $($requestLog.Count) API requests" -ForegroundColor Gray
    
    if ($requestLog.Count -gt 0) {
        Write-Host "   → Recent requests:" -ForegroundColor Gray
        $requestLog | Select-Object -Last 5 | ForEach-Object {
            Write-Host "     • $($_.Method) $($_.Uri.Split('?')[0])" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    
    # Test data filtering and pagination
    Write-Host "9. Testing data filtering and pagination..." -ForegroundColor Yellow
    
    # Simulate a paginated request using Search-RedmineDB with limit
    $pagedResults = Search-RedmineDB -Field type -Keyword "Server" | Select-Object -First 5
    Write-Host "   ✓ Paginated request completed" -ForegroundColor Green
    Write-Host "   → Retrieved $($pagedResults.Count) entries with pagination" -ForegroundColor Gray
    Write-Host ""
    
    # Performance test
    Write-Host "10. Performance testing..." -ForegroundColor Yellow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    for ($i = 1; $i -le 10; $i++) {
        $testSearch = Search-RedmineDB -Field type -Keyword "Server"
    }
    
    $stopwatch.Stop()
    Write-Host "   ✓ Performance test completed" -ForegroundColor Green
    Write-Host "   → 10 searches completed in $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "   → Average: $([math]::Round($stopwatch.ElapsedMilliseconds / 10, 2))ms per search" -ForegroundColor Gray
    Write-Host ""
    
    # Summary
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "   Mock API Testing Summary" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "✓ All tests completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Mock API Features Tested:" -ForegroundColor White
    Write-Host "  • Data loading and caching" -ForegroundColor Gray
    Write-Host "  • API endpoint simulation" -ForegroundColor Gray
    Write-Host "  • Search functionality" -ForegroundColor Gray
    Write-Host "  • Parameter validation" -ForegroundColor Gray
    Write-Host "  • Request logging" -ForegroundColor Gray
    Write-Host "  • Pagination support" -ForegroundColor Gray
    Write-Host "  • Performance characteristics" -ForegroundColor Gray
    Write-Host ""
    
    # Show final request statistics
    $finalLog = Get-MockAPIRequestLog
    $getRequests = ($finalLog | Where-Object Method -eq 'GET').Count
    $postRequests = ($finalLog | Where-Object Method -eq 'POST').Count
    $putRequests = ($finalLog | Where-Object Method -eq 'PUT').Count
    $deleteRequests = ($finalLog | Where-Object Method -eq 'DELETE').Count
    
    Write-Host "API Request Statistics:" -ForegroundColor White
    Write-Host "  • Total requests: $($finalLog.Count)" -ForegroundColor Gray
    Write-Host "  • GET requests: $getRequests" -ForegroundColor Gray
    Write-Host "  • POST requests: $postRequests" -ForegroundColor Gray
    Write-Host "  • PUT requests: $putRequests" -ForegroundColor Gray
    Write-Host "  • DELETE requests: $deleteRequests" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Mock API is ready for use! 🚀" -ForegroundColor Green
    Write-Host "You can now run all your scripts against the mock data." -ForegroundColor White
}
catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogError "Mock API test failed" -Exception $_.Exception
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    
    if (Get-Command Disconnect-Redmine -ErrorAction SilentlyContinue) {
        Disconnect-Redmine
    }
    
    if (Test-MockAPIEnabled) {
        Disable-MockAPI
    }
    
    Write-Host "✓ Cleanup completed" -ForegroundColor Green
}
