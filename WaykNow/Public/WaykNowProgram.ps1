
function Get-WaykNowCommand
{
    [CmdletBinding()]
    param()

    $WaykNowCommand = $null

	if ($IsLinux) {
        $Command = Get-Command 'wayk-now' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykNowCommand = $Command.Source
        }
    } elseif ($IsMacOS) {
        $Command = Get-Command 'wayk-now' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykNowCommand = $Command.Source
        } else {
            $WaykNowAppExe = "/Applications/WaykNow.app/Contents/MacOS/WaykNow"

            if (Test-Path -Path $WaykNowAppExe -PathType Leaf) {
                $WaykNowCommand = $WaykNowAppExe
            }
        }
    } else { # IsWindows
        $DisplayName = 'Wayk Now'

		$UninstallReg = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" `
            | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $DisplayName }
            
		if (-Not $UninstallReg) {
			$UninstallReg = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $DisplayName }
        }
        
        if ($UninstallReg) {
            $InstallLocation = $UninstallReg.InstallLocation
            $WaykNowCommand = Join-Path -Path $InstallLocation -ChildPath "WaykNow.exe"
        }
	}
    
    return $WaykNowCommand
}

function Get-WaykNowProcess
{
    [CmdletBinding()]
    param()

    $wayk_now_process = $null

	if (Get-IsWindows -Or $IsMacOS) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykNow')
	} elseif ($IsLinux) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-now')
	}

    return $wayk_now_process
}

function Get-WaykNowService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = $null

    if (Get-IsWindows -And $PSEdition -Eq 'Desktop') {
        $wayk_now_service = $(Get-Service 'WaykNowService' -ErrorAction SilentlyContinue)
	}

    return $wayk_now_service
}

function Start-WaykNowService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = Get-WaykNowService
    if ($wayk_now_service) {
        Start-Service $wayk_now_service
    }
}

function Start-WaykNow
{
    [CmdletBinding()]
    param()

    Start-WaykNowService

	if (Get-IsWindows) {
        $display_name = 'Wayk Now'
		if ([System.Environment]::Is64BitOperatingSystem) {
			$uninstall_reg = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name }
		} else {
			$uninstall_reg = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name }
        }
        
        if ($uninstall_reg) {
            $install_location = $uninstall_reg.InstallLocation
            $wayk_now_exe = Join-Path -Path $install_location -ChildPath "WaykNow.exe"
            Start-Process $wayk_now_exe
        }
	} elseif ($IsMacOS) {
		Start-Process 'open' -ArgumentList @('-a', 'WaykNow')
	} elseif ($IsLinux) {
        Start-Process 'wayk-now'
	}
}

function Stop-WaykNow
{
    [CmdletBinding()]
    param()

    $wayk_now_process = Get-WaykNowProcess

    if ($wayk_now_process) {
        Stop-Process $wayk_now_process.Id
    }

    $now_service = Get-WaykNowService

    if ($now_service) {
        Stop-Service $now_service
    }

	if (Get-IsWindows) {
        $now_session_process = $(Get-Process | Where-Object -Property ProcessName -Like 'NowSession')

        if ($now_session_process) {
            Stop-Process $now_session_process.Id
        }
	}
}

function Restart-WaykNow
{
    [CmdletBinding()]
    param()

    Stop-WaykNow
    Start-WaykNow
}

Export-ModuleMember -Function Start-WaykNow, Stop-WaykNow, Restart-WaykNow,
    Get-WaykNowCommand, Get-WaykNowProcess, Get-WaykNowService, Start-WaykNowService
