function Get-WaykNowProcess
{
    $wayk_now_process = $null

	if (Get-IsWindows -Or $IsMacOS) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykNow')
	} elseif ($IsLinux) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-now')
	}

    return $wayk_now_process
}

function Get-NowService
{
    $now_service = $null

    if (Get-IsWindows -And $PSEdition -Eq 'Desktop') {
        $now_service = $(Get-Service | Where-Object -Property 'Name' -Like 'WaykNowService')
	}

    return $now_service
}

function Start-NowService
{
    $now_service = Get-NowService
    if ($now_service) {
        Start-Service $now_service
    }
}

function Start-WaykNow
{
    Start-NowService

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
    $wayk_now_process = Get-WaykNowProcess

    if ($wayk_now_process) {
        Stop-Process $wayk_now_process.Id
    }

    $now_service = Get-NowService

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
    Stop-WaykNow
    Start-WaykNow
}

Export-ModuleMember -Function Start-WaykNow, Stop-WaykNow, Restart-WaykNow, Get-WaykNowProcess, Get-NowService, Start-NowService
