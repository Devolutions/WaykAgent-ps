. "$PSScriptRoot/../Public/WaykNowPackage.ps1"
$OS_VERSION_UNKNOWN = "Unknown";
function Get-WaykNowUserAgent(){
    return Build-UserAgent
}

function Build-UserAgent(){
    return (Get-ProductInfo) + " " + (Get-PlatformInfo)
}

function Get-ProductInfo(){
    return "WaykNow/" + (Get-WaykNowVersion)
}

function Get-PlatformInfo(){
    if (Get-IsWindows) {
        $version = $OS_VERSION_UNKNOWN
        $versionExtra = $OS_VERSION_UNKNOWN
        $osVersion = (Get-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
        $osVersionExtra = (Get-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId

        if($osVersion){
            $version= $osVersion
        }
        if($osVersionExtra){
            $versionExtra = $osVersionExtra
        }
        return "(Windows; $version $versionExtra)"

	} elseif ($IsMacOS) {
        $version = $OS_VERSION_UNKNOWN
        $versionExtra = $OS_VERSION_UNKNOWN
        $osVersion = $(Invoke-Process -FilePath "sw_vers" -ArgumentList "-productVersion")
        $osVersionExtra = $(Invoke-Process -FilePath "sw_vers" -ArgumentList "-buildVersion")

        if($osVersion){
            $version= $osVersion -replace "`n", ""
        }
        if($osVersionExtra){
            $versionExtra = $osVersionExtra -replace "`n", ""
        }
        return "(macOS; $version $versionExtra)"
	} elseif ($IsLinux) {
        $version = $OS_VERSION_UNKNOWN
        $osVersion = $(Invoke-Process -FilePath "lsb_release" -ArgumentList "-d -s")

        if($osVersion){
            $version= $osVersion -replace "`n", ""
        }
        return "(Linux; $version)"
	}}

