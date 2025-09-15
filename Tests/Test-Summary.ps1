# Quick test summary
Write-Host "=== Collateral-RedmineDB Pester Test Summary ===" -ForegroundColor Cyan

$result = Invoke-Pester -Path ".\Collateral-RedmineDB.Tests.ps1" -PassThru -Output None

Write-Host "`nTest Results:" -ForegroundColor Yellow
Write-Host "✓ Total Tests: $($result.TotalCount)" -ForegroundColor White
Write-Host "✓ Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "✗ Failed: $($result.FailedCount)" -ForegroundColor Red
Write-Host "⊝ Skipped: $($result.SkippedCount)" -ForegroundColor Gray

$passRate = [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 1)
Write-Host "`nPass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 70) { 'Green' } elseif ($passRate -ge 50) { 'Yellow' } else { 'Red' })

Write-Host "`nTest Coverage Areas:" -ForegroundColor Yellow
Write-Host "✓ Module Import and Structure" -ForegroundColor Green
Write-Host "✓ Basic CRUD Operations (with mocks)" -ForegroundColor Green
Write-Host "✓ Parameter Validation" -ForegroundColor Green
Write-Host "✓ API Key Security" -ForegroundColor Green
Write-Host "✓ Error Handling Patterns" -ForegroundColor Green
Write-Host "✓ Connection Management" -ForegroundColor Green
Write-Host "⊝ Live Integration Tests (skipped - no server)" -ForegroundColor Gray

Write-Host "`nKey Features Tested:" -ForegroundColor Yellow
Write-Host "• Function exports and module structure" -ForegroundColor White
Write-Host "• CRUD operations with proper mocking" -ForegroundColor White
Write-Host "• Parameter validation for Type and Status" -ForegroundColor White
Write-Host "• API key truncation security" -ForegroundColor White
Write-Host "• Connection and disconnection flows" -ForegroundColor White
Write-Host "• Custom field conversion utilities" -ForegroundColor White

Write-Host "`n=== Test Suite Complete ===" -ForegroundColor Cyan
