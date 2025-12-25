function Get-PatClientIdentifier {
    <#
    .SYNOPSIS
        Retrieves or generates a unique client identifier for Plex API authentication.

    .DESCRIPTION
        Returns a persistent unique identifier used in Plex API requests to identify this
        device/application. The identifier is generated once and stored in the configuration
        file for reuse across sessions.

    .OUTPUTS
        System.String
        Returns a GUID-based client identifier
    #>
    [CmdletBinding()]
    param ()

    try {
        $config = Get-PatServerConfig

        # Check if clientIdentifier already exists
        if ($config.PSObject.Properties['clientIdentifier'] -and $config.clientIdentifier) {
            Write-Verbose "Using existing client identifier: $($config.clientIdentifier)"
            return $config.clientIdentifier
        }

        # Generate new client identifier
        $clientIdentifier = [System.Guid]::NewGuid().ToString()
        Write-Verbose "Generated new client identifier: $clientIdentifier"

        # Add to config and save
        $config | Add-Member -MemberType NoteProperty -Name 'clientIdentifier' -Value $clientIdentifier -Force
        Set-PatServerConfig -Config $config

        return $clientIdentifier
    }
    catch {
        throw "Failed to get client identifier: $($_.Exception.Message)"
    }
}
