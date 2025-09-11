# Read-Example.ps1
# Demonstrates how to read and search Redmine database entries using the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to read and search entries in the Redmine database.

.DESCRIPTION
    This script demonstrates various ways to retrieve and search Redmine database entries including:
    - Getting entries by ID and name
    - Searching by different fields
    - Using different output formats
    - Advanced search techniques
    - Error handling for missing entries

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. Appropriate permissions to read entries
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB Read Examples ===" -ForegroundColor Green

# Example 1: Get entry by ID
Write-Host "`n1. Getting entry by ID..." -ForegroundColor Yellow

try {
    $entryById = Get-RedmineDB -Id "12345"
    if ($entryById) {
        Write-Host "✓ Found entry by ID:" -ForegroundColor Green
        Write-Host "  Name: $($entryById.Name)"
        Write-Host "  Type: $($entryById.Type)"
        Write-Host "  Status: $($entryById.Status)"
    }
    else {
        Write-Host "⚠ No entry found with ID 12345" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to get entry by ID: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 2: Get entry by name
Write-Host "`n2. Getting entry by name..." -ForegroundColor Yellow

try {
    $entryByName = Get-RedmineDB -Name "SC-300012"
    if ($entryByName) {
        Write-Host "✓ Found entry by name:" -ForegroundColor Green
        Write-Host "  ID: $($entryByName.Id)"
        Write-Host "  Name: $($entryByName.Name)"
        Write-Host "  Description: $($entryByName.Description)"
    }
    else {
        Write-Host "⚠ No entry found with name 'SC-300012'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to get entry by name: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Get entry as JSON
Write-Host "`n3. Getting entry as JSON format..." -ForegroundColor Yellow

try {
    $jsonOutput = Get-RedmineDB -Id "12345" -AsJson
    if ($jsonOutput) {
        Write-Host "✓ Entry in JSON format:" -ForegroundColor Green
        Write-Host $jsonOutput
    }
}
catch {
    Write-Host "✗ Failed to get entry as JSON: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Search by hostname (Search-RedmineDB no longer supports name field)
Write-Host "`n4. Searching by hostname..." -ForegroundColor Yellow

try {
    $hostnameResults = Search-RedmineDB -Field hostname -Keyword "server-*"
    Write-Host "✓ Found $($hostnameResults.Count) entries with hostname matching 'server-*'" -ForegroundColor Green
    
    if ($hostnameResults.Count -gt 0) {
        Write-Host "First few results:"
        $hostnameResults | Select-Object -First 3 | ForEach-Object {
            Write-Host "  - $($_.Name) (ID: $($_.Id))"
        }
    }
}
catch {
    Write-Host "✗ Failed to search by hostname: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 5: Search by name using Get-RedmineDB (recommended for name searches)
Write-Host "`n5. Searching by name using Get-RedmineDB..." -ForegroundColor Yellow

try {
    # Note: Search-RedmineDB no longer supports 'name' field - use Get-RedmineDB instead
    $nameSearchExample = Get-RedmineDB -Name "SC-300012"
    if ($nameSearchExample) {
        Write-Host "✓ Found entry by name using Get-RedmineDB:" -ForegroundColor Green
        Write-Host "  - $($nameSearchExample.Name) (ID: $($nameSearchExample.Id))"
    }
    else {
        Write-Host "⚠ No entry found with name 'SC-300012'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to get entry by name: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Search by hostname using Search-RedmineDB
Write-Host "`n6. Searching by hostname..." -ForegroundColor Yellow

try {
    $hostnameResults = Search-RedmineDB -Field hostname -Keyword "server-*"
    Write-Host "✓ Found $($hostnameResults.Count) entries with hostname matching 'server-*'" -ForegroundColor Green
    
    $hostnameResults | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.CustomFields | Where-Object {$_.name -like '*hostname*'} | Select-Object -ExpandProperty value)"
    }
}
catch {
    Write-Host "✗ Failed to search by hostname: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 7: Search by type with exact match
Write-Host "`n7. Searching by type with exact match..." -ForegroundColor Yellow

try {
    $typeResults = Search-RedmineDB -Field type -Keyword "Workstation" -ExactMatch
    Write-Host "✓ Found $($typeResults.Count) workstations" -ForegroundColor Green
    
    if ($typeResults.Count -gt 0) {
        $typeResults | Select-Object -First 5 | ForEach-Object {
            Write-Host "  - $($_.Name) (Type: $($_.Type.name))"
        }
    }
}
catch {
    Write-Host "✗ Failed to search by type: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 8: Search by serial number
Write-Host "`n8. Searching by serial number..." -ForegroundColor Yellow

try {
    $serialResults = Search-RedmineDB -Field serialnumber -Keyword "SN*"
    Write-Host "✓ Found $($serialResults.Count) entries with serial numbers starting with 'SN'" -ForegroundColor Green
    
    $serialResults | Select-Object -First 3 | ForEach-Object {
        $serialField = $_.CustomFields | Where-Object {$_.name -like '*serial*'}
        Write-Host "  - $($_.Name): $($serialField.value)"
    }
}
catch {
    Write-Host "✗ Failed to search by serial number: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 9: Search by program
Write-Host "`n9. Searching by program..." -ForegroundColor Yellow

try {
    $programResults = Search-RedmineDB -Field program -Keyword "P123"
    Write-Host "✓ Found $($programResults.Count) entries associated with program 'P123'" -ForegroundColor Green
    
    $programResults | ForEach-Object {
        $programField = $_.CustomFields | Where-Object {$_.name -like '*program*'}
        Write-Host "  - $($_.Name): Programs = $($programField.value -join ', ')"
    }
}
catch {
    Write-Host "✗ Failed to search by program: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 10: Search by MAC address
Write-Host "`n10. Searching by MAC address..." -ForegroundColor Yellow

try {
    $macResults = Search-RedmineDB -Field mac -Keyword "00:1B:*"
    Write-Host "✓ Found $($macResults.Count) entries with MAC addresses starting with '00:1B:'" -ForegroundColor Green
    
    $macResults | ForEach-Object {
        $macField = $_.CustomFields | Where-Object {$_.name -like '*mac*'}
        Write-Host "  - $($_.Name): $($macField.value)"
    }
}
catch {
    Write-Host "✗ Failed to search by MAC address: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 11: Search with status filter - Note: Search-RedmineDB requires specifying a field
Write-Host "`n11. Searching with status filter..." -ForegroundColor Yellow

try {
    # Note: Since 'name' field is no longer supported, we need to use a different field
    $validOnlyResults = Search-RedmineDB -Field type -Keyword "Test*" -Status "valid"
    Write-Host "✓ Found $($validOnlyResults.Count) valid entries with type matching 'Test*'" -ForegroundColor Green
    
    $invalidResults = Search-RedmineDB -Field type -Keyword "Test*" -Status "invalid"
    Write-Host "✓ Found $($invalidResults.Count) invalid entries with type matching 'Test*'" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to search with status filter: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 12: Case-sensitive search
Write-Host "`n12. Case-sensitive search..." -ForegroundColor Yellow

try {
    $caseInsensitiveResults = Search-RedmineDB -Field hostname -Keyword "server"
    $caseSensitiveResults = Search-RedmineDB -Field hostname -Keyword "server" -CaseSensitive
    
    Write-Host "✓ Case-insensitive search found: $($caseInsensitiveResults.Count) entries" -ForegroundColor Green
    Write-Host "✓ Case-sensitive search found: $($caseSensitiveResults.Count) entries" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed case-sensitive search: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 13: Advanced search with multiple criteria
Write-Host "`n13. Advanced search techniques..." -ForegroundColor Yellow

try {
    # Search for Dell workstations that are valid
    $dellWorkstations = Search-RedmineDB -Field type -Keyword "Workstation" -Status "valid" |
        Where-Object { 
            $makeField = $_.CustomFields | Where-Object {$_.name -like '*make*'}
            $makeField.value -eq "Dell"
        }
    
    Write-Host "✓ Found $($dellWorkstations.Count) Dell workstations that are valid" -ForegroundColor Green
    
    # For building searches, we need to use a different approach since Search-RedmineDB no longer supports wildcard searches without a field
    # Search by a specific field instead
    $serverResults = Search-RedmineDB -Field type -Keyword "Server" -Status "*"
    $austinServers = $serverResults | Where-Object {
        $buildingField = $_.CustomFields | Where-Object {$_.name -like '*building*'}
        $buildingField.value -like "*Austin*"
    }
    
    Write-Host "✓ Found $($austinServers.Count) servers in Austin buildings" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed advanced search: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 14: Export search results
Write-Host "`n14. Exporting search results..." -ForegroundColor Yellow

try {
    $exportResults = Search-RedmineDB -Field type -Keyword "Server" -Status "valid"
    
    if ($exportResults.Count -gt 0) {
        # Export to CSV
        $csvPath = ".\Examples\server_export.csv"
        $exportResults | Select-Object Id, Name, Type, Status, Description | 
            Export-Csv -Path $csvPath -NoTypeInformation
        
        Write-Host "✓ Exported $($exportResults.Count) server entries to $csvPath" -ForegroundColor Green
        
        # Display summary statistics
        $typeGroups = $exportResults | Group-Object -Property {$_.Type.name}
        Write-Host "Server types found:"
        $typeGroups | ForEach-Object {
            Write-Host "  - $($_.Name): $($_.Count) entries"
        }
    }
}
catch {
    Write-Host "✗ Failed to export results: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 15: Error handling for missing entries
Write-Host "`n15. Demonstrating error handling..." -ForegroundColor Yellow

# Try to get a non-existent entry
try {
    $nonExistentEntry = Get-RedmineDB -Id "999999999"
    if ($nonExistentEntry) {
        Write-Host "Found entry: $($nonExistentEntry.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with ID 999999999 does not exist" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Error accessing non-existent entry: $($_.Exception.Message)" -ForegroundColor Red
}

# Search with no results - Note: must specify a field since 'name' is no longer supported
try {
    $noResults = Search-RedmineDB -Field type -Keyword "DEFINITELY_DOES_NOT_EXIST_TYPE_12345"
    Write-Host "⚠ Search returned $($noResults.Count) results for non-existent type keyword" -ForegroundColor Yellow
}
catch {
    Write-Host "✗ Error in search: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Read Examples Complete ===" -ForegroundColor Green
Write-Host "These examples show various ways to retrieve and search Redmine database entries." -ForegroundColor Cyan
Write-Host "IMPORTANT NOTE: Search-RedmineDB no longer supports the 'name' field." -ForegroundColor Yellow
Write-Host "Use Get-RedmineDB for name-based searches instead." -ForegroundColor Yellow
