# Debug the DB object creation process
try {
    # Import everything
    Remove-Module -Name "*mock*" -Force -ErrorAction SilentlyContinue
    Remove-Module -Name "*RedmineDB*" -Force -ErrorAction SilentlyContinue
    
    Import-Module .\Misc\mock-api.psm1 -Force
    Initialize-MockAPI -DataPath "Data\db-small.json"
    
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
    
    Write-Host "=== Testing Redmine Connection ===" -ForegroundColor Cyan
    
    Write-Host "Script:Redmine exists: $($null -ne $Script:Redmine)" -ForegroundColor Gray
    if ($Script:Redmine) {
        Write-Host "Script:Redmine type: $($Script:Redmine.GetType().Name)" -ForegroundColor Gray
        Write-Host "Script:Redmine.DB exists: $($null -ne $Script:Redmine.DB)" -ForegroundColor Gray
        if ($Script:Redmine.DB) {
            Write-Host "Script:Redmine.DB type: $($Script:Redmine.DB.GetType().Name)" -ForegroundColor Gray
        }
    }
    
    # Test if Get-RedmineDB function works
    try {
        $result = Get-RedmineDB -Id "18721"
        Write-Host "✓ Get-RedmineDB succeeded" -ForegroundColor Green
    } catch {
        Write-Host "❌ Get-RedmineDB failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Disconnect-Redmine -ErrorAction SilentlyContinue
    Disable-MockAPI
}
