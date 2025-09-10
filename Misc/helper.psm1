<#
    ===========================================================================
     Module Name:       helper.psm1
     Created with:      PowerShell
     Created on:        2025-09-09
     Created by:        Jason Hickey
     Organization:      House of Powershell
     Filename:          helper.psm1
     Description:       Helper functions for Excel (XLSX) and CSV operations
     Version:           1.0.0
    -------------------------------------------------------------------------
     Copyright (c) 2025 Jason Hickey. All rights reserved.
     Licensed under the MIT License.
    ===========================================================================
#>

#Requires -Version 5.1

#region XLSX Helper Functions

<#
.SYNOPSIS
    Imports data from an Excel (XLSX) file with advanced options.

.DESCRIPTION
    This function provides comprehensive Excel import capabilities with support for
    worksheets, headers, data validation, and error handling.

.PARAMETER Path
    The path to the Excel file to import.

.PARAMETER WorksheetName
    The name of the worksheet to import. If not specified, imports the first worksheet.

.PARAMETER WorksheetIndex
    The index (1-based) of the worksheet to import. Alternative to WorksheetName.

.PARAMETER StartRow
    The row number to start importing from. Default is 1.

.PARAMETER StartColumn
    The column number to start importing from. Default is 1.

.PARAMETER EndRow
    The last row to import. If not specified, imports all rows with data.

.PARAMETER EndColumn
    The last column to import. If not specified, imports all columns with data.

.PARAMETER HeaderRow
    The row number containing headers. Default is 1.

.PARAMETER NoHeader
    Skip header row processing and use default column names.

.PARAMETER AsDataTable
    Return results as a System.Data.DataTable instead of PowerShell objects.

.EXAMPLE
    Import-ExcelData -Path "C:\data\report.xlsx"
    
    Imports all data from the first worksheet.

.EXAMPLE
    Import-ExcelData -Path "C:\data\report.xlsx" -WorksheetName "Summary" -StartRow 2
    
    Imports data from the "Summary" worksheet starting from row 2.

.EXAMPLE
    Import-ExcelData -Path "C:\data\report.xlsx" -HeaderRow 3 -StartRow 4
    
    Uses row 3 as headers and starts data import from row 4.
#>
function Import-ExcelData {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            if ($_ -notmatch '\.(xlsx|xls)$') {
                throw "File must be an Excel file (.xlsx or .xls): $_"
            }
            return $true
        })]
        [string]$Path,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$WorksheetName,

        [Parameter(ParameterSetName = 'ByIndex')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$WorksheetIndex = 1,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$StartRow = 1,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$StartColumn = 1,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$EndRow,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$EndColumn,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$HeaderRow = 1,

        [Parameter()]
        [switch]$NoHeader,

        [Parameter()]
        [switch]$AsDataTable
    )

    try {
        Write-Verbose "Opening Excel file: $Path"
        
        # Create Excel application
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        try {
            $workbook = $excel.Workbooks.Open($Path)
            
            # Select worksheet
            if ($PSCmdlet.ParameterSetName -eq 'ByName' -and $WorksheetName) {
                $worksheet = $workbook.Worksheets | Where-Object { $_.Name -eq $WorksheetName }
                if (-not $worksheet) {
                    throw "Worksheet '$WorksheetName' not found"
                }
            } else {
                if ($WorksheetIndex -gt $workbook.Worksheets.Count) {
                    throw "Worksheet index $WorksheetIndex exceeds available worksheets ($($workbook.Worksheets.Count))"
                }
                $worksheet = $workbook.Worksheets.Item($WorksheetIndex)
            }
            
            Write-Verbose "Using worksheet: $($worksheet.Name)"
            
            # Get used range
            $usedRange = $worksheet.UsedRange
            if (-not $usedRange) {
                Write-Warning "No data found in worksheet"
                return @()
            }
            
            # Determine actual end row/column if not specified
            if (-not $EndRow) { $EndRow = $usedRange.Rows.Count }
            if (-not $EndColumn) { $EndColumn = $usedRange.Columns.Count }
            
            # Validate ranges
            if ($StartRow -gt $EndRow) {
                throw "StartRow ($StartRow) cannot be greater than EndRow ($EndRow)"
            }
            if ($StartColumn -gt $EndColumn) {
                throw "StartColumn ($StartColumn) cannot be greater than EndColumn ($EndColumn)"
            }
            
            # Get headers
            $headers = @()
            if (-not $NoHeader) {
                for ($col = $StartColumn; $col -le $EndColumn; $col++) {
                    $headerValue = $worksheet.Cells.Item($HeaderRow, $col).Text
                    if ([string]::IsNullOrWhiteSpace($headerValue)) {
                        $headerValue = "Column$col"
                    }
                    $headers += $headerValue.Trim()
                }
            } else {
                for ($col = $StartColumn; $col -le $EndColumn; $col++) {
                    $headers += "Column$col"
                }
            }
            
            # Import data
            $data = @()
            $dataStartRow = if ($NoHeader) { $StartRow } else { [Math]::Max($StartRow, $HeaderRow + 1) }
            
            for ($row = $dataStartRow; $row -le $EndRow; $row++) {
                $rowData = [ordered]@{}
                $hasData = $false
                
                for ($col = $StartColumn; $col -le $EndColumn; $col++) {
                    $cellValue = $worksheet.Cells.Item($row, $col).Text
                    $headerIndex = $col - $StartColumn
                    $rowData[$headers[$headerIndex]] = $cellValue
                    
                    if (-not [string]::IsNullOrWhiteSpace($cellValue)) {
                        $hasData = $true
                    }
                }
                
                if ($hasData) {
                    $data += New-Object PSObject -Property $rowData
                }
            }
            
            Write-Verbose "Imported $($data.Count) rows from Excel file"
            return $data
            
        } finally {
            if ($workbook) { $workbook.Close($false) }
        }
        
    } catch {
        Write-Error "Failed to import Excel data: $($_.Exception.Message)"
        throw
    } finally {
        if ($excel) {
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        }
        [System.GC]::Collect()
    }
}

<#
.SYNOPSIS
    Exports data to an Excel (XLSX) file with formatting options.

.DESCRIPTION
    This function exports PowerShell objects to Excel with support for multiple
    worksheets, formatting, and advanced Excel features.

.PARAMETER Data
    The data to export (array of objects).

.PARAMETER Path
    The output path for the Excel file.

.PARAMETER WorksheetName
    The name of the worksheet. Default is "Sheet1".

.PARAMETER AutoFit
    Automatically adjust column widths to fit content.

.PARAMETER FreezeTopRow
    Freeze the top row (header row).

.PARAMETER TableStyle
    Apply an Excel table style. Options include Light, Medium, Dark styles.

.PARAMETER ShowGridLines
    Show or hide gridlines. Default is $true.

.PARAMETER Append
    Append to existing file instead of overwriting.

.PARAMETER PassThru
    Return the data that was exported.

.EXAMPLE
    $data | Export-ExcelData -Path "C:\output\report.xlsx" -AutoFit -FreezeTopRow
    
    Exports data with auto-fitted columns and frozen header row.

.EXAMPLE
    Export-ExcelData -Data $users -Path "C:\reports\users.xlsx" -WorksheetName "UserList" -TableStyle "Medium2"
    
    Exports user data with medium table styling.
#>
function Export-ExcelData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$WorksheetName = "Sheet1",

        [Parameter()]
        [switch]$AutoFit,

        [Parameter()]
        [switch]$FreezeTopRow,

        [Parameter()]
        [ValidateSet('Light1', 'Light2', 'Light3', 'Medium1', 'Medium2', 'Medium3', 'Dark1', 'Dark2', 'Dark3')]
        [string]$TableStyle,

        [Parameter()]
        [bool]$ShowGridLines = $true,

        [Parameter()]
        [switch]$Append,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        $allData = @()
    }

    process {
        $allData += $Data
    }

    end {
        if ($allData.Count -eq 0) {
            Write-Warning "No data to export"
            return
        }

        try {
            Write-Verbose "Exporting $($allData.Count) objects to Excel file: $Path"
            
            # Ensure directory exists
            $directory = Split-Path -Path $Path -Parent
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            
            # Create Excel application
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $excel.DisplayAlerts = $false
            
            try {
                # Create or open workbook
                if ($Append -and (Test-Path $Path)) {
                    $workbook = $excel.Workbooks.Open($Path)
                } else {
                    $workbook = $excel.Workbooks.Add()
                }
                
                # Get or create worksheet
                $worksheet = $null
                if ($Append) {
                    $worksheet = $workbook.Worksheets | Where-Object { $_.Name -eq $WorksheetName }
                }
                
                if (-not $worksheet) {
                    if ($workbook.Worksheets.Count -eq 1 -and $workbook.Worksheets.Item(1).Name -like "Sheet*") {
                        $worksheet = $workbook.Worksheets.Item(1)
                        $worksheet.Name = $WorksheetName
                    } else {
                        $worksheet = $workbook.Worksheets.Add()
                        $worksheet.Name = $WorksheetName
                    }
                }
                
                # Get properties from first object
                $properties = $allData[0].PSObject.Properties.Name
                
                # Write headers
                for ($col = 1; $col -le $properties.Count; $col++) {
                    $worksheet.Cells.Item(1, $col) = $properties[$col - 1]
                    $worksheet.Cells.Item(1, $col).Font.Bold = $true
                }
                
                # Write data
                for ($row = 0; $row -lt $allData.Count; $row++) {
                    for ($col = 1; $col -le $properties.Count; $col++) {
                        $value = $allData[$row].($properties[$col - 1])
                        if ($value -ne $null) {
                            $worksheet.Cells.Item($row + 2, $col) = $value.ToString()
                        }
                    }
                }
                
                # Apply formatting
                if ($AutoFit) {
                    $worksheet.Columns.AutoFit() | Out-Null
                }
                
                if ($FreezeTopRow) {
                    $worksheet.Rows.Item(2).Select() | Out-Null
                    $excel.ActiveWindow.FreezePanes = $true
                }
                
                if ($TableStyle) {
                    try {
                        $range = $worksheet.Range("A1").Resize($allData.Count + 1, $properties.Count)
                        $table = $worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $range, $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
                        $table.TableStyle = "TableStyle$TableStyle"
                    } catch {
                        Write-Warning "Could not apply table style: $($_.Exception.Message)"
                    }
                }
                
                $worksheet.Cells.Item(1, 1).Select() | Out-Null
                
                # Show/hide gridlines
                $excel.ActiveWindow.DisplayGridlines = $ShowGridLines
                
                # Save file
                if ($Path.EndsWith('.xlsx')) {
                    $workbook.SaveAs($Path, [Microsoft.Office.Interop.Excel.XlFileFormat]::xlOpenXMLWorkbook)
                } else {
                    $workbook.SaveAs($Path)
                }
                
                Write-Verbose "Successfully exported data to $Path"
                
            } finally {
                if ($workbook) { $workbook.Close($false) }
            }
            
        } catch {
            Write-Error "Failed to export Excel data: $($_.Exception.Message)"
            throw
        } finally {
            if ($excel) {
                $excel.Quit()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
            }
            [System.GC]::Collect()
        }
        
        if ($PassThru) {
            return $allData
        }
    }
}

#endregion

#region CSV Helper Functions

<#
.SYNOPSIS
    Imports CSV data with advanced parsing and validation options.

.DESCRIPTION
    Enhanced CSV import function with support for custom delimiters, encoding,
    data validation, and error handling.

.PARAMETER Path
    The path to the CSV file to import.

.PARAMETER Delimiter
    The field delimiter. Default is comma (,).

.PARAMETER Encoding
    The file encoding. Default is UTF8.

.PARAMETER Header
    Custom header names. If not specified, uses first row as headers.

.PARAMETER SkipRows
    Number of rows to skip at the beginning of the file.

.PARAMETER MaxRows
    Maximum number of data rows to import.

.PARAMETER ValidateHeaders
    Validate that all specified headers exist in the file.

.PARAMETER TrimWhitespace
    Trim leading and trailing whitespace from all values.

.PARAMETER EmptyStringAsNull
    Treat empty strings as null values.

.EXAMPLE
    Import-CsvData -Path "C:\data\report.csv" -TrimWhitespace
    
    Imports CSV with whitespace trimming.

.EXAMPLE
    Import-CsvData -Path "C:\data\report.csv" -Delimiter ";" -Encoding "UTF8"
    
    Imports CSV with semicolon delimiter and UTF8 encoding.

.EXAMPLE
    Import-CsvData -Path "C:\data\report.csv" -Header @("Name", "Email", "Department") -ValidateHeaders
    
    Imports CSV with custom headers and validation.
#>
function Import-CsvData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            return $true
        })]
        [string]$Path,

        [Parameter()]
        [string]$Delimiter = ',',

        [Parameter()]
        [ValidateSet('UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32', 'Unicode', 'ASCII', 'Default')]
        [string]$Encoding = 'UTF8',

        [Parameter()]
        [string[]]$Header,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$SkipRows = 0,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxRows,

        [Parameter()]
        [switch]$ValidateHeaders,

        [Parameter()]
        [switch]$TrimWhitespace,

        [Parameter()]
        [switch]$EmptyStringAsNull
    )

    try {
        Write-Verbose "Importing CSV file: $Path"
        
        # Read file content
        $importParams = @{
            Path = $Path
            Delimiter = $Delimiter
            Encoding = $Encoding
        }
        
        if ($Header) {
            $importParams.Header = $Header
        }
        
        # Import base data
        $rawData = Import-Csv @importParams
        
        # Skip rows if specified
        if ($SkipRows -gt 0) {
            $rawData = $rawData | Select-Object -Skip $SkipRows
        }
        
        # Limit rows if specified
        if ($MaxRows) {
            $rawData = $rawData | Select-Object -First $MaxRows
        }
        
        # Validate headers if requested
        if ($ValidateHeaders -and $Header) {
            $actualHeaders = $rawData[0].PSObject.Properties.Name
            $missingHeaders = $Header | Where-Object { $_ -notin $actualHeaders }
            if ($missingHeaders) {
                throw "Missing headers in CSV file: $($missingHeaders -join ', ')"
            }
        }
        
        # Process data
        $processedData = @()
        foreach ($row in $rawData) {
            $newRow = [ordered]@{}
            
            foreach ($property in $row.PSObject.Properties) {
                $value = $property.Value
                
                # Trim whitespace if requested
                if ($TrimWhitespace -and $value -is [string]) {
                    $value = $value.Trim()
                }
                
                # Convert empty strings to null if requested
                if ($EmptyStringAsNull -and $value -eq '') {
                    $value = $null
                }
                
                $newRow[$property.Name] = $value
            }
            
            $processedData += New-Object PSObject -Property $newRow
        }
        
        Write-Verbose "Successfully imported $($processedData.Count) rows from CSV"
        return $processedData
        
    } catch {
        Write-Error "Failed to import CSV data: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Exports data to CSV with advanced formatting options.

.DESCRIPTION
    Enhanced CSV export function with support for custom formatting,
    encoding, and data transformation options.

.PARAMETER Data
    The data to export (array of objects).

.PARAMETER Path
    The output path for the CSV file.

.PARAMETER Delimiter
    The field delimiter. Default is comma (,).

.PARAMETER Encoding
    The file encoding. Default is UTF8.

.PARAMETER NoTypeInformation
    Exclude type information from the output.

.PARAMETER IncludeHeaders
    Include header row in the output. Default is $true.

.PARAMETER Properties
    Specific properties to export. If not specified, exports all properties.

.PARAMETER SortBy
    Property name to sort the data by before export.

.PARAMETER Append
    Append to existing file instead of overwriting.

.PARAMETER PassThru
    Return the data that was exported.

.PARAMETER QuoteAll
    Quote all fields regardless of content.

.EXAMPLE
    $data | Export-CsvData -Path "C:\output\report.csv" -Delimiter ";" -NoTypeInformation
    
    Exports data with semicolon delimiter and no type information.

.EXAMPLE
    Export-CsvData -Data $users -Path "C:\reports\users.csv" -Properties @("Name", "Email") -SortBy "Name"
    
    Exports specific properties sorted by name.
#>
function Export-CsvData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$Delimiter = ',',

        [Parameter()]
        [ValidateSet('UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32', 'Unicode', 'ASCII', 'Default')]
        [string]$Encoding = 'UTF8',

        [Parameter()]
        [switch]$NoTypeInformation,

        [Parameter()]
        [bool]$IncludeHeaders = $true,

        [Parameter()]
        [string[]]$Properties,

        [Parameter()]
        [string]$SortBy,

        [Parameter()]
        [switch]$Append,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$QuoteAll
    )

    begin {
        $allData = @()
    }

    process {
        $allData += $Data
    }

    end {
        if ($allData.Count -eq 0) {
            Write-Warning "No data to export"
            return
        }

        try {
            Write-Verbose "Exporting $($allData.Count) objects to CSV file: $Path"
            
            # Ensure directory exists
            $directory = Split-Path -Path $Path -Parent
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            
            # Select specific properties if specified
            if ($Properties) {
                $allData = $allData | Select-Object -Property $Properties
            }
            
            # Sort data if requested
            if ($SortBy) {
                $allData = $allData | Sort-Object -Property $SortBy
            }
            
            # Prepare export parameters
            $exportParams = @{
                Path = $Path
                Delimiter = $Delimiter
                Encoding = $Encoding
                NoTypeInformation = $NoTypeInformation
            }
            
            if (-not $IncludeHeaders) {
                # Custom implementation needed for no headers
                $csv = $allData | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation
                if ($csv.Count -gt 1) {
                    $csv = $csv[1..($csv.Count - 1)]  # Skip header row
                }
                $csv | Out-File -FilePath $Path -Encoding $Encoding -Append:$Append
            } else {
                if ($Append) {
                    $allData | Export-Csv @exportParams -Append
                } else {
                    $allData | Export-Csv @exportParams
                }
            }
            
            Write-Verbose "Successfully exported data to $Path"
            
        } catch {
            Write-Error "Failed to export CSV data: $($_.Exception.Message)"
            throw
        }
        
        if ($PassThru) {
            return $allData
        }
    }
}

<#
.SYNOPSIS
    Compares two CSV files and returns differences.

.DESCRIPTION
    Compares data between two CSV files and identifies additions, deletions,
    and modifications.

.PARAMETER ReferencePath
    Path to the reference (baseline) CSV file.

.PARAMETER DifferencePath
    Path to the difference (comparison) CSV file.

.PARAMETER KeyProperty
    Property name to use as unique identifier for comparison.

.PARAMETER IncludeEqual
    Include rows that are equal in both files.

.PARAMETER Delimiter
    Field delimiter for both files. Default is comma.

.EXAMPLE
    Compare-CsvData -ReferencePath "old.csv" -DifferencePath "new.csv" -KeyProperty "ID"
    
    Compares CSV files using ID as the key property.
#>
function Compare-CsvData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ReferencePath,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$DifferencePath,

        [Parameter(Mandatory = $true)]
        [string]$KeyProperty,

        [Parameter()]
        [switch]$IncludeEqual,

        [Parameter()]
        [string]$Delimiter = ','
    )

    try {
        Write-Verbose "Comparing CSV files: $ReferencePath vs $DifferencePath"
        
        # Import both files
        $referenceData = Import-Csv -Path $ReferencePath -Delimiter $Delimiter
        $differenceData = Import-Csv -Path $DifferencePath -Delimiter $Delimiter
        
        # Validate key property exists
        if ($KeyProperty -notin $referenceData[0].PSObject.Properties.Name) {
            throw "Key property '$KeyProperty' not found in reference file"
        }
        if ($KeyProperty -notin $differenceData[0].PSObject.Properties.Name) {
            throw "Key property '$KeyProperty' not found in difference file"
        }
        
        # Create lookup hashtables
        $refLookup = @{}
        $referenceData | ForEach-Object { $refLookup[$_.($KeyProperty)] = $_ }
        
        $diffLookup = @{}
        $differenceData | ForEach-Object { $diffLookup[$_.($KeyProperty)] = $_ }
        
        $results = @()
        
        # Check for additions and modifications
        foreach ($key in $diffLookup.Keys) {
            if ($refLookup.ContainsKey($key)) {
                # Compare objects
                $refObj = $refLookup[$key]
                $diffObj = $diffLookup[$key]
                
                $comparison = Compare-Object -ReferenceObject $refObj -DifferenceObject $diffObj
                if ($comparison) {
                    $results += [PSCustomObject]@{
                        Key = $key
                        ChangeType = 'Modified'
                        ReferenceObject = $refObj
                        DifferenceObject = $diffObj
                    }
                } elseif ($IncludeEqual) {
                    $results += [PSCustomObject]@{
                        Key = $key
                        ChangeType = 'Equal'
                        ReferenceObject = $refObj
                        DifferenceObject = $diffObj
                    }
                }
            } else {
                $results += [PSCustomObject]@{
                    Key = $key
                    ChangeType = 'Added'
                    ReferenceObject = $null
                    DifferenceObject = $diffLookup[$key]
                }
            }
        }
        
        # Check for deletions
        foreach ($key in $refLookup.Keys) {
            if (-not $diffLookup.ContainsKey($key)) {
                $results += [PSCustomObject]@{
                    Key = $key
                    ChangeType = 'Deleted'
                    ReferenceObject = $refLookup[$key]
                    DifferenceObject = $null
                }
            }
        }
        
        Write-Verbose "Comparison complete. Found $($results.Count) differences"
        return $results
        
    } catch {
        Write-Error "Failed to compare CSV data: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Utility Functions

<#
.SYNOPSIS
    Converts CSV data to Excel format.

.DESCRIPTION
    Converts an existing CSV file to Excel format with optional formatting.

.PARAMETER CsvPath
    Path to the source CSV file.

.PARAMETER ExcelPath
    Path for the output Excel file.

.PARAMETER Delimiter
    CSV delimiter. Default is comma.

.PARAMETER WorksheetName
    Name for the Excel worksheet. Default is "Data".

.PARAMETER AutoFit
    Auto-fit column widths.

.PARAMETER TableStyle
    Apply Excel table styling.

.EXAMPLE
    ConvertTo-Excel -CsvPath "data.csv" -ExcelPath "data.xlsx" -AutoFit -TableStyle "Medium2"
#>
function ConvertTo-Excel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$CsvPath,

        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,

        [Parameter()]
        [string]$Delimiter = ',',

        [Parameter()]
        [string]$WorksheetName = 'Data',

        [Parameter()]
        [switch]$AutoFit,

        [Parameter()]
        [ValidateSet('Light1', 'Light2', 'Light3', 'Medium1', 'Medium2', 'Medium3', 'Dark1', 'Dark2', 'Dark3')]
        [string]$TableStyle
    )

    try {
        Write-Verbose "Converting CSV to Excel: $CsvPath -> $ExcelPath"
        
        # Import CSV data
        $data = Import-CsvData -Path $CsvPath -Delimiter $Delimiter
        
        # Export to Excel
        $exportParams = @{
            Data = $data
            Path = $ExcelPath
            WorksheetName = $WorksheetName
        }
        
        if ($AutoFit) { $exportParams.AutoFit = $true }
        if ($TableStyle) { $exportParams.TableStyle = $TableStyle }
        
        Export-ExcelData @exportParams
        
        Write-Verbose "Successfully converted CSV to Excel"
        
    } catch {
        Write-Error "Failed to convert CSV to Excel: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Validates CSV file structure and data.

.DESCRIPTION
    Performs validation checks on CSV files including structure, data types,
    and business rules.

.PARAMETER Path
    Path to the CSV file to validate.

.PARAMETER RequiredHeaders
    Array of required header names.

.PARAMETER DataTypes
    Hashtable defining expected data types for columns.

.PARAMETER ValidationRules
    Scriptblock containing custom validation logic.

.EXAMPLE
    $rules = { param($row) if ([string]::IsNullOrEmpty($row.Email)) { "Email is required" } }
    Test-CsvData -Path "users.csv" -RequiredHeaders @("Name", "Email") -ValidationRules $rules
#>
function Test-CsvData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter()]
        [string[]]$RequiredHeaders,

        [Parameter()]
        [hashtable]$DataTypes,

        [Parameter()]
        [scriptblock]$ValidationRules
    )

    try {
        Write-Verbose "Validating CSV file: $Path"
        
        $data = Import-Csv -Path $Path
        $results = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
            RowCount = $data.Count
        }
        
        if ($data.Count -eq 0) {
            $results.Errors += "CSV file is empty"
            $results.IsValid = $false
            return $results
        }
        
        # Check required headers
        if ($RequiredHeaders) {
            $actualHeaders = $data[0].PSObject.Properties.Name
            $missingHeaders = $RequiredHeaders | Where-Object { $_ -notin $actualHeaders }
            if ($missingHeaders) {
                $results.Errors += "Missing required headers: $($missingHeaders -join ', ')"
                $results.IsValid = $false
            }
        }
        
        # Validate data types
        if ($DataTypes) {
            for ($i = 0; $i -lt $data.Count; $i++) {
                $row = $data[$i]
                foreach ($column in $DataTypes.Keys) {
                    $value = $row.$column
                    $expectedType = $DataTypes[$column]
                    
                    if ($value -and -not ($value -as $expectedType)) {
                        $results.Errors += "Row $($i + 2): Invalid data type for $column. Expected $expectedType, got '$value'"
                        $results.IsValid = $false
                    }
                }
            }
        }
        
        # Apply custom validation rules
        if ($ValidationRules) {
            for ($i = 0; $i -lt $data.Count; $i++) {
                $row = $data[$i]
                $validationResult = & $ValidationRules $row
                if ($validationResult) {
                    $results.Errors += "Row $($i + 2): $validationResult"
                    $results.IsValid = $false
                }
            }
        }
        
        Write-Verbose "Validation complete. IsValid: $($results.IsValid), Errors: $($results.Errors.Count)"
        return $results
        
    } catch {
        Write-Error "Failed to validate CSV data: $($_.Exception.Message)"
        throw
    }
}

#endregion


#region HTTP Request Function
function Send-HTTPRequest {
    <#
    .SYNOPSIS
        Sends an HTTP request to a specified URI with comprehensive error handling and retry logic.
    
    .DESCRIPTION
        The Send-HTTPRequest function provides a robust wrapper around Invoke-RestMethod and Invoke-WebRequest
        with built-in retry logic, comprehensive error handling, and support for various HTTP methods.
        This function is designed to work with the Redmine API but can be used for any HTTP requests.
    
    .PARAMETER Uri
        The URI to send the HTTP request to. Must be a valid HTTP or HTTPS URL.
    
    .PARAMETER Method
        The HTTP method to use for the request. Default is 'GET'.
    
    .PARAMETER Headers
        A hashtable of custom headers to include in the request.
    
    .PARAMETER Body
        The body content for POST, PUT, PATCH requests. Can be a string, hashtable, or custom object.
    
    .PARAMETER ContentType
        The content type for the request body. Default is 'application/json'.
    
    .PARAMETER WebSession
        An existing web session object to use for the request. If provided, cookies and session state will be maintained.
    
    .PARAMETER TimeoutSec
        The timeout in seconds for the request. Default is 30 seconds.
    
    .PARAMETER MaxRetries
        The maximum number of retry attempts for failed requests. Default is 3.
    
    .PARAMETER RetryDelay
        The delay in seconds between retry attempts. Default is 2 seconds.
    
    .PARAMETER UseBasicParsing
        Use basic parsing for the response instead of Internet Explorer's DOM parser.
    
    .PARAMETER PassThru
        Return the full response object instead of just the content.
    
    .PARAMETER Credential
        PSCredential object for authentication.
    
    .PARAMETER UserAgent
        Custom User-Agent string for the request.
    
    .EXAMPLE
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method GET
        
        Sends a simple GET request to the specified URI.
    
    .EXAMPLE
        $headers = @{ 'Authorization' = 'Bearer token123'; 'Accept' = 'application/json' }
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method GET -Headers $headers
        
        Sends a GET request with custom headers.
    
    .EXAMPLE
        $body = @{ name = "Test"; value = "123" } | ConvertTo-Json
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method POST -Body $body -ContentType "application/json"
        
        Sends a POST request with JSON body content.
    
    .EXAMPLE
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        Send-HTTPRequest -Uri "https://api.example.com/login" -Method POST -WebSession $session -MaxRetries 5
        
        Sends a POST request using a web session with custom retry settings.
    
    .OUTPUTS
        PSCustomObject or System.Object depending on response content and PassThru parameter.
    
    .NOTES
        Author: Jason Hickey
        Version: 1.0.0
        This function includes automatic retry logic for transient failures and comprehensive error handling.
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            try {
                $uri = [System.Uri]$_
                if ($uri.Scheme -notin @('http', 'https')) {
                    throw "Invalid URL scheme. Only HTTP and HTTPS are supported."
                }
                return $true
            }
            catch {
                throw "Invalid URI format: $_"
            }
        })]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')]
        [string]$Method = 'GET',
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},
        
        [Parameter(Mandatory = $false)]
        [object]$Body,
        
        [Parameter(Mandatory = $false)]
        [string]$ContentType = 'application/json',
        
        [Parameter(Mandatory = $false)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$TimeoutSec = $script:ModuleConstants.DefaultTimeout,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = $script:ModuleConstants.MaxRetries,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$RetryDelay = 2,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseBasicParsing,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [string]$UserAgent = "PowerShell-RedmineDB/1.0.1"
    )
    
    begin {
        Write-Verbose "Preparing HTTP request: $Method $Uri"
        
        # Build request parameters
        $requestParams = @{
            Uri = $Uri
            Method = $Method
            TimeoutSec = $TimeoutSec
            UserAgent = $UserAgent
        }
        
        # Add optional parameters
        if ($Headers.Count -gt 0) {
            $requestParams.Headers = $Headers
        }
        
        if ($PSBoundParameters.ContainsKey('Body') -and $Body) {
            if ($Body -is [hashtable] -or $Body -is [PSCustomObject]) {
                $requestParams.Body = $Body | ConvertTo-Json -Depth 10
                $requestParams.ContentType = $ContentType
            }
            else {
                $requestParams.Body = $Body
                if ($PSBoundParameters.ContainsKey('ContentType')) {
                    $requestParams.ContentType = $ContentType
                }
            }
        }
        
        if ($WebSession) {
            $requestParams.WebSession = $WebSession
        }
        
        if ($Credential) {
            $requestParams.Credential = $Credential
        }
        
        if ($UseBasicParsing) {
            $requestParams.UseBasicParsing = $true
        }
        
        $attempt = 0
        $lastError = $null
    }
    
    process {
        do {
            $attempt++
            
            try {
                Write-Debug "Attempt $attempt of $($MaxRetries + 1): $Method $Uri"
                
                if ($PassThru) {
                    $response = Invoke-WebRequest @requestParams
                }
                else {
                    $response = Invoke-RestMethod @requestParams
                }
                
                Write-Verbose "HTTP request successful: $Method $Uri (Status: $($response.StatusCode -or 'Success'))"
                return $response
            }
            catch [System.Net.WebException] {
                $lastError = $_
                $statusCode = $_.Exception.Response.StatusCode
                $statusDescription = $_.Exception.Response.StatusDescription
                
                Write-Warning "HTTP request failed (Attempt $attempt): $statusCode - $statusDescription"
                
                # Don't retry for client errors (4xx) except for specific cases
                if ($statusCode -ge 400 -and $statusCode -lt 500 -and $statusCode -notin @(408, 429)) {
                    Write-Error "Client error encountered, not retrying: $statusCode - $statusDescription"
                    throw
                }
                
                # Don't retry for authentication errors
                if ($statusCode -in @(401, 403)) {
                    Write-Error "Authentication/Authorization error: $statusCode - $statusDescription"
                    throw
                }
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
            catch [System.TimeoutException] {
                $lastError = $_
                Write-Warning "Request timeout (Attempt $attempt): $($_.Exception.Message)"
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
            catch {
                $lastError = $_
                Write-Warning "Unexpected error (Attempt $attempt): $($_.Exception.Message)"
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
        }
        while ($attempt -le $MaxRetries)
        
        # If we get here, all attempts failed
        Write-Error "HTTP request failed after $($MaxRetries + 1) attempts: $($lastError.Exception.Message)"
        throw $lastError
    }
}
#endregion

# Export functions
Export-ModuleMember -Function @(
    'Import-ExcelData',
    'Export-ExcelData',
    'Import-CsvData',
    'Export-CsvData',
    'Compare-CsvData',
    'ConvertTo-Excel',
    'Test-CsvData',
    'Send-HTTPRequest'
)
