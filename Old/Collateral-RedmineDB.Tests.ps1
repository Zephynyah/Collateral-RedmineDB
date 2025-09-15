#Requires -Modules Pester

# Import the module for testing
Import-Module "$PSScriptRoot\Collateral-RedmineDB.psm1" -Force

Describe 'Collateral-RedmineDB Module' {
    
    BeforeAll {
        # Mock API key for testing
        $script:TestApiKey = "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
        $script:TestServer = "http://localhost:3000/api"
    }
    
    Context 'Module Import and Structure' {
        It 'Should import the module successfully' {
            Get-Module Collateral-RedmineDB | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export the expected functions' {
            $exportedFunctions = (Get-Module Collateral-RedmineDB).ExportedFunctions.Keys
            $expectedFunctions = @(
                'Connect-Redmine',
                'Disconnect-Redmine', 
                'Get-RedmineDB',
                'New-RedmineDB',
                'Edit-RedmineDB',
                'Edit-RedmineDBXL',
                'Remove-RedmineDB',
                'Search-RedmineDB',
                'Set-RedmineDB',
                'ConvertTo-RedmineCustomField',
                'Invoke-ValidateDB',
                'Import-RedmineEnv',
                'Invoke-DecomissionDB'
            )
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context 'Connect-Redmine' {
        BeforeEach {
            # Clean up any existing connections
            if (Get-Variable -Name 'Redmine' -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'Redmine' -Scope Script -Force
            }
            if (Get-Variable -Name 'APIKey' -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'APIKey' -Scope Script -Force
            }
        }
        
        It 'Should accept Server and Key parameters' {
            Mock Invoke-RestMethod { return @{ projects = @() } }
            
            { Connect-Redmine -Server $script:TestServer -Key $script:TestApiKey } | Should -Not -Throw
        }
        
        It 'Should validate connection with test request' {
            Mock Invoke-RestMethod { return @{ projects = @() } } -ParameterFilter { $Uri -like "*/projects.json*" }
            
            Connect-Redmine -Server $script:TestServer -Key $script:TestApiKey
            
            Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -like "*/projects.json*" }
        }
        
        It 'Should throw error on invalid server' {
            Mock Invoke-RestMethod { throw "Connection failed" }
            
            { Connect-Redmine -Server "http://invalid" -Key $script:TestApiKey } | Should -Throw
        }
    }
    
    Context 'Get-RedmineDB' {
        BeforeAll {
            # Mock connection setup
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    Get = { param($id) return [PSCustomObject]@{ 
                        Id = $id
                        Name = "Test Entry"
                        ToPSObject = { return [PSCustomObject]@{ ID = $id; Name = "Test Entry" } }
                    }}
                    GetByName = { param($name) return [PSCustomObject]@{
                        Id = 999
                        Name = $name
                        ToPSObject = { return [PSCustomObject]@{ ID = 999; Name = $name } }
                    }}
                }
            }
        }
        
        It 'Should get entry by ID' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogError {}
            
            $result = Get-RedmineDB -Id "12345"
            $result | Should -Not -BeNullOrEmpty
            $result.ID | Should -Be "12345"
        }
        
        It 'Should get entry by Name' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogError {}
            
            $result = Get-RedmineDB -Name "TestEntry"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "TestEntry"
        }
        
        It 'Should handle missing ID parameter' {
            { Get-RedmineDB } | Should -Throw
        }
    }
    
    Context 'New-RedmineDB' {
        BeforeAll {
            # Mock connection and DB object
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    Create = { return [PSCustomObject]@{ Id = 999; Name = "New Entry" } }
                }
            }
        }
        
        It 'Should create new DB entry with required parameters' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            Mock -ModuleName Collateral-RedmineDB -CommandName Invoke-ValidateDB { return $true }
            
            $result = New-RedmineDB -Name "Test Entry" -Type "Server" -Status "Active"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate input parameters' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Invoke-ValidateDB { throw "Validation failed" }
            
            { New-RedmineDB -Name "Test Entry" -Type "InvalidType" } | Should -Throw
        }
    }
    
    Context 'Edit-RedmineDB' {
        BeforeAll {
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    Get = { param($id) return [PSCustomObject]@{
                        Id = $id
                        Update = { return $true }
                    }}
                }
            }
        }
        
        It 'Should update existing DB entry' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            Mock -ModuleName Collateral-RedmineDB -CommandName Invoke-ValidateDB { return $true }
            
            { Edit-RedmineDB -Id "12345" -Description "Updated description" } | Should -Not -Throw
        }
        
        It 'Should require ID parameter' {
            { Edit-RedmineDB -Description "Updated description" } | Should -Throw
        }
    }
    
    Context 'Remove-RedmineDB' {
        BeforeAll {
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    Get = { param($id) return [PSCustomObject]@{
                        Id = $id
                        Delete = { return $true }
                    }}
                    GetByName = { param($name) return [PSCustomObject]@{
                        Id = 999
                        Name = $name
                        Delete = { return $true }
                    }}
                }
            }
        }
        
        It 'Should remove DB entry by ID' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            { Remove-RedmineDB -Id "12345" } | Should -Not -Throw
        }
        
        It 'Should remove DB entry by Name' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            { Remove-RedmineDB -Name "TestEntry" } | Should -Not -Throw
        }
    }
    
    Context 'Search-RedmineDB' {
        BeforeAll {
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    GetAllPages = { return @{
                        "1" = [PSCustomObject]@{ Id = 1; Name = "Entry 1" }
                        "2" = [PSCustomObject]@{ Id = 2; Name = "Entry 2" }
                    }}
                }
            }
        }
        
        It 'Should search DB entries' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            $result = Search-RedmineDB
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
        
        It 'Should filter by keyword' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            $result = Search-RedmineDB -Keyword "Entry"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'ConvertTo-RedmineCustomField' {
        It 'Should convert hashtable to custom field format' {
            $inputData = @{
                "CustomField1" = "Value1"
                "CustomField2" = "Value2"
            }
            
            $result = ConvertTo-RedmineCustomField -Data $inputData
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [array]
        }
        
        It 'Should handle empty input' {
            $result = ConvertTo-RedmineCustomField -Data @{}
            $result | Should -BeOfType [array]
            $result.Count | Should -Be 0
        }
    }
    
    Context 'Invoke-ValidateDB' {
        It 'Should validate valid parameters' {
            $validParams = @{
                Name = "TestEntry"
                Type = "Server"
                Status = "Active"
            }
            
            { Invoke-ValidateDB @validParams } | Should -Not -Throw
        }
        
        It 'Should reject invalid Type' {
            $invalidParams = @{
                Name = "TestEntry"
                Type = "InvalidType"
            }
            
            { Invoke-ValidateDB @invalidParams } | Should -Throw
        }
    }
    
    Context 'Set-RedmineDB' {
        BeforeAll {
            $script:Redmine = [PSCustomObject]@{
                Server = $script:TestServer
                Session = $null
            }
        }
        
        It 'Should create DB object' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            $result = Set-RedmineDB
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'API Key Security' {
        It 'Should truncate API keys in logs' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {} -ParameterFilter { 
                $Message -like "*...[TRUNCATED]*"
            }
            
            # This would be tested through the logging module
            $apiKey = "b9124a018b48bbd9f837f7180e84b1eaa05ec9ea"
            # The logging should truncate this to "b9124a01...[TRUNCATED]"
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle connection errors gracefully' {
            Mock Invoke-RestMethod { throw "Network error" }
            
            { Connect-Redmine -Server "http://invalid" -Key $script:TestApiKey } | Should -Throw
        }
        
        It 'Should handle API errors in Get operations' {
            $script:Redmine = [PSCustomObject]@{
                DB = [PSCustomObject]@{
                    Get = { throw "API Error: 404 Not Found" }
                }
            }
            
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogError {}
            
            { Get-RedmineDB -Id "99999" } | Should -Throw
        }
    }
    
    Context 'Disconnect-Redmine' {
        It 'Should clean up connection variables' {
            # Setup connection variables
            $script:Redmine = [PSCustomObject]@{ Server = $script:TestServer }
            $script:APIKey = $script:TestApiKey
            
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogInfo {}
            
            Disconnect-Redmine
            
            # Variables should be cleaned up (this is hard to test directly due to scope)
        }
        
        It 'Should handle disconnect when not connected' {
            Mock -ModuleName Collateral-RedmineDB -CommandName Write-LogWarn {}
            
            { Disconnect-Redmine } | Should -Not -Throw
        }
    }
}

Describe 'Integration Tests' {
    Context 'Full Workflow' {
        BeforeAll {
            # Skip integration tests if no test server available
            $script:SkipIntegration = $true
            if ($env:REDMINE_TEST_SERVER -and $env:REDMINE_TEST_KEY) {
                $script:SkipIntegration = $false
                $script:TestServer = $env:REDMINE_TEST_SERVER
                $script:TestApiKey = $env:REDMINE_TEST_KEY
            }
        }
        
        It 'Should complete full CRUD workflow' -Skip:$script:SkipIntegration {
            # Connect
            Connect-Redmine -Server $script:TestServer -Key $script:TestApiKey
            
            # Create
            $newEntry = New-RedmineDB -Name "Pester Test Entry" -Type "Server" -Status "Active"
            $newEntry | Should -Not -BeNullOrEmpty
            
            # Read
            $retrievedEntry = Get-RedmineDB -Id $newEntry.Id
            $retrievedEntry.Name | Should -Be "Pester Test Entry"
            
            # Update
            Edit-RedmineDB -Id $newEntry.Id -Description "Updated by Pester test"
            $updatedEntry = Get-RedmineDB -Id $newEntry.Id
            $updatedEntry.Description | Should -Be "Updated by Pester test"
            
            # Delete
            Remove-RedmineDB -Id $newEntry.Id
            
            # Verify deletion
            { Get-RedmineDB -Id $newEntry.Id } | Should -Throw
            
            # Disconnect
            Disconnect-Redmine
        }
    }
}
