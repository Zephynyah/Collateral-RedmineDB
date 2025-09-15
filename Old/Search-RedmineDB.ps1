function Search-RedmineDB {
    <#
    .SYNOPSIS
        Search Redmine database resources by keyword and filters
    .DESCRIPTION
        Searches Redmine database resources using keywords across various fields with optional status filtering.
        Supports searching by parent ID, type, serial number, program, hostname, model, and MAC address.
        Uses optimized field mappings and improved error handling.
    .PARAMETER Keyword
        The search term to look for. Supports regex patterns for most fields.
    .PARAMETER Field
        The field to search in. Valid options: 'name', 'parent', 'type', 'serial', 'program', 'hostname', 'model', 'mac', 'macaddress'
    .PARAMETER Status
        Filter results by status. Valid options: 'valid', 'to verify', 'invalid', '*' (all)
    .PARAMETER CaseSensitive
        Perform case-sensitive search. Default is case-insensitive.
    .PARAMETER ExactMatch
        Perform exact match instead of partial/regex match (applies to applicable fields)
    .EXAMPLE
        Search-RedmineDB -Keyword 'SC-000059'
        # Searches by name (default field)
    .EXAMPLE
        Search-RedmineDB -Field hostname -Keyword 'MM17-09'
        # Searches by hostname field
    .EXAMPLE
        Search-RedmineDB -Field type -Keyword 'Workstation' | Export-Csv -Path workstation.csv -NoTypeInformation
        # Searches by type and exports to CSV
    .EXAMPLE
        Search-RedmineDB -Field parent -Keyword 12303 | Format-Table
        # Searches by parent ID and formats as table
    .EXAMPLE
        Search-RedmineDB -Field type -Keyword 'Hard Drive' -Status invalid -ExactMatch
        # Searches by type with status filter and exact match
    .EXAMPLE
        Search-RedmineDB -Field serial -Keyword '^90L0A.*' -CaseSensitive
        # Case-sensitive regex search in serial number field
    .LINK
        https://github.pw.utc.com/m335619/RedmineDB
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Keyword,

        [ValidateSet('name', 'parent', 'type', 'serial', 'program', 'hostname', 'model', 'mac', 'macaddress')]
        [string] $Field = 'name',
        
        [ValidateSet('valid', 'to verify', 'invalid', '*')]
        [string] $Status = '*',
        
        [switch] $CaseSensitive,
        
        [switch] $ExactMatch
    )
    
    begin {
        Write-LogInfo "Searching DB entries with keyword: '$Keyword', field: '$Field', status: '$Status'"
        
        # Verify connection
        if (-not $Script:Redmine -or -not $Script:Redmine.DB) {
            throw "Not connected to Redmine server. Use Connect-Redmine first."
        }
        
        # Custom field ID mappings using the centralized mapping
        $fieldMappings = @{
            'model'      = $script:CustomFieldIds.SystemModel
            'serial'     = $script:CustomFieldIds.SerialNumber
            'parent'     = $script:CustomFieldIds.ParentHardware
            'hostname'   = $script:CustomFieldIds.HostName
            'program'    = $script:CustomFieldIds.Programs
            'mac'        = $script:CustomFieldIds.MACAddress
            'macaddress' = $script:CustomFieldIds.MACAddress
        }
        
        # Normalize MAC address field references
        if ($Field -eq 'macaddress') {
            $Field = 'mac'
        }
        
        # Configure comparison options
        $comparisonType = if ($CaseSensitive) { 
            [StringComparison]::Ordinal 
        } else { 
            [StringComparison]::OrdinalIgnoreCase 
        }
        
        Write-LogDebug "Using field mappings: $($fieldMappings | ConvertTo-Json -Compress)"
        Write-LogDebug "Search options - CaseSensitive: $CaseSensitive, ExactMatch: $ExactMatch"
    }
    
    process {
        try {
            # Build status filter
            $statusFilter = if ($Status -ne '*') {
                "&status_id=$($script:DBStatus[$Status])"
            } else {
                "&status_id=*"
            }
            
            Write-LogDebug "Applying status filter: $statusFilter"
            
            # Retrieve all entries with status filter
            $collection = $Script:Redmine.DB.GetAll($statusFilter)
            if ($collection.Count -eq 0) {
                Write-LogInfo "No entries found matching the status criteria"
                return @()
            }
            
            Write-LogInfo "Retrieved $($collection.Count) entries, applying field filter for '$Field'"
            
            # Create optimized search predicate factory
            $searchPredicate = switch ($Field) {
                'model' { 
                    $fieldId = $fieldMappings['model']
                    if ($ExactMatch) {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and ($CaseSensitive ? 
                                ($fieldValue -cmatch $Keyword) : 
                                ($fieldValue -imatch $Keyword))
                        }
                    }
                }
                
                'serial' { 
                    $fieldId = $fieldMappings['serial']
                    if ($ExactMatch) {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and ($CaseSensitive ? 
                                ($fieldValue -cmatch $Keyword) : 
                                ($fieldValue -imatch $Keyword))
                        }
                    }
                }
                
                'parent' { 
                    $fieldId = $fieldMappings['parent']
                    # Parent ID should always be exact match
                    { param($entry) 
                        $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                        $null -ne $fieldValue -and $fieldValue -eq $Keyword
                    }
                }
                
                'hostname' { 
                    $fieldId = $fieldMappings['hostname']
                    if ($ExactMatch) {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and ($CaseSensitive ? 
                                ($fieldValue -cmatch $Keyword) : 
                                ($fieldValue -imatch $Keyword))
                        }
                    }
                }
                
                'program' { 
                    $fieldId = $fieldMappings['program']
                    if ($ExactMatch) {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            if ($fieldValue -is [array]) {
                                $fieldValue -contains $Keyword
                            } else {
                                $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                            }
                        }
                    } else {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            if ($fieldValue -is [array]) {
                                $fieldValue | Where-Object { 
                                    $CaseSensitive ? ($_ -cmatch $Keyword) : ($_ -imatch $Keyword) 
                                }
                            } else {
                                $null -ne $fieldValue -and ($CaseSensitive ? 
                                    ($fieldValue -cmatch $Keyword) : 
                                    ($fieldValue -imatch $Keyword))
                            }
                        }
                    }
                }
                
                'mac' { 
                    $fieldId = $fieldMappings['mac']
                    if ($ExactMatch) {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $fieldValue = ($entry.CustomFields | Where-Object id -eq $fieldId).value
                            $null -ne $fieldValue -and ($CaseSensitive ? 
                                ($fieldValue -cmatch $Keyword) : 
                                ($fieldValue -imatch $Keyword))
                        }
                    }
                }
                
                'type' { 
                    if ($ExactMatch) {
                        { param($entry) 
                            $null -ne $entry.Type -and $null -ne $entry.Type.name -and 
                            $entry.Type.name.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $null -ne $entry.Type -and $null -ne $entry.Type.name -and 
                            ($CaseSensitive ? 
                                ($entry.Type.name -cmatch $Keyword) : 
                                ($entry.Type.name -imatch $Keyword))
                        }
                    }
                }
                
                'name' { 
                    if ($ExactMatch) {
                        { param($entry) 
                            $null -ne $entry.Name -and $entry.Name.Equals($Keyword, $comparisonType)
                        }
                    } else {
                        { param($entry) 
                            $null -ne $entry.Name -and ($CaseSensitive ? 
                                ($entry.Name -cmatch $Keyword) : 
                                ($entry.Name -imatch $Keyword))
                        }
                    }
                }
                
                default { 
                    throw "Unsupported field: $Field"
                }
            }
            
            # Apply search filter with progress tracking
            $filteredResults = @{}
            $processedCount = 0
            $matchCount = 0
            
            foreach ($id in $collection.Keys) {
                $entry = $collection[$id]
                $processedCount++
                
                try {
                    if (& $searchPredicate $entry) {
                        $filteredResults[$id] = $entry
                        $matchCount++
                    }
                }
                catch {
                    Write-LogWarn "Error processing entry ID $id`: $($_.Exception.Message)"
                    continue
                }
                
                # Progress logging for large collections
                if ($processedCount % 100 -eq 0) {
                    Write-LogDebug "Processed $processedCount/$($collection.Count) entries, found $matchCount matches"
                }
            }
            
            Write-LogInfo "Found $matchCount matching entries out of $processedCount processed"
            
            if ($matchCount -eq 0) {
                Write-Information "No entries found matching keyword '$Keyword' in field '$Field'" -InformationAction Continue
                return @()
            }
            
            # Convert to PSObjects and return sorted results
            Write-LogDebug "Converting $matchCount results to PSObjects"
            $results = $filteredResults.Values | 
                ForEach-Object { $_.ToPSObject() } | 
                Sort-Object ID
            
            Write-LogInfo "Search completed successfully, returning $($results.Count) results"
            return $results
        }
        catch {
            Write-LogError "Search operation failed: $($_.Exception.Message)" -Exception $_.Exception
            throw
        }
    }
}