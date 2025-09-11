<#
	===========================================================================
	 Module Name:       Collateral-RedmineDB.psm1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        10/4/2024 12:23 AM
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          Collateral-RedmineDB.psm1
	 Description:       PowerShell module for Redmine database API operations
	 Version:           1.0.3
	 Last Modified:     2025-06-26
	-------------------------------------------------------------------------
	 Copyright (c) 2024 Jason Hickey. All rights reserved.
	 Licensed under the MIT License.
	===========================================================================
#>
#Requires -Version 5.0

using namespace System.Management.Automation

# PowerShell strict mode for better error detection
Set-StrictMode -Version 'Latest'

# Import required assemblies
Add-Type -AssemblyName 'System.Web'

# Module initialization
$script:ModuleRoot = $PSScriptRoot

# Unblock all files in the module directory to avoid execution issues
try {
    Get-ChildItem -Path $script:ModuleRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Write-Verbose "Module files unblocked successfully"
}
catch {
    Write-Warning "Failed to unblock some module files: $($_.Exception.Message)"
}

try {
    Import-Module .\Misc\logging.psm1 -Force -ErrorAction Stop
    Initialize-Logger -Source "RedmineDB" -MinimumLevel Information -Targets All

    Import-Module .\Misc\helper.psm1 -Force -ErrorAction Stop
    Write-LogInfo "Helper module imported successfully"
    
    Import-Module .\Misc\settings.psm1 -Force -ErrorAction Stop
    Write-LogInfo "Settings module imported successfully"
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Warning "Failed to import required modules: $($_.Exception.Message)"
    exit
}


# Module constants with proper data types and validation
$script:ModuleConstants = [PSCustomObject]@{
    ProjectId      = [int]25
    DefaultLimit   = [int]2000
    MaxRetries     = [int]3
    DefaultTimeout = [int]30
    ApiVersion     = [string]'1.0'
    UserAgent      = [string]"PowerShell-RedmineDB/1.0.3"
}

# Custom field IDs mapping for better maintainability
$script:CustomFieldIds = @{
    SystemMake          = 101
    SystemModel         = 102
    OperatingSystem     = 105
    SerialNumber        = 106
    AssetTag            = 107
    RefreshDate         = 108
    State               = 109
    RackSeat            = 112
    PeriodsProcessing   = 113
    ParentHardware      = 114
    HostName            = 115
    Programs            = 116
    GSCStatus           = 117
    Memory              = 119
    HardDriveSize       = 120
    MemoryVolatility    = 124
    Node                = 125
    Building            = 126
    Room                = 127
    SafeAndDrawerNumber = 128
    MACAddress          = 150
    HardwareLifecycle   = 190
}

$script:propertyMap = @{
    'id'            = 'Id'
    'name'          = 'Name'
    'description'   = 'Description'
    'is_private'    = 'IsPrivate'
    'project'       = 'Project'
    'status'        = 'Status'
    'type'          = 'Type'
    'author'        = 'Author'
    'tags'          = 'Tags'
    'custom_fields' = 'CustomFields'
    'issues'        = 'Issues'
    'created_on'    = 'CreatedOn'
    'updated_on'    = 'UpdatedOn'
}

#region Module Data Import from Settings Module

# Load all settings data from the settings module (no file I/O required)
try {
    $settingsDataNames = Get-AvailableSettings
    $script:LoadedData = @{}
    
    foreach ($dataName in $settingsDataNames) {
        try {
            $data = Get-SettingsData -DataName $dataName
            Set-Variable -Name $dataName -Value $data -Scope Script -Force
            $script:LoadedData[$dataName] = $data
            Write-LogDebug "Successfully loaded $dataName from settings module"
        }
        catch {
            $errorMessage = "Failed to load $dataName from settings module: $($_.Exception.Message)"
            Write-LogError $errorMessage -Exception $_.Exception
            
            # For critical data, throw to prevent module load
            if ($dataName -in @('DBStatus', 'DBType')) {
                Write-LogCritical "Critical data failed to load: $dataName"
                throw $errorMessage
            }
            
            # For non-critical data, set empty defaults and continue
            Set-Variable -Name $dataName -Value @{} -Scope Script -Force
            Write-LogWarn "Using empty default for $dataName due to load failure"
        }
    }
    
    Write-LogInfo "Module data initialization completed. Loaded $($script:LoadedData.Count) data sets from settings module (no file I/O required)."
}
catch {
    Write-LogCritical "Failed to initialize module data from settings module: $($_.Exception.Message)"
    throw
}
#endregion


#region Classes

class RedmineConnection {
    hidden [string] $Server
    hidden [string] $CSRFToken
    hidden [object] $Session
    [DB] $DB
    
    # Constructor
    RedmineConnection([string] $Server, [hashtable] $IWRParams) {
        $this.Server = $this.ValidateServerUrl($Server)
        $this.InitializeConnection($IWRParams)
        $this.DB = [DB]::new($this.Server, $this.Session)
    }
    
    # Private methods
    hidden [string] ValidateServerUrl([string] $Url) {
        try {
            $uri = [System.Uri]::new($Url)
            if ($uri.Scheme -notin @('http', 'https')) {
                throw "Invalid URL scheme. Only HTTP and HTTPS are supported."
            }
            return $uri.ToString().TrimEnd('/')
        }
        catch {
            throw "Invalid server URL: $Url. Please provide a valid HTTP/HTTPS URL."
        }
    }
    
    hidden [void] InitializeConnection([hashtable] $IWRParams) {
        if ($Script:APIKey) {
            Write-LogInfo "Using API Key authentication"
        }
        else {
            Write-LogInfo "Using credential-based authentication"
            $this.SignIn($IWRParams)
        }
    }
    
    hidden [void] SignIn([hashtable] $IWRParams) {
        try {
            $this.Session = New-Object -TypeName "Microsoft.PowerShell.Commands.WebRequestSession" -ErrorAction SilentlyContinue
            $requestParams = $IWRParams.Clone()
            $requestParams.WebSession = $this.Session
            $requestParams.Method = 'GET'
            $requestParams.Uri = "$($this.Server)/login"
            $requestParams.TimeoutSec = $script:ModuleConstants.DefaultTimeout
            
            $response = Invoke-WebRequest @requestParams
            
            if ($response.Forms.Fields -and $response.Forms.Fields['authenticity_token']) {
                $this.CSRFToken = $response.Forms.Fields['authenticity_token']
            }
            
            Write-LogInfo "Successfully signed in to Redmine server"
            Write-LogInfo "Successfully signed in to Redmine server"
        }
        catch {
            Write-LogError "Failed to sign in to Redmine server: $($_.Exception.Message)"
            Write-LogError "Failed to sign in to Redmine server" -Exception $_.Exception
            throw
        }
    }
    
    [void] SignOut() {
        if (-not $this.Session) {
            Write-LogWarn "No active session found"
            Write-LogWarn "No active session found"
            return
        }
        
        try {
            $requestParams = @{
                WebSession = $this.Session
                Method     = 'POST'
                Uri        = "$($this.Server)/logout"
                Headers    = @{ 'X-CSRF-Token' = $this.CSRFToken }
                TimeoutSec = $script:ModuleConstants.DefaultTimeout
            }
            Invoke-RestMethod @requestParams
            Write-LogInfo "Successfully signed out from Redmine server"
            Write-LogInfo "Successfully signed out from Redmine server"
        }
        catch {
            Write-LogWarn "Failed to sign out properly: $($_.Exception.Message)"
            Write-LogWarn "Failed to sign out properly" -Exception $_.Exception
        }
    }
    
    [PSCustomObject] Request([hashtable] $RequestParams) {
        $requestParams = $RequestParams.Clone()
        $requestParams.WebSession = $this.Session
        $requestParams.TimeoutSec = $script:ModuleConstants.DefaultTimeout
        
        try {
            $response = Invoke-RestMethod @requestParams
            Write-LogDebug "Request successful: $($requestParams.Method) $($requestParams.Uri)"
            Write-LogDebug "Request successful: $($requestParams.Method) $($requestParams.Uri)"
            return $response
        }
        catch {
            Write-LogError "API request failed: $($_.Exception.Message)"
            Write-LogError "API request failed" -Exception $_.Exception
            throw
        }
    }
}

class DB {
    # Properties
    hidden [string] $Server
    hidden [object] $Session
    hidden [string] $SetName = 'db'
    hidden [string] $Include = "" #'custom_fields'
    
    # Public properties
    [string] $Id
    [string] $Name
    [string] $Description
    [bool] $IsPrivate
    [PSCustomObject] $Project = @{ id = $script:ModuleConstants.ProjectId }
    [PSCustomObject] $Status
    [PSCustomObject] $Type
    [PSCustomObject] $Author
    [PSCustomObject[]] $Tags
    [PSCustomObject[]] $CustomFields
    [PSCustomObject[]] $Issues
    [string] $CreatedOn
    [string] $UpdatedOn
    
    # Constructors
    DB() {
        $this.CustomFields = @()
        $this.Tags = @()
        $this.Issues = @()
    }
    
    DB([string] $Server, [object] $Session) {
        $this.Server = $Server
        $this.Session = $Session
        $this.CustomFields = @()
        $this.Tags = @()
        $this.Issues = @()
    }

    # Convert object to JSON for API requests
    [string] ToJson() {
        $json = @{ 
            db_entry = @{} 
        }
        
        $propertyMappings = @{
            'Project'      = { $json.db_entry['project_id'] = $this.Project.id }
            'Type'         = { $json.db_entry['type_id'] = $this.Type.id }
            'Status'       = { $json.db_entry['status_id'] = $this.Status.id }
            'IsPrivate'    = { $json.db_entry['is_private'] = $this.IsPrivate }
            'CustomFields' = { $json.db_entry['custom_fields'] = $this.CustomFields }
            'Issues'       = { 
                if ($this.Issues.Count -gt 0) {
                    $json.db_entry['issues_ids'] = $this.Issues | ForEach-Object { $_.id }
                }
            }
        }
        
        foreach ($property in $this.PSObject.Properties.Name) {
            $value = $this.$property
            
            # Skip empty values and internal properties
            if ($null -eq $value -or 
                $value -eq 0 -or 
                ($value -is [array] -and $value.Count -eq 0) -or
                $property -in @('SetName', 'Include', 'Server', 'Session')) {
                continue
            }
            
            # Apply property mappings or use default
            if ($propertyMappings.ContainsKey($property)) {
                & $propertyMappings[$property]
            }
            else {
                $json.db_entry[$property.ToLower()] = $value
            }
        }
        
        $jsonString = $json | ConvertTo-Json -Depth 10 -Compress
        Write-LogDebug "Generated JSON: $jsonString"
        return $jsonString
    }
    
    # Convert to PowerShell object for display
    [PSCustomObject] ToPSObject() {
        $fields = [PSCustomObject]@{
            ID          = $this.Id
            Name        = $this.Name
            Type        = if ($this.Type -and $this.Type.name) { $this.Type.name } else { $null }
            Status      = if ($this.Status -and $this.Status.name) { $this.Status.name } else { $null }
            Private     = $this.IsPrivate
            Project     = if ($this.Project -and $this.Project.name) { $this.Project.name } else { $null }
            Tags        = if ($this.Tags) { ($this.Tags.name -join ", ") } else { $null }
            Author      = if ($this.Author -and $this.Author.name) { $this.Author.name } else { $null }
            Description = $this.Description
            Created     = $this.CreatedOn
            Updated     = $this.UpdatedOn
        }
        
        # Add custom fields
        if ($this.CustomFields) {
            foreach ($field in $this.CustomFields) {
                $value = if ($field.value -is [array]) { $field.value -join ", " } else { $field.value }
                $fields | Add-Member -MemberType NoteProperty -Name $field.name -Value $value
            }
        }
        
        return $fields
    }
    
    # Make API request with retry logic
    [PSCustomObject] Request([string] $Method, [string] $Uri) {
        $requestParams = @{ 
            Method     = $Method
            TimeoutSec = $script:ModuleConstants.DefaultTimeout
        }
        
        # Setup authentication
        if ($Script:APIKey) {
            $requestParams.Headers = @{ 'X-Redmine-API-Key' = $Script:APIKey }
            $separator = if ($Uri.Contains('?')) { '&' } else { '?' }
            $Uri = "$Uri$separator" + "key=$Script:APIKey"
        }
        else {
            $requestParams.WebSession = $this.Session
        }
        
        $requestParams.Uri = "$($this.Server)/$Uri"
        
        # Add body for POST/PUT requests
        if ($Method -in @('POST', 'PUT')) {
            $requestParams.ContentType = 'application/json'
            $requestParams.Body = $this.ToJson()
        }
        
        # Retry logic
        $retryCount = 0
        do {
            try {
                $response = Invoke-RestMethod @requestParams
                Write-LogDebug "API request successful: $Method $($requestParams.Uri)"
                return $response
            }
            catch {
                $retryCount++
                if ($retryCount -ge $script:ModuleConstants.MaxRetries) {
                    Write-LogError "API request failed after $retryCount attempts: $Method $($requestParams.Uri)" -Exception $_.Exception
                    throw
                }
                Write-LogWarn "API request failed, retrying ($retryCount/$($script:ModuleConstants.MaxRetries)): $Method $($requestParams.Uri)" -Exception $_.Exception
                Start-Sleep -Seconds $retryCount
            }
        } while ($retryCount -lt $script:ModuleConstants.MaxRetries)
        return $null
    }
    # CRUD Operations
    [PSCustomObject] Get([string] $Id) {
        if ([string]::IsNullOrWhiteSpace($Id)) {
            throw "ID parameter cannot be null or empty"
        }
        
        try {
            # $response = $this.Request('GET', "$($this.SetName)/$Id.json$($this.Include)")
            $Response = $this.request('GET', $this.setname + '/' + $id + '.json' + $this.include)
            $dbObject = [DB]::new($this.Server, $this.Session)
            
            # Map JSON properties to DB object properties with proper case and naming
            foreach ($jsonProperty in $response.db_entry.PSObject.Properties.Name) {
                if ($script:propertyMap.ContainsKey($jsonProperty)) {
                    $dbProperty = $script:propertyMap[$jsonProperty]
                    Write-LogDebug "Mapping JSON property '$jsonProperty' to DB property '$dbProperty'"
                    Write-LogDebug "  JSON value: $($response.db_entry.$jsonProperty)"
                    $dbObject.$dbProperty = $response.db_entry.$jsonProperty
                    Write-LogDebug "  DB property after mapping: $($dbObject.$dbProperty)"
                }
            }
            
            Write-LogInfo "Successfully retrieved DB entry with ID: $Id"
            return $dbObject
        }
        catch {
            Write-LogError "Failed to get DB entry with ID $Id`: $($_.Exception.Message)"
            throw
        }
    }
    
    [Object] GetByName([string] $Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) { throw "Name parameter cannot be null or empty" }
        
        try {
            # Simple URL encoding without requiring System.Web
            $encodedName = [System.Uri]::EscapeDataString($Name)
            $response = $this.Request('GET', "db.json?name=$encodedName&limit=1")
            # Check if any entries were returned
            if (-not $response.db_entries -or $response.db_entries.Count -eq 0) {
                throw "No DB entry found with name: $Name"
            }
            # Create a new DB object
            $dbObject = [DB]::new($this.Server, $this.Session)
            # Map JSON properties to DB object properties with proper case and naming
            foreach ($jsonProperty in $response.db_entries[0].PSObject.Properties.Name) {
                if ($script:propertyMap.ContainsKey($jsonProperty)) {
                    $dbProperty = $script:propertyMap[$jsonProperty]
                    Write-LogDebug "Mapping JSON property '$jsonProperty' to DB property '$dbProperty'"
                    Write-LogDebug "  JSON value: $($response.db_entries[0].$jsonProperty)"
                    $dbObject.$dbProperty = $response.db_entries[0].$jsonProperty
                    Write-LogDebug "  DB property after mapping: $($dbObject.$dbProperty)"
                }
            }
            # Write-LogInfo "Successfully retrieved DB entry with name: $Name"
            return $dbObject
        }
        catch {
            Write-LogError "Failed to get DB entry with name $Name`: $($_.Exception.Message)"
            throw
        }
    }
    
    [hashtable] GetAllPages([string] $BaseUrl, [string] $Filter) {
        $offset = 0
        $limit = $script:ModuleConstants.DefaultLimit
        $collection = @{}
        
        try {
            do {
                $url = "$BaseUrl`?offset=$offset&limit=$limit$($this.Include)$Filter"
                $response = $this.Request('GET', $url)
                
                if (-not $response.db_entries) {
                    break
                }
                
                foreach ($entry in $response.db_entries) {
                    $dbItem = [DB]::new($this.Server, $this.Session)
                    
                    # Map JSON properties to DB object properties with proper case and naming
                    $propertyMap = @{
                        'id'            = 'Id'
                        'name'          = 'Name'
                        'description'   = 'Description'
                        'is_private'    = 'IsPrivate'
                        'project'       = 'Project'
                        'status'        = 'Status'
                        'type'          = 'Type'
                        'author'        = 'Author'
                        'tags'          = 'Tags'
                        'custom_fields' = 'CustomFields'
                        'issues'        = 'Issues'
                        'created_on'    = 'CreatedOn'
                        'updated_on'    = 'UpdatedOn'
                    }
                    
                    foreach ($jsonProperty in $entry.PSObject.Properties.Name) {
                        if ($propertyMap.ContainsKey($jsonProperty)) {
                            $dbProperty = $propertyMap[$jsonProperty]
                            $dbItem.$dbProperty = $entry.$jsonProperty
                        }
                    }
                    
                    $collection[$dbItem.Id] = $dbItem
                }
                
                $offset += $limit
                $remainingCount = $response.total_count - $offset
                
                Write-LogDebug "Retrieved $($response.db_entries.Count) entries, $remainingCount remaining"
                
            } while ($remainingCount -gt 0)
            
            Write-LogInfo "Successfully retrieved $($collection.Count) DB entries"
            return $collection
        }
        catch {
            Write-LogError "Failed to retrieve DB entries: $($_.Exception.Message)"
            throw
        }
    }
    
    [hashtable] GetAll() { 
        return $this.GetAll('') 
    }
    
    [hashtable] GetAll([string] $Filter) { 
        return $this.GetAllPages('db.json', $Filter) 
    }
    
    [void] Clear() {
        foreach ($property in $this.PSObject.Properties.Name) {
            if ($property -notin @('Server', 'Session', 'SetName', 'Include')) {
                $this.$property = $null
            }
        }
        $this.CustomFields = @()
        $this.Tags = @()
        $this.Issues = @()
    }
    
    [PSCustomObject] Create() {
        try {
            if ([string]::IsNullOrWhiteSpace($this.Name)) {
                throw "Name is required to create a DB entry"
            }
            
            $response = $this.Request('POST', "projects/$($this.Project.id)/db.json")
            $this.Clear()
            
            Write-LogInfo "Successfully created DB entry: $($response.db_entry.name)"
            return $response.db_entry
        }
        catch {
            Write-LogError "Failed to create DB entry: $($_.Exception.Message)"
            throw
        }
    }
    
    [void] Read() {
        if ([string]::IsNullOrWhiteSpace($this.Id)) {
            throw "ID is required to read a DB entry"
        }
        
        try {
            $response = $this.Request('GET', "$($this.SetName)/$($this.Id).json")
            
            foreach ($property in $response.db_entry.PSObject.Properties.Name) {
                if ($this.PSObject.Properties.Name -contains $property) {
                    $this.$property = $response.db_entry.$property
                }
            }
            
            Write-LogInfo "Successfully read DB entry with ID: $($this.Id)"
        }
        catch {
            Write-LogError "Failed to read DB entry with ID $($this.Id): $($_.Exception.Message)"
            throw
        }
    }
    
    [void] Update() {
        if ([string]::IsNullOrWhiteSpace($this.Id)) {
            throw "ID is required to update a DB entry"
        }
        
        try {
            $this.Request('PUT', "$($this.SetName)/$($this.Id).json")
            $this.Clear()
            
            Write-LogInfo "Successfully updated DB entry with ID: $($this.Id)"
        }
        catch {
            Write-LogError "Failed to update DB entry with ID $($this.Id): $($_.Exception.Message)"
            throw
        }
    }
    
    [void] Delete() {
        if ([string]::IsNullOrWhiteSpace($this.Id)) {
            throw "ID is required to delete a DB entry"
        }
        
        try {
            $this.Request('DELETE', "$($this.SetName)/$($this.Id).json")
            Write-LogInfo "Successfully deleted DB entry with ID: $($this.Id)"
        }
        catch {
            Write-LogError "Failed to delete DB entry with ID $($this.Id): $($_.Exception.Message)"
            throw
        }
    }
}

# Base validation class
class ValidatorBase {
    [string] $Name
    
    ValidatorBase([string] $Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) { 
            return 
        }
        $this.ValidateValue($Value)
    }
    
    [void] ValidateValue([string] $Value) {
        throw "ValidateValue method must be implemented in derived class"
    }
    
    [string] ToString() { 
        return $this.Name 
    }
}

class ValidateState : ValidatorBase {
    static [array] $ValidStates = $script:DBvalidState.Keys

    ValidateState([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        if ($Value -notin [ValidateState]::ValidStates) { 
            throw "Invalid state: [$Value]. Valid states are: $([ValidateState]::ValidStates -join ', ')"
        }
        $this.Name = $Value
    }
}

class ValidateBuilding : ValidatorBase {
    static [array] $ValidBuildings = $script:DBvalidBuilding

    ValidateBuilding([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        if ($Value -notin [ValidateBuilding]::ValidBuildings) { 
            throw "Invalid building: [$Value]. Valid buildings are: $([ValidateBuilding]::ValidBuildings -join ', ')"
        }
        $this.Name = $Value
    }
}

class ValidateRoom : ValidatorBase {
    static [array] $ValidRooms = $script:DBvalidRoom

    ValidateRoom([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        if ($Value -notin [ValidateRoom]::ValidRooms) { 
            throw "Invalid room: [$Value]. Valid rooms are: $([ValidateRoom]::ValidRooms -join ', ')"
        }
        $this.Name = $Value
    }
}

class ValidateGSCStatus : ValidatorBase {
    static [array] $ValidStatuses = $script:DBvalidStatusGSC

    ValidateGSCStatus([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        $matchedStatus = [ValidateGSCStatus]::ValidStatuses | 
        Where-Object { $_.ToLower() -eq $Value.ToLower() }
        
        if (-not $matchedStatus) { 
            throw "Invalid GSC status: [$Value]. Valid statuses are: $([ValidateGSCStatus]::ValidStatuses -join ', ')"
        }
        $this.Name = $matchedStatus
    }
}

class ValidateSize : ValidatorBase {
    static [string] $SizePattern = '[.\s0-9]+\s(KB|MB|GB|TB)'

    ValidateSize([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        if ($Value -notmatch [ValidateSize]::SizePattern) { 
            throw "Invalid size format: [$Value]. Expected format: '<number> <unit>' (e.g., '1.5 GB')"
        }
        $this.Name = ($Value -replace '\s+', ' ').Trim()
    }
}

class ValidateOperatingSystem : ValidatorBase {
    static [array] $ValidOperatingSystems = $script:DBvalidOS

    ValidateOperatingSystem([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        $matchedOS = [ValidateOperatingSystem]::ValidOperatingSystems | 
        Where-Object { $_ -match [regex]::Escape($Value) }
        
        if (-not $matchedOS) { 
            throw "Invalid operating system: [$Value]. Available options include: $([ValidateOperatingSystem]::ValidOperatingSystems[0..5] -join ', ')..."
        }
        $this.Name = $Value
    }
}

class ValidateProgram : ValidatorBase {
    static [array] $ValidPrograms = $script:DBvalidProgram
    [string[]] $Programs

    ValidateProgram() {
        # Default constructor
    }

    ValidateProgram([object] $Value) {
        if (-not $Value) { 
            return 
        }
        
        $this.Programs = @()
        $inputPrograms = if ($Value -is [array]) { $Value } else { @($Value) }
        
        foreach ($program in $inputPrograms) {
            $matchedProgram = [ValidateProgram]::ValidPrograms | 
            Where-Object { $_.ToLower() -eq $program.ToString().ToLower() }
            
            if ($matchedProgram) { 
                $this.Programs += $matchedProgram 
            } 
            else { 
                throw "Invalid program: [$program]. Valid programs are: $([ValidateProgram]::ValidPrograms -join ', ')" 
            }
        }
        
        $this.Name = $this.Programs -join ", "
    }
    
    [void] ValidateValue([string] $Value) {
        # Not used for this class as constructor handles validation
    }
}

class ValidateLifecycle : ValidatorBase {
    static [array] $ValidLifecycles = $script:DBvalidLifecycle

    ValidateLifecycle([string] $Value) : base($Value) {}
    
    [void] ValidateValue([string] $Value) {
        if ($Value -notin [ValidateLifecycle]::ValidLifecycles) { 
            throw "Invalid lifecycle: [$Value]. Valid lifecycles are: $([ValidateLifecycle]::ValidLifecycles -join ', ')"
        }
        $this.Name = $Value
    }
}

#endregion


#region Functions

function ConvertTo-RedmineCustomField {
    <#
    .SYNOPSIS
        Converts custom field data to Redmine API format.
    
    .DESCRIPTION
        Helper function to properly format custom fields for Redmine API requests.
        Takes a hashtable of custom field data and converts it to the format expected by the Redmine REST API.
    
    .PARAMETER CustomFields
        A hashtable containing custom field data where keys are field IDs and values are the field values.
    
    .EXAMPLE
        $customFields = @{
            101 = "Dell"
            102 = "Latitude 7420"
            105 = "Windows 11"
        }
        $formatted = ConvertTo-RedmineCustomField -CustomFields $customFields
        # Returns formatted custom fields array for API submission
    
    .OUTPUTS
        System.Array
        Returns an array of hashtables formatted for Redmine API consumption.
    
    .NOTES
        This function is primarily used internally by other module functions when preparing data for API requests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [hashtable]$CustomFields
    )
    
    $formattedFields = foreach ($field in $CustomFields.GetEnumerator()) {
        @{
            id    = $field.Key
            value = $field.Value
        }
    }
    
    return $formattedFields
}

function Connect-Redmine {
    <#
    .SYNOPSIS
        Establishes a connection to the Redmine server
    .DESCRIPTION
        Connects to the Redmine server and sets up the authorization context for subsequent operations.
        Supports both API key and credential-based authentication.
    .PARAMETER Server
        The Redmine server URL (e.g., https://redmine.example.com)
    .PARAMETER Key
        API key for authentication (recommended for automation)
    .PARAMETER Username
        Username for credential-based authentication
    .PARAMETER Password
        Password for credential-based authentication (not recommended for interactive use)
    .EXAMPLE
        Connect-Redmine -Server "https://sctdesk.eh.pweh.com"
        # Prompts for username and password
    .EXAMPLE
        Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Key "0123456789abcdef..."
        # Uses API key authentication
    .EXAMPLE
        Connect-Redmine -Server "https://sctdesk.eh.pweh.com" -Username "user123"
        # Prompts for password for the specified user
    .LINK
        https://github.pw.utc.com/m335619/Collateral-RedmineDB
    .NOTES
        For security reasons, it's recommended to use API key authentication or prompt for passwords
        rather than passing them as plain text parameters.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,
        
        [Parameter(ParameterSetName = 'ApiKey', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(40, 40)] # Redmine API keys are typically 40 characters
        [string]$Key,
        
        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'Interactive')]
        [string]$Username,
        
        [Parameter(ParameterSetName = 'Credential')]
        [string]$Password
    )
    
    begin {
        Write-LogInfo "Initializing connection to Redmine server: $Server"

        try {
            $uri = [System.Uri]::new($Server)
            if ($uri.Scheme -notin @('http', 'https')) {
                throw "Invalid URL scheme. Only HTTP and HTTPS are supported."
            }
            if (-not $uri.IsAbsoluteUri) {
                throw "URL must be absolute (include http:// or https://)"
            }
        }
        catch {
            throw "Invalid server URL: $_. Please provide a valid HTTP/HTTPS URL."
        }
        
        # Normalize server URL
        $Server = $Server.TrimEnd('/')
        
        # Clean up existing connections with proper error handling
        $variablesToClean = @('Redmine', 'APIKey')
        foreach ($varName in $variablesToClean) {
            $existingVar = Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue
            if ($existingVar) {
                try {
                    # If the variable has a cleanup method, call it
                    if ($existingVar.Value -and $existingVar.Value.PSObject.Methods['SignOut']) {
                        $existingVar.Value.SignOut()
                    }
                    Remove-Variable -Name $varName -Scope Script -Force
                    Write-LogInfo "Cleaned up existing $varName variable"
                }
                catch {
                    Write-LogWarn "Failed to clean up $varName`: $($_.Exception.Message)"
                }
            }
        }
    }
    
    process {
        try {
            # Test server connectivity first
            $testUri = "$Server/projects.json?limit=1"
            Write-LogInfo "Testing connectivity to: $testUri"
            
            $requestParams = @{
                Uri         = $testUri
                Method      = 'HEAD'
                TimeoutSec  = $script:ModuleConstants.DefaultTimeout
                ErrorAction = 'Stop'
                UserAgent   = $script:ModuleConstants.UserAgent
            }
            
            switch ($PSCmdlet.ParameterSetName) {
                'ApiKey' {
                    Write-LogInfo "Using API key authentication"
                    $script:APIKey = $Key
                }
                
                'Credential' {
                    Write-LogInfo "Using credential authentication with provided password"
                    if (-not $Username) { 
                        $Username = Read-Host "Enter username (or press Enter for [$env:USERNAME])"
                        if ([string]::IsNullOrWhiteSpace($Username)) { 
                            $Username = $env:USERNAME 
                        }
                    }
                    
                    $securePassword = if ($Password) { 
                        ConvertTo-SecureString $Password -AsPlainText -Force 
                    }
                    else { 
                        Read-Host "Enter password for [$Username]" -AsSecureString
                    }
                    
                    $credential = [PSCredential]::new($Username, $securePassword)
                    $requestParams.Credential = $credential
                }
                
                'Interactive' {
                    Write-LogInfo "Using interactive credential authentication"
                    if (-not $Username) { 
                        $Username = Read-Host "Enter username (or press Enter for [$env:USERNAME])"
                        if ([string]::IsNullOrWhiteSpace($Username)) { 
                            $Username = $env:USERNAME 
                        }
                    }
                    
                    $securePassword = Read-Host "Enter password for [$Username]" -AsSecureString
                    $credential = [PSCredential]::new($Username, $securePassword)
                    $requestParams.Credential = $credential
                }
            }
            
            # Create the connection
            $script:Redmine = [RedmineConnection]::new($Server, $requestParams)

            Write-LogInfo "Successfully connected to Redmine server: $Server" -Source 'SUCCESS'

            if ($script:APIKey) {
                Write-LogInfo "Authentication: API Key" -Source 'SUCCESS'
            }
            else {
                Write-LogInfo "Authentication: Credentials ($Username)"
            }
        }
        catch {
            Write-LogError "Failed to connect to Redmine server: $($_.Exception.Message)" -Exception $_.Exception
            throw
        }
    }
}

function Disconnect-Redmine {
    <#
    .SYNOPSIS
        Disconnects from the Redmine server and cleans up session variables.
    
    .DESCRIPTION
        Properly disconnects from the Redmine server by signing out of active sessions
        and removing all connection-related script variables. This function ensures
        clean termination of the Redmine connection and prevents resource leaks.
    
    .EXAMPLE
        Disconnect-Redmine
        # Disconnects from the current Redmine server and cleans up all session data
    
    .EXAMPLE
        # Use in a try/finally block to ensure cleanup
        try {
            Connect-Redmine -Server "https://redmine.example.com" -Key $apiKey
            # ... perform operations ...
        }
        finally {
            Disconnect-Redmine
        }
    
    .OUTPUTS
        None
        This function does not return any output but displays status messages.
    
    .NOTES
        This function should be called when finished working with the Redmine API
        to ensure proper cleanup of authentication tokens and session data.
        It is safe to call this function multiple times or when no connection exists.
    
    .LINK
        Connect-Redmine
    #>
    [CmdletBinding()]
    param()
    
    begin {
        Write-LogInfo "Disconnecting from Redmine server"
    }
    
    process {
        try {
            # Sign out from the server if we have an active session
            if (Get-Variable -Name 'Redmine' -Scope Script -ErrorAction SilentlyContinue) {
                if ($Script:Redmine -and $Script:Redmine.Session) {
                    $Script:Redmine.SignOut()
                }
                Remove-Variable -Name 'Redmine' -Scope Script -Force
                Write-LogInfo "Removed Redmine session variable"
            }
            
            # Clean up API key
            if (Get-Variable -Name 'APIKey' -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'APIKey' -Scope Script -Force
                Write-LogInfo "Removed API key variable"
            }
            
            Write-Host "Successfully disconnected from Redmine server" -ForegroundColor Green
        }
        catch {
            Write-LogWarn "Error during disconnect: $($_.Exception.Message)"
        }
    }
}

function Invoke-ValidateDB {
    <#
    .SYNOPSIS
        Validates and translates Redmine DB parameters for asset management operations.
    
    .DESCRIPTION
        Validates Redmine DB selection parameters against expected values and translates
        parameter aliases to their canonical names. This function ensures data integrity
        by validating all input parameters against predefined lists and formats before
        submitting to the Redmine API.
    
    .PARAMETER Name
        The name/asset tag for the database entry. This is typically a unique identifier for the asset.
    
    .PARAMETER Id
        The unique identifier for the database entry in Redmine.
    
    .PARAMETER Type
        The type/category of the asset (e.g., 'Workstation', 'Server', 'VoIP'). Default is 'Workstation'.
    
    .PARAMETER Status
        The operational status of the asset. Valid values: 'valid', 'invalid', 'to verify', or numeric equivalents (0, 1, 2).
    
    .PARAMETER Private
        Whether the entry should be marked as private. Accepts boolean values or string representations.
    
    .PARAMETER Description
        Description of the asset providing additional details about its purpose or configuration.
    
    .PARAMETER Tags
        Tags to associate with the asset for categorization and searching purposes.
    
    .PARAMETER SystemMake
        The manufacturer of the system (e.g., 'Dell', 'HP', 'Lenovo').
    
    .PARAMETER SystemModel
        The model of the system (e.g., 'Latitude 7420', 'ThinkPad X1').
    
    .PARAMETER AssetTag
        The asset tag identifier used for inventory tracking.
    
    .PARAMETER OperatingSystem
        The operating system installed on the asset. Must be validated against the approved OS list.
    
    .PARAMETER SerialNumber
        The serial number of the asset as provided by the manufacturer.
    
    .PARAMETER ParentHardware
        The parent hardware identifier for assets that are components of larger systems.
    
    .PARAMETER HostName
        The network hostname assigned to the asset.
    
    .PARAMETER HardwareLifecycle
        The hardware lifecycle stage (e.g., 'New', 'Production', 'End of Life').
    
    .PARAMETER Program
        The associated program(s) that the asset supports.
    
    .PARAMETER GSCStatus
        The Government Security Classification status for compliance tracking.
    
    .PARAMETER MACAddress
        The MAC address for network-enabled devices, particularly VoIP equipment.
    
    .PARAMETER Memory
        The system memory specification (e.g., '8 GB', '16 GB'). Must include size and unit.
    
    .PARAMETER HardDriveSize
        The storage capacity (e.g., '500 GB', '1 TB'). Must include size and unit.
    
    .PARAMETER MemoryVolatility
        The memory volatility classification. Valid values: 'Volatile', 'Non-Volatile', 'N/A'.
    
    .PARAMETER State
        The physical location state using standard state abbreviations. Default is 'CT'.
    
    .PARAMETER Building
        The building identifier where the asset is located.
    
    .PARAMETER Room
        The room identifier within the building where the asset is located.
    
    .PARAMETER RackSeat
        The rack or seat designation for data center equipment.
    
    .PARAMETER SafeAndDrawerNumber
        The safe and drawer number for secure storage locations.
    
    .PARAMETER RefreshDate
        The date when the asset was last refreshed or updated.
    
    .PARAMETER RefreshCost
        The cost associated with the last refresh or update.
    
    .PARAMETER BrassTag
        The brass tag identifier for special asset tracking.
    
    .PARAMETER KeyExpiration
        The expiration date for security keys or certificates.
    
    .PARAMETER FirmwareVersion
        The firmware version installed on the asset.
    
    .PARAMETER Notes
        Additional notes or comments about the asset.
    
    .PARAMETER Issues
        Associated issues or tickets related to the asset.
    
    .EXAMPLE
        $params = Invoke-ValidateDB -Building 'NB - S Building' -Name 'SC-123456'
        # Validates basic asset parameters
    
    .EXAMPLE
        $validParams = @{
            Type = 'VoIP'
            Status = 'valid'
            Private = $false
            Program = 'P397'
            GSCStatus = 'New'
            MemoryVolatility = 'Volatile'
            State = 'FL'
            Building = 'WPB - EOB'
            Room = 'EOB - Marlin'
        }
        $editParams = Invoke-ValidateDB @validParams
        # Validates a comprehensive set of parameters for a VoIP device
    
    .EXAMPLE
        $workstationParams = @{
            Name = 'WS-001234'
            Type = 'Workstation'
            SystemMake = 'Dell'
            SystemModel = 'Latitude 7420'
            OperatingSystem = 'Windows 11'
            Memory = '16 GB'
            HardDriveSize = '512 GB'
            State = 'CT'
            Building = 'Main Building'
            Room = 'Room 101'
        }
        $validated = Invoke-ValidateDB @workstationParams
        # Validates parameters for a workstation asset
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable of validated and normalized parameters ready for API submission.
    
    .NOTES
        This function performs extensive validation against predefined lists and formats.
        Invalid values will result in descriptive error messages indicating valid options.
        Parameter aliases are automatically converted to their canonical names.
    
    .LINK
        Connect-Redmine
        New-RedmineDB
        Edit-RedmineDB
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $Name,
        
        [Alias("#")] 
        [string] $Id,
        
        [string] $Type = 'Workstation',
        
        [ValidateSet("valid", "invalid", "to verify", 0, 1, 2)]
        [string] $Status,
        
        [Alias("is_private")] 
        [object] $Private,
        
        [string] $Description,
        
        [string[]] $Tags,
        
        [Alias("System Make", "system_make")] 
        [string] $SystemMake,
        
        [Alias("System Model", "system_model")] 
        [string] $SystemModel,
        
        [Alias("Asset Tag", "asset_tag")]
        [string] $AssetTag,
        
        [Alias("Operating System", "operating_system")]
        [ValidateOperatingSystem] $OperatingSystem,
        
        [Alias("Serial Number", "serial_number")]
        [string] $SerialNumber,
        
        [Alias("Parent Hardware", "parent_hardware")]
        [string] $ParentHardware,
        
        [Alias("Host Name", "host_name")]
        [string] $HostName,
        
        [Alias("Hardware Lifecycle", "hardware_lifecycle")]
        [ValidateLifecycle] $HardwareLifecycle,
        
        [string] $Program,
        
        [Alias("GSC Status", "gsc_status")]
        [ValidateGSCStatus] $GSCStatus,
        
        [Alias("MAC Address", "mac_address")]
        [string] $MACAddress,
        
        [ValidateSize] $Memory,
        
        [Alias("Hard Drive Size", "hard_drive_size")] 
        [ValidateSize] $HardDriveSize,
        
        [Alias("Memory Volatility", "memory_volatility")] 
        [ValidateSet("Volatile", "Non-Volatile", "N/A", "")]
        [string] $MemoryVolatility,
        
        [ValidateState] $State = 'CT',
        
        [ValidateBuilding] $Building,
        
        [ValidateRoom] $Room,
        
        [Alias("Rack/Seat", "Rack Seat", "rack_seat")] 
        [string] $RackSeat,
        
        [Alias("Safe and Drawer Number", "safe_and_drawer_number")] 
        [string] $SafeAndDrawerNumber,
        
        [Alias("Refresh Date", "refresh_date")]
        [string] $RefreshDate,
        
        [Alias("Refresh Cost", "refresh_cost")]
        [string] $RefreshCost,
        
        [Alias("Brass Tag", "brass_tag")]
        [string] $BrassTag,
        
        [Alias("Key Expiration", "key_expiration")]
        [string] $KeyExpiration,
        
        [Alias("Firmware Version", "firmware_version")]
        [string] $FirmwareVersion,
        
        [string] $Notes,
        
        [string[]] $Issues
    )
    
    begin {
        Write-LogInfo "Validating and translating DB parameters"
    }
    
    process {
        try {
            # Validate Program parameter if provided
            if ($Program) {
                $validPrograms = $script:DBvalidProgram
                $matchedProgram = $validPrograms | Where-Object { $_.ToLower() -eq $Program.ToLower() }
                if (-not $matchedProgram) {
                    throw "Invalid program: [$Program]. Valid programs are: $($validPrograms -join ', ')"
                }
            }
            
            # Handle status number to string conversion
            if ($Status -in @('0', '1', '2', 0, 1, 2)) {
                $statusKey = ($script:DBStatus.GetEnumerator() | Where-Object { $_.Value -eq $Status }).Key
                if ($statusKey) {
                    $PSBoundParameters.Status = $statusKey
                    Write-LogInfo "Converted status $Status to $statusKey"
                }
            }
            
            # Handle boolean conversion for Private parameter
            if ($PSBoundParameters.ContainsKey('Private')) {
                $PSBoundParameters.Private = switch ($Private) {
                    { $_ -in @('yes', '1', 1, 'y', 'true', $true) } { $true }
                    { $_ -in @('no', '0', 0, 'n', 'false', $false) } { $false }
                    default { [bool]$Private }
                }
                Write-LogInfo "Converted Private parameter to boolean: $($PSBoundParameters.Private)"
            }
            
            # Validate that we have either required connection
            if (-not (Get-Variable -Name 'Redmine' -Scope Script -ErrorAction SilentlyContinue)) {
                Write-LogWarn "No active Redmine connection found. Use Connect-Redmine first."
            }
            
            Write-LogInfo "Parameter validation completed successfully"
            return $PSBoundParameters
        }
        catch {
            Write-LogError "Parameter validation failed: $($_.Exception.Message)"
            throw
        }
    }
}

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
        The field to search in. Valid options: 'parent', 'type', 'serialnumber', 'program', 'hostname', 'model', 'mac', 'macaddress'
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
        https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Keyword,

        [ValidateSet('parent', 'type', 'serialnumber', 'program', 'hostname', 'model', 'mac', 'macaddress')]
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
            'model'        = $script:CustomFieldIds.SystemModel
            'serialnumber' = $script:CustomFieldIds.SerialNumber
            'parent'       = $script:CustomFieldIds.ParentHardware
            'hostname'     = $script:CustomFieldIds.HostName
            'program'      = $script:CustomFieldIds.Programs
            'mac'          = $script:CustomFieldIds.MACAddress
            'macaddress'   = $script:CustomFieldIds.MACAddress
        }
        
        # Normalize MAC address field references
        if ($Field -eq 'macaddress') {
            $Field = 'mac'
        }
        
        # Configure comparison options
        $comparisonType = if ($CaseSensitive) { 
            [StringComparison]::Ordinal 
        }
        else { 
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
            }
            else {
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
                    Write-LogDebug "Searching by model with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    $fieldId = $fieldMappings['model']
                    if ($ExactMatch) {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    }
                    else {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($null -eq $fieldValue) { return $false }
                            if ($CaseSensitive) {
                                $fieldValue -cmatch $Keyword
                            }
                            else {
                                $fieldValue -imatch $Keyword
                            }
                        }
                    }
                }

                'serialnumber' {
                    Write-LogDebug "Searching by serial number with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    $fieldId = $fieldMappings['serialnumber']
                    if ($ExactMatch) {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    }
                    else {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($null -eq $fieldValue) { return $false }
                            if ($CaseSensitive) {
                                $fieldValue -cmatch $Keyword
                            }
                            else {
                                $fieldValue -imatch $Keyword
                            }
                        }
                    }
                }
                
                'parent' { 
                    Write-LogDebug "Searching by parent ID (exact match only)"
                    $fieldId = $fieldMappings['parent']
                    # Parent ID should always be exact match
                    { param($entry) 
                        $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                        $fieldValue = if ($customField) { $customField.value } else { $null }
                        $null -ne $fieldValue -and $fieldValue -eq $Keyword
                    }
                }
                
                'hostname' { 
                    Write-LogDebug "Searching by hostname with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    $fieldId = $fieldMappings['hostname']
                    if ($ExactMatch) {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    }
                    else {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($null -eq $fieldValue) { return $false }
                            if ($CaseSensitive) {
                                $fieldValue -cmatch $Keyword
                            }
                            else {
                                $fieldValue -imatch $Keyword
                            }
                        }
                    }
                }
                
                'program' { 
                    Write-LogDebug "Searching by program with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    $fieldId = $fieldMappings['program']
                    if ($ExactMatch) {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($fieldValue -is [array]) {
                                $fieldValue -contains $Keyword
                            }
                            else {
                                $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                            }
                        }
                    }
                    else {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($fieldValue -is [array]) {
                                $fieldValue | Where-Object { 
                                    if ($CaseSensitive) {
                                        $_ -cmatch $Keyword
                                    }
                                    else {
                                        $_ -imatch $Keyword
                                    }
                                }
                            }
                            else {
                                if ($null -eq $fieldValue) { return $false }
                                if ($CaseSensitive) {
                                    $fieldValue -cmatch $Keyword
                                }
                                else {
                                    $fieldValue -imatch $Keyword
                                }
                            }
                        }
                    }
                }
                
                'mac' { 
                    Write-LogDebug "Searching by MAC address with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    $fieldId = $fieldMappings['mac']
                    if ($ExactMatch) {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            $null -ne $fieldValue -and $fieldValue.Equals($Keyword, $comparisonType)
                        }
                    }
                    else {
                        { param($entry) 
                            $customField = $entry.CustomFields | Where-Object id -eq $fieldId
                            $fieldValue = if ($customField) { $customField.value } else { $null }
                            if ($null -eq $fieldValue) { return $false }
                            if ($CaseSensitive) {
                                $fieldValue -cmatch $Keyword
                            }
                            else {
                                $fieldValue -imatch $Keyword
                            }
                        }
                    }
                }
                
                'type' { 
                    Write-LogDebug "Searching by type with ExactMatch=$ExactMatch, CaseSensitive=$CaseSensitive"
                    if ($ExactMatch) {
                        { param($entry) 
                            $null -ne $entry.Type -and $null -ne $entry.Type.name -and 
                            $entry.Type.name.Equals($Keyword, $comparisonType)
                        }
                    }
                    else {
                        { param($entry) 
                            if ($null -eq $entry.Type -or $null -eq $entry.Type.name) { return $false }
                            if ($CaseSensitive) {
                                $entry.Type.name -cmatch $Keyword
                            }
                            else {
                                $entry.Type.name -imatch $Keyword
                            }
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

function Set-RedmineDB {
    <#
    .SYNOPSIS
        Creates a new Redmine database resource object with specified parameters.
    
    .DESCRIPTION
        Constructs a new Redmine database resource object and populates it with the provided
        parameters. This function maps parameter values to the appropriate Redmine custom fields
        and prepares the object for API submission.
    
    .PARAMETER id
        The unique identifier for the database entry.
    
    .PARAMETER name
        The name or asset tag for the database entry.
    
    .PARAMETER type
        The type/category of the asset (e.g., 'Workstation', 'Server', 'VoIP').
    
    .PARAMETER status
        The operational status of the asset ('valid', 'invalid', 'to verify').
    
    .PARAMETER private
        Whether the entry should be marked as private (accepts various boolean representations).
    
    .PARAMETER description
        Description of the asset providing additional details.
    
    .PARAMETER tags
        Array of tags to associate with the asset for categorization.
    
    .PARAMETER systemMake
        The manufacturer of the system (mapped to custom field 101).
    
    .PARAMETER systemModel
        The model of the system (mapped to custom field 102).
    
    .PARAMETER operatingSystem
        The operating system installed on the asset (mapped to custom field 105).
    
    .PARAMETER serialNumber
        The serial number of the asset (mapped to custom field 106).
    
    .PARAMETER assetTag
        The asset tag identifier (mapped to custom field 107).
    
    .PARAMETER periodsProcessing
        The periods processing information (mapped to custom field 113).
    
    .PARAMETER parentHardware
        The parent hardware identifier (mapped to custom field 114).
    
    .PARAMETER hostname
        The network hostname (mapped to custom field 115).
    
    .PARAMETER hardwareLifecycle
        The hardware lifecycle stage (mapped to custom field 190).
    
    .PARAMETER programs
        Array of associated programs (mapped to custom field 116).
    
    .PARAMETER gscStatus
        The Government Security Classification status (mapped to custom field 117).
    
    .PARAMETER hardDriveSize
        The storage capacity (mapped to custom field 120).
    
    .PARAMETER memory
        The system memory specification (mapped to custom field 119).
    
    .PARAMETER memoryVolatility
        The memory volatility classification (mapped to custom field 124).
    
    .PARAMETER state
        The physical location state (mapped to custom field 109).
    
    .PARAMETER building
        The building identifier (mapped to custom field 126).
    
    .PARAMETER room
        The room identifier (mapped to custom field 127).
    
    .PARAMETER rackSeat
        The rack or seat designation.
    
    .PARAMETER node
        The node identifier for network topology.
    
    .PARAMETER safeAndDrawerNumber
        The safe and drawer number for secure storage.
    
    .PARAMETER refreshDate
        The date when the asset was last refreshed.
    
    .PARAMETER macAddress
        The MAC address for network-enabled devices.
    
    .PARAMETER notes
        Additional notes or comments about the asset.
    
    .PARAMETER issues
        Array of associated issues or tickets.
    
    .EXAMPLE
        $dbResource = Set-RedmineDB -name "WS-001234" -type "Workstation" -systemMake "Dell" -systemModel "Latitude 7420"
        # Creates a basic workstation resource object
    
    .EXAMPLE
        $serverParams = @{
            name = "SRV-001"
            type = "Server"
            systemMake = "HPE"
            systemModel = "ProLiant DL380"
            memory = "64 GB"
            hardDriveSize = "2 TB"
            operatingSystem = "Windows Server 2022"
        }
        $dbResource = Set-RedmineDB @serverParams
        # Creates a server resource object with multiple parameters
    
    .OUTPUTS
        PSCustomObject
        Returns a configured Redmine database resource object ready for API operations.
    
    .NOTES
        This function is primarily used internally by other module functions.
        The returned object contains the properly formatted data structure for Redmine API submission.
        Custom field mappings are handled automatically based on predefined field IDs.
    
    .LINK
        New-RedmineDB
        Edit-RedmineDB
        Invoke-ValidateDB
    #>
    Param (
        [String]$id,
        [String]$name,
        [String]$type,
        [String]$status,
        [string]$private,
        [String]$description,
        [String[]]$tags,
        [String]$systemMake,
        [String]$systemModel,
        [String]$operatingSystem,
        [String]$serialNumber,
        [String]$assetTag,
        [String]$periodsProcessing,
        [String]$parentHardware,
        [String]$hostname,
        [string]$hardwareLifecycle,
        [String[]]$programs,
        [String]$gscStatus,
        [String]$hardDriveSize,
        [String]$memory,
        [String]$memoryVolatility,
        [String]$state,
        [String]$building,
        [String]$room,
        [String]$rackSeat,
        [String]$node,
        [String]$safeAndDrawerNumber,
        [string]$refreshDate,
        [String]$macAddress,
        [String]$notes,
        [PSCustomObject[]]$issues
    )
	
    $resource = $Redmine.new('db')
	
    foreach ($boundparam in $PSBoundParameters.GetEnumerator()) {
        If ($null -eq $boundparam.Value) { continue }
        Switch ($boundparam.Key) {
            'private' { $resource.is_private = [bool]( @('yes', 1, '1', 'y', 'true') -contains $boundparam.Value.ToLower()) }
            'type' { $resource.type = @{ id = $script:DBType[$boundparam.Value] } }
            'status' { $resource.status = @{ id = $script:DBStatus[$boundparam.Value] } }
            'systemMake' { $resource.custom_fields += @{ id = 101; value = $boundparam.Value } }
            'systemModel' { $resource.custom_fields += @{ id = 102; value = $boundparam.Value } }
            'operatingSystem' { $resource.custom_fields += @{ id = 105; value = $boundparam.Value } }
            'serialNumber' { $resource.custom_fields += @{ id = 106; value = $boundparam.Value } }
            'assetTag' { $resource.custom_fields += @{ id = 107; value = $boundparam.Value } }
            'periodsProcessing' { $resource.custom_fields += @{ id = 113; value = $boundparam.Value } }
            'parentHardware' { $resource.custom_fields += @{ id = 114; value = $boundparam.Value } }
            'hostname' { $resource.custom_fields += @{ id = 115; value = $boundparam.Value } }
            'hardwareLifecycle' { $resource.custom_fields += @{ id = 190; value = $boundparam.Value } }
            'programs' { $resource.custom_fields += @{ id = 116; value = $boundparam.Value } }
            'gscStatus' { $resource.custom_fields += @{ id = 117; value = $boundparam.Value } }
            'memory' { $resource.custom_fields += @{ id = 119; value = $boundparam.Value } }
            'hardDriveSize' { $resource.custom_fields += @{ id = 120; value = $boundparam.Value } }
            'memoryVolatility' { $resource.custom_fields += @{ id = 124; value = $boundparam.Value } }
            'state' { $resource.custom_fields += @{ id = 109; value = $boundparam.Value } }
            'building' { $resource.custom_fields += @{ id = 126; value = $boundparam.Value } }
            'room' { $resource.custom_fields += @{ id = 127; value = $boundparam.Value } }
            'rackSeat' { $resource.custom_fields += @{ id = 112; value = $boundparam.Value } }
            'node' { $resource.custom_fields += @{ id = 125; value = $boundparam.Value } }
            'safeAndDrawerNumber' { $resource.custom_fields += @{ id = 128; value = $boundparam.Value } }
            'refreshDate' { $resource.custom_fields += @{ id = 108; value = $boundparam.Value } }
            'macAddress' { $resource.custom_fields += @{ id = 150; value = $boundparam.Value } }
            'issues' { $boundparam.Value | ForEach-Object { $resource.issues += @{ id = $_ } } }
            default {
                If ($boundparam.Key -In $resource.PSobject.Properties.Name) {
                    $resource.$($boundparam.Key) = $boundparam.Value
                }
            }
        }
    }
	
    Write-LogDebug 'Returned from Set-RedmineDB'
    Write-LogDebug ($resource | ConvertTo-Json -Depth 4)
    return $resource
}

function New-RedmineDB {
    <#
    .SYNOPSIS
        Creates a new Redmine database resource entry.
    
    .DESCRIPTION
        Creates a new asset entry in the Redmine database with the specified parameters.
        This function validates the input parameters, creates the appropriate resource object,
        and submits it to the Redmine API for creation.
    
    .PARAMETER name
        The name or asset tag for the new database entry. This should be unique.
    
    .PARAMETER type
        The type/category of the asset (e.g., 'Workstation', 'Server', 'Hard Drive', 'VoIP').
    
    .PARAMETER status
        The operational status of the asset ('valid', 'invalid', 'to verify').
    
    .PARAMETER private
        Whether the entry should be marked as private (boolean).
    
    .PARAMETER description
        Description of the asset providing additional details about its purpose or configuration.
    
    .PARAMETER tags
        Array of tags to associate with the asset for categorization and searching.
    
    .PARAMETER systemMake
        The manufacturer of the system (e.g., 'Dell', 'HP', 'TOSHIBA').
    
    .PARAMETER systemModel
        The model of the system (e.g., 'Latitude 7420', 'P5R3T84A EMC3840').
    
    .PARAMETER operatingSystem
        The operating system installed on the asset.
    
    .PARAMETER serialNumber
        The serial number of the asset as provided by the manufacturer.
    
    .PARAMETER assetTag
        The asset tag identifier used for inventory tracking.
    
    .PARAMETER periodsProcessing
        The periods processing information for the asset.
    
    .PARAMETER parentHardware
        The parent hardware identifier for assets that are components of larger systems.
    
    .PARAMETER hostname
        The network hostname assigned to the asset.
    
    .PARAMETER hardwareLifecycle
        The hardware lifecycle stage (e.g., 'New', 'Production', 'End of Life').
    
    .PARAMETER programs
        Array of associated programs that the asset supports.
    
    .PARAMETER gscStatus
        The Government Security Classification status for compliance tracking.
    
    .PARAMETER hardDriveSize
        The storage capacity (e.g., '3.8 TB', '500 GB'). Must include size and unit.
    
    .PARAMETER memory
        The system memory specification (e.g., '8 GB', '16 GB'). Must include size and unit.
    
    .PARAMETER memoryVolatility
        The memory volatility classification ('Volatile', 'Non-Volatile', 'N/A').
    
    .PARAMETER state
        The physical location state using standard state abbreviations.
    
    .PARAMETER building
        The building identifier where the asset is located.
    
    .PARAMETER room
        The room identifier within the building where the asset is located.
    
    .PARAMETER rackSeat
        The rack or seat designation for data center equipment.
    
    .PARAMETER node
        The node identifier for network topology.
    
    .PARAMETER safeAndDrawerNumber
        The safe and drawer number for secure storage locations.
    
    .PARAMETER refreshDate
        The date when the asset was last refreshed or updated.
    
    .PARAMETER macAddress
        The MAC address for network-enabled devices.
    
    .PARAMETER notes
        Additional notes or comments about the asset.
    
    .PARAMETER issues
        Array of associated issues or tickets related to the asset.
    
    .EXAMPLE
        New-RedmineDB -name "SC-005027" -type "Hard Drive" -SystemMake "TOSHIBA" -SystemModel "P5R3T84A EMC3840" `
                      -SerialNumber "90L0A0RJTT1F" -ParentHardware "12303" -Program "AETP", "Underground" `
                      -GSCStatus "Approved" -HardDriveSize "3.8 TB" -State "CT" -Building "CT - C Building" `
                      -Room "C - Data Center"
        # Creates a new hard drive asset entry with comprehensive details
    
    .EXAMPLE
        $newParams = @{
            name                = "WS-001234"
            description         = "Development workstation"
            status              = "valid"
            type                = "Workstation"
            SystemMake          = "Dell"
            SystemModel         = "Latitude 7420"
            OperatingSystem     = "Windows 11"
            SerialNumber        = "ABC123XYZ"
            Memory              = "16 GB"
            HardDriveSize       = "512 GB"
            State               = "CT"
            Building            = "Main Building"
            Room                = "Room 101"
        }
        New-RedmineDB @newParams
        # Creates a new workstation using parameter splatting
    
    .EXAMPLE
        New-RedmineDB -name "VoIP-001" -type "VoIP" -SystemMake "Cisco" -MACAddress "00:1A:2B:3C:4D:5E" `
                      -State "FL" -Building "Tampa Office" -Room "Conference Room A"
        # Creates a new VoIP device entry
    
    .OUTPUTS
        PSCustomObject
        Returns the created database entry object with all assigned properties.
    
    .NOTES
        This function requires an active Redmine connection established via Connect-Redmine.
        All parameters are validated against predefined lists and formats where applicable.
        The function will throw descriptive errors for invalid parameter values.
    
    .LINK
        Connect-Redmine
        Edit-RedmineDB
        Get-RedmineDB
        Invoke-ValidateDB
    #>
    Param (
        [String]$name,
        [String]$type,
        [String]$status,
        [bool]$private,
        [String]$description,
        [String[]]$tags,
        [String]$systemMake,
        [String]$systemModel,
        [String]$operatingSystem,
        [String]$serialNumber,
        [String]$assetTag,
        [String]$periodsProcessing,
        [String]$parentHardware,
        [String]$hostname,
        [String]$hardwareLifecycle,
        [String[]]$programs,
        [String]$gscStatus,
        [String]$hardDriveSize,
        [String]$memory,
        [String]$memoryVolatility,
        [String]$state,
        [String]$building,
        [String]$room,
        [String]$rackSeat,
        [String]$node,
        [String]$safeAndDrawerNumber,
        [string]$refreshDate,
        [String]$macAddress,
        [String]$notes,
        [PSCustomObject[]]$issues
    )
	
    $resource = Set-RedmineDB @PSBoundParameters
    $resource
    $resource.create()
}

function Get-RedmineDB {
    <#
    .SYNOPSIS
    Retrieves a Redmine database resource item by ID or name.

    .DESCRIPTION
    The Get-RedmineDB function retrieves a specific Redmine database resource item using either the 
    unique ID or the name identifier. The function supports two parameter sets for flexible retrieval
    and can return data in either PowerShell object format or JSON format.

    .PARAMETER Id
    Specifies the unique identifier of the Redmine database resource to retrieve.
    This parameter is mandatory when using the 'ID' parameter set.
    Type: String
    Parameter Set: ID
    Position: Named
    Mandatory: Yes

    .PARAMETER Name
    Specifies the name identifier of the Redmine database resource to retrieve.
    This parameter is mandatory when using the 'Name' parameter set.
    Type: String
    Parameter Set: Name
    Position: Named  
    Mandatory: Yes

    .PARAMETER AsJson
    When specified, returns the resource data in JSON format instead of PowerShell object format.
    This is useful for serialization, API responses, or when working with external systems.
    Type: Switch
    Position: Named
    Mandatory: No

    .EXAMPLE
    Get-RedmineDB -Id 438
    
    Retrieves the Redmine database resource with ID 438 and returns it as a PowerShell object.

    .EXAMPLE
    Get-RedmineDB -Name 'SC-300012'
    
    Retrieves the Redmine database resource with the name 'SC-300012' and returns it as a PowerShell object.

    .EXAMPLE
    Get-RedmineDB -Id 438 -AsJson
    
    Retrieves the Redmine database resource with ID 438 and returns it in JSON format for serialization or API use.

    .EXAMPLE
    $resource = Get-RedmineDB -Name 'SC-300012'
    if ($resource) {
        Write-Host "Found resource: $($resource.name)"
        Write-Host "Status: $($resource.status)"
    }
    
    Retrieves a resource by name and displays basic information about it.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    When -AsJson is not specified, returns a PowerShell custom object with resource properties.

    System.String
    When -AsJson is specified, returns a JSON-formatted string representation of the resource.

    .NOTES
    - Either -Id or -Name parameter must be provided (enforced by parameter sets)
    - The function uses the global Redmine connection established by Connect-Redmine
    - Returns $null if the resource is not found or if an error occurs
    - JSON output is formatted with depth of 4 levels for comprehensive serialization

    .LINK
    Connect-Redmine

    .LINK
    Set-RedmineDB

    .LINK
    New-RedmineDB

    .LINK
    Edit-RedmineDB

    .LINK
    https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding(DefaultParameterSetName = 'ID' )]
    Param (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true)]
        [String]$Id,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [switch]$AsJson
    )

    try {
        if ($Id) {
            if ($AsJson) { $Script:Redmine.DB.Get($id) | ConvertTo-Json -Depth 4; return }
            $Script:Redmine.DB.Get($id).ToPSObject() 
        }
        elseif ($Name) {
            if ($AsJson) { $Script:Redmine.DB.GetByName($name) | ConvertTo-Json -Depth 4; return }
            $Script:Redmine.DB.GetByName($name).ToPSObject()
        }
        else {
            Write-LogError "Either -Id or -Name must be provided"
            return $null
        }
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-LogError "Failed to get Redmine DB entry" -Exception $_.Exception
    }
}

function Edit-RedmineDB {
    <#
    .SYNOPSIS
    Edits an existing Redmine database resource with updated information.

    .DESCRIPTION
    The Edit-RedmineDB function updates an existing Redmine database resource with new or modified 
    information. This function accepts a comprehensive set of parameters covering all aspects of 
    hardware and system information that can be tracked in the Redmine database, including hardware
    specifications, location data, lifecycle information, and administrative details.

    .PARAMETER Id
    Specifies the unique identifier of the Redmine database resource to edit.
    This parameter is mandatory and identifies which resource will be updated.
    Type: String
    Position: Named
    Mandatory: Yes

    .PARAMETER Name
    Specifies the name or identifier for the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Type
    Specifies the type or category of the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Status
    Specifies the current status of the resource (e.g., 'valid', 'invalid', 'pending').
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Private
    Specifies whether the resource is marked as private.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Description
    Provides a detailed description of the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Tags
    Specifies an array of tags associated with the resource for categorization.
    Type: String[]
    Position: Named
    Mandatory: No

    .PARAMETER SystemMake
    Specifies the manufacturer or make of the system.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER SystemModel
    Specifies the model number or name of the system.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER OperatingSystem
    Specifies the operating system running on the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER SerialNumber
    Specifies the manufacturer's serial number of the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER AssetTag
    Specifies the organizational asset tag identifier.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER PeriodsProcessing
    Specifies information about processing periods or cycles.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER ParentHardware
    Specifies the parent hardware system this resource belongs to.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Hostname
    Specifies the network hostname of the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER HardwareLifecycle
    Specifies the current lifecycle stage of the hardware.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Programs
    Specifies an array of programs or projects associated with the resource.
    Type: String[]
    Position: Named
    Mandatory: No

    .PARAMETER GscStatus
    Specifies the GSC (General Services Catalog) status.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER HardDriveSize
    Specifies the hard drive or storage capacity.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Memory
    Specifies the memory or RAM specifications.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER MemoryVolatility
    Specifies whether the memory is volatile or non-volatile.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER State
    Specifies the geographical state or region where the resource is located.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Building
    Specifies the building where the resource is physically located.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Room
    Specifies the room within the building where the resource is located.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER RackSeat
    Specifies the rack and seat position of the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Node
    Specifies the network node identifier.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER SafeAndDrawerNumber
    Specifies the safe and drawer number for secure storage locations.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER RefreshDate
    Specifies the date when the resource information was last refreshed.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER MacAddress
    Specifies the MAC address of the network interface.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Notes
    Provides additional notes or comments about the resource.
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Issues
    Specifies an array of known issues associated with the resource.
    Type: String[]
    Position: Named
    Mandatory: No

    .EXAMPLE
    Edit-RedmineDB -Id 12307 -State 'CT' -Building 'CT - C Building' -Room 'C - Data Center'
    
    Updates the location information for resource ID 12307, setting the state to Connecticut,
    building to 'CT - C Building', and room to 'C - Data Center'.

    .EXAMPLE
    $updateParams = @{
        ID        = '8100'
        Status    = 'valid'
        Program   = 'P397'
        GSCStatus = 'Approved'
        State     = 'FL'
        Building  = 'WPB - EOB'
        Room      = 'EOB - Marlin'
    }
    Edit-RedmineDB @updateParams
    
    Uses parameter splatting to update multiple fields for resource ID 8100, including
    status, program association, GSC status, and complete location information.

    .EXAMPLE
    Edit-RedmineDB -Id 15432 -SystemMake 'Dell' -SystemModel 'PowerEdge R740' -Memory '64GB' -HardDriveSize '2TB SSD'
    
    Updates hardware specifications for resource ID 15432, including manufacturer,
    model, memory, and storage information.

    .OUTPUTS
    None
    This function does not return output but performs update operations on the Redmine database.

    .NOTES
    - The -Id parameter is mandatory and must correspond to an existing resource
    - Uses the ShouldProcess pattern for safe execution with -WhatIf and -Confirm support
    - All other parameters are optional and will only update the specified fields
    - Uses the Set-RedmineDB function internally to prepare the resource object
    - Currently the actual update operation is commented out for safety
    - Requires an active Redmine connection established by Connect-Redmine

    .LINK
    Get-RedmineDB

    .LINK
    Set-RedmineDB

    .LINK
    New-RedmineDB

    .LINK
    Connect-Redmine

    .LINK
    https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding(SupportsShouldProcess )]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$id,
        [String]$name,
        [String]$type,
        [String]$status,
        [string]$private,
        [String]$description,
        [String[]]$tags,
        [String]$systemMake,
        [String]$systemModel,
        [String]$operatingSystem,
        [String]$serialNumber,
        [String]$assetTag,
        [String]$periodsProcessing,
        [String]$parentHardware,
        [String]$hostname,
        [String]$hardwareLifecycle,
        [String[]]$programs,
        [String]$gscStatus,
        [String]$hardDriveSize,
        [String]$memory,
        [String]$memoryVolatility,
        [String]$state,
        [String]$building,
        [String]$room,
        [String]$rackSeat,
        [String]$node,
        [String]$safeAndDrawerNumber,
        [string]$refreshDate,
        [String]$macAddress,
        [String]$notes,
        [String[]]$issues
    )
	
    $resource = Set-RedmineDB @PSBoundParameters
    $resource.id = $id
    if ($pscmdlet.ShouldProcess($($resource | ConvertTo-Json), "Edit-RedmineDB")) {
        #$resource.update()
    }
}

function Edit-RedmineDBXL {
    <#
   .SYNOPSIS
    Edit multiple Redmine DB resources using a Microsoft `.xlsx` file. 
   .DESCRIPTION
    Edit multiple Redmine DB resources using a Microsoft `.xlsx` file. 
   .EXAMPLE
    Edit-RedmineDBXL -path "C:\Users\m335619\Downloads\db.xlsx" -whatif
   .EXAMPLE
    Edit-RedmineDBXL -path "C:\Users\m335619\Downloads\db.xlsx"
   .EXAMPLE
    Edit-RedmineDBXL -path "C:\Users\m335619\Downloads\db.xlsx" -StartRow 2 -StartColumn 1
   .EXAMPLE
    Edit-RedmineDBXL -path "C:\Users\m335619\Downloads\db.xlsx" -ImportColumns = @(1, 5, 6)
   .EXAMPLE
    Edit-RedmineDBXL -path "C:\Users\m335619\Downloads\db.xlsx"  -ImportColumns = @(1, 2, 3, 4, 5)
   .LINK
    https://github.pw.utc.com/m335619/DB-PSRedmine
	#>
    [CmdletBinding(DefaultParameterSetName = 'Startposition', SupportsShouldProcess )]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$path,
        [Parameter(ParameterSetName = 'Startposition')]
        [int]$StartColumn = 1,
        [Parameter(ParameterSetName = 'Startposition')]
        [int]$StartRow = 1,
        [Parameter(ParameterSetName = 'ImportColumns')]
        [int[]]$ImportColumns
    )

    try {
        # Import the module.
        Import-Module ImportExcel -ErrorAction Stop

        $ImportData = switch ($PsCmdlet.ParameterSetName) {
            ImportColumns { Import-Excel -Path $path -DataOnly -ImportColumns $ImportColumns }
            Default { Import-Excel -Path $path -DataOnly -StartRow $StartRow -StartColumn $StartColumn }
        }
    }
    catch {
        Write-LogError "Failed to import Excel data" -Exception $_.Exception
        exit
    }

    $ImportData | Foreach-Object { 
        try {
            $params = @{}
            if ($_.program) { $_.program = $_.program.split(',').trim() }
            $_.psobject.properties | ForEach-Object { $params[$_.Name] = $_.Value }
            $ValidateDB = Invoke-ValidateDB @params

            if ($WhatIf) { Edit-RedmineDB @ValidateDB -WhatIf }
            Else { Edit-RedmineDB @ValidateDB }
        }
        catch {
            Write-LogError "Failed to edit Redmine DB entry" -Exception $_.Exception
        }
    }
}

function Remove-RedmineDB {
    <#
    .SYNOPSIS
    Removes a Redmine database resource by ID or name.

    .DESCRIPTION
    The Remove-RedmineDB function permanently deletes a Redmine database resource using either 
    the unique ID or the name identifier. This operation is irreversible and should be used 
    with caution. The function supports two parameter sets for flexible resource identification.

    .PARAMETER Id
    Specifies the unique identifier of the Redmine database resource to remove.
    This parameter is mandatory when using the 'ID' parameter set.
    Type: String
    Parameter Set: ID
    Position: Named
    Mandatory: Yes

    .PARAMETER Name
    Specifies the name identifier of the Redmine database resource to remove.
    This parameter is mandatory when using the 'Name' parameter set.
    Type: String
    Parameter Set: Name
    Position: Named
    Mandatory: Yes

    .EXAMPLE
    Remove-RedmineDB -Id 9955100
    
    Removes the Redmine database resource with ID 9955100 permanently from the database.

    .EXAMPLE
    Remove-RedmineDB -Name 'SK-005027'
    
    Removes the Redmine database resource with the name 'SK-005027' permanently from the database.

    .EXAMPLE
    $resourceToDelete = Get-RedmineDB -Name 'OLD-SYSTEM-001'
    if ($resourceToDelete) {
        Remove-RedmineDB -Id $resourceToDelete.Id
        Write-Host "Successfully removed resource: $($resourceToDelete.Name)"
    }
    
    Safely removes a resource by first verifying it exists, then deleting by ID.

    .OUTPUTS
    None
    This function does not return output but performs deletion operations on the Redmine database.

    .NOTES
    - Either -Id or -Name parameter must be provided (enforced by parameter sets)
    - This operation is permanent and cannot be undone
    - The function uses the global Redmine connection established by Connect-Redmine
    - No confirmation prompt is provided - use with caution in production environments
    - Consider backing up important data before performing delete operations

    .LINK
    Get-RedmineDB

    .LINK
    Edit-RedmineDB

    .LINK
    New-RedmineDB

    .LINK
    Connect-Redmine

    .LINK
    https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding(DefaultParameterSetName = 'ID' )]
    Param (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true)]
        [String]$Id,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name
    )

    switch ($PsCmdlet.ParameterSetName) {
        ID { $Redmine.db.get($id).delete() }
        Name { $Redmine.db.getByName($name).delete() }
    }
}

function Import-RedmineEnv {
    <#
    .SYNOPSIS
    Imports environment variables from an .env configuration file.

    .DESCRIPTION
    The Import-RedmineEnv function reads configuration settings from an .env file and imports them 
    as either environment variables or PowerShell script variables. This is useful for managing 
    configuration settings, API keys, and other environment-specific values without hardcoding 
    them in scripts.

    .PARAMETER Path
    Specifies the path to the .env file to import. 
    Default: "C:\Users\$env:USERNAME\OneDrive - Raytheon Technologies\.env"
    Type: String
    Position: Named
    Mandatory: No

    .PARAMETER Type
    Determines how the variables are imported into the PowerShell session.
    Valid values:
    - 'Environment': Creates environment variables accessible via $env:VariableName
    - 'Regular': Creates PowerShell script variables accessible via $VariableName
    Default: 'Environment'
    Type: String
    Position: Named
    Mandatory: No

    .EXAMPLE
    Import-RedmineEnv
    
    Imports variables from the default .env file location as environment variables.

    .EXAMPLE
    Import-RedmineEnv -Path "C:\Config\.env"
    
    Imports variables from a custom .env file path as environment variables.

    .EXAMPLE
    Import-RedmineEnv -Type Regular
    
    Imports variables from the default .env file as PowerShell script variables instead of environment variables.

    .EXAMPLE
    Import-RedmineEnv -Path "C:\Projects\MyApp\.env" -Type Regular
    
    Imports variables from a specific .env file as PowerShell script variables.

    .EXAMPLE
    Import-RedmineEnv -WhatIf
    
    Shows what the command will do without actually importing the variables (dry run).

    .OUTPUTS
    None
    This function does not return output but creates variables in the specified scope.

    .NOTES
    - The .env file should contain key=value pairs, one per line
    - Comments and empty lines in the .env file are ignored
    - Environment variables are accessible system-wide during the session
    - Regular variables are only accessible within the PowerShell script scope
    - The function includes error handling for missing files or malformed content
    - Supports aliases: 'Dotenv', 'Import-Env'

    .LINK
    Connect-Redmine

    .LINK
    https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding()]
    [Alias('Dotenv', 'Import-Env')]
    param(
        [ValidateNotNullOrEmpty()]
        [String] $Path = "C:\Users\$env:USERNAME\OneDrive - Raytheon Technologies\.env",
        # Determines whether variables are environment variables or normal
        [ValidateSet('Environment', 'Regular')]
        [String] $Type = 'Environment'
    )

    try {
        $Env = Get-Content -raw $Path -ErrorAction Stop | ConvertFrom-StringData
        $Env.GetEnumerator() | Foreach-Object {
            $Name, $Value = $_.Name, $_.Value
            switch ($Type) {
                'Environment' { Set-Content -Path "env:\$Name" -Value $Value; Write-LogDebug '[-] Environment variables Imported....' }
                'Regular' { Set-Variable -Name $Name -Value $Value -Scope Script; Write-LogDebug '[-] Regular variables Imported....' }
            }
        }
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-LogError "Failed to import environment variables" -Exception $_.Exception
    }
}

function Invoke-DecomissionDB {
    <#
    .SYNOPSIS
    Decommissions a Redmine database resource with specified disposition or decommission status.

    .DESCRIPTION
    The Invoke-DecomissionDB function updates a Redmine database resource to mark it as decommissioned
    with appropriate status and disposition information. This function supports two parameter sets:
    'Decommissioned' for standard decommissioning workflows and 'Disposition' for vendor-related actions.
    The function automatically sets the status to 'invalid' and programs to 'None' for decommissioned items.

    .PARAMETER Id
    Specifies the unique identifier of the Redmine database resource to decommission.
    This parameter is mandatory for all parameter sets.
    Type: String
    Position: Named
    Mandatory: Yes

    .PARAMETER Decommissioned
    Specifies the decommissioning disposition for the resource.
    Valid values:
    - 'Collateral': Resource treated as collateral damage
    - 'Destruction': Resource scheduled for destruction
    - 'Reuse': Resource designated for reuse
    - 'Returned to Vendor': Resource returned to the vendor
    Parameter Set: Decommissioned
    Type: String (ValidateSet)
    Position: Named
    Mandatory: No

    .PARAMETER Disposition
    Specifies vendor-related disposition actions for the resource.
    Valid values:
    - 'Vendor Repair': Resource sent to vendor for repair
    - 'Destroyed': Resource has been destroyed
    Parameter Set: Disposition
    Type: Switch (ValidateSet)
    Position: Named
    Mandatory: No

    .EXAMPLE
    Invoke-DecomissionDB -Id 29551 -Decommissioned 'Destruction'
    
    Decommissions resource ID 29551 with destruction disposition, setting status to invalid 
    and removing all program associations.

    .EXAMPLE
    Invoke-DecomissionDB -Id 29551 -Disposition 'Vendor Repair'
    
    Sets resource ID 29551 with vendor repair disposition and removes program associations.

    .EXAMPLE
    Invoke-DecomissionDB -Id 12345 -Decommissioned 'Returned to Vendor'
    
    Decommissions resource ID 12345 as returned to vendor, marking it as invalid and 
    clearing program assignments.

    .EXAMPLE
    $resourcesToDecommission = @(29551, 29552, 29553)
    foreach ($id in $resourcesToDecommission) {
        Invoke-DecomissionDB -Id $id -Decommissioned 'Collateral'
        Write-Host "Decommissioned resource $id as collateral"
    }
    
    Bulk decommissions multiple resources with collateral disposition.

    .OUTPUTS
    None
    This function does not return output but updates the Redmine database resource status.

    .NOTES
    - Either -Decommissioned or -Disposition parameter must be provided
    - The function automatically sets status to 'invalid' for decommissioned items
    - All program associations are cleared (set to 'None') during decommissioning
    - GSC status is updated with the decommission type and disposition
    - The actual update operation is currently commented out for safety
    - Requires an active Redmine connection established by Connect-Redmine

    .LINK
    Get-RedmineDB

    .LINK
    Edit-RedmineDB

    .LINK
    Remove-RedmineDB

    .LINK
    Set-RedmineDB

    .LINK
    https://github.pw.utc.com/m335619/Collateral-RedmineDB
    #>
    [CmdletBinding(DefaultParameterSetName = 'Decommissioned' )]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Id,

        [Parameter(ParameterSetName = 'Decommissioned')]
        [ValidateSet("Collateral", "Destruction", "Reuse", "Returned to Vendor")]
        [string]$Decommissioned,

        [Parameter(ParameterSetName = 'Disposition')]
        [ValidateSet("Vendor Repair", "Destroyed")]
        [switch]$Disposition
    )
	
    $Parameters = switch ($PsCmdlet.ParameterSetName) {
        Disposition { @{ gscstatus = $Disposition ; programs = 'None' } }
        Decommissioned { @{ gscstatus = ("Decommissioned - {0}" -f $Decommissioned) ; programs = 'None'; status = 'invalid' } }
    }
		
    $resource = Set-RedmineDB @Parameters
    $resource.id = $Id
    #########$resource.update()
}
#endregion

Export-ModuleMember -Cmdlet * -Alias * -Function * -Variable @('ModuleConstants', 'CustomFieldIds')

# Module cleanup when removed
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-LogInfo "Cleaning up Collateral-RedmineDB module..."
    
    # Clean up any active connections
    if (Get-Variable -Name 'Redmine' -Scope Script -ErrorAction SilentlyContinue) {
        try {
            $script:Redmine.SignOut()
        }
        catch {
            Write-LogWarn "Failed to sign out during module cleanup: $($_.Exception.Message)"
        }
    }
    
    # Remove script variables
    $variablesToRemove = @('Redmine', 'APIKey', 'LoadedData', 'SettingsFiles')
    foreach ($varName in $variablesToRemove) {
        if (Get-Variable -Name $varName -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name $varName -Scope Script -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-LogInfo "Module cleanup completed."
}

#endregion
# Module initialization message
Write-LogInfo "Collateral-RedmineDB module v$($script:ModuleConstants.ApiVersion) loaded successfully"

