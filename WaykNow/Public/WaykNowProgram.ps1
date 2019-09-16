
function Start-WaykNow
{
	if ($IsWindows) {

	} elseif ($IsMacOS) {
		Start-Process 'open' -ArgumentList @('-a', 'WaykNow')
	} elseif ($IsLinux) {
        Start-Process 'wayk-now'
	}
}

function Stop-WaykNow
{
	if ($IsWindows) {

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
