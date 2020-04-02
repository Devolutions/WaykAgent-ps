. "$PSScriptRoot/../Public/WaykNowLicense.ps1"
. "$PSScriptRoot/../Public/WaykNowProgram.ps1"

function Enable-WaykNowLogs
{
    [CmdletBinding()]
    param(
        [LoggingLevel] $LoggingLevel,
        [switch] $Global,
        [switch] $Restart
    )

    if ($null -eq $LoggingLevel) {
        $LoggingLevel = [LoggingLevel]::Debug
    }

    Set-WaykNowConfig -Global:$Global -LoggingLevel $LoggingLevel

    if ($Restart) {
        Restart-WaykNow
    } else {
        Write-Host "Changes will only be applied after an application restart" 
    }
}

function Disable-WaykNowLogs
{
    [CmdletBinding()]
    param(
        [switch] $Global,
        [switch] $Restart
    )

    Enable-WaykNowLogs -LoggingLevel 'Off' -Global:$Global -Restart:$Restart
}

function Export-WaykNowLogs
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $ExportPath
    )

    if (-Not (Test-Path $ExportPath)) {
        New-Item -Path $ExportPath -ItemType 'Directory' -ErrorAction Stop | Out-Null
    }

    $WaykInfo = Get-WaykNowInfo
    $GlobalLogPath = $WaykInfo.LogGlobalPath
    $LocalLogPath = $WaykInfo.LogPath

    Get-ChildItem -Path $GlobalLogPath -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $ExportPath $_.Name) -Force
    }

    Get-ChildItem -Path $LocalLogPath -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $ExportPath $_.Name) -Force
    }
}

function Clear-WaykNowLogs
{
    [CmdletBinding()]
    param()

    $WaykInfo = Get-WaykNowInfo
    $GlobalLogPath = $WaykInfo.LogGlobalPath
    $LocalLogPath = $WaykInfo.LogPath

    Remove-Item -Path $GlobalLogPath -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $LocalLogPath -Force -Recurse -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Enable-WaykNowLogs, Disable-WaykNowLogs, Export-WaykNowLogs, Clear-WaykNowLogs