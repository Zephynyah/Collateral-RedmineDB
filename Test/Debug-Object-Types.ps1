# Debug script to check object types
try {
    Import-Module .\Misc\mock-api.psm1 -Force
    Initialize-MockAPI -DataPath "Data\db-small.json"
    
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
    
    Write-Host "Checking script variable state:" -ForegroundColor Cyan
    Write-Host "  Script:Redmine exists: $($Script:Redmine -ne $null)"
    if ($Script:Redmine) {
        Write-Host "  Script:Redmine.DB exists: $($Script:Redmine.DB -ne $null)"
        if ($Script:Redmine.DB) {
            Write-Host "  DB object type: $($Script:Redmine.DB.GetType().FullName)"
        }
    }
    
    try {
        $dbEntry = Get-RedmineDB -Id 18721 -ErrorAction Stop
        Write-Host "DB Entry retrieved successfully: $($dbEntry -ne $null)" -ForegroundColor Green
    } catch {
        Write-Host "Error getting DB entry: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
        return
    }
    Write-Host "=== Object Type Analysis ===" -ForegroundColor Green
    Write-Host "DB Entry Type: $($dbEntry.GetType().FullName)"
    Write-Host ""
    
    Write-Host "Type property:" -ForegroundColor Yellow
    Write-Host "  Value: $($dbEntry.Type)"
    Write-Host "  Type: $($dbEntry.Type.GetType().FullName)"
    Write-Host "  Has 'name' property: $($dbEntry.Type.PSObject.Properties.Name -contains 'name')"
    if ($dbEntry.Type.PSObject.Properties.Name -contains 'name') {
        Write-Host "  name value: $($dbEntry.Type.name)"
    }
    Write-Host ""
    
    Write-Host "Status property:" -ForegroundColor Yellow
    Write-Host "  Value: $($dbEntry.Status)"
    Write-Host "  Type: $($dbEntry.Status.GetType().FullName)"
    Write-Host "  Has 'name' property: $($dbEntry.Status.PSObject.Properties.Name -contains 'name')"
    if ($dbEntry.Status.PSObject.Properties.Name -contains 'name') {
        Write-Host "  name value: $($dbEntry.Status.name)"
    }
    Write-Host ""
    
    Write-Host "Project property:" -ForegroundColor Yellow
    Write-Host "  Value: $($dbEntry.Project)"
    Write-Host "  Type: $($dbEntry.Project.GetType().FullName)"
    Write-Host "  Has 'name' property: $($dbEntry.Project.PSObject.Properties.Name -contains 'name')"
    if ($dbEntry.Project.PSObject.Properties.Name -contains 'name') {
        Write-Host "  name value: $($dbEntry.Project.name)"
    }
    Write-Host ""
    
    Write-Host "Author property:" -ForegroundColor Yellow
    Write-Host "  Value: $($dbEntry.Author)"
    Write-Host "  Type: $($dbEntry.Author.GetType().FullName)"
    Write-Host "  Has 'name' property: $($dbEntry.Author.PSObject.Properties.Name -contains 'name')"
    if ($dbEntry.Author.PSObject.Properties.Name -contains 'name') {
        Write-Host "  name value: $($dbEntry.Author.name)"
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    if (Get-Command "Disconnect-Redmine" -ErrorAction SilentlyContinue) {
        Disconnect-Redmine
    }
    if (Get-Command "Disable-MockAPI" -ErrorAction SilentlyContinue) {
        Disable-MockAPI
    }
}
