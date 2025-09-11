# CRUD-XL-Example.ps1
# Demonstrates how to perform CRUD operations using Excel files with the Collateral-RedmineDB module

<#
.SYNOPSIS
    Example script showing how to perform Create, Read, Update, Delete operations using Excel (.xlsx) files.

.DESCRIPTION
    This script demonstrates how to:
    - Import data from Excel files to create new entries
    - Export search results to Excel files with formatting
    - Update multiple entries from Excel data using Edit-RedmineDBXL
    - Handle complex Excel worksheets with multiple tabs
    - Perform data validation and error handling with Excel data

.NOTES
    Make sure you have:
    1. Imported the Collateral-RedmineDB module
    2. Connected to your Redmine server using Connect-Redmine
    3. ImportExcel module installed (Install-Module ImportExcel -Force)
    4. Appropriate permissions for CRUD operations
    5. Sample Excel files or the script will create them

.REQUIREMENTS
    - ImportExcel PowerShell module
    - Excel files (.xlsx format)
    - Appropriate file system permissions
#>

# Import the module (if not already imported)
# Import-Module .\Collateral-RedmineDB.psm1 -Force

# Connect to Redmine server (replace with your server details)
# Connect-Redmine -Server "https://your-redmine-server.com" -Key "your-api-key"

Write-Host "=== Collateral-RedmineDB Excel CRUD Examples ===" -ForegroundColor Green

# Check if ImportExcel module is available
try {
    Import-Module ImportExcel -ErrorAction Stop
    Write-Host "✓ ImportExcel module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ ImportExcel module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module ImportExcel -Force -AllowClobber -Scope CurrentUser
        Import-Module ImportExcel -Force
        Write-Host "✓ ImportExcel module installed and loaded" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to install ImportExcel module: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please install manually: Install-Module ImportExcel -Force" -ForegroundColor Yellow
        return
    }
}

# Ensure Examples directory exists
$ExamplesDir = ".\Examples"
if (-not (Test-Path $ExamplesDir)) {
    New-Item -ItemType Directory -Path $ExamplesDir -Force | Out-Null
}

# Example 1: Create sample Excel file for import
Write-Host "`n1. Creating sample Excel file for import..." -ForegroundColor Yellow

try {
    $sampleWorkstations = @(
        [PSCustomObject]@{
            Name            = "XL-IMPORT-001"
            Type            = "Workstation"
            Status          = "valid"
            Description     = "Gaming workstation imported from Excel"
            SystemMake      = "Alienware"
            SystemModel     = "Aurora R13"
            OperatingSystem = "Windows 11 Pro"
            SerialNumber    = "XL001SN123"
            Memory          = "32GB DDR5"
            HardDriveSize   = "1TB NVMe SSD"
            State           = "TX"
            Building        = "Austin - Gaming Lab"
            Room            = "Lab 201"
            Programs        = "Development;Gaming"
        },
        [PSCustomObject]@{
            Name            = "XL-IMPORT-002"
            Type            = "Workstation"
            Status          = "valid"
            Description     = "Design workstation imported from Excel"
            SystemMake      = "Apple"
            SystemModel     = "Mac Studio"
            OperatingSystem = "macOS Ventura"
            SerialNumber    = "XL002SN456"
            Memory          = "64GB"
            HardDriveSize   = "2TB SSD"
            State           = "CA"
            Building        = "San Francisco - Design Center"
            Room            = "Studio A"
            Programs        = "Design;Marketing"
        }
    )
    
    $sampleServers = @(
        [PSCustomObject]@{
            Name            = "XL-SERVER-001"
            Type            = "Server"
            Status          = "valid"
            Description     = "Database server imported from Excel"
            SystemMake      = "HPE"
            SystemModel     = "ProLiant DL385"
            OperatingSystem = "Ubuntu 22.04 LTS"
            SerialNumber    = "XLS001SN789"
            Memory          = "256GB"
            HardDriveSize   = "8TB RAID 10"
            State           = "FL"
            Building        = "Miami - Data Center"
            Room            = "Server Rack 10"
            Programs        = "Database;Analytics"
        }
    )
    
    $importExcelPath = "$ExamplesDir\import_sample.xlsx"
    
    # Create Excel file with multiple worksheets
    $sampleWorkstations | Export-Excel -Path $importExcelPath -WorksheetName "Workstations" -AutoSize -BoldTopRow
    $sampleServers | Export-Excel -Path $importExcelPath -WorksheetName "Servers" -AutoSize -BoldTopRow
    
    Write-Host "✓ Created sample Excel file: $importExcelPath" -ForegroundColor Green
    Write-Host "  - Workstations sheet: $($sampleWorkstations.Count) entries" -ForegroundColor Gray
    Write-Host "  - Servers sheet: $($sampleServers.Count) entries" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to create sample Excel file: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 2: Import and create entries from Excel worksheets
Write-Host "`n2. Importing and creating entries from Excel worksheets..." -ForegroundColor Yellow

try {
    $importExcelPath = "$ExamplesDir\import_sample.xlsx"
    
    if (Test-Path $importExcelPath) {
        # Get worksheet names
        $worksheets = Get-ExcelSheetInfo -Path $importExcelPath
        
        foreach ($worksheet in $worksheets) {
            Write-Host "Processing worksheet: $($worksheet.Name)" -ForegroundColor Cyan
            
            # Import data from specific worksheet
            $xlData = Import-Excel -Path $importExcelPath -WorksheetName $worksheet.Name
            $successCount = 0
            $failCount = 0
            
            foreach ($row in $xlData) {
                try {
                    # Check if entry already exists
                    $existingEntry = Get-RedmineDB -Name $row.Name -ErrorAction SilentlyContinue
                    
                    if ($existingEntry) {
                        Write-Host "⚠ Entry $($row.Name) already exists - skipping" -ForegroundColor Yellow
                        continue
                    }
                    
                    # Parse programs if they exist (semicolon separated)
                    $programs = if ($row.Programs) { $row.Programs -split ';' } else { @() }
                    
                    # Create new entry from Excel data
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
                        HardDriveSize   = $row.HardDriveSize
                        State           = $row.State
                        Building        = $row.Building
                        Room            = $row.Room
                        Programs        = $programs
                        Notes           = "Imported from Excel worksheet '$($worksheet.Name)' on $(Get-Date -Format 'yyyy-MM-dd')"
                    }
                    
                    New-RedmineDB @createParams | Out-Null
                    Write-Host "✓ Created: $($row.Name)" -ForegroundColor Green
                    $successCount++
                }
                catch {
                    Write-Host "✗ Failed to create $($row.Name): $($_.Exception.Message)" -ForegroundColor Red
                    $failCount++
                }
            }
            
            Write-Host "Worksheet '$($worksheet.Name)' import: $successCount created, $failCount failed" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "⚠ Import Excel file not found: $importExcelPath" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to import from Excel: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 3: Export search results to formatted Excel file
Write-Host "`n3. Exporting search results to formatted Excel..." -ForegroundColor Yellow

try {
    # Search for different types of equipment
    $workstations = Search-RedmineDB -Field type -Keyword "Workstation" -Status "valid"
    $servers = Search-RedmineDB -Field type -Keyword "Server" -Status "valid"
    $laptops = Search-RedmineDB -Field type -Keyword "Laptop" -Status "valid"
    
    $exportExcelPath = "$ExamplesDir\equipment_export.xlsx"
    
    # Export workstations with formatting
    if ($workstations.Count -gt 0) {
        $workstationData = $workstations | ForEach-Object {
            $entry = $_
            [PSCustomObject]@{
                Id              = $entry.Id
                Name            = $entry.Name
                Type            = $entry.Type.name
                Status          = $entry.Status
                SystemMake      = ($entry.CustomFields | Where-Object {$_.name -like '*make*'}).value
                SystemModel     = ($entry.CustomFields | Where-Object {$_.name -like '*model*'}).value
                Memory          = ($entry.CustomFields | Where-Object {$_.name -like '*memory*'}).value
                SerialNumber    = ($entry.CustomFields | Where-Object {$_.name -like '*serial*'}).value
                Building        = ($entry.CustomFields | Where-Object {$_.name -like '*building*'}).value
                LastUpdated     = $entry.UpdatedOn
            }
        }
        
        $workstationData | Export-Excel -Path $exportExcelPath -WorksheetName "Workstations" `
            -AutoSize -BoldTopRow -FreezeTopRow `
            -ConditionalText $(
                New-ConditionalText -Text "valid" -BackgroundColor LightGreen
                New-ConditionalText -Text "invalid" -BackgroundColor LightCoral
            )
    }
    
    # Export servers with different formatting
    if ($servers.Count -gt 0) {
        $serverData = $servers | ForEach-Object {
            $entry = $_
            [PSCustomObject]@{
                Id              = $entry.Id
                Name            = $entry.Name
                Type            = $entry.Type.name
                Status          = $entry.Status
                SystemMake      = ($entry.CustomFields | Where-Object {$_.name -like '*make*'}).value
                SystemModel     = ($entry.CustomFields | Where-Object {$_.name -like '*model*'}).value
                Memory          = ($entry.CustomFields | Where-Object {$_.name -like '*memory*'}).value
                HardDriveSize   = ($entry.CustomFields | Where-Object {$_.name -like '*drive*'}).value
                State           = ($entry.CustomFields | Where-Object {$_.name -like '*state*'}).value
                LastUpdated     = $entry.UpdatedOn
            }
        }
        
        $serverData | Export-Excel -Path $exportExcelPath -WorksheetName "Servers" `
            -AutoSize -BoldTopRow -FreezeTopRow `
            -ConditionalText $(
                New-ConditionalText -Text "HPE" -BackgroundColor LightBlue
                New-ConditionalText -Text "Dell" -BackgroundColor LightYellow
            )
    }
    
    # Export laptops
    if ($laptops.Count -gt 0) {
        $laptopData = $laptops | ForEach-Object {
            $entry = $_
            [PSCustomObject]@{
                Id              = $entry.Id
                Name            = $entry.Name
                Status          = $entry.Status
                SystemMake      = ($entry.CustomFields | Where-Object {$_.name -like '*make*'}).value
                SystemModel     = ($entry.CustomFields | Where-Object {$_.name -like '*model*'}).value
                SerialNumber    = ($entry.CustomFields | Where-Object {$_.name -like '*serial*'}).value
                LastUpdated     = $entry.UpdatedOn
            }
        }
        
        $laptopData | Export-Excel -Path $exportExcelPath -WorksheetName "Laptops" `
            -AutoSize -BoldTopRow -FreezeTopRow
    }
    
    Write-Host "✓ Exported equipment data to: $exportExcelPath" -ForegroundColor Green
    Write-Host "  - Workstations: $($workstations.Count) entries" -ForegroundColor Gray
    Write-Host "  - Servers: $($servers.Count) entries" -ForegroundColor Gray
    Write-Host "  - Laptops: $($laptops.Count) entries" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to export to Excel: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 4: Use Edit-RedmineDBXL function for bulk updates
Write-Host "`n4. Using Edit-RedmineDBXL for bulk updates..." -ForegroundColor Yellow

try {
    # Create update Excel file
    $updateData = @(
        [PSCustomObject]@{
            Name        = "XL-IMPORT-001"
            Memory      = "64GB DDR5"
            Notes       = "Memory upgraded via Excel bulk update"
            RefreshDate = (Get-Date).ToString("yyyy-MM-dd")
        },
        [PSCustomObject]@{
            Name        = "XL-IMPORT-002"
            HardDriveSize = "4TB SSD"
            Notes       = "Storage upgraded via Excel bulk update"
            RefreshDate = (Get-Date).ToString("yyyy-MM-dd")
        }
    )
    
    $updateExcelPath = "$ExamplesDir\bulk_update.xlsx"
    $updateData | Export-Excel -Path $updateExcelPath -WorksheetName "Updates" -AutoSize -BoldTopRow
    
    Write-Host "✓ Created bulk update Excel file: $updateExcelPath" -ForegroundColor Green
    
    # Use Edit-RedmineDBXL to perform bulk updates
    # Note: This function may require the entries to exist and proper column mapping
    # Edit-RedmineDBXL -Path $updateExcelPath -WhatIf
    Write-Host "✓ Bulk update file ready for Edit-RedmineDBXL function" -ForegroundColor Green
    Write-Host "  Use: Edit-RedmineDBXL -Path '$updateExcelPath' -WhatIf" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Failed to create bulk update Excel: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 5: Advanced Excel operations with charts and pivot tables
Write-Host "`n5. Creating advanced Excel reports with charts..." -ForegroundColor Yellow

try {
    # Get comprehensive data for reporting
    $allEntries = Search-RedmineDB -Keyword "*" -Status "*"
    
    if ($allEntries.Count -gt 0) {
        # Prepare data for analysis
        $analysisData = $allEntries | ForEach-Object {
            $entry = $_
            [PSCustomObject]@{
                Id          = $entry.Id
                Name        = $entry.Name
                Type        = $entry.Type.name
                Status      = $entry.Status
                Make        = ($entry.CustomFields | Where-Object {$_.name -like '*make*'}).value
                State       = ($entry.CustomFields | Where-Object {$_.name -like '*state*'}).value
                CreatedYear = if ($entry.CreatedOn) { (Get-Date $entry.CreatedOn).Year } else { (Get-Date).Year }
                HasMemory   = -not [string]::IsNullOrEmpty(($entry.CustomFields | Where-Object {$_.name -like '*memory*'}).value)
                HasSerial   = -not [string]::IsNullOrEmpty(($entry.CustomFields | Where-Object {$_.name -like '*serial*'}).value)
            }
        }
        
        $reportsExcelPath = "$ExamplesDir\advanced_reports.xlsx"
        
        # Main data sheet
        $analysisData | Export-Excel -Path $reportsExcelPath -WorksheetName "All_Equipment" `
            -AutoSize -BoldTopRow -FreezeTopRow `
            -ConditionalText $(
                New-ConditionalText -Text "valid" -BackgroundColor LightGreen
                New-ConditionalText -Text "invalid" -BackgroundColor LightCoral
                New-ConditionalText -Text "to verify" -BackgroundColor LightYellow
            )
        
        # Summary statistics
        $typeStats = $analysisData | Group-Object Type | ForEach-Object {
            [PSCustomObject]@{
                Type  = $_.Name
                Count = $_.Count
                ValidCount = ($_.Group | Where-Object {$_.Status -eq "valid"}).Count
                InvalidCount = ($_.Group | Where-Object {$_.Status -eq "invalid"}).Count
            }
        }
        
        $typeStats | Export-Excel -Path $reportsExcelPath -WorksheetName "Type_Summary" `
            -AutoSize -BoldTopRow `
            -IncludePivotChart -PivotChartType ColumnClustered `
            -PivotRows Type -PivotData Count
        
        # Manufacturer analysis
        $makeStats = $analysisData | Where-Object {$_.Make} | Group-Object Make | ForEach-Object {
            [PSCustomObject]@{
                Manufacturer = $_.Name
                Count        = $_.Count
                Types        = ($_.Group | Group-Object Type | ForEach-Object { $_.Name }) -join ", "
            }
        }
        
        if ($makeStats.Count -gt 0) {
            $makeStats | Export-Excel -Path $reportsExcelPath -WorksheetName "Manufacturer_Analysis" `
                -AutoSize -BoldTopRow `
                -IncludePivotChart -PivotChartType Pie `
                -PivotRows Manufacturer -PivotData Count
        }
        
        # Data quality report
        $qualityData = @(
            [PSCustomObject]@{
                Metric = "Total Entries"
                Count  = $analysisData.Count
                Percentage = 100
            },
            [PSCustomObject]@{
                Metric = "Entries with Memory Info"
                Count  = ($analysisData | Where-Object {$_.HasMemory}).Count
                Percentage = [math]::Round((($analysisData | Where-Object {$_.HasMemory}).Count / $analysisData.Count) * 100, 2)
            },
            [PSCustomObject]@{
                Metric = "Entries with Serial Numbers"
                Count  = ($analysisData | Where-Object {$_.HasSerial}).Count
                Percentage = [math]::Round((($analysisData | Where-Object {$_.HasSerial}).Count / $analysisData.Count) * 100, 2)
            },
            [PSCustomObject]@{
                Metric = "Valid Status"
                Count  = ($analysisData | Where-Object {$_.Status -eq "valid"}).Count
                Percentage = [math]::Round((($analysisData | Where-Object {$_.Status -eq "valid"}).Count / $analysisData.Count) * 100, 2)
            }
        )
        
        $qualityData | Export-Excel -Path $reportsExcelPath -WorksheetName "Data_Quality" `
            -AutoSize -BoldTopRow `
            -IncludePivotChart -PivotChartType ColumnClustered `
            -PivotRows Metric -PivotData Percentage
        
        Write-Host "✓ Created advanced Excel reports: $reportsExcelPath" -ForegroundColor Green
        Write-Host "  - All_Equipment: Complete dataset with conditional formatting" -ForegroundColor Gray
        Write-Host "  - Type_Summary: Equipment type statistics with chart" -ForegroundColor Gray
        Write-Host "  - Manufacturer_Analysis: Vendor analysis with pie chart" -ForegroundColor Gray
        Write-Host "  - Data_Quality: Data completeness metrics with chart" -ForegroundColor Gray
    }
    else {
        Write-Host "⚠ No entries found for advanced reporting" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to create advanced Excel reports: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 6: Excel template creation for data entry
Write-Host "`n6. Creating Excel templates for data entry..." -ForegroundColor Yellow

try {
    $templatePath = "$ExamplesDir\data_entry_template.xlsx"
    
    # Create template with sample data and data validation
    $templateData = @(
        [PSCustomObject]@{
            Name            = "TEMPLATE-001"
            Type            = "Workstation"
            Status          = "valid"
            Description     = "Sample entry - replace with actual data"
            SystemMake      = "Dell"
            SystemModel     = "OptiPlex 7090"
            OperatingSystem = "Windows 11"
            SerialNumber    = "SAMPLE123456"
            Memory          = "16GB"
            HardDriveSize   = "512GB SSD"
            State           = "TX"
            Building        = "Main Campus"
            Room            = "Office 101"
            Programs        = "IT;General"
            Notes           = "Template entry for reference"
        }
    )
    
    # Create instructions sheet
    $instructions = @(
        [PSCustomObject]@{
            Column      = "Name"
            Required    = "Yes"
            Format      = "Alphanumeric, unique identifier"
            Example     = "WS-001234, LAPTOP-5678"
            Notes       = "Must be unique across the database"
        },
        [PSCustomObject]@{
            Column      = "Type"
            Required    = "Yes"
            Format      = "Predefined values"
            Example     = "Workstation, Laptop, Server, Network Equipment"
            Notes       = "Select from available types in Redmine"
        },
        [PSCustomObject]@{
            Column      = "Status"
            Required    = "Yes"
            Format      = "valid, invalid, to verify"
            Example     = "valid"
            Notes       = "Equipment operational status"
        },
        [PSCustomObject]@{
            Column      = "Programs"
            Required    = "No"
            Format      = "Semicolon separated"
            Example     = "P123;P456;Development"
            Notes       = "Multiple programs separated by semicolons"
        }
    )
    
    # Export template with instructions
    $templateData | Export-Excel -Path $templatePath -WorksheetName "Data_Entry" `
        -AutoSize -BoldTopRow -FreezeTopRow
        
    $instructions | Export-Excel -Path $templatePath -WorksheetName "Instructions" `
        -AutoSize -BoldTopRow -FreezeTopRow
    
    # Create validation reference
    $validationReference = @(
        [PSCustomObject]@{
            Field       = "Type"
            ValidValues = "Workstation;Laptop;Server;Network Equipment;Storage;Mobile Device"
        },
        [PSCustomObject]@{
            Field       = "Status"
            ValidValues = "valid;invalid;to verify"
        },
        [PSCustomObject]@{
            Field       = "State"
            ValidValues = "AL;AK;AZ;AR;CA;CO;CT;DE;FL;GA;HI;ID;IL;IN;IA;KS;KY;LA;ME;MD;MA;MI;MN;MS;MO;MT;NE;NV;NH;NJ;NM;NY;NC;ND;OH;OK;OR;PA;RI;SC;SD;TN;TX;UT;VT;VA;WA;WV;WI;WY"
        }
    )
    
    $validationReference | Export-Excel -Path $templatePath -WorksheetName "Valid_Values" `
        -AutoSize -BoldTopRow
    
    Write-Host "✓ Created data entry template: $templatePath" -ForegroundColor Green
    Write-Host "  - Data_Entry: Template with sample data" -ForegroundColor Gray
    Write-Host "  - Instructions: Field descriptions and requirements" -ForegroundColor Gray
    Write-Host "  - Valid_Values: Reference for dropdown values" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to create data entry template: $($_.Exception.Message)" -ForegroundColor Red
}

# Example 7: Excel data validation and error reporting
Write-Host "`n7. Excel data validation and error reporting..." -ForegroundColor Yellow

try {
    # Create test data with some errors for validation
    $testValidationData = @(
        [PSCustomObject]@{
            Name   = "VALID-TEST-001"
            Type   = "Workstation"
            Status = "valid"
            State  = "TX"
        },
        [PSCustomObject]@{
            Name   = ""  # Error: empty name
            Type   = "Laptop"
            Status = "valid"
            State  = "CA"
        },
        [PSCustomObject]@{
            Name   = "INVALID-TEST-002"
            Type   = "InvalidType"  # Error: invalid type
            Status = "valid"
            State  = "FL"
        },
        [PSCustomObject]@{
            Name   = "INVALID-TEST-003"
            Type   = "Server"
            Status = "valid"
            State  = "ZZ"  # Error: invalid state
        }
    )
    
    $validationTestPath = "$ExamplesDir\validation_test.xlsx"
    $testValidationData | Export-Excel -Path $validationTestPath -WorksheetName "Test_Data" -AutoSize -BoldTopRow
    
    # Perform validation
    $validationResults = @()
    $rowNumber = 2  # Start after header
    
    foreach ($row in $testValidationData) {
        $errors = @()
        
        if ([string]::IsNullOrWhiteSpace($row.Name)) {
            $errors += "Name is required"
        }
        
        $validTypes = @("Workstation", "Laptop", "Server", "Network Equipment", "Storage", "Mobile Device")
        if ($row.Type -notin $validTypes) {
            $errors += "Invalid Type: $($row.Type)"
        }
        
        $validStates = @("AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY")
        if ($row.State -and $row.State -notin $validStates) {
            $errors += "Invalid State: $($row.State)"
        }
        
        $validationResults += [PSCustomObject]@{
            Row    = $rowNumber
            Name   = $row.Name
            Valid  = $errors.Count -eq 0
            Errors = $errors -join "; "
        }
        
        $rowNumber++
    }
    
    # Export validation results
    $validationResults | Export-Excel -Path $validationTestPath -WorksheetName "Validation_Results" `
        -AutoSize -BoldTopRow `
        -ConditionalText $(
            New-ConditionalText -Text "True" -BackgroundColor LightGreen
            New-ConditionalText -Text "False" -BackgroundColor LightCoral
        )
    
    $validCount = ($validationResults | Where-Object {$_.Valid}).Count
    $invalidCount = ($validationResults | Where-Object {-not $_.Valid}).Count
    
    Write-Host "✓ Excel validation complete: $validCount valid, $invalidCount invalid" -ForegroundColor Green
    Write-Host "✓ Validation results saved to: $validationTestPath" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed Excel validation: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Excel CRUD Examples Complete ===" -ForegroundColor Green
Write-Host "Excel files created in Examples directory:" -ForegroundColor Cyan
Write-Host "  - import_sample.xlsx (sample import data with multiple sheets)" -ForegroundColor Gray
Write-Host "  - equipment_export.xlsx (exported equipment with formatting)" -ForegroundColor Gray
Write-Host "  - bulk_update.xlsx (template for Edit-RedmineDBXL)" -ForegroundColor Gray
Write-Host "  - advanced_reports.xlsx (comprehensive reports with charts)" -ForegroundColor Gray
Write-Host "  - data_entry_template.xlsx (template for new data entry)" -ForegroundColor Gray
Write-Host "  - validation_test.xlsx (validation examples and results)" -ForegroundColor Gray

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Review the Excel files for formatting and data structure" -ForegroundColor White
Write-Host "2. Use Edit-RedmineDBXL with the bulk_update.xlsx file" -ForegroundColor White
Write-Host "3. Customize templates for your specific use cases" -ForegroundColor White
Write-Host "4. Implement data validation rules in your Excel workflows" -ForegroundColor White
