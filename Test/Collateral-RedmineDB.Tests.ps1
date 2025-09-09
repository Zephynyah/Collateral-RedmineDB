Import-module .\Collateral-RedmineDB.psm1 -Force

InModuleScope Collateral-RedmineDB {
    Describe 'Send-HTTPRequest Function Tests' {
        Context 'Parameter Validation' {
            It 'Should accept valid HTTP URI' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                { Send-HTTPRequest -Uri "http://example.com" } | Should -Not -Throw
            }

            It 'Should accept valid HTTPS URI' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                { Send-HTTPRequest -Uri "https://example.com" } | Should -Not -Throw
            }

            It 'Should reject invalid URI scheme' {
                { Send-HTTPRequest -Uri "ftp://example.com" } | Should -Throw "*Invalid URL scheme*"
            }

            It 'Should reject malformed URI' {
                { Send-HTTPRequest -Uri "not-a-valid-uri" } | Should -Throw "*Invalid URI format*"
            }

            It 'Should validate HTTP methods' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                { Send-HTTPRequest -Uri "https://example.com" -Method "INVALID" } | Should -Throw
            }
        }

        Context 'HTTP Method Tests' {
            BeforeEach {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        method = $Method
                        uri = $Uri
                        headers = $Headers
                        body = $Body
                    } 
                } -ParameterFilter { $Method -eq 'GET' }

                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        method = $Method
                        uri = $Uri
                        headers = $Headers
                        body = $Body
                    } 
                } -ParameterFilter { $Method -eq 'POST' }

                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        method = $Method
                        uri = $Uri
                        headers = $Headers
                        body = $Body
                    } 
                } -ParameterFilter { $Method -eq 'PUT' }

                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        method = $Method
                        uri = $Uri
                        headers = $Headers
                        body = $Body
                    } 
                } -ParameterFilter { $Method -eq 'DELETE' }
            }

            It 'Should use GET method by default' {
                $result = Send-HTTPRequest -Uri "https://example.com"
                $result.method | Should -Be 'GET'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'GET' }
            }

            It 'Should use specified POST method' {
                $result = Send-HTTPRequest -Uri "https://example.com" -Method 'POST'
                $result.method | Should -Be 'POST'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'POST' }
            }

            It 'Should use specified PUT method' {
                $result = Send-HTTPRequest -Uri "https://example.com" -Method 'PUT'
                $result.method | Should -Be 'PUT'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'PUT' }
            }

            It 'Should use specified DELETE method' {
                $result = Send-HTTPRequest -Uri "https://example.com" -Method 'DELETE'
                $result.method | Should -Be 'DELETE'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'DELETE' }
            }
        }

        Context 'Headers and Body Tests' {
            It 'Should include custom headers' {
                $customHeaders = @{ 'Authorization' = 'Bearer token123'; 'Accept' = 'application/json' }
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        headers_received = $Headers
                        authorization = $Headers['Authorization']
                    } 
                }
                
                $result = Send-HTTPRequest -Uri "https://example.com" -Headers $customHeaders
                $result.authorization | Should -Be 'Bearer token123'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $Headers['Authorization'] -eq 'Bearer token123' 
                }
            }

            It 'Should convert hashtable body to JSON' {
                $bodyData = @{ name = 'test'; value = 123 }
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        body_received = $Body
                        content_type = $ContentType
                    } 
                }
                
                $result = Send-HTTPRequest -Uri "https://example.com" -Method 'POST' -Body $bodyData
                $result.content_type | Should -Be 'application/json'
                # Body should be JSON string
                $bodyJson = $bodyData | ConvertTo-Json -Depth 10
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $Body -eq $bodyJson 
                }
            }

            It 'Should use string body as-is' {
                $bodyString = '{"name":"test","value":123}'
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        body_received = $Body
                    } 
                }
                
                Send-HTTPRequest -Uri "https://example.com" -Method 'POST' -Body $bodyString
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $Body -eq $bodyString 
                }
            }
        }

        Context 'Error Handling and Retry Logic' {
            It 'Should retry on network errors' {
                $script:callCount = 0
                Mock Invoke-RestMethod -MockWith { 
                    $script:callCount++
                    if ($script:callCount -lt 3) {
                        throw [System.Net.WebException]::new("Network error")
                    }
                    return @{ status = 'success after retry' }
                }
                
                $result = Send-HTTPRequest -Uri "https://example.com" -MaxRetries 3 -RetryDelay 1
                $result.status | Should -Be 'success after retry'
                Assert-MockCalled Invoke-RestMethod -Times 3
            }

            It 'Should not retry on client errors (400-499)' {
                Mock Invoke-RestMethod -MockWith { 
                    $response = [System.Net.HttpWebResponse]::new()
                    $response | Add-Member -NotePropertyName StatusCode -NotePropertyValue 400
                    $response | Add-Member -NotePropertyName StatusDescription -NotePropertyValue "Bad Request"
                    $exception = [System.Net.WebException]::new("Bad Request", $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
                    throw $exception
                }
                
                { Send-HTTPRequest -Uri "https://example.com" -MaxRetries 3 } | Should -Throw
                Assert-MockCalled Invoke-RestMethod -Times 1
            }

            It 'Should respect MaxRetries parameter' {
                Mock Invoke-RestMethod -MockWith { 
                    throw [System.TimeoutException]::new("Request timeout")
                }
                
                { Send-HTTPRequest -Uri "https://example.com" -MaxRetries 2 -RetryDelay 1 } | Should -Throw
                Assert-MockCalled Invoke-RestMethod -Times 3 # Initial call + 2 retries
            }
        }

        Context 'Response Handling' {
            It 'Should return parsed content by default' {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ data = 'test content'; status = 'ok' }
                }
                
                $result = Send-HTTPRequest -Uri "https://example.com"
                $result.data | Should -Be 'test content'
                $result.status | Should -Be 'ok'
            }

            It 'Should return full response with PassThru' {
                Mock Invoke-WebRequest -MockWith { 
                    $response = New-Object PSObject
                    $response | Add-Member -NotePropertyName StatusCode -NotePropertyValue 200
                    $response | Add-Member -NotePropertyName Content -NotePropertyValue '{"data":"test"}'
                    $response | Add-Member -NotePropertyName Headers -NotePropertyValue @{}
                    return $response
                }
                
                $result = Send-HTTPRequest -Uri "https://example.com" -PassThru
                $result.StatusCode | Should -Be 200
                Assert-MockCalled Invoke-WebRequest -Times 1
                Assert-MockCalled Invoke-RestMethod -Times 0
            }
        }

        Context 'Configuration Parameters' {
            It 'Should use custom timeout' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                
                Send-HTTPRequest -Uri "https://example.com" -TimeoutSec 60
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $TimeoutSec -eq 60 
                }
            }

            It 'Should use custom User-Agent' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                
                Send-HTTPRequest -Uri "https://example.com" -UserAgent "Custom-Agent/1.0"
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $UserAgent -eq "Custom-Agent/1.0" 
                }
            }

            It 'Should use WebSession when provided' {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                Mock Invoke-RestMethod -MockWith { return @{ status = 'success' } }
                
                Send-HTTPRequest -Uri "https://example.com" -WebSession $session
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { 
                    $WebSession -eq $session 
                }
            }
        }
    }

    Describe 'Redmine API' {
        Context 'New-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects.json" }
            It 'project' { New-RedmineResource project -identifier test99 -name testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects/*/versions.json" }
            It 'version' { New-RedmineResource version -project_id 475 -name testversion }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/issues.json" }
            It 'issue' { New-RedmineResource issue -project_id test99 -subject testissue }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Search-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects.json?offset=*&limit=*" }
            It 'project' { Search-RedmineResource project -keyword testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/memberships.json?offset=*&limit=*" }
            It 'membership' { Search-RedmineResource membership -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/versions.json" }
            It 'version' { Search-RedmineResource version -keyword testversion -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues.json?offset=*&limit=*" }
            It 'issue' { Search-RedmineResource issue -keyword testissue }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/users.json?offset=*&limit=*" }
            It 'user' { Search-RedmineResource user -keyword testuser }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Get-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*.json" }
            It 'project' { Get-RedmineResource project -id test99 }
            It 'project' { Get-RedmineResource project 12 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/memberships/*.json" }
            It 'membership' { Get-RedmineResource membership 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/versions/*.json" }
            It 'version' { Get-RedmineResource version 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues/*.json?include=children,attachments,relations,journals,watchers" }
            It 'issue' { Get-RedmineResource issue 1234 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Edit-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'PUT' -and $Body -and $Uri -like "/*/*.json" }
            It 'project' { Edit-RedmineResource project -id 12 -description 'change description' }
            It 'version' { Edit-RedmineResource version -id 123 -description 'add desc' -due_date 2018-09-29 }
            It 'issue' { Edit-RedmineResource issue -id 1234 -version_id 123 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Remove-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'DELETE' -and $Uri -like "/*/*.json" }
            It 'project' { Remove-RedmineResource project -id 12 }
            It 'version' { Remove-RedmineResource version -id 123 }
            It 'issue' { Remove-RedmineResource issue -id 1234 }
            It 'user' { Remove-RedmineResource user -id 20 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 4 -Exactly
        }
    }
}
