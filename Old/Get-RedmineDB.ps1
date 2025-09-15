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
    [CmdletBinding(DefaultParameterSetName = 'ID')]
    Param (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true)]
        [String]$Id,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Random')]
        [string]$Random = 1,
        [switch]$AsJson
    )

    try {

        if ($Id) { $Result =  $Script:Redmine.DB.Get($id)}
        elseif ($Name) {  $Result =  $Script:Redmine.DB.GetByName($name)}
        elseif ($Random) {
            $allEntries = $Script:Redmine.DB.GetAll()
            if ($allEntries.Count -eq 0) {
                Write-LogInfo "No entries found in the Redmine database."
                return $null
            }
            $randomKey = (Get-Random -InputObject $($allEntries.Keys) -Count $Random)
            $Result = $Script:Redmine.DB.Get($randomKey)
        }
        else {
            Write-LogError "Either -Id, -Name or -Random must be provided."
            return $null
        }

        if ($AsJson) { return ($Result | ConvertTo-Json -Depth 4)}
        else { return $Result.ToPSObject()}
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-LogError "Failed to get Redmine DB entry" -Exception $_.Exception
    }
}
