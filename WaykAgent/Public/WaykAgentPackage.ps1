. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

function Get-WaykAgentVersion
{
    [CmdletBinding()]
    param()

	if (Get-IsWindows) {
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Agent'
		if ($uninstall_reg) {
			$version = $uninstall_reg.DisplayVersion
			if ($version -lt 2000) {
					$version = "20" + $version
			}
			return $version
		}
	} elseif ($IsMacOS) {
		$info_plist_path = "/Applications/WaykAgent.app/Contents/Info.plist"
		$cf_bundle_version_xpath = "//dict/key[. ='CFBundleVersion']/following-sibling::string[1]"
		if (Test-Path -Path $info_plist_path) {
			$version = $(Select-Xml -Path $info_plist_path -XPath $cf_bundle_version_xpath `
				| Foreach-Object {$_.Node.InnerXML }).Trim()
			return $version
		}
	} elseif ($IsLinux) {
		$dpkg_status = $(dpkg -s wayk-agent)
		$DpkgMatches = $($dpkg_status | Select-String -AllMatches -Pattern 'version: (\S+)').Matches
		if ($DpkgMatches) {
			$version = $DpkgMatches.Groups[1].Value
			return $version
		}
	}

	return $null
}
function Get-WaykAgentPackage
{
    [CmdletBinding()]
    param(
		[string] $RequiredVersion,
		[ValidateSet("Windows","macOS","Linux")]
		[string] $Platform,
		[ValidateSet("x86","x64")]
		[string] $Architecture
	)

	$VersionQuad = '';
	$ProductsUrl = "https://devolutions.net/products.htm"

	if ($Env:WAYK_PRODUCT_INFO_URL) {
		$ProductsUrl = $Env:WAYK_PRODUCT_INFO_URL
	}

	$ProductsHtm = Invoke-RestMethod -Uri $ProductsUrl -Method 'GET' -ContentType 'text/plain'
	$VersionMatches = $($ProductsHtm | Select-String -AllMatches -Pattern "Wayk.Version=(\S+)").Matches
	$LatestVersion = $VersionMatches.Groups[1].Value

	if ($RequiredVersion) {
		if ($RequiredVersion -Match "^\d+`.\d+`.\d+$") {
			$RequiredVersion = $RequiredVersion + ".0"
		}
		$VersionQuad = $RequiredVersion
	} else {
		$VersionQuad = $LatestVersion
	}

	$VersionMatches = $($VersionQuad | Select-String -AllMatches -Pattern "(\d+)`.(\d+)`.(\d+)`.(\d+)").Matches
	$VersionMajor = $VersionMatches.Groups[1].Value
	$VersionMinor = $VersionMatches.Groups[2].Value
	$VersionPatch = $VersionMatches.Groups[3].Value
	$VersionTriple = "${VersionMajor}.${VersionMinor}.${VersionPatch}"

	$WaykMatches = $($ProductsHtm | Select-String -AllMatches -Pattern "(Wayk\S+).Url=(\S+)").Matches
	$WaykAgentMsi64 = $WaykMatches | Where-Object { $_.Groups[1].Value -eq 'WaykAgentmsi64' }
	$WaykAgentMsi86 = $WaykMatches | Where-Object { $_.Groups[1].Value -eq 'WaykAgentmsi86' }
	$WaykAgentMac = $WaykMatches | Where-Object { $_.Groups[1].Value -eq 'WaykAgentMac' }
	$WaykAgentLinux = $WaykMatches | Where-Object { $_.Groups[1].Value -eq 'WaykAgentLinuxbin' }

	if ($WaykAgentMsi86) {
		$DownloadUrlX86 = $WaykAgentMsi86.Groups[2].Value
	}
	
	if ($WaykAgentMsi64) {
		$DownloadUrlX64 = $WaykAgentMsi64.Groups[2].Value
	}

	if ($WaykAgentMac) {
		$DownloadUrlMac = $WaykAgentMac.Groups[2].Value
	}
	
	if ($WaykAgentLinux) {
		$DownloadUrlLinux = $WaykAgentLinux.Groups[2].Value
	}

	$DownloadUrl = $null

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
			$DownloadUrl = $DownloadUrlX64
		} elseif ($Architecture -eq 'x86') {
			$DownloadUrl = $DownloadUrlX86
		}
	} elseif ($Platform -eq 'macOS') {
		$DownloadUrl = $DownloadUrlMac
	} elseif ($Platform -eq 'Linux') {
		$DownloadUrl = $DownloadUrlLinux
	}

	if ($RequiredVersion) {
		# both variables are in quadruple version format
		$DownloadUrl = $DownloadUrl -Replace $LatestVersion, $RequiredVersion
	}
 
    $result = [PSCustomObject]@{
        Url = $DownloadUrl
        Version = $VersionTriple
    }

	return $result
}
function Install-WaykAgent
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
	$package = Get-WaykAgentPackage $Version
	$latest_version = $package.Version
	$current_version = Get-WaykAgentVersion

	if (([version]$latest_version -gt [version]$current_version) -Or $Force) {
		Write-Host "Installing Wayk Agent ${latest_version}"
	} else {
		Write-Host "Wayk Agent is already up to date"
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
		Uninstall-WaykAgent -Quiet:$Quiet
	}

	if (Get-IsWindows) {
		$display = '/passive'
		if ($Quiet){
			$display = '/quiet'
		}
		$install_log_file = "$tempDirectory/WaykAgent_Install.log"
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
		$volumes_wayk_now = "/Volumes/WaykAgent"
		if (Test-Path -Path $volumes_wayk_now -PathType 'Container') {
			Start-Process 'hdiutil' -ArgumentList @('unmount', $volumes_wayk_now) -Wait
		}
		Start-Process 'hdiutil' -ArgumentList @('mount', "$download_file_path") `
			-Wait -RedirectStandardOutput '/dev/null'
		Wait-Process $(Start-Process 'sudo' -ArgumentList @('cp', '-R', `
			"${volumes_wayk_now}/WaykAgent.app", "/Applications") -PassThru).Id
		Start-Process 'hdiutil' -ArgumentList @('unmount', $volumes_wayk_now) `
			-Wait -RedirectStandardOutput '/dev/null'
		Wait-Process $(Start-Process 'sudo' -ArgumentList @('ln', '-sfn', `
			"/Applications/WaykAgent.app/Contents/MacOS/WaykAgent",
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

function Uninstall-WaykAgent
{
    [CmdletBinding()]
    param(
		[switch] $Quiet
	)
	
	Stop-WaykAgent
	
	if (Get-IsWindows) {
		# https://stackoverflow.com/a/25546511
		$uninstall_reg = Get-UninstallRegistryKey 'Wayk Agent'
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
		$wayk_now_app = "/Applications/WaykAgent.app"
		if (Test-Path -Path $wayk_now_app -PathType 'Container') {
			Start-Process 'sudo' -ArgumentList @('rm', '-rf', $wayk_now_app) -Wait
		}
		$wayk_now_symlink = "/usr/local/bin/wayk-now"
		if (Test-Path -Path $wayk_now_symlink) {
			Start-Process 'sudo' -ArgumentList @('rm', $wayk_now_symlink) -Wait
		}
	} elseif ($IsLinux) {
		if (Get-WaykAgentVersion) {
			$apt_args = @(
				'-y', 'remove', 'wayk-agent', '--purge'
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

function Update-WaykAgent
{
    [CmdletBinding()]
    param(
		[switch] $Force,
		[switch] $Quiet
	)

	$wayk_now_process_was_running = Get-WaykAgentProcess
	$wayk_now_service_was_running = (Get-WaykAgentService).Status -Eq 'Running'

	try {
		Install-WaykAgent -Force:$Force -Quiet:$Quiet
	}
	catch {
		throw $_
	}

	if ($wayk_now_process_was_running) {
		Start-WaykAgent
	} elseif ($wayk_now_service_was_running) {
		Start-WaykAgentService
	}
}

function Get-WaykAgentPath()
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
		[string] $PathType = "ConfigPath"
	)

	if (Get-IsWindows)	{
		$ConfigPath = $Env:ALLUSERSPROFILE + '\Wayk'
	} elseif ($IsMacOS) {
		$ConfigPath = "/Library/Application Support/Wayk"
	} elseif ($IsLinux) {
		$ConfigPath = '/etc/wayk'
	}

	if (Test-Path Env:WAYK_SYSTEM_PATH) {
		$ConfigPath = $Env:WAYK_SYSTEM_PATH
	}

	switch ($PathType) {
		'ConfigPath' { $ConfigPath }
		default { throw("Invalid path type: $PathType") }
	}
}
