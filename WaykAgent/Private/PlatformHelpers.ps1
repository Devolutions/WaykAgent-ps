function Get-IsWindows
{
    if (-Not (Test-Path 'variable:global:IsWindows')) {
        return $true # Windows PowerShell 5.1 or earlier
    } else {
        return $IsWindows
    }
}

function Get-WindowsHostArch
{
    if ([System.Environment]::Is64BitOperatingSystem) {
        if (($Env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($Env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')) {
            return "ARM64"
        } else {
            return "x64"
        }
    } else {
        return "x86"
    }
}

function Get-UninstallRegistryKey(
	[string] $display_name = 'Wayk Agent'
){
    $uninstall_base_reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

    return Get-ChildItem $uninstall_base_reg `
        | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name };
}

function New-TemporaryDirectory()
{
	$parent = [System.IO.Path]::GetTempPath()
	$name = [System.IO.Path]::GetRandomFileName()
	return New-Item -ItemType Directory -Path (Join-Path $parent $name)
}
