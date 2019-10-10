. "$PSScriptRoot/../Public/WaykNowLicense.ps1"
. "$PSScriptRoot/../Public/WaykNowProgram.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"

function Enable-WaykNowLogs(
    [LoggingLevel] $LoggingLevel,
    [switch]$Restart
){
    if($null -eq $LoggingLevel) {
        $LoggingLevel = [LoggingLevel]::Debug
    }

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    $WaykInfo = Get-WaykNowInfo

    if(Get-IsWindows) {
        if (Get-Service "WaykNowService" -ErrorAction SilentlyContinue) {
            if(!(Get-IsRunAsAdministrator)) {
                throw (New-Object RunAsAdministratorException)
            }
            $jsonGlobal = Get-Content -Raw -Path $WaykInfo.GlobalDataPath | ConvertFrom-Json
            $jsonGlobal = Set-JsonValue $jsonGlobal 'LoggingLevel' $LoggingLevel
            $fileValue = $jsonGlobal | ConvertTo-Json
            [System.IO.File]::WriteAllLines($WaykInfo.GlobalDataPath, $fileValue, $Utf8NoBomEncoding)
        }
    }

    $json = Get-Content -Raw -Path $WaykInfo.ConfigFile | ConvertFrom-Json
    $json = Set-JsonValue $json 'LoggingLevel' $LoggingLevel
    $fileValue = $json | ConvertTo-Json
    [System.IO.File]::WriteAllLines($WaykInfo.ConfigFile, $fileValue, $Utf8NoBomEncoding)

    if($Restart){
        $_ = Restart-WaykNow
    }
    else{
        Write-Host "Changes will only be applied after an application restart" 
    }
}

function Disable-WaykNowLogs(
    [switch]$Restart
){
    if($Restart){
        Enable-WaykNowLogs -LoggingLevel "Off" -Restart
    }
    else{
        Enable-WaykNowLogs -LoggingLevel "Off"
    }
}

function Export-WaykNowLogs(
    [Parameter(Mandatory = $true)]
    [string] $ExportPath
){
    try{
        $ExportPath = Resolve-Path -Path $ExportPath
    }catch{
        throw "This path does not exist"
    }

    $WaykInfo = Get-WaykNowInfo

    if(Get-IsWindows) {
        if (Get-Service "WaykNowService" -ErrorAction SilentlyContinue) {
            if(!(Get-IsRunAsAdministrator)) {
                throw (New-Object RunAsAdministratorException)
            }

            Copy-Item -Path $WaykInfo.LogGlobalPath -Destination $ExportPath -Force -Recurse
        }
    }

    Copy-Item -Path $WaykInfo.LogPath -Destination $ExportPath -Force -Recurse
}

function Clear-WaykNowLogs(){
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    $WaykInfo = Get-WaykNowInfo

    if(Get-IsWindows) {
        if (Get-Service "WaykNowService" -ErrorAction SilentlyContinue) {
            if(!(Get-IsRunAsAdministrator)) {
                throw (New-Object RunAsAdministratorException)
            }

            Remove-Item -Path $WaykInfo.LogGlobalPath -Force -Recurse
        }
    }

    Remove-Item -Path $WaykInfo.LogPath -Force -Recurse
}

Export-ModuleMember -Function Enable-WaykNowLogs, Disable-WaykNowLogs, Export-WaykNowLogs, Clear-WaykNowLogs