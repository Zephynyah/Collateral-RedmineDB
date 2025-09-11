# Update-Example.ps1
# Demonstrates how to update existing Redmine database entries using the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to update existing entries in the Redmine database.

.DESCRIPTION
    This script demonstrates various ways to update Redmine database entries including:
    - Single field updates
    - Multiple field updates using parameter splatting
    - Location updates
    - Hardware specification updates
    - Status and lifecycle updates
    - Bulk updates
    - Safe update practices with validation

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. Appropriate permissions to update entries
    4. Existing entries to update (run Create-Example.ps1 first if needed)
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB Update Examples ===" -ForegroundColor Green

# Example 1: Simple single field update
Write-Host "`n1. Simple single field update..." -ForegroundColor Yellow

try {
    # Update the description of an existing entry
    Edit-RedmineDB -Id "12345" -Description "Updated description - $(Get-Date)"
    Write-Host "✓ Successfully updated description for ID 12345" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update description: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 2: Location update
Write-Host "`n2. Updating location information..." -ForegroundColor Yellow

try {
    # Update location details for a resource
    Edit-RedmineDB -Id "12307" -State "CT" -Building "CT - C Building" -Room "C - Data Center"
    Write-Host "✓ Successfully updated location for ID 12307" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update location: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Comprehensive update using parameter splatting
Write-Host "`n3. Comprehensive update using parameter splatting..." -ForegroundColor Yellow

try {
    $updateParams = @{
        ID        = '8100'
        Status    = 'valid'
        Programs  = @('P397', 'P400')
        GSCStatus = 'Approved'
        State     = 'FL'
        Building  = 'WPB - EOB'
        Room      = 'EOB - Marlin'
        Notes     = "Updated on $(Get-Date -Format 'yyyy-MM-dd') - Moved to new location"
    }

    Edit-RedmineDB @updateParams
    Write-Host "✓ Successfully performed comprehensive update for ID 8100" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed comprehensive update: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Hardware specifications update
Write-Host "`n4. Updating hardware specifications..." -ForegroundColor Yellow

try {
    $hardwareParams = @{
        Id              = "15432"
        SystemMake      = "Dell"
        SystemModel     = "PowerEdge R740"
        Memory          = "64GB DDR4"
        HardDriveSize   = "2TB SSD"
        OperatingSystem = "Windows Server 2022"
        SerialNumber    = "DELL-SN-123456"
    }
    
    Edit-RedmineDB @hardwareParams
    Write-Host "✓ Successfully updated hardware specifications for ID 15432" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update hardware specifications: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 5: Network configuration update
Write-Host "`n5. Updating network configuration..." -ForegroundColor Yellow

try {
    Edit-RedmineDB -Id "20001" `
        -Hostname "updated-server.domain.com" `
        -MacAddress "AA:BB:CC:DD:EE:FF" `
        -Node "Network-Node-Alpha" `
        -Notes "Network configuration updated for new VLAN assignment"
        
    Write-Host "✓ Successfully updated network configuration for ID 20001" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update network configuration: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Status and lifecycle update
Write-Host "`n6. Updating status and lifecycle..." -ForegroundColor Yellow

try {
    $lifecycleParams = @{
        Id                = "25000"
        Status            = "to verify"
        HardwareLifecycle = "End of Life"
        GSCStatus         = "Decommission Pending"
        Notes             = "Scheduled for decommission - hardware end of life"
        RefreshDate       = (Get-Date).ToString("yyyy-MM-dd")
    }
    
    Edit-RedmineDB @lifecycleParams
    Write-Host "✓ Successfully updated lifecycle status for ID 25000" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update lifecycle status: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 7: Safe update with validation
Write-Host "`n7. Safe update with pre-validation..." -ForegroundColor Yellow

try {
    $targetId = "30000"
    
    # First, get the current entry to verify it exists
    $currentEntry = Get-RedmineDB -Id $targetId -ErrorAction SilentlyContinue
    
    if ($currentEntry) {
        Write-Host "✓ Found existing entry: $($currentEntry.Name)" -ForegroundColor Green
        
        # Perform the update
        $safeUpdateParams = @{
            Id          = $targetId
            Description = "Safely updated entry - Previous: $($currentEntry.Description)"
            Notes       = "Updated by safe update example on $(Get-Date)"
            RefreshDate = (Get-Date).ToString("yyyy-MM-dd")
        }
        
        Edit-RedmineDB @safeUpdateParams
        Write-Host "✓ Successfully performed safe update for ID $targetId" -ForegroundColor Green
        
        # Verify the update
        $updatedEntry = Get-RedmineDB -Id $targetId
        Write-Host "✓ Verified update - New description: $($updatedEntry.Description)" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Entry with ID $targetId not found - skipping update" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed safe update: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 8: Bulk update multiple entries
Write-Host "`n8. Bulk updating multiple entries..." -ForegroundColor Yellow

try {
    $entriesToUpdate = @("TEST-001", "TEST-002", "TEST-003")
    $successCount = 0
    $failCount = 0
    
    foreach ($entryName in $entriesToUpdate) {
        try {
            # Get entry by name first
            $entry = Get-RedmineDB -Name $entryName -ErrorAction SilentlyContinue
            
            if ($entry) {
                # Update with current timestamp
                Edit-RedmineDB -Id $entry.Id `
                    -Notes "Bulk updated on $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
                    -RefreshDate (Get-Date).ToString("yyyy-MM-dd")
                
                $successCount++
                Write-Host "✓ Updated: $entryName" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Entry not found: $entryName" -ForegroundColor Yellow
                $failCount++
            }
        }
        catch {
            Write-Host "✗ Failed to update $entryName`: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host "Bulk update complete: $successCount successful, $failCount failed" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Bulk update failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 9: Update with tags and issues
Write-Host "`n9. Updating tags and issues..." -ForegroundColor Yellow

try {
    $tagsAndIssuesParams = @{
        Id     = "35000"
        Tags   = @("Updated", "Maintenance", "Q4-2025")
        Issues = @("Needs firmware update", "Documentation required")
        Notes  = "Tagged for Q4 maintenance cycle"
    }
    
    Edit-RedmineDB @tagsAndIssuesParams
    Write-Host "✓ Successfully updated tags and issues for ID 35000" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update tags and issues: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 10: Asset tracking update
Write-Host "`n10. Updating asset tracking information..." -ForegroundColor Yellow

try {
    $assetParams = @{
        Id         = "40000"
        AssetTag   = "ASSET-2025-001"
        ParentHardware = "PARENT-SYS-RACK-15"
        RackSeat   = "Rack 15, U8-U10"
        SafeAndDrawerNumber = "Safe-B-Drawer-5"
        Notes      = "Asset tracking updated for inventory audit"
    }
    
    Edit-RedmineDB @assetParams
    Write-Host "✓ Successfully updated asset tracking for ID 40000" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to update asset tracking: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 11: Conditional update based on current values
Write-Host "`n11. Conditional update based on current values..." -ForegroundColor Yellow

try {
    $conditionalId = "45000"
    $entry = Get-RedmineDB -Id $conditionalId -ErrorAction SilentlyContinue
    
    if ($entry) {
        # Only update if certain conditions are met
        $statusField = $entry.Status
        
        if ($statusField -eq "valid") {
            # Update memory if it's currently less than 16GB
            $memoryField = $entry.CustomFields | Where-Object {$_.name -like '*memory*'}
            $currentMemory = if ($memoryField) { $memoryField.value } else { "Unknown" }
            
            if ($currentMemory -notlike "*32GB*" -and $currentMemory -notlike "*64GB*") {
                Edit-RedmineDB -Id $conditionalId `
                    -Memory "32GB DDR4" `
                    -Notes "Memory upgraded from $currentMemory to 32GB DDR4 on $(Get-Date -Format 'yyyy-MM-dd')"
                
                Write-Host "✓ Conditionally updated memory for ID $conditionalId" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Memory already sufficient for ID $conditionalId" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "⚠ Entry ID $conditionalId not in valid status - skipping update" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ Entry with ID $conditionalId not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed conditional update: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 12: Update with backup and rollback capability
Write-Host "`n12. Update with backup (demonstration)..." -ForegroundColor Yellow

try {
    $backupId = "50000"
    $originalEntry = Get-RedmineDB -Id $backupId -ErrorAction SilentlyContinue
    
    if ($originalEntry) {
        # Create backup of original values
        $backup = @{
            Id          = $originalEntry.Id
            Name        = $originalEntry.Name
            Description = $originalEntry.Description
            Notes       = if ($originalEntry.CustomFields | Where-Object {$_.name -like '*notes*'}) {
                ($originalEntry.CustomFields | Where-Object {$_.name -like '*notes*'}).value
            } else { "" }
        }
        
        Write-Host "✓ Created backup for entry $($backup.Name)" -ForegroundColor Green
        
        # Perform the update
        Edit-RedmineDB -Id $backupId `
            -Description "UPDATED: $($backup.Description)" `
            -Notes "Previous notes: $($backup.Notes) | Updated on: $(Get-Date)"
        
        Write-Host "✓ Successfully updated entry with backup capability" -ForegroundColor Green
        
        # In a real scenario, you could store the backup and implement rollback
        # For demonstration, we'll just show the backup data
        Write-Host "Backup data available for rollback:" -ForegroundColor Cyan
        Write-Host "  Original Description: $($backup.Description)"
        Write-Host "  Original Notes: $($backup.Notes)"
    }
    else {
        Write-Host "⚠ Entry with ID $backupId not found for backup demo" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed backup demo: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 13: Update validation
Write-Host "`n13. Update with validation..." -ForegroundColor Yellow

try {
    $validationId = "55000"
    
    # Define the update parameters
    $validationParams = @{
        Id              = $validationId
        SystemMake      = "HP"
        SystemModel     = "ProLiant DL380"
        OperatingSystem = "Ubuntu 22.04 LTS"
        State           = "TX"
        Building        = "Dallas - Data Center"
    }
    
    # Validate the parameters before applying
    $validation = Invoke-ValidateDB @validationParams
    
    if ($validation.IsValid) {
        Edit-RedmineDB @validationParams
        Write-Host "✓ Successfully updated with validation for ID $validationId" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Validation failed: $($validation.Errors -join ', ')" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Failed validated update: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Update Examples Complete ===" -ForegroundColor Green
Write-Host "These examples demonstrate various update patterns and best practices." -ForegroundColor Cyan
Write-Host "Remember to verify your updates by retrieving the entries afterward." -ForegroundColor Cyan
