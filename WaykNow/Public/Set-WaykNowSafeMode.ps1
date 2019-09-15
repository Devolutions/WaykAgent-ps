
. "$PSScriptRoot/../Private/Invoke-Process.ps1"
function Set-WaykNowSafeMode
{
	# copy default boot entry
	$bcdedit_copy = $(Invoke-Process -FilePath 'bcdedit' -ArgumentList "/copy `{default`} /d `"Safe Mode with Wayk Now`"")

	$guid_pattern = '{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}}'
	$boot_id = $($bcdedit_copy | Select-String -AllMatches -Pattern $guid_pattern).Matches[0]
	Write-Host $boot_id

	# modify boot entry to "Safe Mode with Networking"
	& 'bcdedit' '/set' $boot_id 'safeboot' 'network'

	# make boot entry the new default
	& 'bcdedit' '/default' $boot_id

	# change the default boot timeout
	& 'bcdedit' '/timeout' '5'

	$safeboot_network_reg = "HKLM:SYSTEM\CurrentControlSet\Control\SafeBoot\Network"
	New-Item -Path $safeboot_network_reg -Name 'WaykNowService' -Value 'Service' -Force
}
