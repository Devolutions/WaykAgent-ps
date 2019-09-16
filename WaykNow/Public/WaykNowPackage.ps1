
function Get-HostEnvironment
{
	if ($null -Eq $Global:IsWindows) {
		if ($PSEdition -Eq 'Desktop') {
			$Global:IsWindows = $true
		}
	}
}

function Get-WaykNowVersion
{
	if ($IsWindows) {

	} elseif ($IsMacOS) {
		$info_plist_path = "/Applications/WaykNow.app/Contents/Info.plist"
		$cf_bundle_version_xpath = "//dict/key[. ='CFBundleVersion']/following-sibling::string[1]"
		if (Test-Path -Path $info_plist_path) {
			$version = $(Select-Xml -Path $info_plist_path -XPath $cf_bundle_version_xpath `
				| Foreach-Object {$_.Node.InnerXML }).Trim()
			return $version
		}
	} elseif ($IsLinux) {

	}

	return $null
}
function Get-WaykNowPackage
{
	$products_url = "https://devolutions.net/products.htm"
	$products_htm = Invoke-RestMethod -Uri $products_url -Method 'GET' -ContentType 'text/plain'
	$matches = $($products_htm | Select-String -AllMatches -Pattern "Wayk.Version=(\S+)").Matches
	$version = $matches.Groups[1].Value
	$download_base = "https://cdn.devolutions.net/download"
	$download_url_x64 = "$download_base/Wayk/$version/WaykNow-x64-$version.msi"
	$download_url_x86 = "$download_base/Wayk/$version/WaykNow-x86-$version.msi"
	$download_url_mac = "$download_base/Mac/Wayk/$version/Wayk.Mac.$version.dmg"
	$download_url_deb = "$download_base/Linux/Wayk/$version/wayk-now_${version}_amd64.deb"

	Get-HostEnvironment
	$download_url = $null

	if ($IsWindows) {
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
 
	return $download_url
}
function Install-WaykNow
{
	$download_url = Get-WaykNowPackage
	$download_file = Split-Path -Path $download_url -Leaf
	Write-Host $download_url

	(New-Object System.Net.WebClient).DownloadFile($download_url, $download_file)

	$install_log_file = "WaykNow_Install.log"

	if ($IsWindows) {
		$msi_args = @(
			'/i', $download_file,
			'/quiet', '/norestart',
			'/log', $install_log_file
		)
		Start-Process "msiexec.exe" -ArgumentList $msi_args -Wait -NoNewWindow
	} elseif ($IsMacOS) {
		$volumes_wayk_now = "/Volumes/WaykNow"
		if (Test-Path -Path $volumes_wayk_now -PathType 'Container') {
			Start-Process 'hdiutil' -ArgumentList @('unmount', $volumes_wayk_now) -Wait
		}
		Start-Process 'hdiutil' -ArgumentList @('mount', "./$download_file") `
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
			'-i', $download_file
		)
		if ((id -u) -eq 0) {
			Start-Process 'dpkg' -ArgumentList $dpkg_args -Wait
		} else {
			$dpkg_args = @('dpkg') + $dpkg_args
			Start-Process 'sudo' -ArgumentList $dpkg_args -Wait
		}
	}

	Remove-Item -Path $download_file -Force
	Remove-Item -Path $install_log_file -Force -ErrorAction SilentlyContinue
}

function Uninstall-WaykNow
{
	Stop-WaykNow
	
	if ($IsWindows) {
		# https://stackoverflow.com/a/25546511
		$display_name = 'Wayk Now'
		if ([System.Environment]::Is64BitOperatingSystem) {
			$uninstall_string = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name } `
				| Select-Object UninstallString
		} else {
			$uninstall_string = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name } `
				| Select-Object UninstallString
		}
		$uninstall_string = $($uninstall_string.UninstallString `
			-Replace "msiexec.exe", "" -Replace "/I", "" -Replace "/X", "").Trim()
		$msi_args = @(
			'/X', $uninstall_string, '/qb'
		)
		Start-Process "msiexec.exe" -ArgumentList $msi_args -Wait
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
		$apt_args = @(
			'-y', 'remove', 'wayk-now'
		)
		if ((id -u) -eq 0) {
			Start-Process 'apt-get' -ArgumentList $apt_args -Wait
		} else {
			$apt_args = @('apt-get') + $apt_args
			Start-Process 'sudo' -ArgumentList $apt_args -Wait
		}
	}
}

Export-ModuleMember -Function Get-WaykNowVersion, Get-WaykNowPackage, Install-WaykNow, Uninstall-WaykNow
