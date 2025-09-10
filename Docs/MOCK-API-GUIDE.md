# Mock API Quick Start Guide

## Overview

The Mock API middleware allows you to test all Collateral-RedmineDB functionality without needing a live Redmine server. It uses your actual data from `Data\db-small.json` to simulate realistic API responses.

## Quick Start

### 1. Basic Setup

```powershell
# Import the mock API module
Import-Module .\Misc\mock-api.psm1 -Force

# Initialize with your data
Initialize-MockAPI -DataPath "Data\db-small.json"

# Import the main module (will now use mock data)
Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect using mock credentials
Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
```

### 2. Run the Test Script

```powershell
# Run comprehensive tests
.\Test-MockAPI.ps1

# Run with network delay simulation
.\Test-MockAPI.ps1 -EnableNetworkDelay -DelayMs 200
```

### 3. Use All Normal Functions

Once initialized, all your normal functions work with mock data:

```powershell
# Search functions work normally
$workstations = Search-RedmineDB -Field type -Keyword "Workstation"
$servers = Search-RedmineDB -Field type -Keyword "Server" -Status valid

# Get individual entries
$entry = Get-RedmineDB -Id 18721
$entryByName = Get-RedmineDB -Name "00-008584"

# Parameter validation
$params = Invoke-ValidateDB -Name "TEST-001" -Type "Workstation" -State "CT"

# Create new entries (simulated)
$newEntry = New-RedmineDB -Name "MOCK-TEST-001" -Type "Laptop" -State "CT"

# Edit entries (simulated)
Edit-RedmineDB -Id 18721 -State "FL" -Building "WPB - EOB"
```

## Features

### API Endpoint Simulation
- **GET /db.json** - List all entries with pagination and filtering
- **GET /db/{id}.json** - Get single entry by ID
- **POST /projects/{id}/db.json** - Create new entries
- **PUT /db/{id}.json** - Update existing entries
- **DELETE /db/{id}.json** - Delete entries
- **GET /projects.json** - List projects

### Request Logging
```powershell
# View all API requests made
$log = Get-MockAPIRequestLog
$log | Format-Table Timestamp, Method, Uri

# Clear the log
Clear-MockAPIRequestLog
```

### Configuration Options
```powershell
# Enable network delay simulation for realistic testing
Initialize-MockAPI -DataPath "Data\db-small.json" -EnableNetworkDelay -DelayMs 150

# Use custom API key
Initialize-MockAPI -DataPath "Data\db-small.json" -ApiKey "my-custom-key"
```

### Status Checking
```powershell
# Check if mock mode is active
if (Test-MockAPIEnabled) {
    Write-Host "Mock API is active"
}

# Disable mock mode
Disable-MockAPI
```

## Supported Operations

### ✅ Fully Supported
- Database entry listing with pagination
- Single entry retrieval by ID
- Search by all fields (name, type, serial, hostname, etc.)
- Status filtering (valid, invalid, to verify)
- Parameter validation
- Connection management
- Request logging and monitoring

### 🔄 Simulated (Returns Success)
- Creating new entries
- Updating existing entries
- Deleting entries
- Authentication validation

### ❌ Not Implemented
- Real data persistence (changes don't modify the JSON file)
- Complex relationship queries
- Attachment handling
- User management

## Data Structure

The mock API expects data in this format:
```json
{
    "db_entries": [
        {
            "id": 18721,
            "name": "00-008584",
            "status": { "id": 0, "name": "valid" },
            "type": { "id": 27, "name": "Infiniband Switch" },
            "custom_fields": [
                { "id": 101, "name": "System Make", "value": "Mellanox" },
                { "id": 102, "name": "System Model", "value": "MSB7800" }
            ]
        }
    ],
    "total_count": 16177,
    "offset": 0,
    "limit": 2000
}
```

## Testing Different Scenarios

### Performance Testing
```powershell
# Test search performance
Measure-Command {
    1..100 | ForEach-Object {
        Search-RedmineDB -Field type -Keyword "Workstation"
    }
}
```

### Error Handling
```powershell
# Test with invalid API key
Connect-Redmine -Server "http://localhost:8080" -Key "invalid-key"

# Test with non-existent entry
Get-RedmineDB -Id 999999
```

### Bulk Operations
```powershell
# Process multiple entries
$allEntries = Search-RedmineDB -Field type -Keyword "Server"
$allEntries | ForEach-Object {
    Write-Host "Processing: $($_.Name) - $($_.Type)"
}
```

## Troubleshooting

### Common Issues

1. **"Mock API is not enabled"**
   - Run `Initialize-MockAPI` first
   - Verify the data file path exists

2. **"API key is invalid"**
   - Use the correct mock API key: `mock-api-key-12345-67890-abcdef-ghijkl40`
   - Or disable validation in the config

3. **No data returned**
   - Check if the JSON file is properly formatted
   - Verify the file contains `db_entries` array

### Debug Mode
```powershell
# Enable debug logging
Initialize-Logger -MinimumLevel Debug

# Check request logs
Get-MockAPIRequestLog | Format-List
```

## Cleanup

```powershell
# Always cleanup when done
Disconnect-Redmine
Disable-MockAPI
```

This mock API allows you to test your entire workflow safely with realistic data!
