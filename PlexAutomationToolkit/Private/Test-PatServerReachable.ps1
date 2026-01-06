function Test-PatServerReachable {
    <#
    .SYNOPSIS
        Tests if a Plex server is reachable at a given URI.

    .DESCRIPTION
        Attempts to connect to a Plex server and verify it responds correctly.
        Uses a short timeout to quickly determine reachability without blocking.

    .PARAMETER ServerUri
        The URI of the Plex server to test.

    .PARAMETER Token
        Optional Plex authentication token for servers that require authentication.

    .PARAMETER TimeoutSeconds
        Connection timeout in seconds. Default is 3 seconds for quick local network testing.

    .OUTPUTS
        PSCustomObject with properties:
        - Reachable: Boolean indicating if server responded
        - ResponseTimeMs: Response time in milliseconds (if reachable)
        - Error: Error message (if not reachable)

    .EXAMPLE
        $result = Test-PatServerReachable -ServerUri "http://192.168.1.100:32400"
        if ($result.Reachable) {
            Write-Host "Server responded in $($result.ResponseTimeMs)ms"
        }

    .NOTES
        This function is designed for quick reachability checks, not full validation.
        A successful response indicates the server is accessible, but doesn't verify
        that all functionality works correctly.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 30)]
        [int]
        $TimeoutSeconds = 3
    )

    $uri = Join-PatUri -BaseUri $ServerUri -Endpoint '/'

    $requestParams = @{
        Uri         = $uri
        Method      = 'Get'
        TimeoutSec  = $TimeoutSeconds
        ErrorAction = 'Stop'
        Headers     = @{ 'Accept' = 'application/json' }
    }

    # Add token if provided
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $requestParams.Headers['X-Plex-Token'] = $Token
    }

    # Skip certificate validation for self-signed certs (common with Plex)
    if ($ServerUri -match '^https://') {
        $requestParams['SkipCertificateCheck'] = $true
    }

    Write-Verbose "Testing reachability of $ServerUri (timeout: ${TimeoutSeconds}s)"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $null = Invoke-RestMethod @requestParams
        $stopwatch.Stop()

        Write-Verbose "Server at $ServerUri is reachable (${($stopwatch.ElapsedMilliseconds)}ms)"

        return [PSCustomObject]@{
            Reachable      = $true
            ResponseTimeMs = $stopwatch.ElapsedMilliseconds
            Error          = $null
        }
    }
    catch {
        $stopwatch.Stop()
        $errorMessage = $_.Exception.Message

        # 401/403 means server is reachable but needs auth - still consider it reachable
        if ($errorMessage -match '401|403|Unauthorized|Forbidden') {
            Write-Verbose "Server at $ServerUri is reachable (requires authentication)"

            return [PSCustomObject]@{
                Reachable      = $true
                ResponseTimeMs = $stopwatch.ElapsedMilliseconds
                Error          = $null
            }
        }

        Write-Verbose "Server at $ServerUri is not reachable: $errorMessage"

        return [PSCustomObject]@{
            Reachable      = $false
            ResponseTimeMs = $null
            Error          = $errorMessage
        }
    }
}
