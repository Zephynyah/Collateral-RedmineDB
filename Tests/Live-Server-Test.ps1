#Requires -Modules Pester

# Quick test to verify live server functionality
Import-Module "$PSScriptRoot\..\Collateral-RedmineDB.psm1" -Force

Write-Host "=== Live Server Integration Test ===" -ForegroundColor Green

# Test connection
Write-Host "Testing connection..." -ForegroundColor Yellow
try {
    Connect-Redmine -Server "http://localhost:3000/api" -Key "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
    Write-Host "✓ Connection successful" -ForegroundColor Green
} catch {
    Write-Host "✗ Connection failed: $_" -ForegroundColor Red
    exit 1
}

# Test getting existing entries
Write-Host "Testing Get-RedmineDB..." -ForegroundColor Yellow
try {
    $entries = Get-RedmineDB -Id 18721
    Write-Host "✓ Retrieved $($entries.Count) entries" -ForegroundColor Green
    if ($entries.Count -gt 0) {
        Write-Host "  First entry: $($entries[0].Name)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ Get failed: $_" -ForegroundColor Red
}

# Test searching
Write-Host "Testing Search-RedmineDB..." -ForegroundColor Yellow
try {
    $searchResults = Search-RedmineDB -Keyword "00-"
    Write-Host "✓ Search found $($searchResults.Count) results" -ForegroundColor Green
} catch {
    Write-Host "✗ Search failed: $_" -ForegroundColor Red
}

# Test creating a new entry
Write-Host "Testing New-RedmineDB..." -ForegroundColor Yellow
try {
    $testName = "PesterTest-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $newEntry = New-RedmineDB -Name $testName -Type "network_router" -Status "valid" -Description "Created by Pester integration test"
    Write-Host "✓ Created new entry: $($newEntry.Name) (ID: $($newEntry.Id))" -ForegroundColor Green
    
    # Test updating the entry
    Write-Host "Testing Edit-RedmineDB..." -ForegroundColor Yellow
    Edit-RedmineDB -Id $newEntry.Id -Description "Updated by Pester integration test"
    Write-Host "✓ Updated entry successfully" -ForegroundColor Green
    
    # Test removing the entry
    Write-Host "Testing Remove-RedmineDB..." -ForegroundColor Yellow
    Remove-RedmineDB -Id $newEntry.Id
    Write-Host "✓ Removed entry successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ CRUD operations failed: $_" -ForegroundColor Red
}

# Cleanup
Write-Host "Cleaning up..." -ForegroundColor Yellow
try {
    Disconnect-Redmine
    Write-Host "✓ Disconnected successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Disconnect failed: $_" -ForegroundColor Red
}

Write-Host "=== Integration Test Complete ===" -ForegroundColor Green
