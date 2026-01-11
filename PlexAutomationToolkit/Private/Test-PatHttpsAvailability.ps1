function Test-PatHttpsAvailability {
    <#
    .SYNOPSIS
        Tests if HTTPS is available for a given HTTP URI.

    .DESCRIPTION
        Internal helper function that probes whether a server supports HTTPS connections.
        Handles PowerShell version differences for certificate validation and uses
        mutex-based locking for thread safety in PowerShell 5.1.

    .PARAMETER HttpUri
        The HTTP URI to test for HTTPS availability.

    .OUTPUTS
        System.Boolean
        Returns $true if HTTPS is available (including when auth is required), $false otherwise.

    .EXAMPLE
        Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

        Returns $true if the server responds to HTTPS requests.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^http://')]
        [string]
        $HttpUri
    )

    process {
        $httpsUri = $HttpUri -replace '^http://', 'https://'
        Write-Verbose "Checking if HTTPS is available at $httpsUri"

        $httpsAvailable = $false
        $certValidationCallback = $null
        $certCallbackChanged = $false
        $certMutex = $null

        try {
            $testUri = Join-PatUri -BaseUri $httpsUri -Endpoint '/'
            # Build request params - handle certificate skip for PS version compatibility
            $requestParams = @{
                Uri         = $testUri
                TimeoutSec  = 5
                ErrorAction = 'Stop'
            }

            # Skip certificate validation for self-signed certs (common with Plex)
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                # PowerShell 6.0+ supports SkipCertificateCheck parameter
                $requestParams['SkipCertificateCheck'] = $true
            }
            else {
                # PowerShell 5.1 requires ServerCertificateValidationCallback
                # Use a named mutex to prevent race conditions when multiple calls modify the global callback
                $certMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
                $mutexAcquired = $certMutex.WaitOne(10000) # 10 second timeout
                if (-not $mutexAcquired) {
                    # Could not acquire mutex - skip HTTPS check rather than risk race condition
                    Write-Verbose "Could not acquire certificate callback mutex, skipping HTTPS availability check"
                    $certMutex.Dispose()
                    $certMutex = $null
                    return $false
                }
                else {
                    $certValidationCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                    $certCallbackChanged = $true
                }
            }

            # Only proceed with HTTPS check if we either have PS6+ or successfully acquired mutex
            if ($PSVersionTable.PSVersion.Major -ge 6 -or $certCallbackChanged) {
                $null = Invoke-RestMethod @requestParams
                $httpsAvailable = $true
            }
        }
        catch {
            # 401/403 means HTTPS works, just needs auth - that's fine
            if ($_.Exception.Response.StatusCode.value__ -in @(401, 403)) {
                $httpsAvailable = $true
            }
            else {
                Write-Verbose "HTTPS not available: $($_.Exception.Message)"
            }
        }
        finally {
            # Restore original certificate validation callback if we changed it
            if ($certCallbackChanged) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certValidationCallback
            }
            # Release mutex if acquired
            if ($certMutex) {
                $certMutex.ReleaseMutex()
                $certMutex.Dispose()
            }
        }

        return $httpsAvailable
    }
}
