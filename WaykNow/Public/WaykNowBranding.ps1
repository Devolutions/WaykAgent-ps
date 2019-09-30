. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/Invoke-Process.ps1"

function Set-WaykNowBranding(
    [Parameter(Mandatory = $true, HelpMessage= "brancing.7z file path")]
    [string] $BrandingPath
){
    if((Get-IsWindows) -or ($IsMacOS)){
        [WaykNowInfo]$WaykNowInfo = Get-WaykNowInfo
        $dataPath = $WaykNowInfo.DataPath;
        $tempDirectory = New-TemporaryDirectory
        $fileLocation = "$tempDirectory/branding.7z"

        try{
            $web_client = [System.Net.WebClient]::new()
            $web_client.DownloadFile($brandingPath, $fileLocation)
            $web_client.Dispose()
        }
        catch{
            if(Test-Path -Path $brandingPath){
                $fileLocation = $brandingPath
            }
            else{
                throw (New-Object IncorrectPath)
            }
        }
    
        $fileName = Split-Path -Path $fileLocation -Leaf
        if(!$fileName.Equals("branding.7z"))
        {
            Rename-Item -Path "$fileLocation" -NewName "branding.7z"
        }

        Copy-Item -path $fileLocation -destination $dataPath
        Remove-Item -Path $tempDirectory -Force -Recurse
    }else{
        throw (New-Object UnsuportedPlatformException("Windows, MacOs"))
    }
}

function Reset-WaykNowBranding(){
    if((Get-IsWindows) -or ($IsMacOS)){
        [WaykNowInfo]$WaykNowInfo = Get-WaykNowInfo
        $dataPath = $WaykNowInfo.DataPath;
        $brandingPath = "$dataPath/branding.7z"

        if(Test-Path -Path $brandingPath){
            Remove-Item -Path $brandingPath -Force -ErrorAction SilentlyContinue
        }

        if(Get-IsWindows){
            $dataGlobalPath = $WaykNowInfo.GlobalPath;
            $brandingGlobalPath = "$dataGlobalPath/branding.7z"
            if(Test-Path -Path $brandingGlobalPath){
                if(!(Get-IsRunAsAdministrator)) {
                    throw (New-Object RunAsAdministratorException)
                }
                Remove-Item -Path $brandingGlobalPath -Force -ErrorAction SilentlyContinue
            }
        }
    }else{
        throw (New-Object UnsuportedPlatformException("Windows, MacOs"))
    }
}

function Test-WaykNowBranding(
    [Parameter(Mandatory = $true, HelpMessage= "brancing.7z file path")]
    [string] $BrandingPath
){
    if((Get-IsWindows)){
        if (Get-Command "7z.exe" -ErrorAction SilentlyContinue) { 
            try{

                if(!(Test-Path -Path $BrandingPath)){
                    throw (New-Object IncorrectPath)
                }

                $format = [System.IO.Path]::GetExtension("$BrandingPath")
                if(!($format -eq ".7z")){
                    throw (New-Object IncorrectFormat($format,"7z.exe"))
                }

                $tempDirectory = New-TemporaryDirectory
                Start-Process -FilePath '7z.exe' -ArgumentList "e $BrandingPath -o$tempDirectory -r" -Wait

                $manifestPath = Resolve-Path "$tempDirectory/manifest.json"
                $encoding = Get-FileEncoding($manifestPath)
                if(!($encoding -eq 'UTF8-NOBOM')){
                    throw (New-Object IncorrectFormat($encoding,'UTF8-NOBOM'))
                }

                try{
                    $jsonString = Get-Content -Raw -Path $manifestPath -Encoding utf8 | ConvertFrom-Json

                }
                catch{
                    Write-Error "For more details try to parse the json here :
                    https://jsonlint.com/"
                    Write-Error $_.Exception.Message
                    return;
                }
                $fileValue = $jsonString | ConvertTo-Json
                $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
                [System.IO.File]::WriteAllLines($manifestPath, $fileValue, $Utf8NoBomEncoding)

                Remove-Item -Path $tempDirectory -Force -Recurse
                Write-Host "Success"
            }
            catch{
                Write-Error $_.Exception.Message
            }
        }
        else{
            throw (New-Object SoftwareRequired("7z.exe", "https://www.7-zip.org/download.html"))
        }
    }else{
        throw (New-Object UnsuportedPlatformException("Windows"))
    }
}

function Get-FileEncoding(
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
    [string]$Path
)
{
    [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

    if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ){ 
        Write-Output 'UTF8-BOM' 
    }
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff){
        Write-Output 'Unicode' 
    }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff){ 
        Write-Output 'UTF32' 
    }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76){
        Write-Output 'UTF7'
    }
    else{
        Write-Output 'UTF8-NOBOM'
    }
}

Export-ModuleMember -Function Set-WaykNowBranding, Reset-WaykNowBranding, Test-WaykNowBranding