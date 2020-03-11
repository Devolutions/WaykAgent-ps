function Get-WaykNowUniqueID{
    $waykNowInfo = Get-WaykNowInfo

    $idPath = $waykNowInfo.DataPath

    if ((Get-IsWindows) -And (Get-Service "WaykNowService" -ErrorAction SilentlyContinue)){
        $idPath = $waykNowInfo.GlobalPath
    }

    $idPath = "$idPath/.unique"

    if (Test-Path $idPath)
    {
        return Get-Content -Raw -Path $idPath
    }
}

Export-ModuleMember -Function Get-WaykNowUniqueID