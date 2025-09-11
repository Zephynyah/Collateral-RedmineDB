# CRUD-CSV-Example.ps1
# Demonstrates how to perform CRUD operations using CSV files with the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to perform Create, Read, Update, Delete operations using CSV files.

.DESCRIPTION
    This script demonstrates how to:
    - Import data from CSV files to create new entries
    - Export search results to CSV files
    - Update multiple entries from CSV data
    - Perform bulk operations efficiently
    - Handle errors and validation in bulk operations

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. Appropriate permissions for CRUD operations
    4. Sample CSV files or the script will create them
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB CSV CRUD Examples ===" -ForegroundColor Green

# Ensure Examples directory exists
$ExamplesDir = ".\Examples"
if (-not (Test-Path $ExamplesDir)) {
    New-Item -ItemType Directory -Path $ExamplesDir -Force | Out-Null
}

# Example 1: Create sample CSV file for import
Write-Host "`n1. Creating sample CSV file for import..." -ForegroundColor Yellow

$sampleData = @(
    [PSCustomObject]@{
        Name            = "CSV-IMPORT-001"
        Type            = "Workstation"
        Status          = "valid"
        Description     = "Workstation imported from CSV"
        SystemMake      = "Dell"
        SystemModel     = "OptiPlex 7090"
        OperatingSystem = "Windows 11"
        SerialNumber    = "CSV001SN123"
        Memory          = "16GB"
        State           = "TX"
        Building        = "Austin - Main"
        Room            = "Office 101"
    },
    [PSCustomObject]@{
        Name            = "CSV-IMPORT-002"
        Type            = "Laptop"
        Status          = "valid"
        Description     = "Laptop imported from CSV"
        SystemMake      = "HP"
        SystemModel     = "EliteBook 840"
        OperatingSystem = "Windows 11"
        SerialNumber    = "CSV002SN456"
        Memory          = "32GB"
        State           = "CA"
        Building        = "San Jose - Campus"
        Room            = "Mobile"
    },
    [PSCustomObject]@{
        Name            = "CSV-IMPORT-003"
        Type            = "Server"
        Status          = "valid"
        Description     = "Server imported from CSV"
        SystemMake      = "HPE"
        SystemModel     = "ProLiant DL380"
        OperatingSystem = "Windows Server 2022"
        SerialNumber    = "CSV003SN789"
        Memory          = "128GB"
        State           = "FL"
        Building        = "Miami - Data Center"
        Room            = "Server Room A"
    }
)

$importCsvPath = "$ExamplesDir\import_sample.csv"
$sampleData | Export-Csv -Path $importCsvPath -NoTypeInformation
Write-Host "✓ Created sample CSV file: $importCsvPath" -ForegroundColor Green

# Example 2: Import and create entries from CSV
Write-Host "`n2. Importing and creating entries from CSV..." -ForegroundColor Yellow

try {
    $csvData = Import-Csv -Path $importCsvPath
    $successCount = 0
    $failCount = 0
    
    foreach ($row in $csvData) {
        try {
            # Check if entry already exists
            $existingEntry = Get-RedmineDB -Name $row.Name -ErrorAction SilentlyContinue
            
            if ($existingEntry) {
                Write-Host "⚠ Entry $($row.Name) already exists - skipping" -ForegroundColor Yellow
                continue
            }
            
            # Create new entry from CSV data
            $createParams = @{
                Name            = $row.Name
                Type            = $row.Type
                Status          = $row.Status
                Description     = $row.Description
                SystemMake      = $row.SystemMake
                SystemModel     = $row.SystemModel
                OperatingSystem = $row.OperatingSystem
                SerialNumber    = $row.SerialNumber
                Memory          = $row.Memory
                State           = $row.State
                Building        = $row.Building
                Room            = $row.Room
                Notes           = "Imported from CSV on $(Get-Date -Format 'yyyy-MM-dd')"
            }
            
            $newEntry = New-RedmineDB @createParams
            Write-Host "✓ Created: $($row.Name)" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "✗ Failed to create $($row.Name): $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host "Import complete: $successCount created, $failCount failed" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Failed to import CSV: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Export search results to CSV
Write-Host "`n3. Exporting search results to CSV..." -ForegroundColor Yellow

try {
    # Search for workstations
    $workstations = Search-RedmineDB -Field type -Keyword "Workstation" -Status "valid"
    
    if ($workstations.Count -gt 0) {
        $exportCsvPath = "$ExamplesDir\workstations_export.csv"
        
        # Create custom export format
        $exportData = $workstations | ForEach-Object {
            $entry = $_
            
            # Extract custom field values
            $systemMake = ($entry.CustomFields | Where-Object {$_.name -like '*make*'}).value
            $systemModel = ($entry.CustomFields | Where-Object {$_.name -like '*model*'}).value
            $serialNumber = ($entry.CustomFields | Where-Object {$_.name -like '*serial*'}).value
            $memory = ($entry.CustomFields | Where-Object {$_.name -like '*memory*'}).value
            $state = ($entry.CustomFields | Where-Object {$_.name -like '*state*'}).value
            $building = ($entry.CustomFields | Where-Object {$_.name -like '*building*'}).value
            
            [PSCustomObject]@{
                Id              = $entry.Id
                Name            = $entry.Name
                Type            = $entry.Type.name
                Status          = $entry.Status
                Description     = $entry.Description
                SystemMake      = $systemMake
                SystemModel     = $systemModel
                SerialNumber    = $serialNumber
                Memory          = $memory
                State           = $state
                Building        = $building
                LastUpdated     = $entry.UpdatedOn
            }
        }
        
        $exportData | Export-Csv -Path $exportCsvPath -NoTypeInformation
        Write-Host "✓ Exported $($workstations.Count) workstations to: $exportCsvPath" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ No workstations found to export" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to export search results: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Create update CSV template
Write-Host "`n4. Creating update CSV template..." -ForegroundColor Yellow

try {
    # Get some existing entries to create update template
    $existingEntries = Search-RedmineDB -Keyword "CSV-IMPORT-*"
    
    if ($existingEntries.Count -gt 0) {
        $updateTemplate = $existingEntries | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                Name            = $_.Name
                NewDescription  = "UPDATED: $($_.Description)"
                NewMemory       = "32GB"
                NewNotes        = "Updated via CSV bulk operation"
                NewRefreshDate  = (Get-Date).ToString("yyyy-MM-dd")
            }
        }
        
        $updateCsvPath = "$ExamplesDir\update_template.csv"
        $updateTemplate | Export-Csv -Path $updateCsvPath -NoTypeInformation
        Write-Host "✓ Created update template: $updateCsvPath" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ No entries found to create update template" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to create update template: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 5: Bulk update from CSV
Write-Host "`n5. Performing bulk update from CSV..." -ForegroundColor Yellow

try {
    $updateCsvPath = "$ExamplesDir\update_template.csv"
    
    if (Test-Path $updateCsvPath) {
        $updateData = Import-Csv -Path $updateCsvPath
        $updateSuccessCount = 0
        $updateFailCount = 0
        
        foreach ($updateRow in $updateData) {
            try {
                # Verify entry exists
                $entryToUpdate = Get-RedmineDB -Id $updateRow.Id -ErrorAction SilentlyContinue
                
                if ($entryToUpdate) {
                    # Perform update
                    $updateParams = @{
                        Id          = $updateRow.Id
                        Description = $updateRow.NewDescription
                        Memory      = $updateRow.NewMemory
                        Notes       = $updateRow.NewNotes
                        RefreshDate = $updateRow.NewRefreshDate
                    }
                    
                    Edit-RedmineDB @updateParams
                    Write-Host "✓ Updated: $($updateRow.Name)" -ForegroundColor Green
                    $updateSuccessCount++
                }
                else {
                    Write-Host "⚠ Entry ID $($updateRow.Id) not found - skipping" -ForegroundColor Yellow
                    $updateFailCount++
                }
            }
            catch {
                Write-Host "✗ Failed to update $($updateRow.Name): $($_.Exception.Message)" -ForegroundColor Red
                $updateFailCount++
            }
        }
        
        Write-Host "Bulk update complete: $updateSuccessCount updated, $updateFailCount failed" -ForegroundColor Cyan
    }
    else {
        Write-Host "⚠ Update CSV template not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed bulk update: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Validation before CSV import
Write-Host "`n6. CSV import with validation..." -ForegroundColor Yellow

try {
    # Create validation CSV with some problematic data
    $validationData = @(
        [PSCustomObject]@{
            Name            = "VALID-001"
            Type            = "Workstation"
            Status          = "valid"
            SystemMake      = "Dell"
            State           = "TX"
        },
        [PSCustomObject]@{
            Name            = ""  # Invalid: empty name
            Type            = "Workstation"
            Status          = "valid"
            SystemMake      = "HP"
            State           = "CA"
        },
        [PSCustomObject]@{
            Name            = "VALID-002"
            Type            = ""  # Invalid: empty type
            Status          = "valid"
            SystemMake      = "Lenovo"
            State           = "FL"
        }
    )
    
    $validationCsvPath = "$ExamplesDir\validation_test.csv"
    $validationData | Export-Csv -Path $validationCsvPath -NoTypeInformation
    
    # Import and validate
    $csvValidationData = Import-Csv -Path $validationCsvPath
    $validCount = 0
    $invalidCount = 0
    
    foreach ($row in $csvValidationData) {
        try {
            # Basic validation
            $isValid = $true
            $validationErrors = @()
            
            if ([string]::IsNullOrWhiteSpace($row.Name)) {
                $validationErrors += "Name is required"
                $isValid = $false
            }
            
            if ([string]::IsNullOrWhiteSpace($row.Type)) {
                $validationErrors += "Type is required"
                $isValid = $false
            }
            
            if ($isValid) {
                # Additional validation using Invoke-ValidateDB
                $validationParams = @{
                    Name       = $row.Name
                    Type       = $row.Type
                    Status     = $row.Status
                    SystemMake = $row.SystemMake
                    State      = $row.State
                }
                
                $validation = Invoke-ValidateDB @validationParams
                
                if ($validation.IsValid) {
                    Write-Host "✓ Validation passed: $($row.Name)" -ForegroundColor Green
                    $validCount++
                }
                else {
                    Write-Host "✗ Validation failed for $($row.Name): $($validation.Errors -join ', ')" -ForegroundColor Red
                    $invalidCount++
                }
            }
            else {
                Write-Host "✗ Basic validation failed: $($validationErrors -join ', ')" -ForegroundColor Red
                $invalidCount++
            }
        }
        catch {
            Write-Host "✗ Validation error: $($_.Exception.Message)" -ForegroundColor Red
            $invalidCount++
        }
    }
    
    Write-Host "Validation complete: $validCount valid, $invalidCount invalid" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Failed validation process: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 7: Advanced CSV operations with error logging
Write-Host "`n7. Advanced CSV operations with error logging..." -ForegroundColor Yellow

try {
    $errorLogPath = "$ExamplesDir\csv_operations_errors.log"
    $successLogPath = "$ExamplesDir\csv_operations_success.log"
    
    # Clear previous logs
    "" | Out-File -FilePath $errorLogPath
    "" | Out-File -FilePath $successLogPath
    
    # Complex CSV operation with comprehensive logging
    $complexData = @(
        [PSCustomObject]@{
            Operation = "CREATE"
            Name      = "COMPLEX-001"
            Type      = "Server"
            Status    = "valid"
            SystemMake = "Dell"
        },
        [PSCustomObject]@{
            Operation = "UPDATE"
            Id        = "12345"
            Memory    = "64GB"
            Notes     = "Updated via complex CSV operation"
        },
        [PSCustomObject]@{
            Operation = "DELETE"
            Name      = "TEMP-DELETE-001"
        }
    )
    
    $complexCsvPath = "$ExamplesDir\complex_operations.csv"
    $complexData | Export-Csv -Path $complexCsvPath -NoTypeInformation
    
    $complexCsvData = Import-Csv -Path $complexCsvPath
    
    foreach ($row in $complexCsvData) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        try {
            switch ($row.Operation) {
                "CREATE" {
                    $existing = Get-RedmineDB -Name $row.Name -ErrorAction SilentlyContinue
                    if (-not $existing) {
                        $createParams = @{
                            Name       = $row.Name
                            Type       = $row.Type
                            Status     = $row.Status
                            SystemMake = $row.SystemMake
                        }
                        $newEntry = New-RedmineDB @createParams
                        $logMessage = "$timestamp - SUCCESS - Created entry: $($row.Name)"
                        Write-Host "✓ $logMessage" -ForegroundColor Green
                        $logMessage | Add-Content -Path $successLogPath
                    }
                    else {
                        throw "Entry already exists: $($row.Name)"
                    }
                }
                
                "UPDATE" {
                    $updateParams = @{
                        Id     = $row.Id
                        Memory = $row.Memory
                        Notes  = $row.Notes
                    }
                    Edit-RedmineDB @updateParams
                    $logMessage = "$timestamp - SUCCESS - Updated entry ID: $($row.Id)"
                    Write-Host "✓ $logMessage" -ForegroundColor Green
                    $logMessage | Add-Content -Path $successLogPath
                }
                
                "DELETE" {
                    $entry = Get-RedmineDB -Name $row.Name -ErrorAction SilentlyContinue
                    if ($entry) {
                        Remove-RedmineDB -Name $row.Name
                        $logMessage = "$timestamp - SUCCESS - Deleted entry: $($row.Name)"
                        Write-Host "✓ $logMessage" -ForegroundColor Green
                        $logMessage | Add-Content -Path $successLogPath
                    }
                    else {
                        throw "Entry not found for deletion: $($row.Name)"
                    }
                }
            }
        }
        catch {
            $errorMessage = "$timestamp - ERROR - Operation: $($row.Operation), Error: $($_.Exception.Message)"
            Write-Host "✗ $errorMessage" -ForegroundColor Red
            $errorMessage | Add-Content -Path $errorLogPath
        }
    }
    
    Write-Host "✓ Complex operations complete. Check logs:" -ForegroundColor Cyan
    Write-Host "  Success log: $successLogPath" -ForegroundColor White
    Write-Host "  Error log: $errorLogPath" -ForegroundColor White
}
catch {
    Write-Host "✗ Failed complex CSV operations: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 8: CSV reporting and analytics
Write-Host "`n8. CSV reporting and analytics..." -ForegroundColor Yellow

try {
    # Generate comprehensive report
    $allEntries = Search-RedmineDB -Keyword "*" -Status "*"
    
    if ($allEntries.Count -gt 0) {
        # Create detailed report
        $reportData = $allEntries | ForEach-Object {
            $entry = $_
            
            [PSCustomObject]@{
                Id          = $entry.Id
                Name        = $entry.Name
                Type        = $entry.Type.name
                Status      = $entry.Status
                CreatedOn   = $entry.CreatedOn
                UpdatedOn   = $entry.UpdatedOn
                HasMemory   = -not [string]::IsNullOrEmpty(($entry.CustomFields | Where-Object {$_.name -like '*memory*'}).value)
                HasSerial   = -not [string]::IsNullOrEmpty(($entry.CustomFields | Where-Object {$_.name -like '*serial*'}).value)
                HasLocation = -not [string]::IsNullOrEmpty(($entry.CustomFields | Where-Object {$_.name -like '*building*'}).value)
            }
        }
        
        $reportCsvPath = "$ExamplesDir\database_report.csv"
        $reportData | Export-Csv -Path $reportCsvPath -NoTypeInformation
        
        # Generate statistics
        $statsData = @(
            [PSCustomObject]@{
                Metric = "Total Entries"
                Count  = $allEntries.Count
            },
            [PSCustomObject]@{
                Metric = "Valid Entries"
                Count  = ($reportData | Where-Object {$_.Status -eq "valid"}).Count
            },
            [PSCustomObject]@{
                Metric = "Entries with Memory Info"
                Count  = ($reportData | Where-Object {$_.HasMemory}).Count
            },
            [PSCustomObject]@{
                Metric = "Entries with Serial Numbers"
                Count  = ($reportData | Where-Object {$_.HasSerial}).Count
            },
            [PSCustomObject]@{
                Metric = "Entries with Location Info"
                Count  = ($reportData | Where-Object {$_.HasLocation}).Count
            }
        )
        
        $statsCsvPath = "$ExamplesDir\database_statistics.csv"
        $statsData | Export-Csv -Path $statsCsvPath -NoTypeInformation
        
        Write-Host "✓ Generated reports:" -ForegroundColor Green
        Write-Host "  Detailed report: $reportCsvPath" -ForegroundColor White
        Write-Host "  Statistics: $statsCsvPath" -ForegroundColor White
        
        # Display key statistics
        Write-Host "`nKey Statistics:" -ForegroundColor Cyan
        $statsData | ForEach-Object {
            Write-Host "  $($_.Metric): $($_.Count)" -ForegroundColor White
        }
    }
    else {
        Write-Host "⚠ No entries found for reporting" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to generate reports: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== CSV CRUD Examples Complete ===" -ForegroundColor Green
Write-Host "Check the Examples directory for generated CSV files and logs." -ForegroundColor Cyan
Write-Host "CSV files created:" -ForegroundColor White
Write-Host "  - import_sample.csv (sample import data)" -ForegroundColor Gray
Write-Host "  - workstations_export.csv (exported workstations)" -ForegroundColor Gray
Write-Host "  - update_template.csv (bulk update template)" -ForegroundColor Gray
Write-Host "  - validation_test.csv (validation examples)" -ForegroundColor Gray
Write-Host "  - complex_operations.csv (complex operations)" -ForegroundColor Gray
Write-Host "  - database_report.csv (comprehensive report)" -ForegroundColor Gray
Write-Host "  - database_statistics.csv (database statistics)" -ForegroundColor Gray
