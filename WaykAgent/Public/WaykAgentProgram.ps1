
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
        $UninstallReg = Get-UninstallRegistryKey 'Wayk Agent'
        
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

    $WaykAgentProcess = $null

	if (Get-IsWindows -Or $IsMacOS) {
        $WaykAgentProcess = $(Get-Process | Where-Object -Property ProcessName -Like 'WaykAgent')
	} elseif ($IsLinux) {
        $WaykAgentProcess = $(Get-Process | Where-Object -Property ProcessName -Like 'wayk-agent')
	}

    return $WaykAgentProcess
}

function Get-WaykAgentService
{
    [CmdletBinding()]
    param()

    $WaykAgentService = $null

    if (Get-IsWindows) {
        $WaykAgentService = $(Get-Service 'WaykNowService' -ErrorAction SilentlyContinue)
	}

    return $WaykAgentService
}

function Start-WaykAgentService
{
    [CmdletBinding()]
    param()

    $WaykAgentService = Get-WaykAgentService

    if ($WaykAgentService) {
        Start-Service $WaykAgentService
    }
}

function Start-WaykAgent
{
    [CmdletBinding()]
    param()

    Start-WaykAgentService

    $WaykAgentCommand = Get-WaykAgentCommand

    if ($WaykAgentCommand) {
        Start-Process $WaykAgentCommand
    }
}

function Stop-WaykAgent
{
    [CmdletBinding()]
    param()

    $WaykAgentProcess = Get-WaykAgentProcess

    if ($WaykAgentProcess) {
        Stop-Process $WaykAgentProcess.Id
    }

    $WaykAgentService = Get-WaykAgentService

    if ($WaykAgentService) {
        Stop-Service $WaykAgentService
    }

	if (Get-IsWindows) {
        $NowSessionProcess = $(Get-Process | Where-Object -Property ProcessName -Like 'NowSession')

        if ($NowSessionProcess) {
            Stop-Process $NowSessionProcess.Id
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
