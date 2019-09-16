
function Get-HostEnvironment
{
	if ($null -Eq $Global:IsWindows) {
		if ($PSEdition -Eq 'Desktop') {
			$Global:IsWindows = $true
		}
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
