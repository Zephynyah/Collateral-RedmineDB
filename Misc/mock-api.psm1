<#
	===========================================================================
	 Module Name:       mock-api.psm1
	 Created with:      SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:        9/10/2025
	 Created by:        Jason Hickey
	 Organization:      House of Powershell
	 Filename:          mock-api.psm1
	 Description:       Mock API middleware for simulating Redmine API responses
	 Version:           1.0.0
	 Last Modified:     2025-09-10
	-------------------------------------------------------------------------
	 Copyright (c) 2025 Jason Hickey. All rights reserved.
	 Licensed under the MIT License.
	===========================================================================
#>

#Requires -Version 5.0

# Simple logging functions for mock API (fallback when main logging module not available)
function Write-LogInfo {
    param([string]$Message, [string]$Source = "MockAPI")
    Write-Host "[INFO] [$Source] $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message, [Exception]$Exception = $null, [string]$Source = "MockAPI")
    Write-Host "[ERROR] [$Source] $Message" -ForegroundColor Red
    if ($Exception) {
        Write-Host "[ERROR] [$Source] Exception: $($Exception.Message)" -ForegroundColor Red
    }
}

function Write-LogDebug {
    param([string]$Message, [string]$Source = "MockAPI")
    if ($DebugPreference -ne 'SilentlyContinue') {
        Write-Host "[DEBUG] [$Source] $Message" -ForegroundColor Cyan
    }
}

# Module-level variables
$script:MockDataCache = $null
$script:MockDataPath = $null
$script:MockMode = $false
$script:RequestLog = @()
$script:OriginalInvokeRestMethod = $null

# Mock API configuration
$script:MockConfig = @{
    DefaultLimit = 2000
    MaxLimit = 5000
    DefaultOffset = 0
    SimulateNetworkDelay = $false
    NetworkDelayMs = 100
    EnableRequestLogging = $true
    ValidateApiKey = $true
    RequiredApiKey = "mock-api-key-12345-67890-abcdef-ghijkl40"
}

function Initialize-MockAPI {
    <#
    .SYNOPSIS
        Initialize the mock API with data from JSON file
    .DESCRIPTION
        Loads the mock data from the specified JSON file and enables mock mode.
        This allows testing all Redmine API endpoints without a live server.
    .PARAMETER DataPath
        Path to the JSON file containing mock database entries
    .PARAMETER EnableNetworkDelay
        Simulate network delays for more realistic testing
    .PARAMETER DelayMs
        Network delay in milliseconds (default: 100ms)
    .PARAMETER ApiKey
        Mock API key for authentication simulation (optional)
    .EXAMPLE
        Initialize-MockAPI -DataPath "Data\db-small.json"
    .EXAMPLE
        Initialize-MockAPI -DataPath "Data\db-small.json" -EnableNetworkDelay -DelayMs 200
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string] $DataPath,
        
        [switch] $EnableNetworkDelay,
        
        [int] $DelayMs = 100,
        
        [string] $ApiKey = "mock-api-key-12345-67890-abcdef-ghijkl40"
    )
    
    try {
        Write-LogInfo "Initializing Mock API with data from: $DataPath"
        
        # Store configuration
        $script:MockDataPath = $DataPath
        $script:MockConfig.SimulateNetworkDelay = $EnableNetworkDelay
        $script:MockConfig.NetworkDelayMs = $DelayMs
        $script:MockConfig.RequiredApiKey = $ApiKey
        
        # Load and cache the mock data
        Write-LogInfo "Loading mock data from JSON file..."
        $jsonContent = Get-Content -Path $DataPath -Raw -Encoding UTF8
        $script:MockDataCache = $jsonContent | ConvertFrom-Json
        
        $entryCount = $script:MockDataCache.db_entries.Count
        $totalCount = $script:MockDataCache.total_count
        
        Write-LogInfo "Mock data loaded successfully:"
        Write-LogInfo "  - Entries in cache: $entryCount"
        Write-LogInfo "  - Total count: $totalCount"
        
        # Enable mock mode
        $script:MockMode = $true
        
        # Clear request log
        $script:RequestLog = @()
        
        Write-LogInfo "Mock API initialized and enabled"
        return $true
    }
    catch {
        Write-LogError "Failed to initialize Mock API: $($_.Exception.Message)" -Exception $_.Exception
        $script:MockMode = $false
        throw
    }
}

function Disable-MockAPI {
    <#
    .SYNOPSIS
        Disable mock API mode and clear cached data
    .DESCRIPTION
        Disables mock mode and clears all cached data from memory
    .EXAMPLE
        Disable-MockAPI
    #>
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Disabling Mock API"
    
    $script:MockMode = $false
    $script:MockDataCache = $null
    $script:MockDataPath = $null
    $script:RequestLog = @()
    
    Write-LogInfo "Mock API disabled and cache cleared"
}

function Test-MockAPIEnabled {
    <#
    .SYNOPSIS
        Check if mock API mode is currently enabled
    .DESCRIPTION
        Returns true if mock mode is enabled and data is loaded
    .EXAMPLE
        if (Test-MockAPIEnabled) { Write-Host "Mock mode active" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    return ($script:MockMode -and $null -ne $script:MockDataCache)
}

function Get-MockAPIRequestLog {
    <#
    .SYNOPSIS
        Get the log of mock API requests
    .DESCRIPTION
        Returns an array of all mock API requests that have been made
    .EXAMPLE
        Get-MockAPIRequestLog | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()
    
    return $script:RequestLog
}

function Clear-MockAPIRequestLog {
    <#
    .SYNOPSIS
        Clear the mock API request log
    .DESCRIPTION
        Clears all logged mock API requests
    .EXAMPLE
        Clear-MockAPIRequestLog
    #>
    [CmdletBinding()]
    param()
    
    $script:RequestLog = @()
    Write-LogInfo "Mock API request log cleared"
}

function Invoke-MockAPIRequest {
    <#
    .SYNOPSIS
        Process a mock API request and return simulated response
    .DESCRIPTION
        Intercepts API requests and returns mock responses based on the loaded data.
        Simulates all Redmine API endpoints including pagination, filtering, and CRUD operations.
    .PARAMETER Method
        HTTP method (GET, POST, PUT, DELETE)
    .PARAMETER Uri
        The API endpoint URI
    .PARAMETER Headers
        Request headers (for API key validation)
    .PARAMETER Body
        Request body (for POST/PUT operations)
    .PARAMETER TimeoutSec
        Request timeout (ignored in mock mode)
    .EXAMPLE
        $response = Invoke-MockAPIRequest -Method GET -Uri "db.json?limit=10"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'HEAD')]
        [string] $Method,
        
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        
        [hashtable] $Headers = @{},
        
        [string] $Body,
        
        [int] $TimeoutSec = 30
    )
    
    if (-not (Test-MockAPIEnabled)) {
        throw "Mock API is not enabled. Use Initialize-MockAPI first."
    }
    
    try {
        # Log the request
        $requestInfo = [PSCustomObject]@{
            Timestamp = Get-Date
            Method = $Method
            Uri = $Uri
            Headers = $Headers
            BodyLength = if ($Body) { $Body.Length } else { 0 }
        }
        
        if ($script:MockConfig.EnableRequestLogging) {
            $script:RequestLog += $requestInfo
        }
        
        Write-LogDebug "Mock API Request: $Method $Uri"
        
        # Simulate network delay if enabled
        if ($script:MockConfig.SimulateNetworkDelay) {
            Start-Sleep -Milliseconds $script:MockConfig.NetworkDelayMs
        }
        
        # Validate API key if required
        if ($script:MockConfig.ValidateApiKey) {
            $apiKey = $null
            if ($Headers.ContainsKey('X-Redmine-API-Key')) {
                $apiKey = $Headers['X-Redmine-API-Key']
            }
            elseif ($Uri -match '[?&]key=([^&]+)') {
                $apiKey = $matches[1]
            }
            
            if ($apiKey -ne $script:MockConfig.RequiredApiKey) {
                return [PSCustomObject]@{
                    StatusCode = 401
                    Content = @{
                        errors = @("API key is invalid")
                    } | ConvertTo-Json
                    Headers = @{}
                }
            }
        }
        
        # Parse the URI to extract endpoint and parameters
        $parsedUri = [System.Uri]::new($Uri)
        $path = $parsedUri.AbsolutePath.TrimStart('/')
        $queryParams = @{}
        
        if ($parsedUri.Query) {
            $parsedUri.Query.TrimStart('?').Split('&') | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = [System.Web.HttpUtility]::UrlDecode($matches[1])
                    $value = [System.Web.HttpUtility]::UrlDecode($matches[2])
                    $queryParams[$key] = $value
                }
            }
        }
        
        Write-LogDebug "Parsed path: $path, Query params: $($queryParams | ConvertTo-Json -Compress)"
        
        # Route the request to appropriate handler
        $response = switch -Regex ($path) {
            '^db\.json$' {
                Invoke-MockDBList -Method $Method -QueryParams $queryParams -Body $Body
            }
            '^db/(\d+)\.json$' {
                $id = $matches[1]
                Invoke-MockDBSingle -Method $Method -Id $id -QueryParams $queryParams -Body $Body
            }
            '^projects/(\d+)/db\.json$' {
                $projectId = $matches[1]
                Invoke-MockDBCreate -Method $Method -ProjectId $projectId -QueryParams $queryParams -Body $Body
            }
            '^projects\.json$' {
                Invoke-MockProjectsList -Method $Method -QueryParams $queryParams
            }
            default {
                # Return 404 for unknown endpoints
                [PSCustomObject]@{
                    StatusCode = 404
                    Content = @{
                        errors = @("Not Found")
                    } | ConvertTo-Json
                    Headers = @{}
                }
            }
        }
        
        Write-LogDebug "Mock API Response: Status $($response.StatusCode)"
        return $response
    }
    catch {
        Write-LogError "Mock API request failed: $($_.Exception.Message)" -Exception $_.Exception
        
        return [PSCustomObject]@{
            StatusCode = 500
            Content = @{
                errors = @("Internal server error: $($_.Exception.Message)")
            } | ConvertTo-Json
            Headers = @{}
        }
    }
}

function Invoke-MockDBList {
    <#
    .SYNOPSIS
        Handle mock DB list requests (GET /db.json)
    #>
    [CmdletBinding()]
    param(
        [string] $Method,
        [hashtable] $QueryParams,
        [string] $Body
    )
    
    if ($Method -ne 'GET') {
        return [PSCustomObject]@{
            StatusCode = 405
            Content = @{ errors = @("Method not allowed") } | ConvertTo-Json
            Headers = @{}
        }
    }
    
    # Extract pagination parameters
    $limit = [int]($QueryParams['limit'] ?? $script:MockConfig.DefaultLimit)
    $offset = [int]($QueryParams['offset'] ?? $script:MockConfig.DefaultOffset)
    
    # Limit validation
    if ($limit -gt $script:MockConfig.MaxLimit) {
        $limit = $script:MockConfig.MaxLimit
    }
    
    # Get all entries
    $allEntries = $script:MockDataCache.db_entries
    
    # Apply status filter if specified
    if ($QueryParams.ContainsKey('status_id') -and $QueryParams['status_id'] -ne '*') {
        $statusId = [int]$QueryParams['status_id']
        $allEntries = $allEntries | Where-Object { $_.status.id -eq $statusId }
    }
    
    # Apply other filters (name, type, etc.)
    if ($QueryParams.ContainsKey('name')) {
        $nameFilter = $QueryParams['name']
        $allEntries = $allEntries | Where-Object { $_.name -like "*$nameFilter*" }
    }
    
    $totalCount = $allEntries.Count
    
    # Apply pagination
    $pagedEntries = $allEntries | Select-Object -Skip $offset -First $limit
    
    Write-LogDebug "Mock DB List: offset=$offset, limit=$limit, total=$totalCount, returned=$($pagedEntries.Count)"
    
    $response = [PSCustomObject]@{
        db_entries = $pagedEntries
        total_count = $totalCount
        offset = $offset
        limit = $limit
    }
    
    return [PSCustomObject]@{
        StatusCode = 200
        Content = $response | ConvertTo-Json -Depth 10
        Headers = @{
            'Content-Type' = 'application/json'
        }
    }
}

function Invoke-MockDBSingle {
    <#
    .SYNOPSIS
        Handle mock single DB entry requests (GET/PUT/DELETE /db/{id}.json)
    #>
    [CmdletBinding()]
    param(
        [string] $Method,
        [string] $Id,
        [hashtable] $QueryParams,
        [string] $Body
    )
    
    $entryId = [int]$Id
    $entry = $script:MockDataCache.db_entries | Where-Object { $_.id -eq $entryId } | Select-Object -First 1
    
    switch ($Method) {
        'GET' {
            if (-not $entry) {
                return [PSCustomObject]@{
                    StatusCode = 404
                    Content = @{ errors = @("DB entry not found") } | ConvertTo-Json
                    Headers = @{}
                }
            }
            
            $response = [PSCustomObject]@{
                db_entry = $entry
            }
            
            return [PSCustomObject]@{
                StatusCode = 200
                Content = $response | ConvertTo-Json -Depth 10
                Headers = @{ 'Content-Type' = 'application/json' }
            }
        }
        
        'PUT' {
            if (-not $entry) {
                return [PSCustomObject]@{
                    StatusCode = 404
                    Content = @{ errors = @("DB entry not found") } | ConvertTo-Json
                    Headers = @{}
                }
            }
            
            # For PUT requests, we simulate a successful update
            # In a real implementation, you would update the entry with the new data
            Write-LogInfo "Mock API: Simulating update of DB entry $Id"
            
            return [PSCustomObject]@{
                StatusCode = 200
                Content = ""
                Headers = @{}
            }
        }
        
        'DELETE' {
            if (-not $entry) {
                return [PSCustomObject]@{
                    StatusCode = 404
                    Content = @{ errors = @("DB entry not found") } | ConvertTo-Json
                    Headers = @{}
                }
            }
            
            # For DELETE requests, we simulate a successful deletion
            Write-LogInfo "Mock API: Simulating deletion of DB entry $Id"
            
            return [PSCustomObject]@{
                StatusCode = 200
                Content = ""
                Headers = @{}
            }
        }
        
        default {
            return [PSCustomObject]@{
                StatusCode = 405
                Content = @{ errors = @("Method not allowed") } | ConvertTo-Json
                Headers = @{}
            }
        }
    }
}

function Invoke-MockDBCreate {
    <#
    .SYNOPSIS
        Handle mock DB creation requests (POST /projects/{id}/db.json)
    #>
    [CmdletBinding()]
    param(
        [string] $Method,
        [string] $ProjectId,
        [hashtable] $QueryParams,
        [string] $Body
    )
    
    if ($Method -ne 'POST') {
        return [PSCustomObject]@{
            StatusCode = 405
            Content = @{ errors = @("Method not allowed") } | ConvertTo-Json
            Headers = @{}
        }
    }
    
    # Simulate creating a new DB entry
    $newId = ($script:MockDataCache.db_entries | Measure-Object -Property id -Maximum).Maximum + 1
    
    Write-LogInfo "Mock API: Simulating creation of new DB entry with ID $newId"
    
    # Parse the request body to extract the new entry data
    $newEntryData = $null
    if ($Body) {
        try {
            $bodyObj = $Body | ConvertFrom-Json
            $newEntryData = $bodyObj.db_entry
        }
        catch {
            return [PSCustomObject]@{
                StatusCode = 400
                Content = @{ errors = @("Invalid JSON in request body") } | ConvertTo-Json
                Headers = @{}
            }
        }
    }
    
    # Create a mock response for the new entry
    $newEntry = [PSCustomObject]@{
        id = $newId
        project = @{ id = [int]$ProjectId; name = "Change Control" }
        name = $newEntryData.name ?? "New-Entry-$newId"
        description = $newEntryData.description
        status = @{ id = 0; name = "valid" }
        is_private = $newEntryData.is_private ?? $false
        type = $newEntryData.type ?? @{ id = 1; name = "Workstation" }
        author = @{ id = 1; name = "Mock User" }
        tags = @()
        custom_fields = $newEntryData.custom_fields ?? @()
        created_on = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        updated_on = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $response = [PSCustomObject]@{
        db_entry = $newEntry
    }
    
    return [PSCustomObject]@{
        StatusCode = 201
        Content = $response | ConvertTo-Json -Depth 10
        Headers = @{ 'Content-Type' = 'application/json' }
    }
}

function Invoke-MockProjectsList {
    <#
    .SYNOPSIS
        Handle mock projects list requests (GET /projects.json)
    #>
    [CmdletBinding()]
    param(
        [string] $Method,
        [hashtable] $QueryParams
    )
    
    if ($Method -ne 'GET') {
        return [PSCustomObject]@{
            StatusCode = 405
            Content = @{ errors = @("Method not allowed") } | ConvertTo-Json
            Headers = @{}
        }
    }
    
    # Return a mock project list
    $projects = @(
        [PSCustomObject]@{
            id = 25
            name = "Change Control"
            identifier = "change-control"
            description = "Collateral Management System"
            status = 1
            created_on = "2020-01-01T00:00:00Z"
            updated_on = "2025-01-01T00:00:00Z"
        }
    )
    
    $response = [PSCustomObject]@{
        projects = $projects
        total_count = $projects.Count
        offset = 0
        limit = 25
    }
    
    return [PSCustomObject]@{
        StatusCode = 200
        Content = $response | ConvertTo-Json -Depth 10
        Headers = @{ 'Content-Type' = 'application/json' }
    }
}

# Override Invoke-RestMethod when mock mode is enabled
function Invoke-RestMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        
        [string] $Method = 'GET',
        
        [hashtable] $Headers = @{},
        
        [string] $Body,
        
        [string] $ContentType,
        
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,
        
        [int] $TimeoutSec = 30,
        
        [switch] $UseBasicParsing,
        
        [System.Management.Automation.PSCredential] $Credential
    )
    
    # Check if mock mode is enabled and this is a Redmine API call
    if ((Test-MockAPIEnabled) -and ($Uri -match '(localhost|redmine|sctdesk).*\.(json|xml)')) {
        Write-LogDebug "Intercepting API call for mock processing: $Uri"
        
        $mockResponse = Invoke-MockAPIRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -TimeoutSec $TimeoutSec
        
        if ($mockResponse.StatusCode -ge 400) {
            # Simulate HTTP error
            $errorMessage = "Mock API returned status $($mockResponse.StatusCode)"
            if ($mockResponse.Content) {
                $errorContent = $mockResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($errorContent.errors) {
                    $errorMessage += ": $($errorContent.errors -join ', ')"
                }
            }
            throw $errorMessage
        }
        
        # Return the mock response content as an object
        if ($mockResponse.Content) {
            return $mockResponse.Content | ConvertFrom-Json
        }
        return $null
    }
    
    # Call the original Invoke-RestMethod for non-Redmine URLs
    $originalFunction = Get-Command -Name 'Invoke-RestMethod' -CommandType Cmdlet
    return & $originalFunction @PSBoundParameters
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-MockAPI',
    'Disable-MockAPI', 
    'Test-MockAPIEnabled',
    'Get-MockAPIRequestLog',
    'Clear-MockAPIRequestLog',
    'Invoke-MockAPIRequest',
    'Invoke-RestMethod'
)
