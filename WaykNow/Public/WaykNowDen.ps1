. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/DenHelper.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"

class WaykDenObject{
    [string]$DenUrl
    [string]$Realm
    [string]$DenID
    [string]$DenPath
}

function Get-WaykNowDen(
    [switch]$All
){
    $WaykNowConfig = Get-WaykNowInfo
    $DenLocalPath = $WaykNowConfig.DenPath
    $localJson = Get-Content -Raw -Path "$DenLocalPath/default.json" | ConvertFrom-Json

    $Realm = $localJson.realm
    $denJson = Get-Content -Raw -Path "$DenLocalPath/$Realm/.state" | ConvertFrom-Json
    $settingJson = Get-Content -Raw -Path $WaykNowConfig.ConfigFile | ConvertFrom-Json

    $WaykNowObject = [WaykDenObject]::New()
    $WaykNowObject.Realm = $Realm
    $WaykNowObject.DenID = $denJson.denId
    $WaykNowObject.DenUrl = $settingJson.DenUrl

    # TODO Remove this one when the Den Url will be alwways set in the settings file .cfg
    if(!($WaykNowObject.DenUrl)){
        $WaykNowObject.DenUrl = "wss://den.wayk.net"
    }
    $WaykNowObject.DenPath = "$DenLocalPath/$Realm"

    return $WaykNowObject
}

function Connect-WaykNowDen(
    [switch]$Force
){
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenPath

    $val = (Invoke-RestMethod -Uri "$WaykDenUrl/.well-known/configuration" -Method 'GET' -ContentType 'application/json')
    $lucidUrl = $val.lucid_uri

    $oauthJson = Get-WaykNowDenOauthJson $WaykDenPath

    #if there is aleady oauthCode in oauth.cfg
    if($oauthJson.device_code -AND !($Force)){
        $FormPoke = @{
            client_id = $val.wayk_client_id
            device_code = $oauthJson.device_code
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
        }

        try{
            $result = Invoke-RestMethod -Uri "$lucidUrl/auth/token" -Method 'POST' -ContentType 'application/x-www-form-urlencoded' -Body $FormPoke
            $openIdConfig = Invoke-RestMethod -Uri "$lucidUrl/openid/.well-known/openid-configuration" -Method 'GET' -ContentType 'application/json'
            $access_token = $result.access_token
            
            $Header= @{
                Authorization = "Bearer " + $access_token
                Accept = '*/*'
            }

            $userInfo = Invoke-RestMethod -Uri $openIdConfig.userinfo_endpoint -Method 'GET' -Headers $Header
            $name = ''
            if($userInfo.name){
                $name = $userInfo.name
            }
            else{
                $name = $userInfo.username
            }
            Write-Host "`"$name`" is already connected, you can use -Force to force reconnect"
        }
        catch {
            Write-Host "Unknow error $_"
            Write-Host "Try to use -Force"
        }
    }
    else{
        # if force, disconnect the current sessions
        if($Force){
            $_ = Disconnect-WaykNowDen
        }

        $Form = @{
            client_id = $val.wayk_client_id
            scope = 'openid profile'
            auth_type = 'none'
        }

        $device_authorization = (Invoke-RestMethod -Uri "$lucidUrl/auth/device-authorization" -Method 'POST' -ContentType 'application/x-www-form-urlencoded' -Body $Form)

        $verificationUri = $device_authorization.verification_uri
    
        $FormPoke = @{
            client_id = $val.wayk_client_id
            device_code = $device_authorization.device_code
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
        }
    
        Start-Process $verificationUri -ErrorAction SilentlyContinue
    
        $pokeCode = '400'
        while($pokeCode -eq '400'){
            Start-Sleep -Seconds $device_authorization.interval -ErrorAction SilentlyContinue
    
            try{
                $result = Invoke-RestMethod -Uri "$lucidUrl/auth/token" -Method 'POST' -ContentType 'application/x-www-form-urlencoded' -Body $FormPoke
                $pokeCode = '200'
                $openIdConfig = Invoke-RestMethod -Uri "$lucidUrl/openid/.well-known/openid-configuration" -Method 'GET' -ContentType 'application/json'
                $access_token = $result.access_token
            
                $Header= @{
                Authorization = "Bearer " + $access_token
                Accept = '*/*'
            }

            $userInfo = Invoke-RestMethod -Uri $openIdConfig.userinfo_endpoint -Method 'GET' -Headers $Header
            $name = ''
            if($userInfo.name){
                $name = $userInfo.name
            }
            else{
                $name = $userInfo.username
            }
            Write-Host "`"$name`" is now connected"

            }
            catch [Microsoft.PowerShell.Commands.HttpResponseException]{
                $pokeCode = $_.Exception.Response.StatusCode.Value__
                if(!($pokeCode -eq '400')){
                    throw $_
                }
            }
        }

        $oauthPath = "$WaykDenPath/oauth.cfg"
        $oauthJson = Set-JsonValue $oauthJson "device_code" $device_authorization.device_code
        $fileValue = $oauthJson | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($oauthPath , $fileValue, $Utf8NoBomEncoding)
    }
}

function Disconnect-WaykNowDen(
){
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenPath

    $val = (Invoke-RestMethod -Uri "$WaykDenUrl/.well-known/configuration" -Method 'GET' -ContentType 'application/json')
    $lucidUrl = $val.lucid_uri

    $oauthDeviceCodeJson = Get-WaykNowDenOauthJson $WaykDenPath
    if($oauthDeviceCodeJson.device_code){
        $deviceCode = $oauthDeviceCodeJson.device_code
        try{
            $_ = Invoke-RestMethod -Uri "$lucidUrl/auth/device-logout?code=$deviceCode" -Method 'POST' -ContentType 'application/x-www-form-urlencoded'
        }
        catch{
            #Just hide error from here, you can try to disconnect with an device code who not work at all so // miam
        }

        $oauthPath = "$WaykDenPath/oauth.cfg"
        $oauthDeviceCodeJson = Set-JsonValue $oauthDeviceCodeJson "device_code" $null
        $fileValue = $oauthDeviceCodeJson | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($oauthPath , $fileValue, $Utf8NoBomEncoding)
    }
}

function Get-WaykNowDenMachine {
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenPath
    $oauthJson = Get-WaykNowDenOauthJson $WaykDenPath

    if(!($oauthJson.device_code) -OR ($null -eq $oauthJson.device_code)){
        throw (New-Object NotConnectedException)
    }

    $val = (Invoke-RestMethod -Uri "$WaykDenUrl/.well-known/configuration" -Method 'GET' -ContentType 'application/json')
    $lucidUrl = $val.lucid_uri

    try{
        $FormPoke = @{
            client_id = $val.wayk_client_id
            device_code = $oauthJson.device_code
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
        }

        $getToken = Invoke-RestMethod -Uri "$lucidUrl/auth/token" -Method 'POST' -ContentType 'application/x-www-form-urlencoded' -Body $FormPoke
        $access_token = $getToken.access_token
    }
    catch {
        Write-Host "Unknow error $_"
        Write-Host "Try Connect-WaykNowDen -Force"
        return;
    }
            
    $Header = @{
        Authorization = "Bearer " + $access_token
    }

    $machineResult = Invoke-RestMethod -Uri "$WaykDenUrl/machine" -Method 'GET' -ContentType 'application/json' -Headers $Header

    $MachineReport = @()
    foreach($machine in $machineResult){
        $PSObject = New-Object PSObject -Property @{
            UserAgent = $machine.user_agent
            MachineName = $machine.machine_name
            DenID = $machine.den_id
            State = $machine.state
        }
        $MachineReport += $PSObject
    }

    return $MachineReport | Format-Table MachineName, DenID, State, UserAgent
}

Export-ModuleMember -Function Get-WaykNowDen, Connect-WaykNowDen, Disconnect-WaykNowDen, Get-WaykNowDenMachine