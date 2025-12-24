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
        unauthenticated local network access. Use Get-PatToken for instructions on obtaining your token.

        WARNING: Tokens are stored in PLAINTEXT in servers.json. Only use on trusted systems.

    .PARAMETER PassThru
        If specified, returns the server configuration object after adding.

    .PARAMETER SkipValidation
        If specified, skips validation of server connectivity and token authentication.
        Use this when adding a server that is temporarily offline or not yet configured.

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
        [ValidateScript({
            if ($_ -notmatch '^https?://[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*(:[0-9]{1,5})?$') {
                throw "ServerUri must be a valid HTTP or HTTPS URL (e.g., http://plex.local:32400)"
            }
            $true
        })]
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
        $SkipValidation
    )

    try {
        # Warn if using unencrypted HTTP
        if ($ServerUri -match '^http://') {
            Write-Warning "Using unencrypted HTTP connection to '$ServerUri'. Authentication tokens will be transmitted in clear text. Consider using HTTPS for secure communication."
        }

        $config = Get-PatServerConfig -ErrorAction Stop

        # Check for duplicate name
        if ($config.servers | Where-Object { $_.name -eq $Name }) {
            throw "A server with name '$Name' already exists"
        }

        # If marking as default, unset other defaults
        if ($Default) {
            foreach ($server in $config.servers) {
                $server.default = $false
            }
        }

        # Add new server
        $newServer = [PSCustomObject]@{
            name    = $Name
            uri     = $ServerUri
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
                $validationUri = Join-PatUri -BaseUri $ServerUri -Endpoint '/'

                # Build headers with authentication if token provided
                $validationHeaders = Get-PatAuthHeaders -Server $newServer

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
                        Write-Warning "Authentication with provided token failed for '$ServerUri'. Verify your token is correct using Get-PatToken. The server configuration has been saved but may not work until corrected."
                    }
                    else {
                        Write-Warning "Server '$ServerUri' requires authentication but no token was provided. The server configuration has been saved but you may need to add a token using Remove-PatServer and Add-PatServer with -Token parameter."
                    }
                }
                # Check for connection failures
                elseif ($errorMessage -match 'Unable to connect|No such host|refused|timed out|unreachable') {
                    Write-Warning "Unable to connect to server at '$ServerUri'. The server may be offline or unreachable, but the configuration has been saved."
                }
                # Generic error
                else {
                    Write-Warning "Failed to validate server at '$ServerUri': $errorMessage. The configuration has been saved but may not work correctly."
                }
            }
        }
        else {
            Write-Verbose "Skipping server validation as requested"
        }

        $config.servers += $newServer

        if ($PSCmdlet.ShouldProcess($Name, 'Add server to configuration')) {
            Set-PatServerConfig -Config $config -ErrorAction Stop
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
