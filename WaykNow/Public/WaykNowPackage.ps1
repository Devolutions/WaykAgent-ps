
. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"

function Get-WaykNowVersion
{
	if (Get-IsWindows) {
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Now'
		if ($uninstall_reg) {
			$version = $uninstall_reg.DisplayVersion
			return $version
		}
	} elseif ($IsMacOS) {
		$info_plist_path = "/Applications/WaykNow.app/Contents/Info.plist"
		$cf_bundle_version_xpath = "//dict/key[. ='CFBundleVersion']/following-sibling::string[1]"
		if (Test-Path -Path $info_plist_path) {
			$version = $(Select-Xml -Path $info_plist_path -XPath $cf_bundle_version_xpath `
				| Foreach-Object {$_.Node.InnerXML }).Trim()
			return $version
		}
	} elseif ($IsLinux) {
		$dpkg_status = $(Invoke-Process -FilePath 'dpkg' -ArgumentList "-s wayk-now" -IgnoreExitCode)
		$matches = $($dpkg_status | Select-String -AllMatches -Pattern 'version: (\S+)').Matches
		if ($matches) {
			$version = $matches.Groups[1].Value
			return $version
		}
	}

	return $null
}
function Get-WaykNowPackage(
	[string] $Version
)
{
	$version_quad = '';
	$products_url = "https://devolutions.net/products.htm"
	$products_htm = Invoke-RestMethod -Uri $products_url -Method 'GET' -ContentType 'text/plain'
	$matches = $($products_htm | Select-String -AllMatches -Pattern "Wayk.Version=(\S+)").Matches
	if($version)
	{
		$version_quad = $version
	}
	else
	{
		$version_quad = $matches.Groups[1].Value
	}
	$download_base = "https://cdn.devolutions.net/download"
	$download_url_x64 = "$download_base/Wayk/$version_quad/WaykNow-x64-$version_quad.msi"
	$download_url_x86 = "$download_base/Wayk/$version_quad/WaykNow-x86-$version_quad.msi"
	$download_url_mac = "$download_base/Mac/Wayk/$version_quad/Wayk.Mac.$version_quad.dmg"
	$download_url_deb = "$download_base/Linux/Wayk/$version_quad/wayk-now_${version_quad}_amd64.deb"

	$version_matches = $($version_quad | Select-String -AllMatches -Pattern "(\d+)`.(\d+)`.(\d+)`.(\d+)").Matches
	$version_major = $version_matches.Groups[1].Value
	$version_minor = $version_matches.Groups[2].Value
	$version_patch = $version_matches.Groups[3].Value
	$version_triple = "${version_major}.${version_minor}.${version_patch}"

	$download_url = $null

	if (Get-IsWindows) {
		if ([System.Environment]::Is64BitOperatingSystem) {
			$download_url = $download_url_x64
		} else {
			$download_url = $download_url_x86
		}
	} elseif ($IsMacOS) {
		$download_url = $download_url_mac
	} elseif ($IsLinux) {
		$download_url = $download_url_deb
	}
 
    $result = [PSCustomObject]@{
        Url = $download_url
        Version = $version_triple
    }

	return $result
}
function Install-WaykNow(
	[switch] $Force,
	[string] $Version
){
	if(Get-IsWindows){
        if(!(Get-IsRunAsAdministrator)) {
			throw (New-Object RunAsAdministratorException)
		}
	}

	$tempDirectory = New-TemporaryDirectory
	$package = Get-WaykNowPackage $Version
	$latest_version = $package.Version
	$current_version = Get-WaykNowVersion

	if (([version]$latest_version -gt [version]$current_version) -Or $Force) {
		Write-Host "Installing Wayk Now ${latest_version}"
	} else {
		Write-Host "Wayk Now is already up to date"
		return
	}

	if(([version]$current_version -gt [version]$latest_version) -And $Force)
	{
		Uninstall-WaykNow
	}

	$download_url = $package.url
	$download_file = Split-Path -Path $download_url -Leaf
	$download_file_path = "$tempDirectory/$download_file"
	Write-Host "Downloading $download_url"

	$web_client = [System.Net.WebClient]::new()
	$web_client.DownloadFile($download_url, $download_file_path)
	$web_client.Dispose()
	
	$download_file_path = Resolve-Path $download_file_path

	if (Get-IsWindows) {
		$install_log_file = "$tempDirectory/WaykNow_Install.log"
		$msi_args = @(
			'/i', $download_file_path,
			'/quiet', '/norestart',
			'/log', $install_log_file
		)
		Start-Process "msiexec.exe" -ArgumentList $msi_args -Wait -NoNewWindow

		Remove-Item -Path $install_log_file -Force -ErrorAction SilentlyContinue
	} elseif ($IsMacOS) {
		$volumes_wayk_now = "/Volumes/WaykNow"
		if (Test-Path -Path $volumes_wayk_now -PathType 'Container') {
			Start-Process 'hdiutil' -ArgumentList @('unmount', $volumes_wayk_now) -Wait
		}
		Start-Process 'hdiutil' -ArgumentList @('mount', "$download_file_path") `
			-Wait -RedirectStandardOutput '/dev/null'
		Wait-Process $(Start-Process 'sudo' -ArgumentList @('cp', '-R', `
			"${volumes_wayk_now}/WaykNow.app", "/Applications") -PassThru).Id
		Start-Process 'hdiutil' -ArgumentList @('unmount', $volumes_wayk_now) `
			-Wait -RedirectStandardOutput '/dev/null'
		Wait-Process $(Start-Process 'sudo' -ArgumentList @('ln', '-sfn', `
			"/Applications/WaykNow.app/Contents/MacOS/WaykNow",
			"/usr/local/bin/wayk-now") -PassThru).Id
	} elseif ($IsLinux) {
		$dpkg_args = @(
			'-i', $download_file_path
		)
		if ((id -u) -eq 0) {
			Start-Process 'dpkg' -ArgumentList $dpkg_args -Wait
		} else {
			$dpkg_args = @('dpkg') + $dpkg_args
			Start-Process 'sudo' -ArgumentList $dpkg_args -Wait
		}
	}

	Remove-Item -Path $tempDirectory -Force -Recurse
}

function Uninstall-WaykNow
{
	Stop-WaykNow
	
	if (Get-IsWindows) {
		# https://stackoverflow.com/a/25546511
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Now'
		if ($uninstall_reg) {
			$uninstall_string = $($uninstall_reg.UninstallString `
				-Replace "msiexec.exe", "" -Replace "/I", "" -Replace "/X", "").Trim()
			$msi_args = @(
				'/X', $uninstall_string, '/qb'
			)
			Start-Process "msiexec.exe" -ArgumentList $msi_args -Wait
		}
	} elseif ($IsMacOS) {
		$wayk_now_app = "/Applications/WaykNow.app"
		if (Test-Path -Path $wayk_now_app -PathType 'Container') {
			Start-Process 'sudo' -ArgumentList @('rm', '-rf', $wayk_now_app) -Wait
		}
		$wayk_now_symlink = "/usr/local/bin/wayk-now"
		if (Test-Path -Path $wayk_now_symlink) {
			Start-Process 'sudo' -ArgumentList @('rm', $wayk_now_symlink) -Wait
		}
	} elseif ($IsLinux) {
		if (Get-WaykNowVersion) {
			$apt_args = @(
				'-y', 'remove', 'wayk-now', '--purge'
			)
			if ((id -u) -eq 0) {
				Start-Process 'apt-get' -ArgumentList $apt_args -Wait
			} else {
				$apt_args = @('apt-get') + $apt_args
				Start-Process 'sudo' -ArgumentList $apt_args -Wait
			}
		}
	}
}

class WaykNowInfo
{
	[string] $DataPath
	[string] $GlobalDataPath
	[string] $ConfigFile
	[string] $LogPath
	[string] $CertificateFile
	[string] $PrivateKeyFile
	[string] $PasswordVault
	[string] $KnownHostsFile
	[string] $BookmarksFile
}

function Get-WaykNowInfo()
{
	$DataPath = '';
	$GlobalDataPath = '';
	$resolvedGlobalPath = '';
	if (Get-IsWindows)	{
		Add-PathIfNotExist "$Env:APPDATA\Wayk" $true
		$DataPath = $Env:APPDATA + '\Wayk';
		if (Get-Service "WaykNowService" -ErrorAction SilentlyContinue)	{
			if(Get-IsRunAsAdministrator)	{
				Add-PathIfNotExist "$Env:ALLUSERSPROFILE\Wayk" $true
				Add-PathIfNotExist "$Env:ALLUSERSPROFILE\Wayk\WaykNow.cfg" $false
			}

			$GlobalDataPath = $Env:ALLUSERSPROFILE + '\Wayk\WaykNow.cfg'
			$resolvedGlobalPath = Resolve-Path -Path $GlobalDataPath
		}
	} elseif ($IsMacOS) {
		Add-PathIfNotExist "~/Library/Application Support/Wayk" $true
		$DataPath = '~/Library/Application Support/Wayk'
	} elseif ($IsLinux) {
		Add-PathIfNotExist "~/.config/Wayk" $true
		$DataPath = '~/.config/Wayk'
	}

	$resolvedPath = Resolve-Path -Path $DataPath

	Add-PathIfNotExist "$resolvedPath/WaykNow.cfg" $false
	Add-PathIfNotExist "$resolvedPath/logs" $true
	Add-PathIfNotExist "$resolvedPath/bookmarks" $true

	Add-PathIfNotExist "$resolvedPath/WaykNow.crt" $false
	Add-PathIfNotExist "$resolvedPath/WaykNow.key" $false
	Add-PathIfNotExist "$resolvedPath/WaykNow.vault" $false
	Add-PathIfNotExist "$resolvedPath/known_hosts" $false

	$WaykNowInfoObject = [WaykNowInfo]::New()
	$WaykNowInfoObject.DataPath = $resolvedPath
	$WaykNowInfoObject.GlobalDataPath = $resolvedGlobalPath
	$WaykNowInfoObject.ConfigFile =  Resolve-Path -Path "$resolvedPath/WaykNow.cfg" 
	$WaykNowInfoObject.LogPath =  Resolve-Path -Path "$resolvedPath/logs" 
	$WaykNowInfoObject.CertificateFile =  Resolve-Path -Path "$resolvedPath/WaykNow.crt" 
	$WaykNowInfoObject.PrivateKeyFile =   Resolve-Path -Path "$resolvedPath/WaykNow.key" 
	$WaykNowInfoObject.PasswordVault =  Resolve-Path -Path "$resolvedPath/WaykNow.vault" 
	$WaykNowInfoObject.KnownHostsFile =  Resolve-Path -Path "$resolvedPath/known_hosts" 
	$WaykNowInfoObject.BookmarksFile = Resolve-Path -Path "$resolvedPath/bookmarks"

	return $WaykNowInfoObject 
}

function Add-PathIfNotExist(
	[string] $path,
	[bool] $isFolder
)
{
	if($isFolder) {
		if (!(Test-Path $path)) {
		   New-Item -path $path -ItemType Directory -Force
		}
	}
	else {
		if (!(Test-Path $path))	{
		   New-Item -path $path -ItemType File -Force
		}
	}
}

Export-ModuleMember -Function Get-WaykNowVersion, Get-WaykNowPackage, Install-WaykNow, Uninstall-WaykNow, Get-WaykNowInfo
