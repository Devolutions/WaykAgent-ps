. "$PSScriptRoot/../Public/WaykAgentProgram.ps1"

function Enable-WaykAgentLogs
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

    Set-WaykAgentConfig -Global:$Global -LoggingLevel $LoggingLevel

    if ($Restart) {
        Restart-WaykAgent
    } else {
        Write-Host "Changes will only be applied after an application restart" 
    }
}

function Disable-WaykAgentLogs
{
    [CmdletBinding()]
    param(
        [switch] $Global,
        [switch] $Restart
    )

    Enable-WaykAgentLogs -LoggingLevel 'Off' -Global:$Global -Restart:$Restart
}

function Export-WaykAgentLogs
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $ExportPath
    )

    if (-Not (Test-Path $ExportPath)) {
        New-Item -Path $ExportPath -ItemType 'Directory' -ErrorAction Stop | Out-Null
    }

    $WaykInfo = Get-WaykAgentInfo
    $GlobalLogPath = $WaykInfo.LogGlobalPath
    $LocalLogPath = $WaykInfo.LogPath

    Get-ChildItem -Path $GlobalLogPath -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $ExportPath $_.Name) -Force
    }

    Get-ChildItem -Path $LocalLogPath -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $ExportPath $_.Name) -Force
    }
}

function Clear-WaykAgentLogs
{
    [CmdletBinding()]
    param()

    $WaykInfo = Get-WaykAgentInfo
    $GlobalLogPath = $WaykInfo.LogGlobalPath
    $LocalLogPath = $WaykInfo.LogPath

    Remove-Item -Path $GlobalLogPath -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $LocalLogPath -Force -Recurse -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Enable-WaykAgentLogs, Disable-WaykAgentLogs, Export-WaykAgentLogs, Clear-WaykAgentLogs