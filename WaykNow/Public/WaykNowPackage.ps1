
. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/PlatformHelpers.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"

function Get-WaykNowVersion
{
    [CmdletBinding()]
    param()

	if (Get-IsWindows) {
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Now'
		if ($uninstall_reg) {
			$version = $uninstall_reg.DisplayVersion
			if ($version -lt 2000) {
					$version = "20" + $version
			}
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
function Get-WaykNowPackage
{
    [CmdletBinding()]
    param(
		[string] $Version,
		[ValidateSet("Windows","macOS","Linux")]
		[string] $Platform,
		[ValidateSet("x86","x64")]
		[string] $Architecture
	)

	$version_quad = '';
	$products_url = "https://devolutions.net/products.htm"
	$products_htm = Invoke-RestMethod -Uri $products_url -Method 'GET' -ContentType 'text/plain'
	$version_matches = $($products_htm | Select-String -AllMatches -Pattern "Wayk.Version=(\S+)").Matches

	if ($version) {
		$version_quad = $version
	} else {
		$version_quad = $version_matches.Groups[1].Value
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

	if (-Not $Platform) {
		if ($IsLinux) {
			$Platform = 'Linux'
		} elseif ($IsMacOS) {
			$Platform = 'macOS'
		} else {
			$Platform = 'Windows'
		}
	}

	if (-Not $Architecture) {
		if (Get-IsWindows) {
			if ([System.Environment]::Is64BitOperatingSystem) {
				if ((Get-WindowsHostArch) -eq 'ARM64') {
					$Architecture = 'x86' # Windows on ARM64, use intel 32-bit build
				} else {
					$Architecture = 'x64'
				}
			} else {
				$Architecture = 'x86'
			}
		} else {
			$Architecture = 'x64' # default
		}
	}

	if ($Platform -eq 'Windows') {
		if ($Architecture -eq 'x64') {
			$download_url = $download_url_x64
		} elseif ($Architecture -eq 'x86') {
			$download_url = $download_url_x86
		}
	} elseif ($Platform -eq 'macOS') {
		$download_url = $download_url_mac
	} elseif ($Platform -eq 'Linux') {
		$download_url = $download_url_deb
	}
 
    $result = [PSCustomObject]@{
        Url = $download_url
        Version = $version_triple
    }

	return $result
}
function Install-WaykNow
{
    [CmdletBinding()]
    param(
		[switch] $Force,
		[switch] $Quiet,
		[string] $Version,
		[switch] $NoDesktopShortcut,
		[switch] $NoStartMenuShortcut
	)

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

	$download_url = $package.url
	$download_file = Split-Path -Path $download_url -Leaf
	$download_file_path = "$tempDirectory/$download_file"
	Write-Host "Downloading $download_url"

	$web_client = [System.Net.WebClient]::new()
	$web_client.DownloadFile($download_url, $download_file_path)
	$web_client.Dispose()
	
	$download_file_path = Resolve-Path $download_file_path

	if (([version]$current_version -gt [version]$latest_version) -And $Force)
	{
		Uninstall-WaykNow -Quiet:$Quiet
	}

	if (Get-IsWindows) {
		$display = '/passive'
		if ($Quiet){
			$display = '/quiet'
		}
		$install_log_file = "$tempDirectory/WaykNow_Install.log"
		$msi_args = @(
			'/i', "`"$download_file_path`"",
			$display,
			'/norestart',
			'/log', "`"$install_log_file`""
		)
		if ($NoDesktopShortcut){
			$msi_args += "INSTALLDESKTOPSHORTCUT=`"`""
		}
		if ($NoStartMenuShortcut){
			$msi_args += "INSTALLSTARTMENUSHORTCUT=`"`""
		}

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
    [CmdletBinding()]
    param(
		[switch] $Quiet
	)
	
	Stop-WaykNow
	
	if (Get-IsWindows) {
		# https://stackoverflow.com/a/25546511
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Now'
		if ($uninstall_reg) {
			$uninstall_string = $($uninstall_reg.UninstallString `
				-Replace "msiexec.exe", "" -Replace "/I", "" -Replace "/X", "").Trim()
			$display = '/passive'
			if ($Quiet){
				$display = '/quiet'
			}
			$msi_args = @(
				'/X', $uninstall_string, $display
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

function Update-WaykNow
{
    [CmdletBinding()]
    param(
		[switch] $Force,
		[switch] $Quiet
	)

	$wayk_now_process_was_running = Get-WaykNowProcess
	$wayk_now_service_was_running = (Get-WaykNowService).Status -Eq 'Running'

	try {
		Install-WaykNow -Force:$Force -Quiet:$Quiet
	}
	catch {
		throw $_
	}

	if ($wayk_now_process_was_running) {
		Start-WaykNow
	} elseif ($wayk_now_service_was_running) {
		Start-WaykNowService
	}
}

class WaykNowInfo
{
	[string] $DataPath
	[string] $GlobalPath
	[string] $GlobalDataPath
	[string] $GlobalConfigFile
	[string] $ConfigFile
	[string] $DenPath
	[string] $DenGlobalPath
	[string] $LogPath
	[string] $LogGlobalPath
	[string] $CertificateFile
	[string] $PrivateKeyFile
	[string] $PasswordVault
	[string] $KnownHostsFile
	[string] $BookmarksFile
}

function Get-WaykNowPath()
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory,Position=0)]
		[string] $PathType
	)

	$HomePath = Resolve-Path '~'

	if (Get-IsWindows)	{
		$LocalPath = $Env:APPDATA + '\Wayk';
		$GlobalPath = $Env:ALLUSERSPROFILE + '\Wayk'
	} elseif ($IsMacOS) {
		$LocalPath = "$HomePath/Library/Application Support/Wayk"
		$GlobalPath = "/Library/Application Support/Wayk"
	} elseif ($IsLinux) {
		$LocalPath = "$HomePath/.config/Wayk"
		$GlobalPath = '/etc/wayk'
	}

	if (Test-Path Env:WAYK_DATA_PATH) {
		$LocalPath = $Env:WAYK_DATA_PATH
	}

	if (Test-Path Env:WAYK_SYSTEM_PATH) {
		$GlobalPath = $Env:WAYK_SYSTEM_PATH
	}

	switch ($PathType) {
		'LocalPath' { $LocalPath }
		'GlobalPath' { $GlobalPath }
		default { throw("Invalid path type: $PathType") }
	}
}

function Get-WaykNowInfo()
{
	[CmdletBinding()]
	param()

	$DataPath = Get-WaykNowPath 'LocalPath'
	$GlobalPath = Get-WaykNowPath 'GlobalPath'

	$info = [WaykNowInfo]::New()
	$info.DataPath = $DataPath
	$info.GlobalPath = $GlobalPath
	$info.GlobalDataPath = $GlobalPath
	$info.GlobalConfigFile = Join-Path -Path $GlobalPath -ChildPath 'WaykNow.cfg'
	$info.DenGlobalPath = Join-Path -Path $GlobalPath -ChildPath 'den'
	$info.LogGlobalPath = Join-Path -Path $GlobalPath -ChildPath 'logs'
	$info.ConfigFile = Join-Path -Path $DataPath -ChildPath 'WaykNow.cfg'
	$info.DenPath = Join-Path -Path $DataPath -ChildPath 'den'
	$info.LogPath = Join-Path -Path $DataPath -ChildPath 'logs'
	$info.CertificateFile = Join-Path -Path $DataPath -ChildPath 'WaykNow.crt'
	$info.PrivateKeyFile = Join-Path -Path $DataPath -ChildPath 'WaykNow.key'
	$info.PasswordVault = Join-Path -Path $DataPath -ChildPath 'WaykNow.vault'
	$info.KnownHostsFile = Join-Path -Path $DataPath -ChildPath 'known_hosts'
	$info.BookmarksFile = Join-Path -Path $DataPath -ChildPath 'bookmarks'

	return $info 
}

Export-ModuleMember -Function Get-WaykNowVersion, Get-WaykNowPackage, Install-WaykNow, Uninstall-WaykNow, Update-WaykNow, Get-WaykNowPath, Get-WaykNowInfo
