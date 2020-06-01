function Get-IsWindows
{
    if (-Not (Test-Path 'variable:global:IsWindows')) {
        return $true # Windows PowerShell 5.1 or earlier
    } else {
        return $IsWindows
    }
}

function Get-WindowsHostArch
{
    if ([System.Environment]::Is64BitOperatingSystem) {
        if (($Env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($Env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')) {
            return "ARM64"
        } else {
            return "x64"
        }
    } else {
        return "x86"
    }
}

function Get-UninstallRegistryKey(
	[string] $display_name = 'Wayk Now'
){
    if ([System.Environment]::Is64BitOperatingSystem) {
        $uninstall_base_reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    } else {
        $uninstall_base_reg = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    }

    return Get-ChildItem $uninstall_base_reg `
        | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name };
}

function New-TemporaryDirectory()
{
	$parent = [System.IO.Path]::GetTempPath()
	$name = [System.IO.Path]::GetRandomFileName()
	return New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Get-FileEncoding(
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
    [string]$Path
)
{
    [byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

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

function Add-PathIfNotExist(
	[string] $path,
	[bool] $isFolder
)
{
	if($isFolder) {
		if (!(Test-Path $path)) {
		    $_ = New-Item -path $path -ItemType Directory -Force
		}
	}
	else {
		if (!(Test-Path $path))	{
            $_ = New-Item -path $path -ItemType File -Force
		}
	}
}
