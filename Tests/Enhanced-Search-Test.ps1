#Requires -Modules Pester

# Enhanced search test to demonstrate comprehensive search capabilities
Import-Module "$PSScriptRoot\..\Collateral-RedmineDB.psm1" -Force

function Search-RedmineDBEnhanced {
    <#
    .SYNOPSIS
        Enhanced search that includes name, ID, and custom fields
    .DESCRIPTION
        Extends the existing Search-RedmineDB to also search by name and ID fields
    .PARAMETER Keyword
        The search term to look for
    .PARAMETER Field
        The field to search in. Includes 'name', 'id' plus all existing custom fields
    .PARAMETER Status
        Filter results by status
    .PARAMETER CaseSensitive
        Perform case-sensitive search
    .PARAMETER ExactMatch
        Perform exact match instead of partial match
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Keyword,

        [ValidateSet('name', 'id', 'parent', 'type', 'serialnumber', 'program', 'hostname', 'model', 'mac', 'macaddress')]
        [string] $Field = 'name',
        
        [ValidateSet('valid', 'to verify', 'invalid', '*')]
        [string] $Status = '*',
        
        [switch] $CaseSensitive,
        [switch] $ExactMatch
    )
    
    Write-Host "Enhanced Search: Field='$Field', Keyword='$Keyword', Status='$Status'" -ForegroundColor Cyan
    
    # For custom fields, use the existing Search-RedmineDB
    if ($Field -in @('parent', 'type', 'serialnumber', 'program', 'hostname', 'model', 'mac', 'macaddress')) {
        Write-Host "  → Using custom field search" -ForegroundColor Yellow
        return Search-RedmineDB -Keyword $Keyword -Field $Field -Status $Status -CaseSensitive:$CaseSensitive -ExactMatch:$ExactMatch
    }
    
    # For name and ID, implement direct search using API calls
    Write-Host "  → Using direct field search" -ForegroundColor Yellow
    
    # Use direct API call to get all entries (like the original function does)
    try {
        # Build the API URL with status filter
        $baseUrl = $Script:Redmine.Server
        $apiKey = $Script:APIKey
        $url = "$baseUrl/db.json?key=$apiKey"
        
        if ($Status -ne '*') {
            $statusId = $script:DBStatus[$Status]
            $url += "&status_id=$statusId"
        }
        
        Write-Host "  → Making API call to retrieve entries..." -ForegroundColor Gray
        $response = Invoke-RestMethod -Uri $url -Method GET -ContentType "application/json"
        $allEntries = $response.db_entries
        
        Write-Host "  → Retrieved $($allEntries.Count) entries" -ForegroundColor Gray
        
        $results = @()
        $matchCount = 0
        
        foreach ($entry in $allEntries) {
            $isMatch = $false
            
            switch ($Field) {
                'name' {
                    $fieldValue = $entry.name
                    if ($ExactMatch) {
                        $isMatch = if ($CaseSensitive) { 
                            $fieldValue -ceq $Keyword 
                        } else { 
                            $fieldValue -ieq $Keyword 
                        }
                    } else {
                        $isMatch = if ($CaseSensitive) { 
                            $fieldValue -cmatch $Keyword 
                        } else { 
                            $fieldValue -imatch $Keyword 
                        }
                    }
                }
                'id' {
                    $fieldValue = $entry.id.ToString()
                    $isMatch = if ($ExactMatch) {
                        $fieldValue -eq $Keyword
                    } else {
                        $fieldValue -match $Keyword
                    }
                }
            }
            
            if ($isMatch) {
                $matchCount++
                # Convert to the expected format
                $entryObj = [PSCustomObject]@{
                    ID = $entry.id
                    Name = $entry.name
                    Description = $entry.description
                    Type = if ($entry.type) { $entry.type.name } else { "" }
                    Status = if ($entry.status) { $entry.status.name } else { "" }
                    Private = $entry.is_private
                    Project = if ($entry.project) { $entry.project.name } else { "" }
                    Tags = $entry.tags -join ","
                    Author = if ($entry.author) { $entry.author.name } else { "" }
                    Created = $entry.created_on
                    Updated = $entry.updated_on
                }
                $results += $entryObj
            }
        }
        
        Write-Host "  → Found $matchCount matching entries" -ForegroundColor Green
        return $results
    }
    catch {
        Write-Host "  → Error: $_" -ForegroundColor Red
        return @()
    }
}

Write-Host "=== Enhanced Search Testing ===" -ForegroundColor Green

# Connect to server
Write-Host "Connecting to server..." -ForegroundColor Yellow
Connect-Redmine -Server "http://localhost:3000/api" -Key "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"

# Test 1: Search by name (should find the entry)
Write-Host "`n1. Testing name search for '00-008584'..." -ForegroundColor Yellow
$nameResults = Search-RedmineDBEnhanced -Field name -Keyword "00-008584" -ExactMatch
Write-Host "✓ Found $($nameResults.Count) entries by name" -ForegroundColor Green
if ($nameResults.Count -gt 0) {
    Write-Host "  Entry: $($nameResults[0].Name) (ID: $($nameResults[0].ID))" -ForegroundColor Cyan
}

# Test 2: Search by partial name
Write-Host "`n2. Testing partial name search for '00-'..." -ForegroundColor Yellow
$partialResults = Search-RedmineDBEnhanced -Field name -Keyword "00-"
Write-Host "✓ Found $($partialResults.Count) entries with partial name match" -ForegroundColor Green

# Test 3: Search by ID
Write-Host "`n3. Testing ID search for '18721'..." -ForegroundColor Yellow
$idResults = Search-RedmineDBEnhanced -Field id -Keyword "18721" -ExactMatch
Write-Host "✓ Found $($idResults.Count) entries by ID" -ForegroundColor Green
if ($idResults.Count -gt 0) {
    Write-Host "  Entry: $($idResults[0].Name) (ID: $($idResults[0].ID))" -ForegroundColor Cyan
}

# Test 4: Compare with original function (should find 0)
Write-Host "`n4. Testing original search function for '00-008584'..." -ForegroundColor Yellow
$originalResults = Search-RedmineDB -Keyword "00-008584" -Field serialnumber
Write-Host "✓ Original function found $($originalResults.Count) entries (expected 0)" -ForegroundColor $(if ($originalResults.Count -eq 0) { "Green" } else { "Red" })

# Test 5: Search by custom field (serial number)
Write-Host "`n5. Testing custom field search for serial number..." -ForegroundColor Yellow
$serialResults = Search-RedmineDBEnhanced -Field serialnumber -Keyword "MT1849X03893" -ExactMatch
Write-Host "✓ Found $($serialResults.Count) entries by serial number" -ForegroundColor Green

# Disconnect
Write-Host "`nDisconnecting..." -ForegroundColor Yellow
Disconnect-Redmine

Write-Host "`n=== Search Comparison Summary ===" -ForegroundColor Green
Write-Host "• Name search (enhanced):     $($nameResults.Count) results" -ForegroundColor White
Write-Host "• Partial name (enhanced):    $($partialResults.Count) results" -ForegroundColor White
Write-Host "• ID search (enhanced):       $($idResults.Count) results" -ForegroundColor White
Write-Host "• Original search function:   $($originalResults.Count) results" -ForegroundColor White
Write-Host "• Serial number search:       $($serialResults.Count) results" -ForegroundColor White

Write-Host "`n💡 The original Search-RedmineDB only searches custom fields!" -ForegroundColor Yellow
Write-Host "💡 Use the enhanced version to search by name and ID as well." -ForegroundColor Yellow
