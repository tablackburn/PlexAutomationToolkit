function Invoke-PatApi {
    <#
    .SYNOPSIS
        Invokes the Plex API.

    .DESCRIPTION
        Internal function that sends HTTP requests to the Plex API and returns the response.
        Includes automatic retry with exponential backoff for transient errors such as
        DNS failures, connection timeouts, and rate limiting (503/429).

    .PARAMETER Uri
        The complete URI to call

    .PARAMETER Method
        The HTTP method to use (default: Get)

    .PARAMETER Headers
        Optional headers to include in the request (default: Accept = application/json)

    .PARAMETER MaxRetries
        Maximum number of retry attempts for transient errors (default: 3)

    .PARAMETER BaseDelaySeconds
        Base delay in seconds for exponential backoff (default: 1)
        Actual delays will be: 1s, 2s, 4s for the default value

    .OUTPUTS
        PSCustomObject
        Returns the MediaContainer object from the Plex API response if present, otherwise returns the full response
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Method = 'Get',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Headers = @{
            Accept = 'application/json'
        },

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]
        $MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 60)]
        [int]
        $BaseDelaySeconds = 1
    )

    # Warn if using HTTP with authentication token
    if ($Uri -match '^http://' -and $Headers.ContainsKey('X-Plex-Token')) {
        Write-Warning "Sending authentication token over unencrypted HTTP connection. Consider using HTTPS."
    }

    $apiQueryParameters = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $Headers
        ErrorAction = 'Stop'
    }
    Write-Debug 'Invoking Plex API with the following parameters:'
    $apiQueryParameters | Out-String | Write-Debug

    # Helper function to determine if an error is transient and should be retried
    function Test-TransientError {
        param([System.Management.Automation.ErrorRecord]$ErrorRecord)

        $message = $ErrorRecord.Exception.Message

        # DNS failures
        if ($message -match 'No such host|DNS|name.+not.+resolve') {
            return $true
        }

        # Connection/timeout issues
        if ($message -match 'timed out|timeout|connection.+refused|connection.+reset|unable to connect') {
            return $true
        }

        # Server-side transient errors (rate limiting, service unavailable)
        if ($message -match '503|429|temporarily unavailable|service unavailable|too many requests') {
            return $true
        }

        return $false
    }

    $lastError = $null

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $response = Invoke-RestMethod @apiQueryParameters

            # Handle case where response is returned as JSON string (some servers/content-types)
            # Check for both JSON objects ({) and arrays ([)
            $trimmedResponse = if ($response -is [string]) { $response.TrimStart() } else { $null }
            if ($trimmedResponse -and ($trimmedResponse.StartsWith('{') -or $trimmedResponse.StartsWith('['))) {
                Write-Debug "Response is JSON string, parsing with -AsHashtable..."
                # Use -AsHashtable to handle Plex API's case-sensitive keys (e.g., "guid" and "Guid")
                # Then convert back to PSCustomObject for consistent property access patterns
                $hashtable = $response | ConvertFrom-Json -AsHashtable -Depth 100
                $response = ConvertTo-PsCustomObjectFromHashtable -Hashtable $hashtable
            }

            if ($response.PSObject.Properties['MediaContainer']) {
                return $response.MediaContainer
            }
            return $response
        }
        catch {
            $lastError = $_

            # Check if this is a transient error that should be retried
            $isTransient = Test-TransientError -ErrorRecord $_

            if (-not $isTransient -or $attempt -eq $MaxRetries) {
                # Non-transient error or final attempt - throw immediately
                throw "Error invoking Plex API: $($_.Exception.Message)"
            }

            # Calculate exponential backoff delay
            $delay = $BaseDelaySeconds * [Math]::Pow(2, $attempt - 1)
            Write-Verbose "Transient error on attempt $attempt of $MaxRetries. Retrying in ${delay}s. Error: $($_.Exception.Message)"
            Start-Sleep -Seconds $delay
        }
    }

    # Should not reach here, but just in case
    if ($lastError) {
        throw "Error invoking Plex API: $($lastError.Exception.Message)"
    }
}
