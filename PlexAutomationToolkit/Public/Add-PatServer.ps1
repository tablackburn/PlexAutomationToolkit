function Add-PatServer {
    <#
    .SYNOPSIS
        Adds a Plex server to the configuration.

    .DESCRIPTION
        Adds a new Plex server entry to the server configuration file.
        Optionally marks the server as default.

    .PARAMETER Name
        Friendly name for the server (e.g., "Main Plex Server")

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)

    .PARAMETER Default
        If specified, marks this server as the default server

    .PARAMETER Token
        Optional Plex authentication token (X-Plex-Token). Required for servers that don't allow
        unauthenticated local network access.

        If not provided and the server requires authentication, you will be prompted to authenticate
        using Connect-PatAccount.

        WARNING: Tokens are stored in PLAINTEXT in servers.json. Only use on trusted systems.

    .PARAMETER PassThru
        If specified, returns the server configuration object after adding.

    .PARAMETER SkipValidation
        If specified, skips validation of server connectivity and token authentication.
        Use this when adding a server that is temporarily offline or not yet configured.

    .PARAMETER Force
        Suppresses all interactive prompts. When specified:
        - Automatically accepts HTTPS upgrade if available
        - Automatically attempts authentication if server requires it
        Use this parameter for non-interactive scripts and automation.

    .EXAMPLE
        Add-PatServer -Name "Main Server" -ServerUri "http://plex.local:32400" -Default

        Adds a new server and marks it as default. Validates connectivity before saving.

    .EXAMPLE
        Add-PatServer -Name "Remote Server" -ServerUri "http://remote.plex.com:32400"

        Adds a new server without marking it as default. Validates connectivity before saving.

    .EXAMPLE
        Add-PatServer -Name "Authenticated Server" -ServerUri "http://plex.remote.com:32400" -Token "ABC123xyz" -Default

        Adds a new server with authentication token and marks it as default. Validates both connectivity and token.

    .EXAMPLE
        Add-PatServer -Name "New Server" -ServerUri "http://plex.local:32400" -PassThru

        Adds a new server and returns the server configuration object.

    .EXAMPLE
        Add-PatServer -Name "Offline Server" -ServerUri "http://plex.offline.com:32400" -SkipValidation

        Adds a server without validating connectivity. Useful for servers that are temporarily down.

    .NOTES
        Security Warning: Authentication tokens are stored in PLAINTEXT in the servers.json configuration file.
        Your Plex token provides full access to your Plex account. Only use on trusted systems with
        appropriate file permissions.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [switch]
        $Default,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru,

        [Parameter(Mandatory = $false)]
        [switch]
        $SkipValidation,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    try {
        # Use local variable for potentially modified ServerUri (e.g., HTTP->HTTPS upgrade)
        $effectiveUri = $ServerUri

        # Check if HTTPS is available when HTTP is specified
        if ($ServerUri -match '^http://' -and -not $SkipValidation) {
            $httpsUri = $ServerUri -replace '^http://', 'https://'
            Write-Verbose "Checking if HTTPS is available at $httpsUri"

            $httpsAvailable = $false
            try {
                $testUri = Join-PatUri -BaseUri $httpsUri -Endpoint '/'
                # Use SkipCertificateCheck for self-signed certs (common with Plex)
                $null = Invoke-RestMethod -Uri $testUri -TimeoutSec 5 -SkipCertificateCheck -ErrorAction Stop
                $httpsAvailable = $true
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

            if ($httpsAvailable) {
                # HTTPS is available - use it if -Force or user confirms
                if ($Force -or $PSCmdlet.ShouldContinue(
                    "Server supports HTTPS. Use $httpsUri instead?",
                    'HTTPS Available'
                )) {
                    $effectiveUri = $httpsUri
                    Write-Information "Using HTTPS: $effectiveUri" -InformationAction Continue
                }
                else {
                    Write-Warning "Using unencrypted HTTP. Authentication tokens will be transmitted in clear text."
                }
            }
            else {
                Write-Warning "Using unencrypted HTTP connection to '$ServerUri'. Authentication tokens will be transmitted in clear text. Consider using HTTPS for secure communication."
            }
        }

        $configuration = Get-PatServerConfiguration -ErrorAction Stop

        # Check for duplicate name
        if ($configuration.servers | Where-Object { $_.name -eq $Name }) {
            throw "A server with name '$Name' already exists"
        }

        # If marking as default, unset other defaults
        if ($Default) {
            foreach ($server in $configuration.servers) {
                $server.default = $false
            }
        }

        # Add new server
        $newServer = [PSCustomObject]@{
            name    = $Name
            uri     = $effectiveUri
            default = $Default.IsPresent
        }

        # Conditionally add token if provided
        if ($Token) {
            $newServer | Add-Member -NotePropertyName 'token' -NotePropertyValue $Token
        }

        # Validate server connectivity and token unless skipped
        if (-not $SkipValidation) {
            Write-Verbose "Validating server connectivity and authentication"

            try {
                # Build URI for root endpoint
                $validationUri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'

                # Build headers with authentication if token provided
                $validationHeaders = Get-PatAuthenticationHeader -Server $newServer

                # Attempt to connect to server
                $null = Invoke-PatApi -Uri $validationUri -Headers $validationHeaders -ErrorAction Stop
                Write-Verbose "Server validation successful"
            }
            catch {
                # Extract error details for specific warnings
                $errorMessage = $_.Exception.Message

                # Check for authentication failures (401 or 403)
                if ($errorMessage -match '401|403|Unauthorized|Forbidden') {
                    if ($Token) {
                        Write-Warning "Authentication with provided token failed for '$effectiveUri'. Verify your token is correct. The server configuration has been saved but may not work until corrected."
                    }
                    else {
                        Write-Information "Server '$effectiveUri' requires authentication." -InformationAction Continue

                        # Authenticate if -Force or user confirms
                        if ($Force -or $PSCmdlet.ShouldContinue(
                            'Would you like to authenticate now using Connect-PatAccount?',
                            'Authentication Required'
                        )) {
                            try {
                                $authenticationToken = Connect-PatAccount -Force:$Force
                                $newServer | Add-Member -NotePropertyName 'token' -NotePropertyValue $authenticationToken -Force
                                Write-Information "Authentication successful. Token added to server configuration." -InformationAction Continue
                            }
                            catch {
                                Write-Warning "Authentication failed: $($_.Exception.Message). Server saved without token."
                            }
                        }
                        else {
                            Write-Warning "Server saved without token. You may need to re-add with -Token parameter."
                        }
                    }
                }
                # Check for connection failures
                elseif ($errorMessage -match 'Unable to connect|No such host|refused|timed out|unreachable') {
                    Write-Warning "Unable to connect to server at '$effectiveUri'. The server may be offline or unreachable, but the configuration has been saved."
                }
                # Generic error
                else {
                    Write-Warning "Failed to validate server at '$effectiveUri': $errorMessage. The configuration has been saved but may not work correctly."
                }
            }
        }
        else {
            Write-Verbose "Skipping server validation as requested"
        }

        $configuration.servers += $newServer

        if ($PSCmdlet.ShouldProcess($Name, 'Add server to configuration')) {
            Set-PatServerConfiguration -Configuration $configuration -ErrorAction Stop
            Write-Verbose "Added server '$Name' to configuration"

            if ($PassThru) {
                $newServer
            }
        }
    }
    catch {
        throw "Failed to add server: $($_.Exception.Message)"
    }
}
