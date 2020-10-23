. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

function Set-WaykAgentBranding
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string] $BrandingPath,
        [switch] $Force
    )

    $DataPath = Get-WaykAgentPath -PathType "GlobalPath"
    $OutputPath = Join-Path $DataPath "branding.zip"
    New-Item -Path $(Split-Path $OutputPath -Parent) -ItemType 'Directory' -Force | Out-Null
    Copy-Item -Path $BrandingPath -Destination $OutputPath -Force
}

function Reset-WaykAgentBranding
{
    [CmdletBinding()]
    param()

    $DataPath = Get-WaykAgentPath -PathType "GlobalPath"
    $BrandingPath = "$DataPath/branding.zip"

    if (Test-Path -Path $BrandingPath) {
        Remove-Item -Path $BrandingPath -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Set-WaykAgentBranding, Reset-WaykAgentBranding
