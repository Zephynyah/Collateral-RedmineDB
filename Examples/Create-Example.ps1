# Create-Example.ps1
# Demonstrates how to create new Redmine database entries using the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to create new entries in the Redmine database.

.DESCRIPTION
    This script demonstrates various ways to create new Redmine database entries including:
    - Single entry creation with basic information
    - Entry creation with comprehensive hardware details
    - Bulk creation of multiple entries
    - Error handling and validation

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. Appropriate permissions to create entries
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB Create Examples ===" -ForegroundColor Green

# Example 1: Create a basic workstation entry
Write-Host "`n1. Creating a basic workstation entry..." -ForegroundColor Yellow

try {
    $basicWorkstation = New-RedmineDB -Name "WS-001234" -Type "Workstation" -Status "valid" -Description "Basic workstation for testing"
    Write-Host "✓ Successfully created basic workstation: $($basicWorkstation.Name)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to create basic workstation: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 2: Create a comprehensive server entry
Write-Host "`n2. Creating a comprehensive server entry..." -ForegroundColor Yellow

try {
    $serverParams = @{
        Name               = "SRV-DB-001"
        Type               = "Server"
        Status             = "valid"
        Description        = "Production database server"
        SystemMake         = "Dell"
        SystemModel        = "PowerEdge R740"
        OperatingSystem    = "Windows Server 2022"
        SerialNumber       = "SN123456789"
        AssetTag           = "AT-001234"
        Hostname           = "db-prod-01.company.com"
        HardwareLifecycle  = "Production"
        Programs           = @("P123", "P456")
        GSCStatus          = "Approved"
        HardDriveSize      = "2TB SSD"
        Memory             = "128GB"
        MemoryVolatility   = "Non-Volatile"
        State              = "TX"
        Building           = "Austin - Main Campus"
        Room               = "Server Room A"
        RackSeat           = "Rack 15, U10-U12"
        MacAddress         = "00:1B:21:12:34:56"
        Notes              = "Critical production database server - handle with care"
    }
    
    $comprehensiveServer = New-RedmineDB @serverParams
    Write-Host "✓ Successfully created comprehensive server: $($comprehensiveServer.Name)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to create comprehensive server: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Create a network device
Write-Host "`n3. Creating a network device entry..." -ForegroundColor Yellow

try {
    $networkDevice = New-RedmineDB `
        -Name "SW-CORE-001" `
        -Type "Network Equipment" `
        -Status "valid" `
        -SystemMake "Cisco" `
        -SystemModel "Catalyst 9300" `
        -SerialNumber "FCW2140L0GH" `
        -Hostname "core-switch-01" `
        -State "CA" `
        -Building "San Jose - Building 1" `
        -Room "Network Closet 1A" `
        -Programs @("Infrastructure") `
        -Notes "Core network switch - primary"
        
    Write-Host "✓ Successfully created network device: $($networkDevice.Name)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to create network device: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Bulk creation of test devices
Write-Host "`n4. Creating multiple test devices..." -ForegroundColor Yellow

$testDevices = @(
    @{ Name = "TEST-001"; Type = "Workstation"; Description = "Test device 1" },
    @{ Name = "TEST-002"; Type = "Laptop"; Description = "Test device 2" },
    @{ Name = "TEST-003"; Type = "Tablet"; Description = "Test device 3" }
)

$createdDevices = @()
foreach ($device in $testDevices) {
    try {
        $newDevice = New-RedmineDB -Name $device.Name -Type $device.Type -Status "valid" -Description $device.Description
        $createdDevices += $newDevice
        Write-Host "✓ Created: $($device.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create $($device.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nSuccessfully created $($createdDevices.Count) out of $($testDevices.Count) test devices" -ForegroundColor Cyan

# Example 5: Create with validation
Write-Host "`n5. Creating with pre-validation..." -ForegroundColor Yellow

try {
    $newEntryName = "VALIDATE-001"
    
    # Check if entry already exists
    $existingEntry = Get-RedmineDB -Name $newEntryName -ErrorAction SilentlyContinue
    if ($existingEntry) {
        Write-Host "⚠ Entry $newEntryName already exists with ID: $($existingEntry.Id)" -ForegroundColor Yellow
    }
    else {
        # Validate required fields before creation
        $validationParams = @{
            Name        = $newEntryName
            Type        = "Test Equipment"
            Status      = "valid"
            Description = "Equipment created with validation"
            SystemMake  = "Generic"
            State       = "FL"
        }
        
        # Perform validation using Invoke-ValidateDB
        $validation = Invoke-ValidateDB @validationParams
        if ($validation.IsValid) {
            $validatedEntry = New-RedmineDB @validationParams
            Write-Host "✓ Successfully created validated entry: $($validatedEntry.Name)" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Validation failed: $($validation.Errors -join ', ')" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "✗ Validation and creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Create with custom fields demonstration
Write-Host "`n6. Creating entry with all available custom fields..." -ForegroundColor Yellow

try {
    $fullCustomFieldsParams = @{
        Name                = "FULL-CUSTOM-001"
        Type                = "Specialized Equipment"
        Status              = "valid"
        Description         = "Example showing all custom field usage"
        Tags                = @("Example", "Demo", "Full")
        SystemMake          = "Example Corp"
        SystemModel         = "Model X1000"
        OperatingSystem     = "Custom OS 1.0"
        SerialNumber        = "EC-123456789"
        AssetTag            = "ASSET-001"
        PeriodsProcessing   = "Monthly"
        ParentHardware      = "PARENT-SYS-001"
        Hostname            = "example-host.domain.com"
        HardwareLifecycle   = "Development"
        Programs            = @("DEV", "TEST", "DEMO")
        GSCStatus           = "Pending"
        HardDriveSize       = "1TB NVMe"
        Memory              = "32GB DDR4"
        MemoryVolatility    = "Volatile"
        State               = "WA"
        Building            = "Seattle - Tech Campus"
        Room                = "Lab 101"
        RackSeat            = "Mobile Unit"
        Node                = "Node-Alpha"
        SafeAndDrawerNumber = "Safe-A-Drawer-3"
        RefreshDate         = (Get-Date).ToString("yyyy-MM-dd")
        MacAddress          = "AA:BB:CC:DD:EE:FF"
        Notes               = "Complete example with all custom fields populated for demonstration purposes"
        Issues              = @("Initial setup pending", "Documentation needed")
    }
    
    $fullEntry = New-RedmineDB @fullCustomFieldsParams
    Write-Host "✓ Successfully created full custom fields entry: $($fullEntry.Name)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to create full custom fields entry: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Create Examples Complete ===" -ForegroundColor Green
Write-Host "Check your Redmine database to verify the created entries." -ForegroundColor Cyan

# Example cleanup (uncomment if you want to remove test entries)
<#
Write-Host "`nCleaning up test entries..." -ForegroundColor Yellow
$testEntriesToCleanup = @("TEST-001", "TEST-002", "TEST-003", "VALIDATE-001", "FULL-CUSTOM-001")
foreach ($entryName in $testEntriesToCleanup) {
    try {
        $entry = Get-RedmineDB -Name $entryName -ErrorAction SilentlyContinue
        if ($entry) {
            Remove-RedmineDB -Id $entry.Id
            Write-Host "✓ Cleaned up: $entryName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✗ Failed to cleanup $entryName`: $($_.Exception.Message)" -ForegroundColor Red
    }
}
#>
