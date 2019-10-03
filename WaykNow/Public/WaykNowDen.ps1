. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/DenHelper.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"

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

    $Form = @{
        client_id = $val.wayk_client_id
        scope = 'openid profile'
        auth_type = 'none'
    }

    $oauthPath = "$WaykDenPath/oauth.cfg"
    $oauthJson
    if(Test-Path $oauthPath){
        $oauthJson = Get-Content -Raw -Path $oauthPath | ConvertFrom-Json
    }else{
        Add-PathIfNotExist $oauthPath $false
        $oauthJson = Get-Content -Raw -Path $oauthPath | ConvertFrom-Json
    }

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

    $oauthPath = "$WaykDenPath/oauth.cfg"
    $oauthJson
    if(Test-Path $oauthPath){
        $oauthJson = Get-Content -Raw -Path $oauthPath | ConvertFrom-Json
    }else{
        Add-PathIfNotExist $oauthPath $false
        $oauthJson = Get-Content -Raw -Path $oauthPath | ConvertFrom-Json
    }
    if($oauthJson.device_code){
        $deviceCode = $oauthJson.device_code
        try{
            $_ = Invoke-RestMethod -Uri "$lucidUrl/auth/device-logout?code=$deviceCode" -Method 'POST' -ContentType 'application/x-www-form-urlencoded'
        }
        catch{
            #Just hide error from here, you can try to disconnect with an device code who not work at all so // miam
        }

        $oauthJson = Set-JsonValue $oauthJson "device_code" $null
        $fileValue = $oauthJson | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($oauthPath , $fileValue, $Utf8NoBomEncoding)
    }
}

Export-ModuleMember -Function Get-WaykNowDen, Connect-WaykNowDen, Disconnect-WaykNowDen