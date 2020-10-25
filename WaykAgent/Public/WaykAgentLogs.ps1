. "$PSScriptRoot/../Public/WaykAgentProgram.ps1"

function Enable-WaykAgentLogs
{
    [CmdletBinding()]
    param(
        [LoggingLevel] $LoggingLevel,
        [switch] $Restart
    )

    if ($null -eq $LoggingLevel) {
        $LoggingLevel = [LoggingLevel]::Debug
    }

    Set-WaykAgentConfig -LoggingLevel $LoggingLevel

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
        [switch] $Restart
    )

    Enable-WaykAgentLogs -LoggingLevel 'Off' -Restart:$Restart
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

    $ConfigPath = Get-WaykAgentPath
    $LogPath = Join-Path $ConfigPath "logs"

    Get-ChildItem -Path $LogPath -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $ExportPath $_.Name) -Force
    }
}

function Clear-WaykAgentLogs
{
    [CmdletBinding()]
    param()

    $ConfigPath = Get-WaykAgentPath
    $LogPath = Join-Path $ConfigPath "logs"

    Remove-Item -Path $LogPath -Force -Recurse -ErrorAction SilentlyContinue
}
