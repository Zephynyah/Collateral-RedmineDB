function Send-HTTPRequest {
    <#
    .SYNOPSIS
        Sends an HTTP request to a specified URI with comprehensive error handling and retry logic.
    
    .DESCRIPTION
        The Send-HTTPRequest function provides a robust wrapper around Invoke-RestMethod and Invoke-WebRequest
        with built-in retry logic, comprehensive error handling, and support for various HTTP methods.
        This function is designed to work with the Redmine API but can be used for any HTTP requests.
    
    .PARAMETER Uri
        The URI to send the HTTP request to. Must be a valid HTTP or HTTPS URL.
    
    .PARAMETER Method
        The HTTP method to use for the request. Default is 'GET'.
    
    .PARAMETER Headers
        A hashtable of custom headers to include in the request.
    
    .PARAMETER Body
        The body content for POST, PUT, PATCH requests. Can be a string, hashtable, or custom object.
    
    .PARAMETER ContentType
        The content type for the request body. Default is 'application/json'.
    
    .PARAMETER WebSession
        An existing web session object to use for the request. If provided, cookies and session state will be maintained.
    
    .PARAMETER TimeoutSec
        The timeout in seconds for the request. Default is 30 seconds.
    
    .PARAMETER MaxRetries
        The maximum number of retry attempts for failed requests. Default is 3.
    
    .PARAMETER RetryDelay
        The delay in seconds between retry attempts. Default is 2 seconds.
    
    .PARAMETER UseBasicParsing
        Use basic parsing for the response instead of Internet Explorer's DOM parser.
    
    .PARAMETER PassThru
        Return the full response object instead of just the content.
    
    .PARAMETER Credential
        PSCredential object for authentication.
    
    .PARAMETER UserAgent
        Custom User-Agent string for the request.
    
    .EXAMPLE
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method GET
        
        Sends a simple GET request to the specified URI.
    
    .EXAMPLE
        $headers = @{ 'Authorization' = 'Bearer token123'; 'Accept' = 'application/json' }
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method GET -Headers $headers
        
        Sends a GET request with custom headers.
    
    .EXAMPLE
        $body = @{ name = "Test"; value = "123" } | ConvertTo-Json
        Send-HTTPRequest -Uri "https://api.example.com/data" -Method POST -Body $body -ContentType "application/json"
        
        Sends a POST request with JSON body content.
    
    .EXAMPLE
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        Send-HTTPRequest -Uri "https://api.example.com/login" -Method POST -WebSession $session -MaxRetries 5
        
        Sends a POST request using a web session with custom retry settings.
    
    .OUTPUTS
        PSCustomObject or System.Object depending on response content and PassThru parameter.
    
    .NOTES
        Author: Jason Hickey
        Version: 1.0.0
        This function includes automatic retry logic for transient failures and comprehensive error handling.
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            try {
                $uri = [System.Uri]$_
                if ($uri.Scheme -notin @('http', 'https')) {
                    throw "Invalid URL scheme. Only HTTP and HTTPS are supported."
                }
                return $true
            }
            catch {
                throw "Invalid URI format: $_"
            }
        })]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')]
        [string]$Method = 'GET',
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},
        
        [Parameter(Mandatory = $false)]
        [object]$Body,
        
        [Parameter(Mandatory = $false)]
        [string]$ContentType = 'application/json',
        
        [Parameter(Mandatory = $false)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$TimeoutSec = $script:ModuleConstants.DefaultTimeout,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = $script:ModuleConstants.MaxRetries,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$RetryDelay = 2,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseBasicParsing,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [string]$UserAgent = "PowerShell-RedmineDB/1.0.1"
    )
    
    begin {
        Write-Verbose "Preparing HTTP request: $Method $Uri"
        
        # Build request parameters
        $requestParams = @{
            Uri = $Uri
            Method = $Method
            TimeoutSec = $TimeoutSec
            UserAgent = $UserAgent
        }
        
        # Add optional parameters
        if ($Headers.Count -gt 0) {
            $requestParams.Headers = $Headers
        }
        
        if ($PSBoundParameters.ContainsKey('Body') -and $Body) {
            if ($Body -is [hashtable] -or $Body -is [PSCustomObject]) {
                $requestParams.Body = $Body | ConvertTo-Json -Depth 10
                $requestParams.ContentType = $ContentType
            }
            else {
                $requestParams.Body = $Body
                if ($PSBoundParameters.ContainsKey('ContentType')) {
                    $requestParams.ContentType = $ContentType
                }
            }
        }
        
        if ($WebSession) {
            $requestParams.WebSession = $WebSession
        }
        
        if ($Credential) {
            $requestParams.Credential = $Credential
        }
        
        if ($UseBasicParsing) {
            $requestParams.UseBasicParsing = $true
        }
        
        $attempt = 0
        $lastError = $null
    }
    
    process {
        do {
            $attempt++
            
            try {
                Write-Debug "Attempt $attempt of $($MaxRetries + 1): $Method $Uri"
                
                if ($PassThru) {
                    $response = Invoke-WebRequest @requestParams
                }
                else {
                    $response = Invoke-RestMethod @requestParams
                }
                
                Write-Verbose "HTTP request successful: $Method $Uri (Status: $($response.StatusCode -or 'Success'))"
                return $response
            }
            catch [System.Net.WebException] {
                $lastError = $_
                $statusCode = $_.Exception.Response.StatusCode
                $statusDescription = $_.Exception.Response.StatusDescription
                
                Write-Warning "HTTP request failed (Attempt $attempt): $statusCode - $statusDescription"
                
                # Don't retry for client errors (4xx) except for specific cases
                if ($statusCode -ge 400 -and $statusCode -lt 500 -and $statusCode -notin @(408, 429)) {
                    Write-Error "Client error encountered, not retrying: $statusCode - $statusDescription"
                    throw
                }
                
                # Don't retry for authentication errors
                if ($statusCode -in @(401, 403)) {
                    Write-Error "Authentication/Authorization error: $statusCode - $statusDescription"
                    throw
                }
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
            catch [System.TimeoutException] {
                $lastError = $_
                Write-Warning "Request timeout (Attempt $attempt): $($_.Exception.Message)"
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
            catch {
                $lastError = $_
                Write-Warning "Unexpected error (Attempt $attempt): $($_.Exception.Message)"
                
                if ($attempt -le $MaxRetries) {
                    Write-Verbose "Retrying in $RetryDelay seconds... (Attempt $attempt of $MaxRetries)"
                    Start-Sleep -Seconds $RetryDelay
                }
            }
        }
        while ($attempt -le $MaxRetries)
        
        # If we get here, all attempts failed
        Write-Error "HTTP request failed after $($MaxRetries + 1) attempts: $($lastError.Exception.Message)"
        throw $lastError
    }
}