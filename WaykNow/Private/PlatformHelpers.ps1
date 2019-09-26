

function Get-IsWindows
{
    if (-Not (Test-Path 'variable:global:IsWindows')) {
        return $true # Windows PowerShell 5.1 or earlier
    } else {
        return $IsWindows
    }
}

function Get-UninstallRegistryKey(
	[string] $display_name = 'Wayk Now'
){
    if ([System.Environment]::Is64BitOperatingSystem) {
        $uninstall_base_reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    } else {
        $uninstall_base_reg = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    }

    return Get-ChildItem $uninstall_base_reg `
        | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_ -Match $display_name };
}

# Work only with windows, use the check Get-IsWindows before call this one
function Get-IsRunAsAdministrator  
{
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}
