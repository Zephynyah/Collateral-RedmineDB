# Search-RedmineDB Field Changes

## Important Update

The `Search-RedmineDB` function has been updated and **no longer supports searching by the 'name' field**.

## Supported Fields

The following fields are now supported in `Search-RedmineDB`:

- `parent` - Search by parent hardware ID
- `type` - Search by equipment type
- `serialnumber` - Search by serial number
- `program` - Search by program associations
- `hostname` - Search by hostname
- `model` - Search by system model
- `mac` - Search by MAC address
- `macaddress` - Alias for MAC address

## Migration Guide

### Before (No longer supported):
```powershell
# This will cause an error
Search-RedmineDB -Keyword "SC-*"
Search-RedmineDB -Field name -Keyword "SC-300012"
```

### After (Recommended approach):
```powershell
# Use Get-RedmineDB for name-based searches
Get-RedmineDB -Name "SC-300012"

# For pattern matching by name, you'll need to use other approaches:
# 1. Search by a different field
Search-RedmineDB -Field type -Keyword "Workstation"

# 2. Get all entries and filter (less efficient for large datasets)
$allEntries = Search-RedmineDB -Field type -Keyword "*" -Status "*"
$nameMatches = $allEntries | Where-Object { $_.Name -like "SC-*" }
```

## Updated Examples

All example files have been updated to reflect these changes:

- `Read-Example.ps1` - Updated to show proper usage of Get-RedmineDB for name searches
- Other example files - Updated to use appropriate field parameters

## Best Practices

1. **For exact name matches**: Use `Get-RedmineDB -Name "exact-name"`
2. **For pattern searches**: Use the most appropriate field (type, hostname, etc.)
3. **For complex searches**: Combine Search-RedmineDB with PowerShell filtering

## Error Prevention

Always specify a field when using Search-RedmineDB:
```powershell
# ✅ Correct
Search-RedmineDB -Field hostname -Keyword "server-*"

# ❌ Will cause error (no field specified)
Search-RedmineDB -Keyword "server-*"
```
