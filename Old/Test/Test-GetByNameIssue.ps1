# Test script to debug the GetByName issue
Write-Host "Testing GetByName method issue..." -ForegroundColor Yellow

try {
    # Load the module
    Import-Module .\Collateral-RedmineDB.psm1 -Force
    
    # Connect (using mock key)
    $key = "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
    Connect-Redmine -Server "http://localhost:3000" -Key $key
    
    Write-Host "Testing Get-RedmineDB with multiple test names..."
    
    $testNames = @("TEST-001", "TEST-002", "TEST-003")
    
    foreach ($name in $testNames) {
        Write-Host "`nTesting name: $name" -ForegroundColor Cyan
        try {
            $result = Get-RedmineDB -Name $name -ErrorAction SilentlyContinue
            
            if ($result) {
                Write-Host "✓ Result found for $name`: ID=$($result.ID), Name=$($result.Name)" -ForegroundColor Green
            } else {
                Write-Host "⚠ No result found for $name" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ Error for $name`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "Error caught: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $_" -ForegroundColor Red
}
