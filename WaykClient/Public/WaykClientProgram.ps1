
function Get-WaykClientCommand
{
    [CmdletBinding()]
    param()

    $WaykClientCommand = $null

	if ($IsLinux) {
        $Command = Get-Command 'wayk-client' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykClientCommand = $Command.Source
        }
    } elseif ($IsMacOS) {
        $Command = Get-Command 'wayk-client' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykClientCommand = $Command.Source
        } else {
            $WaykClientAppExe = "/Applications/WaykClient.app/Contents/MacOS/WaykClient"

            if (Test-Path -Path $WaykClientAppExe -PathType Leaf) {
                $WaykClientCommand = $WaykClientAppExe
            }
        }
    } else { # IsWindows
        $DisplayName = 'Wayk Client'

		$UninstallReg = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" `
            | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $DisplayName }
            
		if (-Not $UninstallReg) {
			$UninstallReg = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
				| ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $DisplayName }
        }
        
        if ($UninstallReg) {
            $InstallLocation = $UninstallReg.InstallLocation
            $WaykClientCommand = Join-Path -Path $InstallLocation -ChildPath "WaykClient.exe"
        }
	}
    
    return $WaykClientCommand
}

function Get-WaykClientProcess
{
    [CmdletBinding()]
    param()

    $wayk_now_process = $null

	if (Get-IsWindows -Or $IsMacOS) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykClient')
	} elseif ($IsLinux) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-client')
	}

    return $wayk_now_process
}

function Get-WaykClientService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = $null

    if (Get-IsWindows -And $PSEdition -Eq 'Desktop') {
        $wayk_now_service = $(Get-Service 'WaykClientService' -ErrorAction SilentlyContinue)
	}

    return $wayk_now_service
}

function Start-WaykClientService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = Get-WaykClientService
    if ($wayk_now_service) {
        Start-Service $wayk_now_service
    }
}

function Start-WaykClient
{
    [CmdletBinding()]
    param()

    Start-WaykClientService

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
            $wayk_now_exe = Join-Path -Path $install_location -ChildPath "WaykClient.exe"
            Start-Process $wayk_now_exe
        }
	} elseif ($IsMacOS) {
		Start-Process 'open' -ArgumentList @('-a', 'WaykClient')
	} elseif ($IsLinux) {
        Start-Process 'wayk-client'
	}
}

function Stop-WaykClient
{
    [CmdletBinding()]
    param()

    $wayk_now_process = Get-WaykClientProcess

    if ($wayk_now_process) {
        Stop-Process $wayk_now_process.Id
    }

    $now_service = Get-WaykClientService

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

function Restart-WaykClient
{
    [CmdletBinding()]
    param()

    Stop-WaykClient
    Start-WaykClient
}

Export-ModuleMember -Function Start-WaykClient, Stop-WaykClient, Restart-WaykClient,
    Get-WaykClientCommand, Get-WaykClientProcess, Get-WaykClientService, Start-WaykClientService
