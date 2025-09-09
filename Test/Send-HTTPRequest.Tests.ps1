Import-module .\Collateral-RedmineDB.psm1 -Force

InModuleScope Collateral-RedmineDB {
    Describe 'Send-HTTPRequest Function Tests' {
        Context 'Basic Functionality' {
            It 'Should accept valid HTTPS URI and return response' {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        status = 'success'
                        method = $Method
                        uri = $Uri
                    } 
                }
                
                $result = Send-HTTPRequest -Uri "https://httpbin.org/get"
                $result.status | Should -Be 'success'
                $result.method | Should -Be 'GET'
                Assert-MockCalled Invoke-RestMethod -Times 1
            }

            It 'Should use specified HTTP method' {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ method = $Method } 
                }
                
                $result = Send-HTTPRequest -Uri "https://httpbin.org/post" -Method 'POST'
                $result.method | Should -Be 'POST'
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'POST' }
            }

            It 'Should include custom headers' {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        received_auth = $Headers['Authorization']
                    } 
                }
                
                $headers = @{ 'Authorization' = 'Bearer test123' }
                $result = Send-HTTPRequest -Uri "https://httpbin.org/get" -Headers $headers
                $result.received_auth | Should -Be 'Bearer test123'
            }

            It 'Should convert hashtable body to JSON' {
                Mock Invoke-RestMethod -MockWith { 
                    return @{ 
                        body_length = $Body.Length
                        content_type = $ContentType
                    } 
                }
                
                $bodyData = @{ name = 'test'; value = 123 }
                $result = Send-HTTPRequest -Uri "https://httpbin.org/post" -Method 'POST' -Body $bodyData
                $result.content_type | Should -Be 'application/json'
                $result.body_length | Should -BeGreaterThan 0
            }
        }

        Context 'Parameter Validation' {
            It 'Should reject invalid URI scheme' {
                { Send-HTTPRequest -Uri "ftp://example.com" } | Should -Throw "*Invalid URL scheme*"
            }

            It 'Should reject malformed URI' {
                { Send-HTTPRequest -Uri "not-a-valid-uri" } | Should -Throw "*Invalid URI format*"
            }

            It 'Should validate timeout range' {
                { Send-HTTPRequest -Uri "https://httpbin.org/get" -TimeoutSec 500 } | Should -Throw
            }

            It 'Should validate retry range' {
                { Send-HTTPRequest -Uri "https://httpbin.org/get" -MaxRetries 15 } | Should -Throw
            }
        }

        Context 'Response Handling' {
            It 'Should use Invoke-RestMethod by default' {
                Mock Invoke-RestMethod -MockWith { return @{ data = 'test' } }
                Mock Invoke-WebRequest -MockWith { }
                
                Send-HTTPRequest -Uri "https://httpbin.org/get"
                Assert-MockCalled Invoke-RestMethod -Times 1
                Assert-MockCalled Invoke-WebRequest -Times 0
            }

            It 'Should use Invoke-WebRequest with PassThru' {
                Mock Invoke-RestMethod -MockWith { }
                Mock Invoke-WebRequest -MockWith { 
                    return [PSCustomObject]@{
                        StatusCode = 200
                        Content = '{"data":"test"}'
                    }
                }
                
                $result = Send-HTTPRequest -Uri "https://httpbin.org/get" -PassThru
                $result.StatusCode | Should -Be 200
                Assert-MockCalled Invoke-WebRequest -Times 1
                Assert-MockCalled Invoke-RestMethod -Times 0
            }
        }

        Context 'Error Handling' {
            It 'Should handle timeout with retry' {
                $script:callCount = 0
                Mock Invoke-RestMethod -MockWith { 
                    $script:callCount++
                    if ($script:callCount -lt 2) {
                        throw [System.TimeoutException]::new("Request timeout")
                    }
                    return @{ status = 'success after retry' }
                }
                
                $result = Send-HTTPRequest -Uri "https://httpbin.org/get" -MaxRetries 2 -RetryDelay 1
                $result.status | Should -Be 'success after retry'
                $script:callCount | Should -Be 2
            }

            It 'Should respect MaxRetries limit' {
                Mock Invoke-RestMethod -MockWith { 
                    throw [System.TimeoutException]::new("Request timeout")
                }
                
                { Send-HTTPRequest -Uri "https://httpbin.org/get" -MaxRetries 1 -RetryDelay 1 } | Should -Throw "*timeout*"
            }
        }

        Context 'Configuration' {
            It 'Should use custom timeout' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'ok' } }
                
                Send-HTTPRequest -Uri "https://httpbin.org/get" -TimeoutSec 45
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $TimeoutSec -eq 45 }
            }

            It 'Should use custom User-Agent' {
                Mock Invoke-RestMethod -MockWith { return @{ status = 'ok' } }
                
                Send-HTTPRequest -Uri "https://httpbin.org/get" -UserAgent "TestAgent/1.0"
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $UserAgent -eq "TestAgent/1.0" }
            }

            It 'Should include WebSession when provided' {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                Mock Invoke-RestMethod -MockWith { return @{ status = 'ok' } }
                
                Send-HTTPRequest -Uri "https://httpbin.org/get" -WebSession $session
                Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter { $WebSession -eq $session }
            }
        }
    }
}
