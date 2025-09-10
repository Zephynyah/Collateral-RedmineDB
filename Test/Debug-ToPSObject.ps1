# Minimal debug script to test the exact issue
try {
    Remove-Module -Name "*mock*" -Force -ErrorAction SilentlyContinue
    Remove-Module -Name "*RedmineDB*" -Force -ErrorAction SilentlyContinue
    
    Import-Module .\Misc\mock-api.psm1 -Force
    Initialize-MockAPI -DataPath "Data\db-small.json"
    
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    Connect-Redmine -Server "http://localhost:8080" -Key "mock-api-key-12345-67890-abcdef-ghijkl40"
    
    Write-Host "=== Direct Method Call Test ===" -ForegroundColor Cyan
    
    # Bypass Get-RedmineDB and call the method directly
    try {
        $directResult = Get-RedmineDB -Id "18721"
        Write-Host "This shouldn't succeed, but if it does:" -ForegroundColor Yellow
        Write-Host $directResult -ForegroundColor Green
    } catch {
        Write-Host "Expected error in Get-RedmineDB: $($_.Exception.Message)" -ForegroundColor Yellow
        
        # Now let's get the raw object and inspect it step by step
        Write-Host "`n=== Manual Step-by-Step Debug ===" -ForegroundColor Cyan
        
        # Step 1: Get raw JSON response
        Write-Host "Step 1: Getting raw API response" -ForegroundColor Gray
        $rawResponse = Invoke-RestMethod -Uri "http://localhost:8080/db/18721.json" -Headers @{'X-Redmine-API-Key' = 'mock-api-key-12345-67890-abcdef-ghijkl40'}
        
        Write-Host "Raw response type: $($rawResponse.GetType().Name)" -ForegroundColor Gray
        Write-Host "Raw response db_entry.name: '$($rawResponse.db_entry.name)'" -ForegroundColor Gray
        Write-Host "Raw response db_entry.type: '$($rawResponse.db_entry.type)'" -ForegroundColor Gray
        Write-Host "Raw response db_entry.type.name: '$($rawResponse.db_entry.type.name)'" -ForegroundColor Gray
        
        # Step 2: Create DB object manually and try mapping one property at a time
        Write-Host "`nStep 2: Creating DB object manually" -ForegroundColor Gray
        try {
            # Create the session manually (mimicking what the module does)
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $dbObj = [DB]::new("http://localhost:8080", $session)
            
            Write-Host "Empty DB object created successfully" -ForegroundColor Gray
            
            # Try setting Name property
            $dbObj.Name = $rawResponse.db_entry.name
            Write-Host "✓ Name property set to: '$($dbObj.Name)'" -ForegroundColor Green
            
            # Try setting Type property
            $dbObj.Type = $rawResponse.db_entry.type
            Write-Host "✓ Type property set to: '$($dbObj.Type)'" -ForegroundColor Green
            Write-Host "  Type.name: '$($dbObj.Type.name)'" -ForegroundColor Green
            
            # Try calling ToPSObject
            Write-Host "`nStep 3: Testing ToPSObject method" -ForegroundColor Gray
            $psResult = $dbObj.ToPSObject()
            Write-Host "✓ ToPSObject succeeded!" -ForegroundColor Green
            Write-Host "Result Name: '$($psResult.Name)'" -ForegroundColor Green
            Write-Host "Result Type: '$($psResult.Type)'" -ForegroundColor Green
            
        } catch {
            Write-Host "❌ Error in manual object creation: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Error location: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "❌ Script error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Disconnect-Redmine -ErrorAction SilentlyContinue
    Disable-MockAPI
}
