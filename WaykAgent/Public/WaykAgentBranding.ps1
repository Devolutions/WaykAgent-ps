. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

function Set-WaykAgentBranding
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string] $BrandingPath,
        [switch] $Force
    )

    $ConfigPath = Get-WaykAgentPath
    $OutputPath = Join-Path $ConfigPath "branding.zip"
    New-Item -Path $(Split-Path $OutputPath -Parent) -ItemType 'Directory' -Force | Out-Null
    Copy-Item -Path $BrandingPath -Destination $OutputPath -Force
}

function Reset-WaykAgentBranding
{
    [CmdletBinding()]
    param()

    $ConfigPath = Get-WaykAgentPath
    $BrandingPath = Join-Path $ConfigPath "branding.zip"

    if (Test-Path -Path $BrandingPath) {
        Remove-Item -Path $BrandingPath -Force -ErrorAction SilentlyContinue
    }
}
