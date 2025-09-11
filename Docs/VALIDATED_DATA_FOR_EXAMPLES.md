# Validated Data for Examples

This document contains real, validated data extracted from `Data\db.json` and `Misc\settings.psm1` that can be used to update examples with actual working values.

## Real Database Entries (from Data\db.json)

### Entry 1: Infiniband Switch
- **ID**: 18721
- **Name**: "00-008584"
- **Type**: "Infiniband Switch" (ID: 27)
- **Status**: "valid" (ID: 0)
- **Make**: "Mellanox"
- **Model**: "MSB7800"
- **Serial**: "MT1849X03893"
- **Program**: "P430B"
- **State**: "CT"
- **Building**: "CT - M Building"
- **Lifecycle**: "Decommissioned"

### Entry 2: Infiniband Switch  
- **ID**: 18722
- **Name**: "00-008585"
- **Type**: "Infiniband Switch" (ID: 27) 
- **Status**: "valid" (ID: 0)
- **Make**: "Mellanox"
- **Model**: "MSB7800"
- **Serial**: (partial data visible)

### Entry 3: Hard Drive
- **ID**: 4067
- **Name**: "50603-1"
- **Type**: "Hard Drive" (ID: 3)
- **Status**: "valid" (ID: 0)
- **Make**: "Intel"
- **Model**: "SSDSCKKI128G801"
- **Serial**: "BTLA8032061Y128I"
- **Parent Hardware**: "4066"
- **Host Name**: "MM28-090"
- **Program**: "P397"
- **State**: "CT"
- **Building**: "CT - M-Mezz"
- **Room**: "M-Mezz - 28"
- **Lifecycle**: "Operational"

### Entry 4: Hard Drive
- **ID**: 6047
- **Name**: "512SS-100833"
- **Type**: "Hard Drive" (ID: 3)
- **Status**: "valid" (ID: 0)
- **Make**: "Micron"
- **Model**: "0JNPWN"
- **Serial**: "21142E22514F"
- **Parent Hardware**: "6046"
- **Host Name**: "BEB982857"
- **Program**: "P268"
- **Hard Drive Size**: "512 GB"
- **State**: "FL"
- **Building**: "WPB - EOB"
- **Room**: "EOB - Dolphin"
- **Rack/Seat**: "B1"
- **Lifecycle**: "Operational"

### Entry 5: Hard Drive (Decommissioned)
- **ID**: 10784
- **Name**: "AI983768: 515F71CBF8J3 placed in bag D00422915 in GSC safe.SC-003963"
- **Type**: "Hard Drive" (ID: 3)
- **Status**: "valid" (ID: 0)
- **Make**: "Kioxia"
- **Model**: "KXG60ZNV256G"
- **Serial**: "515F71CBF8J3"
- **Parent Hardware**: "10783"

## Valid Settings Values (from Misc\settings.psm1)

### Status Values
- **valid** = 0
- **to verify** = 1
- **invalid** = 2

### Type Values (Selected)
- **Workstation** = 1
- **Laptop** = 2
- **Hard Drive** = 3
- **Server** = 4
- **Network Switch** = 7
- **Infiniband Switch** = 27
- **Other** = 22

### Programs (Selected)
- P97, P174, P175, P176, P268, P333, P397, P397h, P430, P430B, P452, P462
- GSC, SIPR, F22, Gambit, AETP, Underground

### Lifecycle States
- New (not in use)
- In Testing
- Active
- Operational
- End of Life
- Retired
- Disposed
- Transferred
- Missing
- Decommissioned
- Unknown

### Buildings (Selected)
- CT - C Building
- CT - D Building
- CT - M Building
- CT - M-Mezz
- WPB - EOB
- CT - EB
- CT - RTRC

### Rooms (Selected)
- M-Mezz - 28
- EOB - Dolphin
- M - 103
- D - 144
- EB - D-8

### States
- CT (Connecticut)
- FL (Florida)
- IL (Illinois)
- OH (Ohio)
- OK (Oklahoma)
- PR (Puerto Rico)
- TN (Tennessee)

### Operating Systems (Selected)
- Windows 11
- Windows 10
- Windows Server 2022
- Windows Server 2019
- Ubuntu
- CentOS
- RHEL
- VMware ESXi

## Custom Field IDs
- **System Make** = 101
- **System Model** = 102
- **Operating System** = 105  
- **Serial Number** = 106
- **State** = 109
- **Parent Hardware** = 114
- **Host Name** = 115
- **Program** = 116
- **Hard Drive Size** = 120
- **Building** = 126
- **Room** = 127
- **Hardware Lifecycle** = 190

## Search Field Validation
Based on Search-RedmineDB ValidateSet, these are the only valid search fields:
- parent
- type
- serialnumber
- program
- hostname
- model
- mac
- macaddress

**Note**: 'name' field searches are NOT supported in Search-RedmineDB. Use Get-RedmineDB for name-based searches.

## Recommended Test Data Sets

### For Create Examples:
- Type: Workstation (1), Laptop (2), Server (4)
- Status: valid (0)
- Programs: P397, P430B, P268
- Buildings: CT - M Building, CT - M-Mezz
- States: CT, FL

### For Search Examples:
- Search by type: "Hard Drive", "Infiniband Switch"
- Search by program: "P397", "P430B", "P268"
- Search by hostname: "MM28-090", "BEB982857"
- Search by model: "MSB7800", "SSDSCKKI128G801"
- Search by serialnumber: "MT1849X03893", "BTLA8032061Y128I"

### For Update/Delete Examples:
- Existing IDs: 18721, 18722, 4067, 6047
- Names for Get-RedmineDB: "00-008584", "00-008585", "50603-1", "512SS-100833"
