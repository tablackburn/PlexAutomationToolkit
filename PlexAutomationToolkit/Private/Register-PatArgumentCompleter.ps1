function Register-PatArgumentCompleter {
    <#
    .SYNOPSIS
        Registers argument completers for PlexAutomationToolkit commands.

    .DESCRIPTION
        This function registers all argument completers used by the module.
        It is called from the module's psm1 file after all functions are loaded.
        Using Register-ArgumentCompleter ensures the scriptblocks run in the
        module's scope, giving them access to private helper functions.
    #>
    # Suppress unused parameter warnings - completer scriptblocks require these parameters by signature
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'commandName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'parameterName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'commandAst')]
    [CmdletBinding()]
    param()

    # ============================================================
    # Shared Completer Scriptblocks
    # These are thin wrappers that call the testable helper functions
    # ============================================================

    # SectionName completer - used by multiple commands
    $SectionNameCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $params = @{ WordToComplete = $wordToComplete }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $params['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $params['Token'] = $fakeBoundParameters['Token']
        }

        Get-PatSectionNameCompletion @params
    }

    # SectionId completer - used by multiple commands
    $SectionIdCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $params = @{ WordToComplete = $wordToComplete }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $params['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $params['Token'] = $fakeBoundParameters['Token']
        }

        Get-PatSectionIdCompletion @params
    }

    # Path completer for Update-PatLibrary - browses Plex server filesystem
    $LibraryPathCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $params = @{ WordToComplete = $wordToComplete }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $params['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('SectionId')) {
            $params['SectionId'] = $fakeBoundParameters['SectionId']
        }
        if ($fakeBoundParameters.ContainsKey('SectionName')) {
            $params['SectionName'] = $fakeBoundParameters['SectionName']
        }

        Get-PatLibraryPathCompletion @params
    }

    # Collection name completer
    $CollectionTitleCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $params = @{ WordToComplete = $wordToComplete }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $params['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $params['Token'] = $fakeBoundParameters['Token']
        }
        if ($fakeBoundParameters.ContainsKey('SectionId')) {
            $params['SectionId'] = $fakeBoundParameters['SectionId']
        }
        if ($fakeBoundParameters.ContainsKey('SectionName')) {
            $params['SectionName'] = $fakeBoundParameters['SectionName']
        }

        Get-PatCollectionTitleCompletion @params
    }

    # Playlist title completer
    $PlaylistTitleCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $params = @{ WordToComplete = $wordToComplete }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $params['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $params['Token'] = $fakeBoundParameters['Token']
        }

        Get-PatPlaylistTitleCompletion @params
    }

    # ============================================================
    # Register Completers for Each Command
    # ============================================================

    # Update-PatLibrary
    Register-ArgumentCompleter -CommandName 'Update-PatLibrary' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Update-PatLibrary' -ParameterName 'Path' -ScriptBlock $LibraryPathCompleter

    # Get-PatLibrary - no completers needed (just retrieves all sections)

    # Get-PatLibraryPath
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryPath' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryPath' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatLibraryChildItem
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryChildItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryChildItem' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatLibraryItem
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryItem' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Search-PatMedia
    Register-ArgumentCompleter -CommandName 'Search-PatMedia' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Search-PatMedia' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatCollection
    Register-ArgumentCompleter -CommandName 'Get-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatCollection' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # New-PatCollection
    Register-ArgumentCompleter -CommandName 'New-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter

    # Remove-PatCollection
    Register-ArgumentCompleter -CommandName 'Remove-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Remove-PatCollection' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Add-PatCollectionItem
    Register-ArgumentCompleter -CommandName 'Add-PatCollectionItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Add-PatCollectionItem' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Remove-PatCollectionItem
    Register-ArgumentCompleter -CommandName 'Remove-PatCollectionItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Remove-PatCollectionItem' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Get-PatPlaylist
    Register-ArgumentCompleter -CommandName 'Get-PatPlaylist' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Remove-PatPlaylist
    Register-ArgumentCompleter -CommandName 'Remove-PatPlaylist' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Add-PatPlaylistItem
    Register-ArgumentCompleter -CommandName 'Add-PatPlaylistItem' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Sync-PatMedia
    Register-ArgumentCompleter -CommandName 'Sync-PatMedia' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter

    # Get-PatSyncPlan
    Register-ArgumentCompleter -CommandName 'Get-PatSyncPlan' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
}
