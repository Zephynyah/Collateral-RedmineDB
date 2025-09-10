# Debug script to check property mapping
try {
    # Import the mock API first
    Remove-Module -Name "*mock*" -Force -ErrorAction SilentlyContinue
    Import-Module .\Misc\mock-api.psm1 -Force
    
    # Initialize mock data
    Initialize-MockAPI -DataPath "Data\db-small.json"
    
    # Test direct mock API call with API key
    Write-Host "=== Testing Mock API Response ===" -ForegroundColor Cyan
    $mockResponse = Invoke-MockAPIRequest -Method GET -Uri "http://localhost:8080/db/18721.json" -Headers @{'X-Redmine-API-Key' = 'mock-api-key-12345-67890-abcdef-ghijkl40'}
    $data = $mockResponse.Content | ConvertFrom-Json
    
    Write-Host "Mock API response structure:" -ForegroundColor Yellow
    Write-Host "- StatusCode: $($mockResponse.StatusCode)" -ForegroundColor Gray
    Write-Host "- Content type: $($data.GetType().Name)" -ForegroundColor Gray
    Write-Host "- db_entry properties:" -ForegroundColor Gray
    $data.db_entry.PSObject.Properties | ForEach-Object {
        $value = if ($null -eq $_.Value) {
            "[NULL]"
        } elseif ($_.Value -is [object] -and $_.Value.PSObject.Properties) {
            "[$($_.Value.GetType().Name)] with properties: $($_.Value.PSObject.Properties.Name -join ', ')"
        } else {
            "[$($_.Value.GetType().Name)] $($_.Value)"
        }
        Write-Host "  - $($_.Name): $value" -ForegroundColor Gray
    }
    
    Write-Host "`n=== Testing Invoke-RestMethod ===" -ForegroundColor Cyan
    try {
        $restResult = Invoke-RestMethod -Uri "http://localhost:8080/db/18721.json" -Headers @{'X-Redmine-API-Key' = 'mock-api-key-12345-67890-abcdef-ghijkl40'}
        
        Write-Host "Invoke-RestMethod result structure:" -ForegroundColor Yellow
        Write-Host "- Result type: $($restResult.GetType().Name)" -ForegroundColor Gray
        Write-Host "- db_entry properties:" -ForegroundColor Gray
        $restResult.db_entry.PSObject.Properties | ForEach-Object {
            $value = if ($null -eq $_.Value) {
                "[NULL]"
            } elseif ($_.Value -is [object] -and $_.Value.PSObject.Properties) {
                "[$($_.Value.GetType().Name)] with properties: $($_.Value.PSObject.Properties.Name -join ', ')"
            } else {
                "[$($_.Value.GetType().Name)] $($_.Value)"
            }
            Write-Host "  - $($_.Name): $value" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invoke-RestMethod failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Disable-MockAPI
}
