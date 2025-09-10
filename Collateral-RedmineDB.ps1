$VerbosePreference = "Continue"

Import-Module .\Collateral-RedmineDB.psm1 -Force -Verbose

$key = "c5fc2de08e46b51bbd8c0a448c0b08f35e99004d"

Connect-Redmine -Server "http://localhost:8080" -Key $key

# Connect-Redmine -Server "http://localhost:8080" -Username "admin"


$VerbosePreference = "silentlyContinue"


