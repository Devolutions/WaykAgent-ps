
function Get-WaykAgentCommand
{
    [CmdletBinding()]
    param()

    $WaykAgentCommand = $null

	if ($IsLinux) {
        $Command = Get-Command 'wayk-now' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykAgentCommand = $Command.Source
        }
    } elseif ($IsMacOS) {
        $Command = Get-Command 'wayk-now' -ErrorAction SilentlyContinue

        if ($Command) {
            $WaykAgentCommand = $Command.Source
        } else {
            $WaykAgentAppExe = "/Applications/WaykAgent.app/Contents/MacOS/WaykAgent"

            if (Test-Path -Path $WaykAgentAppExe -PathType Leaf) {
                $WaykAgentCommand = $WaykAgentAppExe
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
            $WaykAgentCommand = Join-Path -Path $InstallLocation -ChildPath "WaykAgent.exe"
        }
	}
    
    return $WaykAgentCommand
}

function Get-WaykAgentProcess
{
    [CmdletBinding()]
    param()

    $wayk_now_process = $null

	if (Get-IsWindows -Or $IsMacOS) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykAgent')
	} elseif ($IsLinux) {
        $wayk_now_process = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-now')
	}

    return $wayk_now_process
}

function Get-WaykAgentService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = $null

    if (Get-IsWindows -And $PSEdition -Eq 'Desktop') {
        $wayk_now_service = $(Get-Service 'WaykAgentService' -ErrorAction SilentlyContinue)
	}

    return $wayk_now_service
}

function Start-WaykAgentService
{
    [CmdletBinding()]
    param()

    $wayk_now_service = Get-WaykAgentService
    if ($wayk_now_service) {
        Start-Service $wayk_now_service
    }
}

function Start-WaykAgent
{
    [CmdletBinding()]
    param()

    Start-WaykAgentService

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
            $wayk_now_exe = Join-Path -Path $install_location -ChildPath "WaykAgent.exe"
            Start-Process $wayk_now_exe
        }
	} elseif ($IsMacOS) {
		Start-Process 'open' -ArgumentList @('-a', 'WaykAgent')
	} elseif ($IsLinux) {
        Start-Process 'wayk-now'
	}
}

function Stop-WaykAgent
{
    [CmdletBinding()]
    param()

    $wayk_now_process = Get-WaykAgentProcess

    if ($wayk_now_process) {
        Stop-Process $wayk_now_process.Id
    }

    $now_service = Get-WaykAgentService

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

function Restart-WaykAgent
{
    [CmdletBinding()]
    param()

    Stop-WaykAgent
    Start-WaykAgent
}

Export-ModuleMember -Function Start-WaykAgent, Stop-WaykAgent, Restart-WaykAgent,
    Get-WaykAgentCommand, Get-WaykAgentProcess, Get-WaykAgentService, Start-WaykAgentService
