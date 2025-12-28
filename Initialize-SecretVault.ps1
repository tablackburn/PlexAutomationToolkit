<#
.SYNOPSIS
    Initializes and unlocks the SecretStore vault for PlexAutomationToolkit.

.DESCRIPTION
    Reads the vault password from local.secrets.json and either creates a new
    SecretStore vault or unlocks an existing one. The vault is configured for
    non-interactive use (no password prompt, no timeout).

.EXAMPLE
    . .\Initialize-SecretVault.ps1

    Dot-source to initialize the vault in the current session.

.NOTES
    Requires Microsoft.PowerShell.SecretManagement and Microsoft.PowerShell.SecretStore modules.
    Copy local.secrets.template.json to local.secrets.json and set a secure password.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Check for required modules
$requiredModules = @('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "Required module '$module' not installed. Run: Install-Module $module -Scope CurrentUser"
        return
    }
    Import-Module $module -ErrorAction Stop
}

# Read vault password from local.secrets.json
$secretsPath = Join-Path $PSScriptRoot 'local.secrets.json'
if (-not (Test-Path $secretsPath)) {
    Write-Error @"
local.secrets.json not found. Create it from the template:
    Copy-Item local.secrets.template.json local.secrets.json
Then generate a secure password:
    `$password = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
    `$json = @{ vaultPassword = `$password } | ConvertTo-Json
    Set-Content local.secrets.json `$json
"@
    return
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
$vaultPassword = $secrets.vaultPassword | ConvertTo-SecureString -AsPlainText -Force

$vaultName = 'PlexAutomationToolkit'

# Check if vault exists
$existingVault = Get-SecretVault -Name $vaultName -ErrorAction SilentlyContinue

if (-not $existingVault) {
    Write-Host "Creating new SecretStore vault '$vaultName'..." -ForegroundColor Cyan

    # Configure SecretStore for non-interactive use
    $storeConfig = @{
        Authentication  = 'Password'
        PasswordTimeout = -1  # Never timeout (stay unlocked for session)
        Interaction     = 'None'  # No interactive prompts
        Password        = $vaultPassword
        Confirm         = $false
    }
    Set-SecretStoreConfiguration @storeConfig

    # Register the vault
    Register-SecretVault -Name $vaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
    Write-Host "Vault '$vaultName' created and set as default." -ForegroundColor Green
}
else {
    Write-Host "Unlocking existing vault '$vaultName'..." -ForegroundColor Cyan
}

# Unlock the vault
Unlock-SecretStore -Password $vaultPassword
Write-Host "Vault '$vaultName' unlocked for this session." -ForegroundColor Green

# Show vault status
$vault = Get-SecretVault -Name $vaultName
Write-Host "Vault: $($vault.Name) | Module: $($vault.ModuleName) | Default: $($vault.IsDefault)" -ForegroundColor Gray
