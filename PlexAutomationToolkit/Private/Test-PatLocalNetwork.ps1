function Test-PatLocalNetwork {
    <#
    .SYNOPSIS
        Tests if an IP address or hostname is on a local/private network.

    .DESCRIPTION
        Determines whether a given IP address falls within private IP ranges
        as defined by RFC 1918 (IPv4) and RFC 4193 (IPv6), or is a localhost address.

        Private IPv4 ranges:
        - 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)
        - 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
        - 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)
        - 127.0.0.0/8 (localhost)

        Private IPv6 ranges:
        - fc00::/7 (Unique Local Addresses)
        - ::1 (localhost)
        - fe80::/10 (Link-Local)

    .PARAMETER IPAddress
        The IP address to test. Can be an IPv4 or IPv6 address string.

    .PARAMETER Hostname
        A hostname to resolve and test. The function will attempt DNS resolution
        and test the resulting IP address(es).

    .OUTPUTS
        Boolean
        Returns $true if the address is on a private/local network, $false otherwise.

    .EXAMPLE
        Test-PatLocalNetwork -IPAddress "192.168.1.100"
        Returns: $true

    .EXAMPLE
        Test-PatLocalNetwork -IPAddress "8.8.8.8"
        Returns: $false

    .EXAMPLE
        Test-PatLocalNetwork -Hostname "plex.local"
        Returns: $true (if resolves to a private IP)

    .NOTES
        For hostnames that resolve to multiple IP addresses, returns $true if ANY
        of the resolved addresses is on a private network.
    #>
    [CmdletBinding(DefaultParameterSetName = 'IPAddress')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'IPAddress')]
        [ValidateNotNullOrEmpty()]
        [string]
        $IPAddress,

        [Parameter(Mandatory = $true, ParameterSetName = 'Hostname')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Hostname
    )

    # Helper function to test if an IP is in a private range
    function Test-PrivateIP {
        param([System.Net.IPAddress]$IP)

        if ($IP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            # IPv4
            $bytes = $IP.GetAddressBytes()

            # 10.0.0.0/8
            if ($bytes[0] -eq 10) {
                return $true
            }

            # 172.16.0.0/12 (172.16.x.x - 172.31.x.x)
            if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) {
                return $true
            }

            # 192.168.0.0/16
            if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) {
                return $true
            }

            # 127.0.0.0/8 (localhost)
            if ($bytes[0] -eq 127) {
                return $true
            }

            # 169.254.0.0/16 (link-local / APIPA)
            if ($bytes[0] -eq 169 -and $bytes[1] -eq 254) {
                return $true
            }

            return $false
        }
        elseif ($IP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            # IPv6
            $bytes = $IP.GetAddressBytes()

            # ::1 (localhost)
            if ($IP.ToString() -eq '::1') {
                return $true
            }

            # fc00::/7 (Unique Local Addresses) - first byte is fc or fd
            if ($bytes[0] -eq 0xfc -or $bytes[0] -eq 0xfd) {
                return $true
            }

            # fe80::/10 (Link-Local) - first byte is fe, second byte starts with 8, 9, a, or b
            if ($bytes[0] -eq 0xfe -and ($bytes[1] -band 0xc0) -eq 0x80) {
                return $true
            }

            return $false
        }

        return $false
    }

    if ($PSCmdlet.ParameterSetName -eq 'Hostname') {
        try {
            Write-Verbose "Resolving hostname '$Hostname' to IP address"
            $resolved = [System.Net.Dns]::GetHostAddresses($Hostname)

            if ($resolved.Count -eq 0) {
                Write-Verbose "No IP addresses resolved for hostname '$Hostname'"
                return $false
            }

            # Return true if any resolved IP is private
            foreach ($ip in $resolved) {
                if (Test-PrivateIP -IP $ip) {
                    Write-Verbose "Hostname '$Hostname' resolves to private IP: $($ip.ToString())"
                    return $true
                }
            }

            Write-Verbose "Hostname '$Hostname' resolves only to public IPs"
            return $false
        }
        catch {
            Write-Verbose "Failed to resolve hostname '$Hostname': $($_.Exception.Message)"
            return $false
        }
    }
    else {
        try {
            $ip = [System.Net.IPAddress]::Parse($IPAddress)
            $result = Test-PrivateIP -IP $ip
            Write-Verbose "IP '$IPAddress' is $(if ($result) { 'private' } else { 'public' })"
            return $result
        }
        catch {
            Write-Verbose "Failed to parse IP address '$IPAddress': $($_.Exception.Message)"
            return $false
        }
    }
}
