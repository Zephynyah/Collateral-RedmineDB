# Mock API Configuration
# This file contains settings for the Mock API middleware

# Data source configuration
$MockAPIConfig = @{
    # Path to the JSON data file (relative to module root)
    DataPath = "Data\db-small.json"
    
    # Mock server settings
    MockServerUrl = "http://localhost:8080"
    MockApiKey = "mock-api-key-12345"
    
    # Simulation settings
    EnableNetworkDelay = $false
    NetworkDelayMs = 100
    
    # Logging and debugging
    EnableRequestLogging = $true
    EnableVerboseLogging = $false
    
    # API behavior settings
    DefaultLimit = 2000
    MaxLimit = 5000
    ValidateApiKey = $true
    
    # Response configuration
    SimulateErrors = $false
    ErrorRate = 0.05  # 5% error rate when enabled
}

# Export the configuration
Export-ModuleMember -Variable MockAPIConfig
