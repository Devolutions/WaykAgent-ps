
function Start-WaykNow
{
	if ($IsWindows) {
        if ($PSEdition -Eq 'Desktop') {
            $wayk_now_service = $(Get-Service | Where-Object -Property 'Name' -Like 'WaykNowService')

            if ($wayk_now_service) {
                Start-Service $wayk_now_service
            }
        }

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
	if ($IsWindows) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykNow')

        if ($wayk_now_process) {
            Stop-Process $wayk_now_process.Id
        }

        if ($PSEdition -Eq 'Desktop') {
            $wayk_now_service = $(Get-Service | Where-Object -Property 'Name' -Like 'WaykNowService')

            if ($wayk_now_service) {
                Stop-Service $wayk_now_service
            }
        }

        $now_session_process = $(Get-Process | Where-Object -Property ProcessName -Like 'NowSession')

        if ($now_session_process) {
            Stop-Process $now_session_process.Id
        }
	} elseif ($IsMacOS) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykNow')

        if ($wayk_now_process) {
            Stop-Process $wayk_now_process.Id
        }
	} elseif ($IsLinux) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-now')

        if ($wayk_now_process) {
            Stop-Process $wayk_now_process.Id
        }
	}
}

function Restart-WaykNow
{
    Stop-WaykNow
    Start-WaykNow
}

Export-ModuleMember -Function Start-WaykNow, Stop-WaykNow, Restart-WaykNow
