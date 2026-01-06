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

    .PARAMETER SkipCertificateCheck
        If specified, skips TLS certificate validation for HTTPS connections.
        Only use this for trusted local servers with self-signed certificates.
        WARNING: Skipping certificate validation exposes you to man-in-the-middle attacks.

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
        $TimeoutSeconds = 3,

        [Parameter(Mandatory = $false)]
        [switch]
        $SkipCertificateCheck
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

    Write-Verbose "Testing reachability of $ServerUri (timeout: ${TimeoutSeconds}s)"

    # Handle HTTPS certificate validation if opt-in skip is requested
    # This must be explicitly requested to prevent man-in-the-middle attacks
    $certValidationCallback = $null
    $certCallbackChanged = $false
    if ($SkipCertificateCheck -and ($ServerUri -match '^https://')) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 6.0+ supports SkipCertificateCheck parameter
            $requestParams['SkipCertificateCheck'] = $true
        }
        else {
            # PowerShell 5.1 requires ServerCertificateValidationCallback
            # Save the current callback to restore it later
            $certValidationCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $certCallbackChanged = $true
        }
    }

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
    finally {
        # Restore original certificate validation callback if we changed it
        if ($certCallbackChanged) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certValidationCallback
        }
    }
}
