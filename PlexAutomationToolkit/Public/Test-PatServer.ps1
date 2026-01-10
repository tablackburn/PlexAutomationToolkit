function Test-PatServer {
    <#
    .SYNOPSIS
        Tests connectivity to a stored Plex server.

    .DESCRIPTION
        Validates that a stored server configuration works by attempting to connect
        and authenticate with the Plex server. Returns connection status information
        including whether the server is reachable, authenticated, and basic server details.

    .PARAMETER Name
        The name of the stored server to test. Use Get-PatStoredServer to see available servers.

    .PARAMETER Quiet
        If specified, returns only a boolean indicating success/failure instead of
        detailed connection information.

    .EXAMPLE
        Test-PatServer -Name 'Home'

        Tests connectivity to the stored server named 'Home' and returns detailed status.

    .EXAMPLE
        Test-PatServer -Name 'Home' -Quiet

        Tests connectivity and returns $true if successful, $false otherwise.

    .EXAMPLE
        Get-PatStoredServer | ForEach-Object { Test-PatServer -Name $_.name }

        Tests all stored servers and returns their connection status.

    .EXAMPLE
        if (Test-PatServer -Name 'Home' -Quiet) {
            Get-PatLibrary -ServerName 'Home'
        }

        Checks server connectivity before attempting operations.

    .OUTPUTS
        PlexAutomationToolkit.ServerTestResult (default)
        Returns an object with properties:
        - Name: Server name from configuration
        - Uri: The URI used for connection
        - IsConnected: Whether the server responded
        - IsAuthenticated: Whether authentication succeeded
        - FriendlyName: Server's friendly name (if connected)
        - Version: Plex server version (if connected)
        - Error: Error message (if connection failed)

        System.Boolean (with -Quiet)
        Returns $true if connection succeeded, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [switch]
        $Quiet
    )

    process {
        $result = [PSCustomObject]@{
            PSTypeName      = 'PlexAutomationToolkit.ServerTestResult'
            Name            = $Name
            Uri             = $null
            IsConnected     = $false
            IsAuthenticated = $false
            FriendlyName    = $null
            Version         = $null
            Error           = $null
        }

        try {
            # Get the stored server configuration
            $server = Get-PatStoredServer -Name $Name -ErrorAction 'Stop'
            $result.Uri = $server.uri

            # Try to resolve context (this handles local/remote URI selection)
            $serverContext = Resolve-PatServerContext -ServerName $Name -ErrorAction 'Stop'
            $result.Uri = $serverContext.Uri

            # Try to get server info
            $uri = Join-PatUri -BaseUri $serverContext.Uri -Endpoint '/'
            $serverInfo = Invoke-PatApi -Uri $uri -Headers $serverContext.Headers -ErrorAction 'Stop'

            $result.IsConnected = $true
            $result.IsAuthenticated = $true
            $result.FriendlyName = $serverInfo.friendlyName
            $result.Version = $serverInfo.version

            Write-Verbose "Successfully connected to '$Name' at $($result.Uri)"
        }
        catch {
            $errorMessage = $_.Exception.Message
            $innerException = $_.Exception.InnerException

            # Categorize errors by checking exception types first (more robust than regex)
            $isAuthError = $false
            $isConnectionError = $false

            # Check for HTTP status code in WebException or HttpRequestException
            if ($innerException -is [System.Net.WebException]) {
                $webResponse = $innerException.Response
                if ($webResponse -and $webResponse.StatusCode -eq 401) {
                    $isAuthError = $true
                }
                elseif ($innerException.Status -eq [System.Net.WebExceptionStatus]::ConnectFailure -or
                        $innerException.Status -eq [System.Net.WebExceptionStatus]::NameResolutionFailure -or
                        $innerException.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
                    $isConnectionError = $true
                }
            }
            elseif ($innerException -is [System.Net.Http.HttpRequestException]) {
                # Check for status code property (available in .NET 5+)
                if ($innerException.PSObject.Properties['StatusCode'] -and $innerException.StatusCode -eq 401) {
                    $isAuthError = $true
                }
            }

            # Fall back to message pattern matching if exception type checks didn't categorize
            if (-not $isAuthError -and -not $isConnectionError) {
                if ($errorMessage -match '\b401\b|Unauthorized') {
                    $isAuthError = $true
                }
                elseif ($errorMessage -match 'Unable to connect|ConnectFailure|NameResolutionFailure|timed?\s*out|unreachable|The remote name could not be resolved') {
                    $isConnectionError = $true
                }
            }

            # Set result based on categorization
            if ($isAuthError) {
                $result.IsConnected = $true
                $result.IsAuthenticated = $false
                $result.Error = 'Authentication failed - token may be invalid or expired'
            }
            elseif ($isConnectionError) {
                $result.IsConnected = $false
                $result.IsAuthenticated = $false
                $result.Error = "Server unreachable: $errorMessage"
            }
            else {
                $result.Error = $errorMessage
            }

            Write-Verbose "Connection test failed for '$Name': $errorMessage"
        }

        if ($Quiet) {
            $result.IsConnected -and $result.IsAuthenticated
        }
        else {
            $result
        }
    }
}
