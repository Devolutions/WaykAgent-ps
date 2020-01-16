. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/DenHelper.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"
. "$PSScriptRoot/../Private/Base64Url.ps1"
. "$PSScriptRoot/../Private/UserAgent.ps1"
. "$PSScriptRoot/../Private/RSAHelper.ps1"

class WaykDenObject{
    [string]$DenUrl
    [string]$Realm
    [string]$DenID
    [string]$DenLocalPath
    [string]$DenGlobalPath
}

class WaykDenRegistrationObject{
    [bool]$IsRegistered
}

function Get-WaykNowDen(
    [switch]$All
){
    $WaykNowConfig = Get-WaykNowInfo
    $DenLocalPath = $WaykNowConfig.DenPath
    $DenGlobalPath = $WaykNowConfig.DenGlobalPath

    $localJson = Get-Content -Raw -Path "$DenLocalPath/default.json" | ConvertFrom-Json

    $Realm = $localJson.realm
    $denJson = Get-Content -Raw -Path "$DenLocalPath/$Realm/.state" | ConvertFrom-Json
    $settingJson = Get-Content -Raw -Path $WaykNowConfig.GlobalConfigFile | ConvertFrom-Json

    $WaykNowObject = [WaykDenObject]::New()
    $WaykNowObject.Realm = $Realm
    $WaykNowObject.DenID = $denJson.denId
    $WaykNowObject.DenUrl = $settingJson.DenUrl

    # TODO Remove this one when the Den Url will be always set in the settings file .cfg
    if(!($WaykNowObject.DenUrl)){
        $WaykNowObject.DenUrl = "https://den.wayk.net"
    }
    $WaykNowObject.DenLocalPath = "$DenLocalPath\$Realm"
    $WaykNowObject.DenGlobalPath = "$DenGlobalPath\$Realm"

    return $WaykNowObject
}

function Connect-WaykNowDen(
    [switch]$Force
){
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenLocalPath
    $WaykDenGlobalPath = $WaykNowDenObject.DenGlobalPath

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
            Write-Host "Unknown error $_"
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

        $oauthGlobalPath = "$WaykDenGlobalPath/oauth.cfg"
        $oauthPath = "$WaykDenPath/oauth.cfg"
        $oauthJson = Set-JsonValue $oauthJson "device_code" $device_authorization.device_code
        $fileValue = $oauthJson | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($oauthPath , $fileValue, $Utf8NoBomEncoding)
        [System.IO.File]::WriteAllLines($oauthGlobalPath , $fileValue, $Utf8NoBomEncoding)
    }
}

function Disconnect-WaykNowDen(
){
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenLocalPath
    $WaykDenGlobalPath = $WaykNowDenObject.DenGlobalPath

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

        $oauthGlobalPath = "$WaykDenGlobalPath/oauth.cfg"
        $oauthPath = "$WaykDenPath/oauth.cfg"
        $oauthDeviceCodeJson = Set-JsonValue $oauthDeviceCodeJson "device_code" $null
        $fileValue = $oauthDeviceCodeJson | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($oauthPath , $fileValue, $Utf8NoBomEncoding)
        [System.IO.File]::WriteAllLines($oauthGlobalPath , $fileValue, $Utf8NoBomEncoding)
    }
}

function Get-WaykNowMachine {
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $WaykDenPath = $WaykNowDenObject.DenLocalPath
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
        Write-Host "Unknown error $_"
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

function Register-WaykNowMachine(){
    # 1 : Is Windows
    if(!(Get-IsWindows)){
        throw (New-Object UnsuportedPlatformException("Windows"))
    }
    # 2 : Is Running in admin mode
    if(!(Get-IsRunAsAdministrator)) {
        throw (New-Object RunAsAdministratorException)
    }
    # 3 : Is Running in admin mode
    if (!(Get-Service "WaykNowService" -ErrorAction SilentlyContinue)){
        throw (New-Object UnattendedNotFound)
    }

    # 4 : Check if machine is registered
    $WaykNowDenRegistered = Get-WaykNowDenRegistration
    if($WaykNowDenRegistered.IsRegistered){
        throw "This machine is already registered"
    }

    $WaykNowUniqueID = Get-WaykNowUniqueID
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenPath = $WaykNowDenObject.DenGlobalPath
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $DenGlobalPath = $WaykNowDenObject.DenGlobalPath
    $oauthJson = Get-WaykNowDenOauthJson $WaykDenPath

    # 5 :  You are connected with Lucid
    if(!($oauthJson.device_code) -OR ($null -eq $oauthJson.device_code)){
        throw (New-Object NotConnectedException)
    }

    # 6 : Get the AccessToken
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
        Write-Host "Unknown error $_"
        Write-Host "Try Connect-WaykNowDen -Force"
        return;
    }

    # 7 : Get the CA Chain and test it
    $intermediateAuthority = "CN=" + $WaykNowDenObject.Realm + " Authority"
    $rootAuthority = "CN=" + $WaykNowDenObject.Realm + " Root CA"

    #Get Ca Chain from Den
    $contentsDen = Invoke-RestMethod -Uri "$WaykDenUrl/pki/chain" -Method 'GET' -ContentType 'text/plain'
    $ca_chain_from_den = @()
    $contentsDen | Select-String  -Pattern '(?smi)^-{2,}BEGIN CERTIFICATE-{2,}.*?-{2,}END CERTIFICATE-{2,}' `
    			-Allmatches | ForEach-Object {$_.Matches} | ForEach-Object { $ca_chain_from_den += $_.Value }

    if(!($ca_chain_from_den.Count -eq 2)){
        throw "Incorrect Wayk Den CA Chain"
    }

    $tempDirectory = New-TemporaryDirectory
    $DenChainPem = "$DenGlobalPath/$WaykNowUniqueID-ca-chain.pem"
    $DenIntermediateCa = "$tempDirectory/intermediate_ca.pem"
    $DenRootCa = "$tempDirectory/root_ca.pem"
    $Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($False)

    [System.IO.File]::WriteAllLines($DenChainPem, $contentsDen, $Utf8NoBomEncoding)
    [System.IO.File]::WriteAllLines($DenIntermediateCa, $ca_chain_from_den[0], $Utf8NoBomEncoding)
    [System.IO.File]::WriteAllLines($DenRootCa, $ca_chain_from_den[1], $Utf8NoBomEncoding)

    $intermediate_ca = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$DenIntermediateCa")
    $root_ca = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$DenRootCa")
    
    # Check the subject and the Isuer are the same
    if(!(($intermediate_ca.Subject -eq $intermediateAuthority) -AND ($intermediate_ca.Issuer -eq $rootAuthority))){
        Write-Host "intermediate Subject: " + $intermediate_ca.Subject + "Must be $intermediateAuthority"
        Write-Host "intermediate issuer: " + $intermediate_ca.Issuer  + "Must be $rootAuthority"
        throw "Incorrect intermediate Chain"
    }
    if(!(($root_ca.Subject -eq $rootAuthority) -AND ($root_ca.Issuer -eq $rootAuthority))){
        Write-Host "root Subject: " + $root_ca.Subject  + "Must be $rootAuthority"
        Write-Host "root issuer: " + $root_ca.Issuer+ "Must be $rootAuthority"
        throw "Incorrect Root Chain"
    }

    # 8 : Create CSR
    $key_size = 2048
    $subject = "CN=$WaykNowUniqueID"
    $rsa_key = [System.Security.Cryptography.RSA]::Create($key_size)

    $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        $subject, $rsa_key,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)

    $csr_der = $certRequest.CreateSigningRequest()

    $sb = [System.Text.StringBuilder]::new()
    $csr_base64 = [Convert]::ToBase64String($csr_der)

    $offset = 0
    $line_length = 64

    [void]$sb.AppendLine("-----BEGIN CERTIFICATE REQUEST-----")
    while ($offset -lt $csr_base64.Length) {
        $line_end = [Math]::Min($offset + $line_length, $csr_base64.Length)
        [void]$sb.AppendLine($csr_base64.Substring($offset, $line_end - $offset))
    $offset = $line_end
    }

    [void]$sb.AppendLine("-----END CERTIFICATE REQUEST-----")

    $csr_pem = $sb.ToString()

    $RSAParams = $rsa_key.ExportParameters($true);
    $privateKey = ExportPrivateKeyFromRSA $RSAParams
    $privateKey = $privateKey -Replace "`r`n", "`n"

    $DenCertificatePath = "$DenGlobalPath/$WaykNowUniqueID.crt"
    $DenKeyPath = "$DenGlobalPath/$WaykNowUniqueID.key"
    $DenCsrPath = "$DenGlobalPath/$WaykNowUniqueID.csr"

    [System.IO.File]::WriteAllLines($DenCsrPath, $csr_pem, $Utf8NoBomEncoding)
    [System.IO.File]::WriteAllLines($DenKeyPath, $privateKey, $Utf8NoBomEncoding)

    $csr = Get-Content "$DenCsrPath" | Out-String
    $csr = $csr -Replace "`r`n", "`n"

    # 9 : Sign CSR to Den
    $WaykNowUseAgent = Get-WaykNowUserAgent
    $ComputerName = $env:computername

    $headers = @{
        Authorization = "Bearer " + $access_token
    }

    $payload = [PSCustomObject]@{
        csr=$csr
        machine_id=[string]$WaykNowUniqueID
        machine_name=$ComputerName
        user_agent=$WaykNowUseAgent
    } | ConvertTo-Json

    $cert = Invoke-RestMethod -Uri "$WaykDenUrl/machine" -Method 'POST' -Headers $headers -ContentType 'application/json' -Body $payload

    if(!($cert.certificate)){
        throw "Error with signed CSR"
    }
    
    [System.IO.File]::WriteAllLines($DenCertificatePath, $cert.certificate, $Utf8NoBomEncoding)

    $leaf_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$DenCertificatePath")

    # 10 : Check if CSR signed is correct
    if(!(($leaf_cert.Subject -eq "$subject") -AND ($leaf_cert.Issuer -eq $intermediateAuthority))){
        Write-Host "Subject:" $leaf_cert.Subject
        Write-Host "Authority: " $leaf_cert.Issuer
        throw "Incorrect signature on certificate"
    }

    #11 load the chain and validate the leaf
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()

    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    [void]$chain.ChainPolicy.ExtraStore.Add($root_ca)
    [void]$chain.ChainPolicy.ExtraStore.Add($intermediate_ca)

    [void]$chain.Build($leaf_cert)

    $storeContainsCertficate = $chain.ChainPolicy.ExtraStore.Contains($chain.ChainElements[$chain.ChainElements.Count -1].Certificate)
    $IsUntrustedRoot = ([Linq.Enumerable]::First($chain.ChainStatus)).Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot

    if(($chain.ChainStatus.Length -gt 0) `
    -AND ($IsUntrustedRoot)`
    -AND ($storeContainsCertficate))
    {
        $isValidCertificate = $true
    }

    Remove-Item -Path $tempDirectory -Force -Recurse
   
    if(!($isValidCertificate )){
        $_ = Unregister-WaykNowMachine
        throw "Invalid Certificate Chain"
    }

    return "Machine Registered: " + $WaykNowUniqueID
}

function Unregister-WaykNowMachine(){
    # 1 : Is Windows
    if(!(Get-IsWindows)){
        throw (New-Object UnsuportedPlatformException("Windows"))
    }
    # 2 : Is Running in admin mode
    if(!(Get-IsRunAsAdministrator)) {
        throw (New-Object RunAsAdministratorException)
    }
    # 3 : Is Running in admin mode
    if (!(Get-Service "WaykNowService" -ErrorAction SilentlyContinue)){
        throw (New-Object UnattendedNotFound)
    }
    # 4 : Check if machine is registered
    $WaykNowDenRegistered = Get-WaykNowDenRegistration
    if(!($WaykNowDenRegistered.IsRegistered)){
        throw "This machine is not registered"
    }

    $WaykNowUniqueID = Get-WaykNowUniqueID
    $WaykNowDenObject = Get-WaykNowDen
    $WaykDenPath = $WaykNowDenObject.DenGlobalPath
    $WaykDenUrl = Format-WaykDenUrl $WaykNowDenObject.DenUrl
    $DenGlobalPath = $WaykNowDenObject.DenGlobalPath
    $oauthJson = Get-WaykNowDenOauthJson $WaykDenPath

    # 5 : You are connected with Lucid
    if(!($oauthJson.device_code) -OR ($null -eq $oauthJson.device_code)){
        throw (New-Object NotConnectedException)
    }

    # 6 : Get the AccessToken
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
        Write-Host "Unknown error $_"
        Write-Host "Try Connect-WaykNowDen -Force"
        return;
    }

    $headers = @{
        Authorization = "Bearer " + $access_token
    }

    #7 Remove Machine, and certificats files
    Invoke-RestMethod -Uri "$WaykDenUrl/machine/$WaykNowUniqueID" -Method 'DELETE' -Headers $headers -ContentType 'application/json'

    $_ = Remove-WaykNowMachineCertificate $DenGlobalPath
} 

function Remove-WaykNowMachineCertificate(
    [string] $DenGlobalPath
){
    $ListItem = Get-ChildItem -Path $DenGlobalPath
    $waykNowCRT = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}.crt'
    $waykNowCSR = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}.csr'
    $waykNowKEY = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}.key'
    $waykNowCaChainPEM = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}-ca-chain.pem'

    foreach($item in $ListItem){
        $path = "$DenGlobalPath\$item"

        if($item -CMatch $waykNowCRT){
            Remove-Item -Path $path -Force -Recurse
            continue;
        }
        if($item -CMatch $waykNowCSR){
            Remove-Item -Path $path -Force -Recurse
            continue;
        }
        if($item -CMatch $waykNowKEY){
            Remove-Item -Path $path -Force -Recurse
            continue;
        }
        if($item -CMatch $waykNowCaChainPEM){
            Remove-Item -Path $path -Force -Recurse
            continue;
        }
    }
}

function Get-WaykNowDenRegistration(){
    $WaykNowDenObject = Get-WaykNowDen
    $WaykNowDenRegistration = [WaykDenRegistrationObject]::new();
    $WaykNowDenRegistration.IsRegistered = $false;

    $DenGlobalPath = $WaykNowDenObject.DenGlobalPath
    $ListItem = Get-ChildItem -Path $DenGlobalPath
    $waykNowUniqueIDPattern = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}.crt'

    foreach($item in $ListItem){
        if($item -CMatch $waykNowUniqueIDPattern){
            #if file .crt is empty, just continue
            If ($Null -eq (Get-Content "$DenGlobalPath/$item")) {
                continue
            }
            $WaykNowDenRegistration.IsRegistered = $true;
            break;
        }
    }

    return $WaykNowDenRegistration;
}

Export-ModuleMember -Function Get-WaykNowDen, Connect-WaykNowDen, Disconnect-WaykNowDen, Get-WaykNowMachine, Register-WaykNowMachine, Unregister-WaykNowMachine, Get-WaykNowDenRegistration
