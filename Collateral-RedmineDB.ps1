

Import-Module .\Collateral-RedmineDB.psm1 -Force -Verbose

$key = "c5fc2de08e46b51bbd8c0a448c0b08f35e99004d"

# Connect-Redmine -Server "http://localhost:8080" -Key $key

# Connect-Redmine -Server "http://localhost:8080" -Username "admin"


# Simple GET request
Send-HTTPRequest -Uri "https://api.example.com/data"

# POST with JSON body
$data = @{ name = "test"; value = 123 }
Send-HTTPRequest -Uri "https://api.example.com/data" -Method POST -Body $data

# With custom headers and authentication
$headers = @{ 'Authorization' = 'Bearer token123' }
Send-HTTPRequest -Uri "https://api.example.com/secure" -Headers $headers

# With retry configuration
Send-HTTPRequest -Uri "https://unreliable-api.com" -MaxRetries 5 -RetryDelay 3




