function Get-WaykAgentUniqueId
{
    [CmdletBinding()]
    param()

    $WaykAgentInfo = Get-WaykAgentInfo

    $idPath = $WaykAgentInfo.DataPath

    if ((Get-IsWindows) -And (Get-Service "WaykAgentService" -ErrorAction SilentlyContinue)){
        $idPath = $WaykAgentInfo.GlobalPath
    }

    $idPath = "$idPath/.unique"

    if (Test-Path $idPath)
    {
        return Get-Content -Path $idPath -Raw -Encoding UTF8
    }
}

Export-ModuleMember -Function Get-WaykAgentUniqueId
