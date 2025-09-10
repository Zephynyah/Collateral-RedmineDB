<#
	===========================================================================
	 Module Name:       Collateral-RedmineDB.psm1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        10/4/2024 12:23 AM
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          Collateral-RedmineDB.psm1
	 Description:       PowerShell module for Redmine database API operations
	 Version:           1.0.1
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
    hidden [Microsoft.PowerShell.Commands.WebRequestSession] $Session
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
            $this.Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
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
    hidden [Microsoft.PowerShell.Commands.WebRequestSession] $Session
    hidden [string] $SetName = 'db'
    hidden [string] $Include = ''
    
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
    
    DB([string] $Server, [Microsoft.PowerShell.Commands.WebRequestSession] $Session) {
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
            Type        = $this.Type.name
            Status      = $this.Status.name
            Private     = $this.IsPrivate
            Project     = $this.Project.name
            Tags        = ($this.Tags.name -join ", ")
            Author      = $this.Author.name
            Description = $this.Description
            Created     = $this.CreatedOn
            Updated     = $this.UpdatedOn
        }
        
        # Add custom fields
        foreach ($field in $this.CustomFields) {
            $value = if ($field.value -is [array]) { $field.value -join ", " } else { $field.value }
            $fields | Add-Member -MemberType NoteProperty -Name $field.name -Value $value
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
                Write-LogDebug "API request successful: $Method $Uri"
                return $response
            }
            catch {
                $retryCount++
                if ($retryCount -ge $script:ModuleConstants.MaxRetries) {
                    Write-LogError "API request failed after $retryCount attempts: $Method $Uri" -Exception $_.Exception
                    throw
                }
                Write-LogWarn "API request failed, retrying ($retryCount/$($script:ModuleConstants.MaxRetries)): $Method $Uri" -Exception $_.Exception
                Start-Sleep -Seconds $retryCount
            }
        } while ($retryCount -lt $script:ModuleConstants.MaxRetries)
        return $null
    }
    # CRUD Operations
    [DB] Get([string] $Id) {
        if ([string]::IsNullOrWhiteSpace($Id)) {
            throw "ID parameter cannot be null or empty"
        }
        
        try {
            $response = $this.Request('GET', "$($this.SetName)/$Id.json$($this.Include)")
            $dbObject = [DB]::new($this.Server, $this.Session)
            
            foreach ($property in $response.db_entry.PSObject.Properties.Name) {
                if ($dbObject.PSObject.Properties.Name -contains $property) {
                    $dbObject.$property = $response.db_entry.$property
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
    
    [DB] GetByName([string] $Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw "Name parameter cannot be null or empty"
        }
        
        try {
            $encodedName = [System.Web.HttpUtility]::UrlEncode($Name)
            $response = $this.Request('GET', "db.json?name=$encodedName&limit=1")
            
            if (-not $response.db_entries -or $response.db_entries.Count -eq 0) {
                throw "No DB entry found with name: $Name"
            }
            
            $dbObject = [DB]::new($this.Server, $this.Session)
            $entry = $response.db_entries[0]
            
            foreach ($property in $entry.PSObject.Properties.Name) {
                if ($dbObject.PSObject.Properties.Name -contains $property) {
                    $dbObject.$property = $entry.$property
                }
            }
            
            Write-LogInfo "Successfully retrieved DB entry with name: $Name"
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
                    foreach ($property in $entry.PSObject.Properties.Name) {
                        if ($dbItem.PSObject.Properties.Name -contains $property) {
                            $dbItem.$property = $entry.$property
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
    static [array] $ValidStates = $script:DBvalidState

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
        https://github.pw.utc.com/m335619/RedmineDB
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
        Disconnects from the Redmine server
    .DESCRIPTION
        Properly disconnects from the Redmine server and cleans up the session variables.
    .EXAMPLE
        Disconnect-Redmine
    .LINK
        https://github.pw.utc.com/m335619/RedmineDB
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
        Validates and translates Redmine DB parameters
    .DESCRIPTION
        Validates Redmine DB selection parameters against expected values and translates
        parameter aliases to their canonical names.
    .PARAMETER Name
        The name/asset tag for the database entry
    .PARAMETER Id
        The unique identifier for the database entry
    .PARAMETER Type
        The type/category of the asset
    .PARAMETER Status
        The operational status of the asset
    .PARAMETER Private
        Whether the entry should be marked as private
    .PARAMETER Description
        Description of the asset
    .PARAMETER Tags
        Tags to associate with the asset
    .PARAMETER SystemMake
        The manufacturer of the system
    .PARAMETER SystemModel
        The model of the system
    .PARAMETER AssetTag
        The asset tag identifier
    .PARAMETER OperatingSystem
        The operating system installed on the asset
    .PARAMETER SerialNumber
        The serial number of the asset
    .PARAMETER ParentHardware
        The parent hardware identifier
    .PARAMETER HostName
        The network hostname
    .PARAMETER HardwareLifecycle
        The hardware lifecycle stage
    .PARAMETER Program
        The associated program(s)
    .PARAMETER GSCStatus
        The Government Security Classification status
    .PARAMETER MACAddress
        The MAC address (for VoIP devices)
    .PARAMETER Memory
        The system memory specification
    .PARAMETER HardDriveSize
        The storage capacity
    .PARAMETER MemoryVolatility
        The memory volatility classification
    .PARAMETER State
        The physical location state
    .PARAMETER Building
        The building identifier
    .PARAMETER Room
        The room identifier
    .PARAMETER RackSeat
        The rack or seat designation
    .PARAMETER SafeAndDrawerNumber
        The safe and drawer number
    .PARAMETER Notes
        Additional notes
    .PARAMETER Issues
        Associated issues
    .EXAMPLE
        $params = Invoke-ValidateDB -Building 'NB - S Building' -Name 'test'
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
    .LINK
        https://github.pw.utc.com/m335619/RedmineDB
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
        
        [ValidateProgram] $Program = 'Underground',
        
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
        Supports searching by parent ID, type, serial number, program, hostname, and model.
    .PARAMETER Keyword
        The search term to look for
    .PARAMETER Field
        The field to search in. Valid options: 'parent', 'type', 'serial', 'program', 'hostname', 'model'
    .PARAMETER Status
        Filter results by status. Valid options: 'valid', 'to verify', 'invalid', '*' (all)
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
        Search-RedmineDB -Field type -Keyword 'Hard Drive' -Status invalid
        # Searches by type with status filter
    .LINK
        https://github.pw.utc.com/m335619/RedmineDB
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Keyword,

        [ValidateSet('parent', 'type', 'serial', 'program', 'hostname', 'model', 'mac', 'macaddress')]
        [string] $Field = 'name',
        
        [ValidateSet('valid', 'to verify', 'invalid', '*')]
        [string] $Status = '*'
    )
    
    begin {
        Write-LogInfo "Searching DB entries with keyword: '$Keyword', field: '$Field', status: '$Status'"
        
        # Verify connection
        if (-not $Script:Redmine -or -not $Script:Redmine.DB) {
            throw "Not connected to Redmine server. Use Connect-Redmine first."
        }
        
        # Custom field ID mappings for search
        $fieldMappings = @{
            'model'      = 102
            'serial'     = 106
            'parent'     = 114
            'hostname'   = 115
            'program'    = 116
            'mac'        = 150
            'macaddress' = 150
        }
    }
    
    process {
        try {
            # Build filter string
            $filter = if ($Status -ne '*') {
                "&status_id=$($script:DBStatus[$Status])"
            }
            else {
                "&status_id=*"
            }
            
            # Get all entries with filter
            $collection = $Script:Redmine.DB.GetAll($filter)
            
            if ($collection.Count -eq 0) {
                Write-LogInfo "No entries found matching the criteria"
                return
            }
            
            Write-LogInfo "Retrieved $($collection.Count) entries, filtering by field '$Field'"
            
            # Create search predicate based on field
            $searchPredicate = switch ($Field) {
                'model' { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings['model']).value -match $Keyword 
                    }
                }
                'serial' { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings['serial']).value -match $Keyword 
                    }
                }
                'parent' { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings['parent']).value -eq $Keyword 
                    }
                }
                'hostname' { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings['hostname']).value -match $Keyword 
                    }
                }
                'program' { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings['program']).value -contains $Keyword 
                    }
                }
                { $_ -in 'mac', 'macaddress' } { 
                    { param($entry) 
                        ($entry.CustomFields | Where-Object id -eq $fieldMappings[$_]).value -match $Keyword 
                    }
                }
                'type' { 
                    { param($entry) 
                        $entry.Type.name -match $Keyword 
                    }
                }
                default { 
                    { param($entry) 
                        $entry.Name -match $Keyword 
                    }
                }
            }
            
            # Filter entries and collect results
            $filteredResults = @{}
            
            foreach ($id in $collection.Keys) {
                $entry = $collection[$id]
                if (& $searchPredicate $entry) {
                    $filteredResults[$id] = $entry
                }
            }
            
            $resultCount = $filteredResults.Count
            Write-LogInfo "Found $resultCount matching entries"
            
            if ($resultCount -eq 0) {
                Write-Information "No entries found matching keyword '$Keyword' in field '$Field'" -InformationAction Continue
                return
            }
            
            # Convert to PSObjects and return
            $results = $filteredResults.Values | ForEach-Object { $_.ToPSObject() }
            return $results
        }
        catch {
            Write-LogError "Search operation failed: $($_.Exception.Message)"
            throw
        }
    }
}

function Set-RedmineDB {
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
    Create a new Redmine resource
   .DESCRIPTION
    Create a new Redmine resource
   .EXAMPLE
	New-RedmineDB -name "SC-005027" -type "Hard Drive" -SystemMake "TOSHIBA" -SystemModel "P5R3T84A EMC3840" `
              -SerialNumber  "90L0A0RJTT1F" -ParentHardware "12303" -Program  "AETP", "Underground" `
			  -GSCStatus "Approved" -HardDriveSize "3.8 TB" -State  "CT" -Building  "CT - C Building" `
			  -Room  "C - Data Center"
   .EXAMPLE
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
		Program             = "AETP", "Underground"
		GSCStatus           = "Approved"
		HardDriveSize       = "3.8 TB"
		MemoryVolatility    = ""
		State               = "CT"
		Building            = "CT - C Building"
		Room                = "C - Data Center"
		RackSeat            = ""
		SafeandDrawerNumber = ""
	}

	New-RedmineDB @newParams
   .LINK
    https://github.pw.utc.com/m335619/RedmineDB
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
    Get Redmine resource item by id or name
   .DESCRIPTION
    Get Redmine resource item by id or name
   .EXAMPLE
    Get-RedmineDB -id 438
   .EXAMPLE
    Get-RedmineDB -name 'SC-300012'
   .LINK
    https://github.pw.utc.com/m335619/RedmineDB
	#>
    [CmdletBinding(DefaultParameterSetName = 'ID' )]
    Param (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true)]
        [String]$Id,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name
    )

    switch ($PsCmdlet.ParameterSetName) {
        ID { $Redmine.db.get($id).to_psobject() }
        Name { $Redmine.db.getByName($name).to_psobject() }
    } 	
}

function Edit-RedmineDB {
    <#
   .SYNOPSIS
    Edit a Redmine resource
   .DESCRIPTION
    Edit a Redmine resource
   .EXAMPLE
  	Edit-RedmineDB -id 12307 -State 'CT' -Building 'CT - C Building' -Room 'C - Data Center'
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
   .LINK
    https://github.pw.utc.com/m335619/RedmineDB
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
    Remove a Redmine resource
   .DESCRIPTION
    Remove a Redmine DB Entry.
   .EXAMPLE
    Remove-RedmineDB id 9955100
   .EXAMPLE
    Remove-RedmineDB -name SK-005027
   .LINK
    https://github.pw.utc.com/m335619/RedmineDB
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
	 Imports variables from an ENV file
	.EXAMPLE
	 Import-RedmineEnv
	.EXAMPLE
	 Import-RedmineEnv path/to/env
	.EXAMPLE
	 See what the command will do before it runs
	 Import-RedmineEnv -whatif
	.EXAMPLE
	 Import-RedmineEnv -type regular
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
    Decomission a Redmine resource
   .DESCRIPTION
    Decomission a Redmine DB Entry.
   .EXAMPLE
    Invoke-DecomissionDB -id 29551 -Decommissioned Destruction
   .EXAMPLE
    Invoke-DecomissionDB -id 29551 -Disposition
   .LINK
    https://github.pw.utc.com/m335619/RedmineDB
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

Export-ModuleMember -Cmdlet * -Alias * -Function * -Variable *

# Module cleanup when removed
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-LogInfo "Cleaning up Collateral-RedmineDB module..."
    
    # Clean up any active connections
    if (Get-Variable -Name 'Redmine' -Scope Script -ErrorAction SilentlyContinue) {
        try {
            $script:Redmine.SignOut()
        } catch {
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

