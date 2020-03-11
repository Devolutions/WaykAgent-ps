function Get-WaykNowUniqueId
{
    $waykNowInfo = Get-WaykNowInfo

    $idPath = $waykNowInfo.DataPath

    if ((Get-IsWindows) -And (Get-Service "WaykNowService" -ErrorAction SilentlyContinue)){
        $idPath = $waykNowInfo.GlobalPath
    }

    $idPath = "$idPath/.unique"

    if (Test-Path $idPath)
    {
        return Get-Content -Path $idPath -Raw -Encoding UTF8
    }
}

Export-ModuleMember -Function Get-WaykNowUniqueId
