function Set-JsonValue(
    [PSCustomObject] $json,
    [string] $name,
    [PSCustomObject] $value
)
{
    if ($json.$name) {
        $json.$name = $value;
    } else {
        # If the json is empty
        if (!$json) {
            $json = '{}'
            $json = ConvertFrom-Json $json
        }
          
        $json | Add-Member -Type NoteProperty -Name $name -Value $value -Force
    }

    return $json
}

function Get-WaykNowDenOauthJson(
    [string]$WaykDenPath
){
    $oauthPath = "$WaykDenPath/oauth.cfg"
    $oauthJson = ''

    if (Test-Path $oauthPath) {
        $oauthJson = Get-Content -Path $oauthPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        Add-PathIfNotExist $oauthPath $false
        $oauthJson = Get-Content -Path $oauthPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    return $oauthJson
}
