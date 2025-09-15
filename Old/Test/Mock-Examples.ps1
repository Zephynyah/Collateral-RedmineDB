# Example: How to Mock Send-HTTPRequest in Your Tests

<#
This file demonstrates various ways to mock the Send-HTTPRequest function
for testing other functions that depend on it.
#>

Import-module .\Collateral-RedmineDB.psm1 -Force

InModuleScope Collateral-RedmineDB {
    Describe 'Mock Send-HTTPRequest Examples' {
        
        Context 'Basic Mocking Patterns' {
            It 'Mock GET request returning success' {
                Mock Send-HTTPRequest -MockWith { 
                    return @{ status = 'success'; data = 'test response' } 
                } -ParameterFilter { 
                    $Method -eq 'GET' -and $Uri -like "*api/endpoint*" 
                }
                
                # Your function that uses Send-HTTPRequest would go here
                # $result = Your-Function-That-Calls-Send-HTTPRequest
                
                # Verify the mock was called
                Assert-MockCalled Send-HTTPRequest -Times 1 -ParameterFilter { 
                    $Method -eq 'GET' -and $Uri -like "*api/endpoint*" 
                }
            }

            It 'Mock POST request with body validation' {
                Mock Send-HTTPRequest -MockWith { 
                    return @{ 
                        id = 123
                        created = $true 
                    } 
                } -ParameterFilter { 
                    $Method -eq 'POST' -and 
                    $Body -and 
                    $Uri -like "*/projects.json" 
                }
                
                # Example usage in your actual test:
                # $result = New-RedmineProject -Name "Test Project" -Identifier "test123"
                
                Assert-MockCalled Send-HTTPRequest -Times 1 -ParameterFilter { 
                    $Method -eq 'POST' -and $Uri -like "*/projects.json" 
                }
            }

            It 'Mock with specific headers validation' {
                Mock Send-HTTPRequest -MockWith { 
                    return @{ authenticated = $true } 
                } -ParameterFilter { 
                    $Headers['Authorization'] -like "Bearer *" -and
                    $Headers['Content-Type'] -eq 'application/json'
                }
                
                # Your authenticated API call would go here
                
                Assert-MockCalled Send-HTTPRequest -Times 1 -ParameterFilter { 
                    $Headers['Authorization'] -like "Bearer *" 
                }
            }
        }

        Context 'Error Scenario Mocking' {
            It 'Mock network error for testing retry logic' {
                Mock Send-HTTPRequest -MockWith { 
                    throw [System.Net.WebException]::new("Network unreachable") 
                } -ParameterFilter { 
                    $Method -eq 'GET' -and $Uri -like "*unreliable-service*" 
                }
                
                # Test that your function handles the error appropriately
                # { Your-Function-That-Should-Handle-Network-Errors } | Should -Throw
                
                Assert-MockCalled Send-HTTPRequest -Times 1
            }

            It 'Mock HTTP 404 error' {
                Mock Send-HTTPRequest -MockWith { 
                    $response = New-Object System.Net.HttpWebResponse
                    $exception = [System.Net.WebException]::new(
                        "Not Found", 
                        $null, 
                        [System.Net.WebExceptionStatus]::ProtocolError, 
                        $response
                    )
                    throw $exception
                } -ParameterFilter { 
                    $Uri -like "*nonexistent-resource*" 
                }
                
                # Test 404 handling
                # { Get-NonexistentResource } | Should -Throw
            }
        }

        Context 'Complex Response Mocking' {
            It 'Mock paginated API response' {
                Mock Send-HTTPRequest -MockWith { 
                    return @{
                        items = @(
                            @{ id = 1; name = "Item 1" },
                            @{ id = 2; name = "Item 2" }
                        )
                        total_count = 25
                        offset = 0
                        limit = 2
                    }
                } -ParameterFilter { 
                    $Uri -like "*offset=0*" -and $Uri -like "*limit=2*" 
                }
                
                # Test pagination handling
                # $result = Get-PaginatedData -Limit 2
                # $result.items.Count | Should -Be 2
                # $result.total_count | Should -Be 25
            }

            It 'Mock different responses based on parameters' {
                # Mock for user creation
                Mock Send-HTTPRequest -MockWith { 
                    return @{ id = 100; status = 'created' } 
                } -ParameterFilter { 
                    $Method -eq 'POST' -and $Uri -like "*/users.json" 
                }
                
                # Mock for user update  
                Mock Send-HTTPRequest -MockWith { 
                    return @{ id = 100; status = 'updated' } 
                } -ParameterFilter { 
                    $Method -eq 'PUT' -and $Uri -like "*/users/100.json" 
                }
                
                # Test both scenarios
                # $created = New-User -Name "Test User"
                # $updated = Update-User -Id 100 -Name "Updated Name"
                
                Assert-MockCalled Send-HTTPRequest -Times 2
            }
        }

        Context 'WebSession and Authentication Mocking' {
            It 'Mock authenticated requests with WebSession' {
                $mockSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                
                Mock Send-HTTPRequest -MockWith { 
                    return @{ 
                        authenticated = $true
                        user = "test@example.com" 
                    } 
                } -ParameterFilter { 
                    $WebSession -eq $mockSession -and
                    $Headers['X-Redmine-API-Key'] -eq 'test-api-key'
                }
                
                # Test authenticated operations
                # $result = Get-CurrentUser -Session $mockSession -ApiKey 'test-api-key'
                
                Assert-MockCalled Send-HTTPRequest -Times 1 -ParameterFilter { 
                    $WebSession -eq $mockSession 
                }
            }
        }
    }
}

<#
USAGE EXAMPLES FOR YOUR ACTUAL FUNCTIONS:

1. Simple GET request mock:
   Mock Send-HTTPRequest -MockWith { return @{ data = 'test' } } -ParameterFilter { $Method -eq 'GET' }

2. POST with body validation:
   Mock Send-HTTPRequest -MockWith { return @{ id = 123 } } -ParameterFilter { $Method -eq 'POST' -and $Body }

3. Specific URI pattern:
   Mock Send-HTTPRequest -MockWith { return @{ success = $true } } -ParameterFilter { $Uri -like "*/projects.json" }

4. Headers validation:
   Mock Send-HTTPRequest -MockWith { return @{ auth = $true } } -ParameterFilter { $Headers['Authorization'] }

5. Error simulation:
   Mock Send-HTTPRequest -MockWith { throw "Network error" } -ParameterFilter { $Uri -like "*error*" }

6. Multiple mocks for different scenarios:
   Mock Send-HTTPRequest -MockWith { return @{ status = 'created' } } -ParameterFilter { $Method -eq 'POST' }
   Mock Send-HTTPRequest -MockWith { return @{ status = 'updated' } } -ParameterFilter { $Method -eq 'PUT' }
   Mock Send-HTTPRequest -MockWith { return @{ status = 'deleted' } } -ParameterFilter { $Method -eq 'DELETE' }
#>
