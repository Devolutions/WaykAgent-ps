function Set-WaykNowLicense
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string] $License
    )

    $licensePattern = '[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}'
    $WaykNowInfo = Get-WaykNowInfo
    $ConfigFile = $WaykNowInfo.ConfigFile

    if ($License -CMatch $licensePattern) {

        if (Test-Path $ConfigFile) {
            $json = Get-Content -Path $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } else {
            $json = '{}' | ConvertFrom-Json
        }

        if ($json.RegistrationSerial)
        {
            $json.RegistrationSerial = $License;
        }
        else
        {
            # If the json is empty
            if (!$json) {
                $json = '{}'
                $json = ConvertFrom-Json $json
            }
            
            $json | Add-Member -Type NoteProperty -Name 'RegistrationSerial' -Value $License -Force
        }

        New-Item -Path $(Split-Path $ConfigFile -Parent) -ItemType 'Directory' -Force

        $fileValue = $json | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($ConfigFile, $fileValue, $Utf8NoBomEncoding)
    } else {
        Write-Error "Invalid License Format"
    }
}

function Get-WaykNowLicense
{
    [CmdletBinding()]
    param()

    [WaykNowInfo]$WaykInfo = Get-WaykNowInfo

    if (Test-Path $WaykInfo.ConfigFile) {
        $json = Get-Content -Path $WaykInfo.ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        return $json.RegistrationSerial;
    } else {
        return $null
    }
}

function Reset-WaykNowLicense
{
    [CmdletBinding()]
    param()

    [WaykNowInfo]$WaykInfo = Get-WaykNowInfo

    if (Test-Path $WaykInfo.ConfigFile) {
        $json = Get-Content -Path $WaykInfo.ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($json.RegistrationSerial) {
            $json.RegistrationSerial = ''
            $fileValue = $json | ConvertTo-Json
            $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($WaykInfo.ConfigFile, $fileValue, $Utf8NoBomEncoding)
        }
    }
}

Export-ModuleMember -Function Set-WaykNowLicense, Get-WaykNowLicense, Reset-WaykNowLicense
