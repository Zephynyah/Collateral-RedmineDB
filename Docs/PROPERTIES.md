# RedmineDB Properties Reference

Database field properties and aliases for the RedmineDB PowerShell module.

## Overview

This document provides a comprehensive reference for all database properties supported by the RedmineDB PowerShell module. Each property corresponds to a field in the Redmine database and includes available aliases for easier scripting and parameter binding.

## Database Properties

The following table lists all available database properties, their descriptions, and supported aliases:

| Property Name         | Description                                 | Available Aliases                                  |
| :-------------------- | :------------------------------------------ | :------------------------------------------------- |
| `Id`                  | Database entry unique identifier            | `#`                                                |
| `Name`                | SCDT Asset tag (format: SC-##### or SS-######) | `none`                                         |
| `Type`                | Category classification for the asset       | `none`                                             |
| `Status`              | Current operational status                  | `none`                                             |
| `Private`             | Visibility setting for database entry       | `is_private`                                       |
| `Project`             | Associated project name                     | `none`                                             |
| `Tags`                | Comma-separated tags for categorization     | `none`                                             |
| `SystemMake`          | Hardware manufacturer name                  | `System Make`, `system_make`                       |
| `SystemModel`         | Hardware model designation                  | `System Model`, `system_model`                     |
| `OperatingSystem`     | Installed operating system                  | `Operating System`, `operating_system`             |
| `SerialNumber`        | Manufacturer's serial number                | `Serial Number`, `serial_number`                   |
| `AssetTag`            | Organization asset tracking tag             | `Asset Tag`, `asset_tag`                           |
| `MACAddress`          | Network MAC address (VoIP devices only)    | `MAC Address`, `mac_address`                       |
| `PeriodsProcessing`   | Processing period scope assignment          | `Periods Processing`, `periods_processing`         |
| `HostName`            | Network hostname identifier                 | `Host Name`, `host_name`                           |
| `HardwareLifecycle`   | Hardware lifecycle stage                    | `Hardware Lifecycle`, `hardware_lifecycle`         |
| `Program`             | Associated auditing program                 | `none`                                             |
| `GSCStatus`           | Government Security Classification status   | `GSC Status`, `gsc_status`                         |
| `Memory`              | System memory (RAM) specification          | `none`                                             |
| `HardDriveSize`       | Storage capacity (HDD/SSD)                  | `Hard Drive Size`, `hard_drive_size`               |
| `MemoryVolatility`    | Memory type classification                  | `Memory Volatility`, `memory_volatility`           |
| `State`               | Physical location: State/Province           | `none`                                             |
| `Building`            | Physical location: Building identifier      | `none`                                             |
| `Room`                | Physical location: Room number              | `none`                                             |
| `RackSeat`            | Physical location: Rack or seat designation | `Rack Seat`, `Rack/Seat`, `rack_seat`              |
| `Node`                | Logical node number assignment              | `none`                                             |
| `Safe`                | Physical location: Safe number              | `none`                                             |
| `SafeAndDrawerNumber` | Physical location: Safe and drawer details  | `Safe and Drawer Number`, `safe_and_drawer_number` |
| `RefreshDate`         | Last refresh/update date                    | `Refresh Date`, `refresh_date`                     |
| `RefreshCost`         | Associated refresh cost                     | `Refresh Cost`, `refresh_cost`                     |
| `BrassTag`            | Physical brass identification tag           | `Brass Tag`, `brass_tag`                           |
| `KeyExpiration`       | Security key expiration date                | `Key Expiration`, `key_expiration`                 |
| `FirmwareVersion`     | Current firmware version                    | `Firmware Version`, `firmware_version`             |

## Property Categories

Properties can be grouped into the following logical categories:

### Identification & Basic Info

- `Id`, `Name`, `Type`, `Status`, `Private`, `Project`, `Tags`

### Hardware Specifications

- `SystemMake`, `SystemModel`, `SerialNumber`, `AssetTag`, `Memory`, `HardDriveSize`, `MemoryVolatility`, `FirmwareVersion`

### Software & Configuration

- `OperatingSystem`, `HostName`, `Program`, `PeriodsProcessing`

### Network Information

- `MACAddress` (VoIP devices only)

### Lifecycle Management

- `HardwareLifecycle`, `GSCStatus`, `RefreshDate`, `RefreshCost`, `KeyExpiration`

### Physical Location

- `State`, `Building`, `Room`, `RackSeat`, `Node`, `Safe`, `SafeAndDrawerNumber`, `BrassTag`

## Usage Examples

### Using Property Names

```powershell
# Get database entry by ID
Get-RedmineDB -Id 12345

# Search by hostname
Search-RedmineDB -HostName "SERVER001"

# Filter by operating system
Search-RedmineDB -OperatingSystem "Windows Server 2022"
```

### Using Property Aliases

```powershell
# Using aliases for easier parameter binding
Get-RedmineDB -# 12345                    # Using Id alias
Search-RedmineDB -host_name "SERVER001"   # Using HostName alias
Search-RedmineDB -operating_system "Windows Server 2022"  # Using OperatingSystem alias
```

### Creating New Entries

```powershell
# Create a new database entry with multiple properties
New-RedmineDB -Name "SC-12345" -SystemMake "Dell" -SystemModel "PowerEdge R740" -OperatingSystem "Windows Server 2022" -State "VA" -Building "Building1" -Room "101"
```

### Editing Existing Entries

```powershell
# Update multiple properties at once
Edit-RedmineDB -Id 12345 -GSCStatus "Active" -RefreshDate "2025-06-26" -HardwareLifecycle "Production"
```

## Notes

- Properties marked with `none` in the aliases column do not have alternative parameter names
- Use the `Invoke-ValidateDB` command to validate property values before submission
- The `Private` property uses the `is_private` alias for consistency with the API
- Date fields should be formatted as strings in ISO format (YYYY-MM-DD)
- All property names are case-sensitive when used in API calls

## Related Commands

- `Get-RedmineDB` - Retrieve database entries
- `Search-RedmineDB` - Search database entries by criteria
- `New-RedmineDB` - Create new database entries
- `Edit-RedmineDB` - Modify existing database entries
- `Invoke-ValidateDB` - Validate property values and perform parameter translation

For detailed command syntax and examples, use PowerShell's built-in help system:

```powershell
Get-Help <CommandName> -Full
```
