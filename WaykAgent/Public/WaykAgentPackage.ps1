. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

function Get-WaykAgentVersion
{
    [CmdletBinding()]
    param()

	if (Get-IsWindows) {
		$UninstallReg = Get-UninstallRegistryKey 'Wayk Agent'
		if ($UninstallReg) {
			$Version = $UninstallReg.DisplayVersion
			if ($Version -lt 2000) {
					$Version = "20" + $Version
			}
			return $Version
		}
	} elseif ($IsMacOS) {
		$InfoPlistPath = "/Applications/WaykAgent.app/Contents/Info.plist"
		$CfBundleVersionXpath = "//dict/key[. ='CFBundleVersion']/following-sibling::string[1]"
		if (Test-Path -Path $InfoPlistPath) {
			$Version = $(Select-Xml -Path $InfoPlistPath -XPath $CfBundleVersionXpath `
				| Foreach-Object {$_.Node.InnerXML }).Trim()
			return $Version
		}
	} elseif ($IsLinux) {
		$DpkgStatus = $(dpkg -s wayk-agent)
		$DpkgMatches = $($DpkgStatus | Select-String -AllMatches -Pattern 'Version: (\S+)').Matches
		if ($DpkgMatches) {
			$Version = $DpkgMatches.Groups[1].Value
			return $Version
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
	$ProductsUrl = "https://devolutions.net/productinfo.htm"

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
		# both variables are in quadruple Version format
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

	$TempDirectory = New-TemporaryDirectory
	$Package = Get-WaykAgentPackage $Version
	$LatestVersion = $Package.Version
	$CurrentVersion = Get-WaykAgentVersion

	if (([Version]$LatestVersion -gt [Version]$CurrentVersion) -Or $Force) {
		Write-Host "Installing Wayk Agent ${LatestVersion}"
	} else {
		Write-Host "Wayk Agent is already up to date"
		return
	}

	$DownloadUrl = $Package.url
	$DownloadFile = Split-Path -Path $DownloadUrl -Leaf
	$DownloadFilePath = Join-Path $TempDirectory $DownloadFile
	Write-Host "Downloading $DownloadUrl"

	$WebClient = [System.Net.WebClient]::new()
	$WebClient.DownloadFile($DownloadUrl, $DownloadFilePath)
	$WebClient.Dispose()
	
	$DownloadFilePath = Resolve-Path $DownloadFilePath

	if (([Version]$CurrentVersion -gt [Version]$LatestVersion) -And $Force)
	{
		Uninstall-WaykAgent -Quiet:$Quiet
	}

	if (Get-IsWindows) {
		$Display = '/passive'
		if ($Quiet){
			$Display = '/quiet'
		}
		$InstallLogFile = "$TempDirectory/WaykAgent_Install.log"
		$MsiArgs = @(
			'/i', "`"$DownloadFilePath`"",
			$Display,
			'/norestart',
			'/log', "`"$InstallLogFile`""
		)
		if ($NoDesktopShortcut){
			$MsiArgs += "INSTALLDESKTOPSHORTCUT=`"`""
		}
		if ($NoStartMenuShortcut){
			$MsiArgs += "INSTALLSTARTMENUSHORTCUT=`"`""
		}

		Start-Process "msiexec.exe" -ArgumentList $MsiArgs -Wait -NoNewWindow

		Remove-Item -Path $InstallLogFile -Force -ErrorAction SilentlyContinue
	} elseif ($IsMacOS) {
		Wait-Process $(Start-Process 'sudo' -ArgumentList `
			@('installer', '-pkg', $DownloadFilePath, '-target', '/') -PassThru).Id
	} elseif ($IsLinux) {
		$DpkgArgs = @(
			'-i', $DownloadFilePath
		)
		if ((id -u) -eq 0) {
			Start-Process 'dpkg' -ArgumentList $DpkgArgs -Wait
		} else {
			$DpkgArgs = @('dpkg') + $DpkgArgs
			Start-Process 'sudo' -ArgumentList $DpkgArgs -Wait
		}
	}

	Remove-Item -Path $TempDirectory -Force -Recurse
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
		$UninstallReg = Get-UninstallRegistryKey 'Wayk Agent'
		if ($UninstallReg) {
			$UninstallString = $($UninstallReg.UninstallString `
				-Replace "msiexec.exe", "" -Replace "/I", "" -Replace "/X", "").Trim()
			$Display = '/passive'
			if ($Quiet){
				$Display = '/quiet'
			}
			$MsiArgs = @(
				'/X', $UninstallString, $Display
			)
			Start-Process "msiexec.exe" -ArgumentList $MsiArgs -Wait
		}
	} elseif ($IsMacOS) {
		$InstallerUser = $(stat -f '%Su' $HOME)
		$WaykAgentAppPath = "/Applications/WaykAgent.app"
		$NowPrivacyHelper = "${WaykAgentAppPath}/Contents/MacOS/NowPrivacyHelper"
		$NowSessionLauncher = "${WaykAgentAppPath}/Contents/MacOS/NowSessionLauncher"
		$NowService = "${WaykAgentAppPath}/Contents/MacOS/NowService"

		foreach ($UnloadProgram in @($NowPrivacyHelper, $NowSessionLauncher)) {
			if (Test-Path -Path $UnloadProgram -PathType 'Leaf') {
				Wait-Process $(Start-Process 'sudo' -ArgumentList `
					@('-u', $InstallerUser, '-s', $UnloadProgram, '--cmd', 'unload') -PassThru).Id
			}
		}

		foreach ($DeleteProgram in @($NowPrivacyHelper, $NowSessionLauncher, $NowService)) {
			if (Test-Path -Path $DeleteProgram -PathType 'Leaf') {
				Wait-Process $(Start-Process 'sudo' -ArgumentList `
					@($DeleteProgram, '--cmd', 'delete') -PassThru).Id
			}
		}

		Wait-Process $(Start-Process 'sudo' -ArgumentList `
			@('rm', '-rf', '/var/run/wayk') -PassThru).Id

		Wait-Process $(Start-Process 'sudo' -ArgumentList `
			@('rm', '-f', '/usr/local/bin/wayk-now') -PassThru).Id

		Stop-Process -Name 'WaykAgent' -ErrorAction 'SilentlyContinue'

		Wait-Process $(Start-Process 'sudo' -ArgumentList `
			@('rm', '-rf', $WaykAgentAppPath) -PassThru).Id

	} elseif ($IsLinux) {
		if (Get-WaykAgentVersion) {
			$AptArgs = @(
				'-y', 'remove', 'wayk-agent', '--purge'
			)
			if ((id -u) -eq 0) {
				Start-Process 'apt-get' -ArgumentList $AptArgs -Wait
			} else {
				$AptArgs = @('apt-get') + $AptArgs
				Start-Process 'sudo' -ArgumentList $AptArgs -Wait
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

	$ProcessWasRunning = Get-WaykAgentProcess
	$ServiceWasRunning = (Get-WaykAgentService).Status -Eq 'Running'

	try {
		Install-WaykAgent -Force:$Force -Quiet:$Quiet
	}
	catch {
		throw $_
	}

	if ($ProcessWasRunning) {
		Start-WaykAgent
	} elseif ($ServiceWasRunning) {
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
