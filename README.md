# Collateral-RedmineDB

﻿# RedmineDB PowerShell Module

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-RedmineDB-blue.svg)](https://www.powershellgallery.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A comprehensive PowerShell module for interacting with Redmine database API, specifically designed for hardware asset management and tracking.

## 📋 Table of Contents

- [Description](#description)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Available Commands](#available-commands)
- [Command Reference](#command-reference)
- [Examples](#examples)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Authors](#authors)

## Description

RedmineDB is a specialized PowerShell module that provides seamless integration with Redmine database APIs for managing hardware assets, equipment tracking, and inventory management. The module offers comprehensive CRUD operations while maintaining data integrity and validation.

> **Note:** This module deliberately excludes bulk database entry creation. Please continue to use the existing DB Import functionality for bulk operations.

## Features

- 🔐 **Secure Authentication** - Support for API keys and credential-based authentication
- 🔍 **Advanced Search** - Flexible search capabilities across multiple fields
- 📝 **CRUD Operations** - Complete Create, Read, Update, Delete functionality
- 📊 **Excel Integration** - Bulk operations using Excel (.xlsx) files
- ✅ **Data Validation** - Built-in parameter validation and translation
- 🌐 **Environment Support** - .env file configuration support
- 📚 **Comprehensive Help** - Detailed help documentation for all commands

## Prerequisites

- **PowerShell 5.0** or higher
- **Windows PowerShell** or **PowerShell Core**
- Valid **Redmine server** access with API permissions
- **Microsoft Excel** (for Excel-based operations)
- **ImportExcel module** (for Import-Excel function)

### Optional Dependencies

Install the ImportExcel module for advanced Excel import functionality:

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

## Installation

### Method 1: Manual Installation

Copy the entire module folder to one of the PowerShell module directories:

- **All users:** `C:\Program Files\WindowsPowerShell\Modules\RedmineDB\`
- **Current user:** `$HOME\Documents\WindowsPowerShell\Modules\RedmineDB\`

### Verification

Verify the installation by checking available modules:

```powershell
Get-Module -ListAvailable RedmineDB
```

## Quick Start

### 1. Import the Module

```powershell
Import-Module RedmineDB
```

### 2. Connect to Redmine Server

```powershell
# Using API Key
Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

# Using Username/Password
Connect-Redmine -Server "https://your-redmine-server.com" -Username "your-username"
```

### 3. Basic Operations

```powershell
# Get a specific database entry
Get-RedmineDB -Id 12345

# Search for entries
Search-RedmineDB -Keyword "SC-000059"

# Create a new entry
New-RedmineDB -Name "SC-123456" -Type "Server" -Status "valid"
```

## Available Commands

The following table lists all available commands in the RedmineDB module:

| Command Name         | Description                                      | Alias    |
|:---------------------|:-------------------------------------------------|:---------|
| `Connect-Redmine`    | Connect to the Redmine server                    | `none`   |
| `Get-RedmineDB`      | Get Redmine resource item by ID or name          | `none`   |
| `Search-RedmineDB`   | Search Redmine resources by keyword              | `none`   |
| `Edit-RedmineDB`     | Edit/update a Redmine resource                   | `none`   |
| `New-RedmineDB`      | Create a new Redmine resource                    | `none`   |
| `Remove-RedmineDB`   | Remove a Redmine resource                        | `none`   |
| `Disconnect-Redmine` | Disconnect from the Redmine server               | `none`   |
| `Import-RedmineEnv`  | Import variables from an ENV file                | `dotenv` |
| `Edit-RedmineDBXL`   | Edit multiple resources using Excel (.xlsx) file | `none`   |
| `Import-Excel`       | Import Excel data for bulk operations with validation | `ImportExcel` |
| `Invoke-ValidateDB`  | Validate DB parameters and perform translation   | `none`   |

## Command Reference

> **💡 Tip:** For detailed information about any command, use PowerShell's built-in help system: `Get-Help <CommandName> -Full`

### Connect-Redmine

Establishes a connection to the Redmine server and sets the authorization context for subsequent operations.

#### Syntax

```powershell
Connect-Redmine [-Server] <String> [[-Key] <String>] [[-UserName] <String>] [[-Password] <String>] [<CommonParameters>]
```

#### Parameters

- **Server** (Required): The Redmine server URL
- **Key** (Optional): API key for authentication
- **UserName** (Optional): Username for credential-based authentication
- **Password** (Optional): Password for credential-based authentication

#### Examples

```powershell
# Connect using API key
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key "0123456789abcdef0123456789abcdef01234567"

# Connect using username (will prompt for password)
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Username "m123456"

# Connect using environment variable
Import-RedmineEnv
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key $env:REDMINE_API_KEY
```

#### Using Environment Files

The module supports `.env` files for secure credential management. Default path: `C:\Users\$env:USERNAME\OneDrive - Raytheon Technologies\.env`

**Example .env file:**

```env
REDMINE_API_KEY=0123456789abcdef0123456789abcdef01234567
```

**Usage:**

```powershell
# Use default .env path
Import-RedmineEnv
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key $env:REDMINE_API_KEY

# Use custom .env path
Import-RedmineEnv -Path "C:\custom\path\.env"
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key $env:REDMINE_API_KEY
```

### Get-RedmineDB

Retrieves a specific Redmine database resource by ID or name.

#### Syntax

```powershell
Get-RedmineDB [-Id] <String> [<CommonParameters>]
Get-RedmineDB [-Name] <String> [<CommonParameters>]
```

#### Parameters

- **Id**: Unique database entry identifier
- **Name**: Asset name/tag (e.g., 'SS-101248')

#### Examples

```powershell
# Get entry by ID
Get-RedmineDB -Id 8100

# Get entry by name
Get-RedmineDB -Name 'SS-101248'
```

### Search-RedmineDB

Search Redmine database resources using keywords and filters. The default search field is `name`.

**Supported search fields:** `parent`, `type`, `serial`, `program`, `hostname`, `model`

#### Syntax

```powershell
Search-RedmineDB [-Keyword] <String> [[-Field] <String>] [[-Status] <String>] [<CommonParameters>]
```

#### Parameters

- **Keyword** (Required): Search term
- **Field** (Optional): Field to search in (default: 'name')
- **Status** (Optional): Filter by status

#### Examples

```powershell
# Search by name (default field)
Search-RedmineDB -Keyword 'SC-000059'

# Search by hostname
Search-RedmineDB -Field hostname -Keyword 'MM17-09'

# Search and export to CSV
Search-RedmineDB -Field type -Keyword 'Workstation' | Export-Csv -Path workstation.csv -NoTypeInformation

# Search with status filter
Search-RedmineDB -Field type -Keyword 'Hard Drive' -Status invalid

# Search by serial number
Search-RedmineDB -Field serial -Keyword '1943041301385'

# Search by program
Search-RedmineDB -Field program -Keyword GSC

# Search by parent ID and format output
Search-RedmineDB -Field parent -Keyword 12303 | Format-Table
```

### Edit-RedmineDB

Edits or updates a single Redmine database resource.

#### Important Guidelines

- Only include fields that need to be changed
- Use an empty string `""` to remove a field value (Example: `Edit-RedmineDB -Room ""`)
- Mandatory fields will not accept empty strings

#### Syntax

```powershell
Edit-RedmineDB [-id] <String> [[-name] <String>] [[-type] <String>] [[-status] <String>] [[-private] <Boolean>] 
[[-description] <String>] [[-tags] <String[]>] [[-systemMake] <String>] [[-systemModel] <String>] 
[[-operatingSystem] <String>] [[-serialNumber] <String>] [[-assetTag] <String>] [[-periodsProcessing] <String>] 
[[-parentHardware] <String>] [[-hostname] <String>] [[-hardwareLifecycle] <String>] [[-programs] <String[]>] [[-gscStatus] <String>] 
[[-hardDriveSize] <String>] [[-memory] <String>] [[-memoryVolatility] <String>] [[-state] <String>] 
[[-building] <String>] [[-room] <String>] [[-rackSeat] <String>] [[-node] <String>] 
[[-safeAndDrawerNumber] <String>] [[-refreshDate] <String>] [[-macAddress] <String>] [[-notes] <String>] 
[[-issues] <PSObject[]>] [<CommonParameters>]
```

#### Examples

```powershell
# Update location information
Edit-RedmineDB -Id 12307 -State 'CT' -Building 'CT - C Building' -Room 'C - Data Center'

# Update multiple properties using splatting
$updateParams = @{
    ID        = '8100'
    Status    = 'valid'
    Program   = 'P397'
    GSCStatus = 'Approved'
    State     = 'FL'
    Building  = 'WPB - EOB'
    Room      = 'EOB - Marlin'
    HardwareLifecycle   = "Operational"
}
Edit-RedmineDB @updateParams
```

### New-RedmineDB

Creates a new Redmine DB resource.

***Golden Rules***

- Only include the fields that needs to change.
- Use an empty string `""` for removing the value of a field. Example. `Edit-RedmineDB -Room = ""`
- Madatory fields will not accept an empty string `""`

#### Usage

```powershell
New-RedmineDB [[-name] <String>] [[-type] <String>] [[-status] <String>] [[-private] <Boolean>] [[-description] <String>] 
[[-tags] <String[]>] [[-systemMake] <String>] [[-systemModel] <String>] [[-operatingSystem] <String>] [[-serialNumber] <String>] 
[[-assetTag] <String>] [[-periodsProcessing] <String>] [[-parentHardware] <String>] [[-hostname] <String>] [[-hardwareLifecycle] <String>]
[[-programs] <String[]>] [[-gscStatus] <String>] [[-hardDriveSize] <String>] [[-memory] <String>] [[-memoryValitility] <String>] 
[[-state] <String>] [[-building] <String>] [[-room] <String>] [[-rackSeat] <String>] [[-node] <String>]
[[-safeAndDrawerNumber] <String>] [[-refreshDate] <String>] [[-macAddress] <String>] [[-notes] <String>] [[-issues] <PSObject[]>] 
[<CommonParameters>]

```

#### Example

```powershell
New-RedmineDB -name "SC-005027" -type "Hard Drive" -SystemMake "TOSHIBA" -SystemModel "P5R3T84A EMC3840" `
        -SerialNumber  "90L0A0RJTT1F" -ParentHardware "12303" -Program  "Underground" `
        -GSCStatus "Approved" -HardDriveSize "3.8 TB" -State  "CT" -Building  "CT - C Building" `
        -Room  "C - Data Center" -HardwareLifecycle "Allocated"
```

```powershell
$newParams = @{
 name                = "SC-005027"
 description         = ""
 status              = "valid"
 type                = "Hard Drive"
 SystemMake          = "TOSHIBA"
 SystemModel         = "P5R3T84A EMC3840"
 SerialNumber        = "90L0A0RJTT1F"
 ParentHardware      = "12303"
 HostName            = ""
 Program             = "Underground"
 GSCStatus           = "Approved"
 HardDriveSize       = "3.8 TB"
 MemoryVolatility    = ""
 State               = "CT"
 Building            = "CT - C Building"
 Room                = "C - Data Center"
 RackSeat            = ""
 SafeandDrawerNumber = ""
 HardwareLifecycle   = "Allocated"
}

New-RedmineDB @newParams
```

```powershell
$translateParams = @{
 name                     = "SC - 005027"
 description              = ""
 status                   = "valid"
 type                     = "Hard Drive"
 is_private               = $true
 "System Make"            = "TOSHIBA"
 "System Model"           = "P5R3T84A EMC3840"
 "Serial Number"          = "90L0A0RJTT1F"
 "Parent Hardware"        = "12303"
 "Host Name"              = ""
 Program                  = "Underground"
 "GSC Status"             = "Approved"
 "Hard Drive Size"        = "3.8 TB"
 "Memory Volatility"      = ""
 State                    = "CT"
 Building                 = "CT - C Building"
 Room                     = "C - Data Center"
 "Rack/Seat"              = ""
 "Safe and Drawer Number" = ""
 "Hardware Lifecycle"     = 'Allocated'
}

$newParams = Invoke-ValidateDB @translateParams

New-RedmineDB @newParams
```

### Edit-RedmineDBXL

Edit multiple Redmine DB resources using a Microsoft `.xlsx` file.

***Golden Rules***

- Only include the fields that needs to change.
- Use an empty string `""` for removing the value of a field. Example. `""`
- Madatory fields will not accept an empty string `""`
- Always include the `id` field in the Microsoft `.xlsx` file.
- The headers of the Microsoft `.xlsx` file must match the [Redmine-HWBL-Template-UTF8.xlsx](https://sctdesk.eh.pweh.com/documents/29) Template.

#### Usage

```powershell
Edit-RedmineDBXL [-Path] <String> [[-StartColumn] <int>]  [[-StartRow] <int>]  [<CommonParameters>]
```

```powershell
Edit-RedmineDBXL [-Path] <String> [-ImportColumns] <int[]> [<CommonParameters>]
```

#### Example

```powershell
Edit-RedmineDBXL -path "C:\Users\m123456\Downloads\db.xlsx" -whatif
```

```powershell
Edit-RedmineDBXL -path "C:\Users\m123456\Downloads\db.xlsx"
```

```powershell
Edit-RedmineDBXL -path "C:\Users\m123456\Downloads\db.xlsx" -StartRow 2 -StartColumn 1
```

```powershell
 Edit-RedmineDBXL -path "C:\Users\m123456\Downloads\db.xlsx" -ImportColumns @(1, 5, 6)
```

```powershell
Edit-RedmineDBXL -path "C:\Users\m123456\Downloads\db.xlsx"  -ImportColumns @(1, 2, 3, 4, 5)
```

### Import-Excel

Import Excel data for bulk Redmine DB operations with validation, column mapping, and error handling.

#### Usage

```powershell
Import-Excel [-Path] <String> [[-WorksheetName] <String>] [[-StartRow] <int>] [[-StartColumn] <int>] [[-ColumnMapping] <hashtable>] [[-Operation] <String>] [-ValidateOnly] [[-MaxRows] <int>] [-ContinueOnError] [-WhatIf] [-Confirm] [<CommonParameters>]
```

```powershell
Import-Excel [-Path] <String> [[-WorksheetName] <String>] [-ImportColumns] <int[]> [[-ColumnMapping] <hashtable>] [[-Operation] <String>] [-ValidateOnly] [[-MaxRows] <int>] [-ContinueOnError] [-WhatIf] [-Confirm] [<CommonParameters>]
```

#### Examples

```powershell
# Preview what would be imported
Import-Excel -Path "C:\data\assets.xlsx" -Operation Preview
```

```powershell
# Create new entries with column mapping
$mapping = @{
    'Asset Name' = 'Name'
    'Asset Type' = 'Type'
    'Serial #' = 'SerialNumber'
    'Location' = 'Building'
}
Import-Excel -Path "assets.xlsx" -ColumnMapping $mapping -Operation Create
```

```powershell
# Validate data without making changes
Import-Excel -Path "updates.xlsx" -Operation Update -ValidateOnly
```

```powershell
# Process with error handling
Import-Excel -Path "bulk_data.xlsx" -Operation Create -ContinueOnError -MaxRows 100
```

### Remove-RedmineDB

Remove a Redmine DB resource.

#### Usage

```powershell
Remove-RedmineDB [-Id] <String> [<CommonParameters>]
```

```powershell
Remove-RedmineDB  [-Name] <String> [<CommonParameters>]
```

#### Example

```powershell
Remove-RedmineDB -id 29552
```

```powershell
Remove-RedmineDB -name SC-000059
```

### Disconnect-Redmine

Disconnect from the Redmine server.

#### Usage

```powershell
Disconnect-Redmine [<CommonParameters>]
```

#### Example

```powershell
Disconnect-Redmine
```

## Helper Commands

### Invoke-ValidateDB

This function is used for Redmine DB resource input validation and parameter translation.

- It validates Redmine DB selection parameter against expected values.
- It uses `Alias` to translate input parameter to predefined parameter. Example. `System Model` or `system_model` will be translated to `systemModel`.

#### Usage

```powershell
Invoke-ValidateDB [[-name] <String>] [[-type] <String>] [[-status] <String>] [[-private] <Boolean>] [[-description] <String>] 
[[-tags] <String[]>] [[-systemMake] <String>] [[-systemModel] <String>] [[-operatingSystem] <String>] [[-serialNumber] <String>] 
[[-assetTag] <String>] [[-periodsProcessing] <String>] [[-parentHardware] <String>] [[-hostname] <String>] [[-hardwareLifecycle] <String>]
[[-programs] <String[]>] [[-gscStatus] <String>] [[-hardDriveSize] <String>] [[-memory] <String>] [[-memoryValitility] <String>] 
[[-state] <String>] [[-building] <String>] [[-room] <String>] [[-rackSeat] <String>] [[-node] <String>]
[[-safeAndDrawerNumber] <String>] [[-refreshDate] <String>] [[-macAddress] <String>] [[-notes] <String>] [[-issues] <PSObject[]>] 
[<CommonParameters>]

```

#### Example

```powershell
Invoke-ValidateDB -building 'NB - S Building' -name 'test'
```

```powershell
$valideParams = @{
 Type              = 'VoIP'
 Status            = 'valid'
 Private           = 0
 Program           = 'P397'
 GSCStatus         = 'New'
 MemoryVolatility  = 'Volatile'
 State             = 'FL'
 Building          = 'WPB - EOB'
 Room              = 'EOB - Marlin'
 hardwareLifecycle  = 'Operational'
}


$editParams = Invoke-ValidateDB @valideParams

Edit-RedmineDB @editParams
```

## Configuration

### Environment Variables

The module supports secure credential storage using environment files:

| Variable | Description | Example |
|:---------|:------------|:--------|
| `REDMINE_API_KEY` | Your Redmine API key | `0123456789abcdef...` |

### Default Paths

- **.env file:** `C:\Users\$env:USERNAME\OneDrive - Raytheon Technologies\.env`
- **Module path (all users):** `C:\Program Files\WindowsPowerShell\Modules\RedmineDB\`
- **Module path (current user):** `$HOME\Documents\WindowsPowerShell\Modules\RedmineDB\`

## Practical Examples

### Complete Workflow Example

```powershell
# 1. Import the module
Import-Module RedmineDB

# 2. Set up environment and connect
Import-RedmineEnv
Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key $env:REDMINE_API_KEY

# 3. Search for existing assets
$assets = Search-RedmineDB -Field type -Keyword 'Server'

# 4. Create a new asset
$newAsset = @{
    Name = "SC-123456"
    Type = "Server"
    Status = "valid"
    SystemMake = "Dell"
    SystemModel = "PowerEdge R740"
    State = "VA"
    Building = "Building1"
    Room = "DataCenter"
}
New-RedmineDB @newAsset

# 5. Update existing asset
Edit-RedmineDB -Id 12345 -GSCStatus "Approved" -RefreshDate "2025-06-26"

# 6. Disconnect when done
Disconnect-Redmine
```

### Bulk Operations with Excel

```powershell
# Edit multiple entries from Excel file
Edit-RedmineDBXL -Path "C:\temp\asset_updates.xlsx" -WhatIf

# Execute the changes
Edit-RedmineDBXL -Path "C:\temp\asset_updates.xlsx"
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|:------|:---------|
| "Module not found" | Verify module is in correct PowerShell modules directory |
| "Access denied" | Check API key permissions and server connectivity |
| "Invalid field values" | Use `Invoke-ValidateDB` to validate parameters |
| "Excel file errors" | Ensure Excel file matches the required template format |

### Getting Help

```powershell
# Get detailed help for any command
Get-Help Connect-Redmine -Full
Get-Help Search-RedmineDB -Examples
Get-Help Edit-RedmineDB -Parameter *

# List all available commands
Get-Command -Module RedmineDB

# Check module version
Get-Module RedmineDB
```

## Contributing

Contributions are welcome! Please ensure:

1. **Code Quality:** Follow PowerShell best practices
2. **Documentation:** Update help documentation for new features
3. **Testing:** Test thoroughly before submitting
4. **Compatibility:** Maintain PowerShell 5.0+ compatibility

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

**Jason Hickey** - *Primary Developer*

## Version History

- **1.0.3** - Current release

## Acknowledgments

- **[hamletmun](https://github.com/hamletmun)** - Initial code for [PSRedmine](https://github.com/hamletmun/PSRedmine) Module
- **Kevin Adorno** - Redmine testing and support
- **Jonathan Grassley** - Redmine testing and support

---

**For detailed property information, see [PROPERTIES.md](PROPERTIES.md)**
