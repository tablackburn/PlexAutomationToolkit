param()

# Allow end users to add their own custom psake tasks
$customPsakeFile = Join-Path -Path $PSScriptRoot -ChildPath 'custom.psake.ps1'
if (Test-Path -Path $customPsakeFile) {
    Include -FileNamePathToInclude $customPsakeFile
}

properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    # Analyze against the repo's own PSScriptAnalyzer ruleset instead of PowerShellBuild's
    # bundled default. Analysis runs on every platform: loading a settings file no longer
    # crashes PSScriptAnalyzer on Linux/macOS (verified 2026-05 on pwsh 7.5), so the previous
    # non-Windows disable is no longer needed.
    $PSBPreference.Test.ScriptAnalysis.SettingsPath =
        Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
    # Use absolute paths for test output (relative paths resolve from tests directory)
    $PSBPreference.Test.OutputFile = [IO.Path]::Combine($PSScriptRoot, 'out', 'testResults.xml')
    $PSBPreference.Test.OutputFormat = 'NUnitXml'
    $PSBPreference.Test.CodeCoverage.Enabled = $false # TEMPORARY DIAGNOSTIC - REVERT
    # Coverage must target the staged build output, not the source tree — tests
    # Import-Module from Output/<Name>/<Version>, so Pester only records hits
    # against those paths. $Env:BHBuildOutput points at <root>/BuildOutput at
    # properties-evaluation time (PowerShellBuild rewrites it later inside its
    # tasks), so we compute the staged path from the manifest version here.
    if (-not $Env:BHPSModuleManifest -or -not $Env:BHProjectName) {
        throw 'Coverage configuration requires BuildHelpers env vars. Run via ./build.ps1 or call Set-BuildEnvironment first.'
    }
    $moduleVersion = (Import-PowerShellDataFile -Path $Env:BHPSModuleManifest).ModuleVersion
    $stagedOutput = [IO.Path]::Combine($PSScriptRoot, 'Output', $Env:BHProjectName, $moduleVersion)
    $PSBPreference.Test.CodeCoverage.Files = @(
        "$stagedOutput/Public/*.ps1"
        "$stagedOutput/Private/*.ps1"
    )
    $PSBPreference.Test.CodeCoverage.Threshold = 0  # Threshold enforced by Codecov
    $PSBPreference.Test.CodeCoverage.OutputFile = [IO.Path]::Combine($PSScriptRoot, 'out', 'codeCoverage.xml')
    $PSBPreference.Test.CodeCoverage.OutputFileFormat = 'JaCoCo'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Init_Integration' -Description 'Load integration test environment variables from local.settings.ps1' {
    $localSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'tests/local.settings.ps1'
    if (Test-Path -Path $localSettingsPath) {
        Write-Host "Loading integration test settings from tests/local.settings.ps1" -ForegroundColor Cyan
        . $localSettingsPath
    } else {
        Write-Host "No local.settings.ps1 found - integration tests will be skipped" -ForegroundColor Yellow
    }
}

# Populate the built manifest's ReleaseNotes from the matching CHANGELOG.md entry so the
# PowerShell Gallery release-notes panel shows the curated, user-facing notes (the same
# content used for the GitHub release) instead of just a link. Depends on Build so the
# staged manifest in ModuleOutDir exists; runs before Publish (see $PSBPublishDependency
# below). Non-fatal if the changelog can't be read or has no entry for the version being
# published, so a release is never blocked.
Task -Name 'UpdateReleaseNotes' -Depends 'Build' -Description 'Set built manifest ReleaseNotes from the matching CHANGELOG.md entry' {
    $changelogPath = Join-Path -Path $PSScriptRoot -ChildPath 'CHANGELOG.md'
    if (-not (Test-Path -Path $changelogPath)) {
        Write-Warning 'CHANGELOG.md not found; leaving ReleaseNotes unchanged.'
        return
    }

    $moduleVersion = $PSBPreference.General.ModuleVersion
    try {
        Import-Module -Name 'ChangelogManagement' -ErrorAction Stop
        $changelogData = Get-ChangelogData -Path $changelogPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not read CHANGELOG.md ($($_.Exception.Message)); leaving ReleaseNotes unchanged."
        return
    }

    $releaseEntry = $changelogData.Released |
        Where-Object { [string]$_.Version -eq [string]$moduleVersion } |
        Select-Object -First 1
    if (-not $releaseEntry) {
        Write-Warning "No CHANGELOG.md entry found for version $moduleVersion; leaving ReleaseNotes unchanged."
        return
    }

    $releaseNotes = $releaseEntry.RawData.Trim()
    if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
        Write-Warning "CHANGELOG.md entry for version $moduleVersion is empty; leaving ReleaseNotes unchanged."
        return
    }
    $builtManifest = Join-Path -Path $PSBPreference.Build.ModuleOutDir -ChildPath "$($PSBPreference.General.ModuleName).psd1"
    if (-not (Test-Path -Path $builtManifest)) {
        Write-Warning "Built manifest not found at '$builtManifest'; leaving ReleaseNotes unchanged."
        return
    }
    try {
        Update-ModuleManifest -Path $builtManifest -ReleaseNotes $releaseNotes -ErrorAction Stop
        Write-Host "  Set ReleaseNotes on built manifest from CHANGELOG [$($releaseEntry.Version)] ($($releaseNotes.Length) chars)" -ForegroundColor Gray
    }
    catch {
        # Keep publishing unblocked: a failure here just leaves the manifest's existing
        # ReleaseNotes in place rather than aborting the release.
        Write-Warning "Failed to set ReleaseNotes on the built manifest '$builtManifest' ($($_.Exception.Message)); leaving it unchanged."
    }
}

# Inject ReleaseNotes into the built manifest before publishing (PowerShellBuild's Publish
# defaults to depending only on 'Test').
$PSBPublishDependency = @('Test', 'UpdateReleaseNotes')

# Note: -Depends replaces PowerShellBuild's default dependencies, so we must include Pester and
# our own analysis task explicitly. We depend on a custom 'Lint' task (defined below) instead of
# PowerShellBuild's 'Analyze', because that task never fails the build: its Test-PSBuildScriptAnalysis
# - in every released PowerShellBuild version (through 0.8.0) and on its main branch - filters
# results with '$_Severity' (an undefined variable) instead of '$_.Severity', so its error/warning
# counts are always zero (upstream psake/PowerShellBuild#125). psake won't let us redefine the
# 'Analyze' task it loads via -FromModule (duplicate-name error), so we leave it unused and run our
# own task under a distinct name.
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3' -Depends 'Init_Integration', 'Pester', 'Lint'

Task -Name 'Lint' -Depends 'Build' -Description 'Run PSScriptAnalyzer against the built module and fail on the configured severity threshold' {
    if (-not $PSBPreference.Test.ScriptAnalysis.Enabled) {
        Write-Host 'Script analysis is disabled; skipping.'
        return
    }

    $analyzeParameters = @{
        Path     = $PSBPreference.Build.ModuleOutDir
        Settings = $PSBPreference.Test.ScriptAnalysis.SettingsPath
        Recurse  = $true
    }
    # PSScriptAnalyzer 1.25.0 intermittently throws a NullReferenceException
    # ("Object reference not set to an instance of an object.") from inside the
    # analyzer engine - a transient failure that has struck both Linux and Windows
    # CI runners (PRs #65 and #66) on otherwise-passing builds. It is not a code
    # defect and clears on a retry, so attempt the analysis a few times, retrying
    # only that specific null reference and letting any genuine error surface
    # immediately.
    $maxAnalysisAttempts = 3
    $analysisResult = $null
    for ($analysisAttempt = 1; $analysisAttempt -le $maxAnalysisAttempts; $analysisAttempt++) {
        try {
            $analysisResult = Invoke-ScriptAnalyzer @analyzeParameters
            break
        }
        catch {
            $isTransientNullReference =
                $_.Exception -is [NullReferenceException] -or
                $_.Exception.InnerException -is [NullReferenceException] -or
                $_.Exception.Message -like '*Object reference not set to an instance of an object*'
            if (-not $isTransientNullReference -or $analysisAttempt -eq $maxAnalysisAttempts) {
                throw
            }
            Write-Warning "PSScriptAnalyzer threw a transient null reference on attempt $analysisAttempt of $maxAnalysisAttempts; retrying. ($($_.Exception.Message))"
            Start-Sleep -Seconds 1
        }
    }
    if ($analysisResult) {
        $analysisResult | Format-Table -AutoSize | Out-String | Write-Host
    }

    # Count ParseError (unparseable/syntax-broken files) as an error too - PSScriptAnalyzer
    # reports those with Severity 'ParseError', which would otherwise bypass the 'Error' gate.
    $errorCount = @($analysisResult).Where({ $_.Severity -eq 'Error' -or $_.Severity -eq 'ParseError' }).Count
    $warningCount = @($analysisResult).Where({ $_.Severity -eq 'Warning' }).Count
    $informationCount = @($analysisResult).Where({ $_.Severity -eq 'Information' }).Count

    $failOnSeverity = $PSBPreference.Test.ScriptAnalysis.FailBuildOnSeverityLevel
    switch ($failOnSeverity) {
        'Error' {
            if ($errorCount -gt 0) {
                throw "PSScriptAnalyzer found $errorCount error(s)."
            }
        }
        'Warning' {
            if ($errorCount -gt 0 -or $warningCount -gt 0) {
                throw "PSScriptAnalyzer found $errorCount error(s) and $warningCount warning(s)."
            }
        }
        default {
            if ($errorCount -gt 0 -or $warningCount -gt 0 -or $informationCount -gt 0) {
                throw "PSScriptAnalyzer found $errorCount error(s), $warningCount warning(s), and $informationCount information record(s)."
            }
        }
    }

    Write-Host "PSScriptAnalyzer passed (errors: $errorCount, warnings: $warningCount, information: $informationCount; fail level: $failOnSeverity)."
}
