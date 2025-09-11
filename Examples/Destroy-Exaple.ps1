# Destroy-Example.ps1
# Demonstrates how to remove and decommission Redmine database entries using the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to remove and decommission entries in the Redmine database.

.DESCRIPTION
    This script demonstrates various ways to remove and decommission Redmine database entries including:
    - Safe removal with confirmation
    - Decommissioning with different dispositions
    - Bulk removal operations
    - Proper cleanup procedures
    - Error handling and validation

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. Appropriate permissions to remove/decommission entries
    4. CAUTION: These operations are destructive and may be irreversible
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB Destroy Examples ===" -ForegroundColor Red
Write-Host "⚠ WARNING: These operations can permanently delete or decommission entries!" -ForegroundColor Yellow
Write-Host "⚠ Make sure you have backups and proper authorization before proceeding." -ForegroundColor Yellow

# Example 1: Safe removal with verification
Write-Host "`n1. Safe removal with verification..." -ForegroundColor Yellow

try {
    $targetId = "999999"  # Use a test ID that likely doesn't exist
    
    # First verify the entry exists
    $entryToRemove = Get-RedmineDB -Id $targetId -ErrorAction SilentlyContinue
    
    if ($entryToRemove) {
        Write-Host "Found entry to remove:" -ForegroundColor Cyan
        Write-Host "  ID: $($entryToRemove.Id)"
        Write-Host "  Name: $($entryToRemove.Name)"
        Write-Host "  Type: $($entryToRemove.Type)"
        
        # In a real scenario, you might want user confirmation here
        $confirmation = Read-Host "Are you sure you want to remove this entry? (yes/no)"
        
        if ($confirmation -eq "yes") {
            Remove-RedmineDB -Id $targetId
            Write-Host "✓ Successfully removed entry ID $targetId" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ Removal cancelled by user" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ Entry with ID $targetId not found - nothing to remove" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to remove entry by ID: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 2: Remove entry by name
Write-Host "`n2. Remove entry by name..." -ForegroundColor Yellow

try {
    $targetName = "TEST-REMOVE-001"
    
    # Verify entry exists by name
    $entryByName = Get-RedmineDB -Name $targetName -ErrorAction SilentlyContinue
    
    if ($entryByName) {
        Write-Host "Found entry by name: $targetName (ID: $($entryByName.Id))" -ForegroundColor Cyan
        
        # Remove by name
        Remove-RedmineDB -Name $targetName
        Write-Host "✓ Successfully removed entry: $targetName" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with name '$targetName' not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to remove entry by name: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Decommission with destruction disposition
Write-Host "`n3. Decommissioning with destruction disposition..." -ForegroundColor Yellow

try {
    $decommissionId = "29551"
    
    # Verify entry exists before decommissioning
    $entryToDecommission = Get-RedmineDB -Id $decommissionId -ErrorAction SilentlyContinue
    
    if ($entryToDecommission) {
        Write-Host "Decommissioning entry: $($entryToDecommission.Name)" -ForegroundColor Cyan
        
        # Decommission with destruction
        Invoke-DecomissionDB -Id $decommissionId -Decommissioned "Destruction"
        Write-Host "✓ Successfully decommissioned entry for destruction" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with ID $decommissionId not found for decommissioning" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to decommission entry: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Decommission with different dispositions
Write-Host "`n4. Decommissioning with various dispositions..." -ForegroundColor Yellow

$decommissionExamples = @(
    @{ Id = "30001"; Disposition = "Collateral"; Description = "Equipment damaged beyond repair" },
    @{ Id = "30002"; Disposition = "Reuse"; Description = "Equipment repurposed for different use" },
    @{ Id = "30003"; Disposition = "Returned to Vendor"; Description = "Equipment returned under warranty" }
)

foreach ($example in $decommissionExamples) {
    try {
        $entry = Get-RedmineDB -Id $example.Id -ErrorAction SilentlyContinue
        
        if ($entry) {
            Write-Host "Decommissioning $($entry.Name) as $($example.Disposition)" -ForegroundColor Cyan
            Invoke-DecomissionDB -Id $example.Id -Decommissioned $example.Disposition
            Write-Host "✓ Decommissioned as: $($example.Disposition)" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ Entry ID $($example.Id) not found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Failed to decommission ID $($example.Id): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Example 5: Decommission with vendor repair disposition
Write-Host "`n5. Decommissioning for vendor repair..." -ForegroundColor Yellow

try {
    $vendorRepairId = "35001"
    
    $entry = Get-RedmineDB -Id $vendorRepairId -ErrorAction SilentlyContinue
    
    if ($entry) {
        Write-Host "Sending $($entry.Name) for vendor repair" -ForegroundColor Cyan
        Invoke-DecomissionDB -Id $vendorRepairId -Disposition "Vendor Repair"
        Write-Host "✓ Successfully marked for vendor repair" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with ID $vendorRepairId not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed vendor repair disposition: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Bulk removal of test entries
Write-Host "`n6. Bulk removal of test entries..." -ForegroundColor Yellow

try {
    # Define test entries to remove (use safe test names)
    $testEntriesToRemove = @("TEST-001", "TEST-002", "TEST-003", "DEMO-TEMP-001")
    $removedCount = 0
    $notFoundCount = 0
    
    Write-Host "Attempting to remove $($testEntriesToRemove.Count) test entries..." -ForegroundColor Cyan
    
    foreach ($testName in $testEntriesToRemove) {
        try {
            $testEntry = Get-RedmineDB -Name $testName -ErrorAction SilentlyContinue
            
            if ($testEntry) {
                Remove-RedmineDB -Name $testName
                Write-Host "✓ Removed: $testName" -ForegroundColor Green
                $removedCount++
            }
            else {
                Write-Host "⚠ Not found: $testName" -ForegroundColor Yellow
                $notFoundCount++
            }
        }
        catch {
            Write-Host "✗ Failed to remove $testName`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "Bulk removal complete: $removedCount removed, $notFoundCount not found" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Bulk removal failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 7: Safe cleanup with search and remove
Write-Host "`n7. Safe cleanup with search and remove..." -ForegroundColor Yellow

try {
    # Search for entries with specific criteria to clean up
    $tempEntries = Search-RedmineDB -Field type -Keyword "Test*" -Status "invalid"
    
    if ($tempEntries.Count -gt 0) {
        Write-Host "Found $($tempEntries.Count) temporary invalid entries to clean up" -ForegroundColor Cyan
        
        foreach ($tempEntry in $tempEntries) {
            try {
                Write-Host "Removing temporary entry: $($tempEntry.Name)" -ForegroundColor Yellow
                Remove-RedmineDB -Id $tempEntry.Id
                Write-Host "✓ Cleaned up: $($tempEntry.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "✗ Failed to clean up $($tempEntry.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "⚠ No temporary invalid entries found for cleanup" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed cleanup operation: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 8: Conditional decommissioning based on age or status
Write-Host "`n8. Conditional decommissioning based on criteria..." -ForegroundColor Yellow

try {
    # Find entries that meet decommission criteria
    $oldEntries = Search-RedmineDB -Field type -Keyword "Test Equipment" -Status "to verify"
    
    if ($oldEntries.Count -gt 0) {
        Write-Host "Found $($oldEntries.Count) test equipment entries marked 'to verify'" -ForegroundColor Cyan
        
        foreach ($oldEntry in $oldEntries) {
            try {
                # Check if it's really old test equipment that should be decommissioned
                if ($oldEntry.Name -like "OLD-TEST-*") {
                    Write-Host "Decommissioning old test equipment: $($oldEntry.Name)" -ForegroundColor Yellow
                    Invoke-DecomissionDB -Id $oldEntry.Id -Decommissioned "Destruction"
                    Write-Host "✓ Decommissioned: $($oldEntry.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠ Skipping $($oldEntry.Name) - doesn't match old test criteria" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "✗ Failed to decommission $($oldEntry.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "⚠ No test equipment found for conditional decommissioning" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed conditional decommissioning: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 9: Archive before destroy (backup strategy)
Write-Host "`n9. Archive before destroy strategy..." -ForegroundColor Yellow

try {
    $archiveId = "40001"
    $entry = Get-RedmineDB -Id $archiveId -ErrorAction SilentlyContinue
    
    if ($entry) {
        # Create archive record (export to file)
        $archiveData = @{
            Id              = $entry.Id
            Name            = $entry.Name
            Type            = $entry.Type
            Status          = $entry.Status
            Description     = $entry.Description
            CustomFields    = $entry.CustomFields
            ArchivedDate    = Get-Date
            ArchivedReason  = "Scheduled for removal"
        }
        
        # Export archive data
        $archivePath = ".\Examples\archived_entry_$($entry.Id).json"
        $archiveData | ConvertTo-Json -Depth 10 | Out-File -FilePath $archivePath
        
        Write-Host "✓ Archived entry data to: $archivePath" -ForegroundColor Green
        
        # Now safely remove the entry
        # Remove-RedmineDB -Id $archiveId
        Write-Host "✓ Entry archived and ready for removal (removal commented out for safety)" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with ID $archiveId not found for archiving" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed archive operation: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 10: Error handling and rollback demonstration
Write-Host "`n10. Error handling and rollback demonstration..." -ForegroundColor Yellow

try {
    $problematicId = "50001"
    
    # Attempt operation with rollback capability
    $originalEntry = Get-RedmineDB -Id $problematicId -ErrorAction SilentlyContinue
    
    if ($originalEntry) {
        Write-Host "Attempting potentially problematic operation on: $($originalEntry.Name)" -ForegroundColor Cyan
        
        try {
            # This might fail - for demonstration
            # Invoke-DecomissionDB -Id $problematicId -Decommissioned "SomeInvalidOption"
            
            # Simulate error for demonstration
            throw "Simulated error during decommission operation"
        }
        catch {
            Write-Host "✗ Operation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "⚠ Entry remains unchanged - rollback successful" -ForegroundColor Yellow
            
            # Verify entry is still in original state
            $verifyEntry = Get-RedmineDB -Id $problematicId
            if ($verifyEntry.Status -eq $originalEntry.Status) {
                Write-Host "✓ Verified entry state unchanged after failed operation" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "⚠ Entry with ID $problematicId not found for rollback demo" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed error handling demo: $($_.Exception.Message)" -ForegroundColor Red
}

# Safety reminder and best practices
Write-Host "`n=== Destroy Examples Complete ===" -ForegroundColor Red
Write-Host "`n🛡️  SAFETY REMINDERS:" -ForegroundColor Yellow
Write-Host "1. Always verify entries before removal" -ForegroundColor White
Write-Host "2. Create backups/archives before destructive operations" -ForegroundColor White
Write-Host "3. Use decommissioning instead of removal when possible" -ForegroundColor White
Write-Host "4. Test operations on non-production data first" -ForegroundColor White
Write-Host "5. Implement proper approval workflows for destructive operations" -ForegroundColor White
Write-Host "6. Consider using -WhatIf parameters where available" -ForegroundColor White
Write-Host "7. Maintain audit logs of all removal operations" -ForegroundColor White

Write-Host "`nRemember: Some operations may be irreversible!" -ForegroundColor Red
