function Format-WaykDenUrl(
    [Parameter(Mandatory=$true, HelpMessage="Den URL")]
    [string] $DenUrl
){
    $result = ''
    [System.Uri]$Url = $DenUrl
    if(($Url.Host -eq "den.wayk.net") -OR ($Url.Host -eq "den.wayk.lol")){
        $DenUrlHost = $Url.Host
        $result =  "https://api.$DenUrlHost"
    }
    elseif(($Url.Scheme -eq "https") -OR ($Url.Scheme -eq "wss")){
        $urlHost = $Url.Host
        $port = $Url.Port
        $path = $Url.Path
        $result =  "https://$urlHost`:$port$path"
    }
    elseif(($Url.Scheme -eq "http") -OR ($Url.Scheme -eq "ws")){
        $urlHost = $Url.Host
        $port = $Url.Port
        $path = $Url.Path
        $result =  "http://$urlHost`:$port$path"
    }
    else{
        return $null
    }

    if($result.endswith("/")){
        $result.TrimEnd("/")
    }

    return $result
}
