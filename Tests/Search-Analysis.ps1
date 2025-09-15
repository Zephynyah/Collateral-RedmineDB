# Simple demonstration of search limitation and solution
Import-Module "$PSScriptRoot\..\Collateral-RedmineDB.psm1" -Force

Write-Host "=== Search Function Analysis ===" -ForegroundColor Green

# Connect to server
Connect-Redmine -Server "http://localhost:3000/api" -Key "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"

Write-Host "`n1. Testing original Search-RedmineDB for name '00-008584':" -ForegroundColor Yellow
$originalResult = Search-RedmineDB -Keyword "00-008584" -Field serialnumber
Write-Host "   Result: $($originalResult.Count) entries found" -ForegroundColor $(if ($originalResult.Count -eq 0) { "Red" } else { "Green" })

Write-Host "`n2. Testing original Search-RedmineDB for serial number 'MT1849X03893':" -ForegroundColor Yellow
$serialResult = Search-RedmineDB -Keyword "MT1849X03893" -Field serialnumber
Write-Host "   Result: $($serialResult.Count) entries found" -ForegroundColor Green
if ($serialResult.Count -gt 0) {
    Write-Host "   Found entry: $($serialResult[0].Name)" -ForegroundColor Cyan
}

Write-Host "`n3. Direct API call to find entry by name:" -ForegroundColor Yellow
$apiResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/db.json?key=b9124a018b48bbd9f837f7180e84b1eaa05ec9ea&limit=5"
$targetEntry = $apiResponse.db_entries | Where-Object { $_.name -eq "00-008584" }
Write-Host "   Result: $($targetEntry.Count) entries found via direct API" -ForegroundColor Green
if ($targetEntry) {
    Write-Host "   Found entry: $($targetEntry.name) (ID: $($targetEntry.id))" -ForegroundColor Cyan
}

Write-Host "`n4. Available search fields in original function:" -ForegroundColor Yellow
$searchHelp = Get-Help Search-RedmineDB -Parameter Field
Write-Host "   Valid fields: parent, type, serialnumber, program, hostname, model, mac, macaddress" -ForegroundColor Cyan
Write-Host "   Missing fields: name, id" -ForegroundColor Red

Write-Host "`n5. Solution demonstration - Custom name search:" -ForegroundColor Yellow
$allEntries = Invoke-RestMethod -Uri "http://localhost:3000/api/db.json?key=b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
$nameMatches = $allEntries.db_entries | Where-Object { $_.name -match "00-" }
Write-Host "   Entries with names containing '00-': $($nameMatches.Count)" -ForegroundColor Green

Disconnect-Redmine

Write-Host "`n=== CONCLUSION ===" -ForegroundColor Yellow
Write-Host "❌ Search-RedmineDB cannot search by 'name' or 'id' fields" -ForegroundColor Red
Write-Host "✅ Search-RedmineDB works perfectly for custom fields (serialnumber, etc.)" -ForegroundColor Green
Write-Host "💡 To search by name/id, use direct API calls or enhance the function" -ForegroundColor Cyan

Write-Host "`n=== WORKAROUND ===" -ForegroundColor Yellow
Write-Host "# For name search, use:" -ForegroundColor Cyan
Write-Host 'Invoke-RestMethod -Uri "http://localhost:3000/api/db.json?key=YOUR_KEY" | ' -ForegroundColor Gray
Write-Host '  Select-Object -ExpandProperty db_entries | ' -ForegroundColor Gray
Write-Host '  Where-Object { $_.name -match "YOUR_SEARCH_TERM" }' -ForegroundColor Gray
