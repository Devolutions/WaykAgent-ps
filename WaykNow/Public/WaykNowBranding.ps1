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
    Copy-Item -Path $BrandingPath -Destination $OutputPath -Force
}

function Reset-WaykNowBranding
{
    [CmdletBinding()]
    param()

    [WaykNowInfo]$WaykNowInfo = Get-WaykNowInfo
    $DataPath = $WaykNowInfo.DataPath;
    $brandingPath = "$DataPath/branding.zip"

    if (Test-Path -Path $brandingPath){
        Remove-Item -Path $brandingPath -Force -ErrorAction SilentlyContinue
    }

    if (Get-IsWindows) {
        $dataGlobalPath = $WaykNowInfo.GlobalPath;
        $brandingGlobalPath = "$dataGlobalPath/branding.zip"

        if (Test-Path -Path $brandingGlobalPath) {
            Remove-Item -Path $brandingGlobalPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Set-WaykNowBranding, Reset-WaykNowBranding
