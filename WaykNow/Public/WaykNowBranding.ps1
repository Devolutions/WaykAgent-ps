. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/Invoke-Process.ps1"

function Set-WaykNowBranding
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string] $BrandingPath,
        [switch] $Force
    )

    $DataPath = Get-WaykNowPath -PathType "GlobalPath"
    $OutputPath = Join-Path $DataPath "branding.zip"
    New-Item -Path $(Split-Path $OutputPath -Parent) -ItemType 'Directory' -Force | Out-Null
    Copy-Item -Path $BrandingPath -Destination $OutputPath -Force
}

function Reset-WaykNowBranding
{
    [CmdletBinding()]
    param()

    $DataPath = Get-WaykNowPath -PathType "GlobalPath"
    $BrandingPath = "$DataPath/branding.zip"

    if (Test-Path -Path $BrandingPath) {
        Remove-Item -Path $BrandingPath -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Set-WaykNowBranding, Reset-WaykNowBranding
