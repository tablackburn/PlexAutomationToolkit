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

    # Test settings - use relative paths from project root
    $PSBPreference.Test.Enabled = $true
    $PSBPreference.Test.RootDir = Join-Path -Path $PSScriptRoot -ChildPath 'tests'
    $PSBPreference.Test.OutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'out/testResults.xml'
    $PSBPreference.Test.OutputFormat = 'NUnitXml'
    $PSBPreference.Test.CodeCoverage.Enabled = $true
    $PSBPreference.Test.CodeCoverage.Threshold = 0.70  # 70% minimum coverage
    $PSBPreference.Test.CodeCoverage.OutputPath = Join-Path -Path $PSScriptRoot -ChildPath 'out/coverage.xml'
    $PSBPreference.Test.CodeCoverage.OutputFormat = 'JaCoCo'
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

# Override the Pester dependency to include Init_Integration before running tests
# This ensures integration test env vars are loaded before Pester runs
$PSBPesterDependency = @('Build', 'Init_Integration')

Task -Name 'Pester' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'
Task -Name 'Analyze' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'
