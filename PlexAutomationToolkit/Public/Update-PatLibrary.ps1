function Update-PatLibrary {
    <#
    .SYNOPSIS
        Refreshes a Plex library section.

    .DESCRIPTION
        Triggers a refresh scan on a specified Plex library section.
        Optionally scans a specific path within the library.
        You can specify the section by ID or by friendly name.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER SectionId
        The ID of the library section to refresh

    .PARAMETER SectionName
        The friendly name of the library section to refresh (e.g., "Movies", "TV Shows")

    .PARAMETER Path
        Optional path within the library to scan. If omitted, the entire section is scanned.

    .PARAMETER PassThru
        If specified, returns the library section object after refreshing.

    .PARAMETER SkipPathValidation
        If specified, skips validation that the path exists before triggering the refresh.
        Use when you know the path is valid or want to scan a path that may not be browsable.

    .PARAMETER Wait
        If specified, waits for the library scan to complete before returning.

    .PARAMETER Timeout
        Maximum time in seconds to wait for the scan to complete when using -Wait.
        Default is 300 seconds (5 minutes).

    .PARAMETER ReportChanges
        If specified, returns a report of changes detected during the scan.
        Automatically enables -Wait behavior.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2

        Refreshes the entire library section 2.

    .EXAMPLE
        Update-PatLibrary -SectionName "Movies"

        Refreshes the "Movies" library section on the default stored server.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies"

        Refreshes the library section named "Movies".

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -Path "/mnt/media/Movies"

        Refreshes only the specified path within library section 2.

    .EXAMPLE
        Update-PatLibrary -SectionId 2 -Path "/mnt/media/Movies"

        Refreshes only the specified path within library section 2 on the default stored server.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies" -Path "/mnt/media/Movies/Action"

        Refreshes only the specified path within the "Movies" library section.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -WhatIf

        Shows what would happen if the command runs without actually refreshing the library.

    .EXAMPLE
        Update-PatLibrary -SectionId 2 -PassThru

        Refreshes library section 2 and returns the library object.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'

        Validates that the path exists (default behavior), then triggers the refresh.
        Throws an error if the path is invalid or not within the library's configured paths.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -SkipPathValidation

        Skips path validation and triggers the refresh directly. Use when you know the
        path is valid or want to scan a path that may not be browsable.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -Wait

        Validates the path, triggers the refresh, and waits for the scan to complete.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -Wait -Timeout 60

        Validates the path, triggers the refresh, and waits up to 60 seconds for completion.

    .EXAMPLE
        $changes = Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -ReportChanges
        $changes | Where-Object ChangeType -eq 'Added'

        Returns a list of items that were added or removed by the scan.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -Token $myToken -SectionId 2

        Refreshes library section 2 using an explicit server URI and token.
        Use this when you don't have the server stored in configuration.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $SectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $PassThru,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $SkipPathValidation,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $Wait,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateRange(1, 3600)]
        [int]
        $Timeout = 300,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $ReportChanges,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
    )

    try {
        $serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
    }
    catch {
        throw "Failed to resolve server: $($_.Exception.Message)"
    }

    $effectiveUri = $serverContext.Uri
    $headers = $serverContext.Headers
    $usingStoredServer = -not $serverContext.WasExplicitUri

    # If using section name, resolve it to section ID
    $resolvedSectionId = $SectionId
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        try {
            # If using stored server, don't pass ServerUri so Get-PatLibrary can retrieve server object with token
            $libParams = @{ ErrorAction = 'Stop' }
            if ($serverContext.WasExplicitUri) {
                $libParams['ServerUri'] = $effectiveUri
                if ($Token) { $libParams['Token'] = $Token }
            }
            elseif ($ServerName) {
                $libParams['ServerName'] = $ServerName
            }
            $sections = Get-PatLibrary @libParams
            $matchedSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }

            if (-not $matchedSection) {
                throw "No library section found with name '$SectionName'"
            }

            if ($matchedSection -is [array]) {
                throw "Multiple library sections found with name '$SectionName'. Please use -SectionId instead."
            }

            $resolvedSectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
        }
        catch {
            throw "Failed to resolve section name: $($_.Exception.Message)"
        }
    }

    # Pre-validation: Check if path exists (default behavior, skip with -SkipPathValidation)
    if ($Path -and -not $SkipPathValidation) {
        Write-Verbose "Validating path: $Path"
        $testParameters = @{ Path = $Path }
        # Only pass ServerUri/Token when using explicit URI, otherwise pass ServerName
        if ($serverContext.WasExplicitUri) {
            if ($effectiveUri) { $testParameters['ServerUri'] = $effectiveUri }
            if ($Token) { $testParameters['Token'] = $Token }
        }
        elseif ($ServerName) {
            $testParameters['ServerName'] = $ServerName
        }
        if ($resolvedSectionId) { $testParameters['SectionId'] = $resolvedSectionId }

        $pathValid = Test-PatLibraryPath @testParameters
        if (-not $pathValid) {
            throw "Path validation failed: '$Path' does not exist or is not within the library's configured paths. Use -SkipPathValidation to bypass this check."
        }
        Write-Verbose "Path validation passed"
    }

    # Capture before state if we need to report changes
    $beforeItems = $null
    if ($ReportChanges) {
        Write-Verbose "Capturing library state before scan"
        $getItemParameters = @{ SectionId = $resolvedSectionId }
        if ($effectiveUri) { $getItemParameters['ServerUri'] = $effectiveUri }
        $beforeItems = @(Get-PatLibraryItem @getItemParameters -ErrorAction 'SilentlyContinue')
        Write-Verbose "Captured $($beforeItems.Count) items before scan"
    }

    $endpoint = "/library/sections/$resolvedSectionId/refresh"
    $queryString = $null

    if ($Path) {
        $queryString = "path=$([System.Uri]::EscapeDataString($Path))"
    }

    $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryString

    if ($Path) {
        $target = "section $resolvedSectionId path '$Path'"
    }
    else {
        $target = "section $resolvedSectionId"
    }

    if ($PSCmdlet.ShouldProcess($target, 'Refresh library')) {
        try {
            Invoke-PatApi -Uri $uri -Method 'Post' -Headers $headers -ErrorAction 'Stop'

            # Wait for scan to complete if requested
            if ($Wait -or $ReportChanges) {
                Write-Verbose "Waiting for scan to complete (timeout: ${Timeout}s)"
                $waitParameters = @{
                    SectionId       = $resolvedSectionId
                    Timeout         = $Timeout
                    PollingInterval = 2
                }
                if ($effectiveUri) { $waitParameters['ServerUri'] = $effectiveUri }

                Wait-PatLibraryScan @waitParameters
                Write-Verbose "Scan completed"
            }

            # Report changes if requested
            if ($ReportChanges) {
                Write-Verbose "Capturing library state after scan"
                $getItemParameters = @{ SectionId = $resolvedSectionId }
                if ($effectiveUri) { $getItemParameters['ServerUri'] = $effectiveUri }
                $afterItems = @(Get-PatLibraryItem @getItemParameters -ErrorAction 'SilentlyContinue')
                Write-Verbose "Captured $($afterItems.Count) items after scan"

                $changes = Compare-PatLibraryContent -Before $beforeItems -After $afterItems
                $changes
            }
            elseif ($PassThru) {
                # Return the refreshed library section
                $libParams = @{ SectionId = $resolvedSectionId; ErrorAction = 'Stop' }
                if ($serverContext.WasExplicitUri) {
                    $libParams['ServerUri'] = $effectiveUri
                    if ($Token) { $libParams['Token'] = $Token }
                }
                elseif ($ServerName) {
                    $libParams['ServerName'] = $ServerName
                }
                Get-PatLibrary @libParams
            }
        }
        catch {
            throw "Failed to refresh Plex library: $($_.Exception.Message)"
        }
    }
}
