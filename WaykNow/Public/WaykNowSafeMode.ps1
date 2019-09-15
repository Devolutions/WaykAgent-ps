
. "$PSScriptRoot/../Private/Invoke-Process.ps1"

$safeboot_name = "Safe Mode with Wayk Now"
$safeboot_reg = "HKLM:SYSTEM\CurrentControlSet\Control\SafeBoot\Network"

function Get-BcdEntries
{
	$bcdedit_enum = $(Invoke-Process -FilePath 'bcdedit' -ArgumentList "/enum OSLOADER") | Out-String

	$entries = @()
	Foreach ($entry in $($bcdedit_enum -Split ".*`r`n-+`r`n")) {
		$entry = $entry.trim()
		if ($entry) {
			$entries += $entry
		}
	}

	return $entries
}

function Get-BcdIdByName(
	[string] $name,
	[string[]] $entries
){
	Foreach ($entry in $entries) {
		if ($entry -Match "\s.+${name}`r`n") {
			$identifier = $($entry | Select-String -AllMatches -Pattern '{.+}').Matches[0]
			return $identifier
		}
	}

	return $null
}

function Get-BcdNameById(
	[string] $id,
	[string[]] $entries
){
	Foreach ($entry in $entries) {
		if ($entry -Match "\s.+${id}`r`n") {
			$result = $entry | Select-String -AllMatches -Pattern "description+\s+(.+)`r`n"
			$name = $result.Matches.Groups[1]
			return $name
		}
	}

	return $null
}

function Set-WaykNowSafeMode
{
	$bcd_entries = Get-BcdEntries
	$bcd_default = Get-BcdNameById '`{default`}' $entries

	# copy default boot entry
	$bcdedit_copy = $(Invoke-Process -FilePath 'bcdedit' -ArgumentList "/copy `{default`} /d `"${safeboot_name}`"")

	$guid_pattern = '{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}}'
	$safeboot_id = $($bcdedit_copy | Select-String -AllMatches -Pattern $guid_pattern).Matches[0]

	# modify boot entry to "Safe Mode with Networking"
	& 'bcdedit' '/set' $safeboot_id 'safeboot' 'network' | Out-Null

	# make boot entry the new default
	& 'bcdedit' '/default' $safeboot_id | Out-Null

	# change the default boot timeout
	& 'bcdedit' '/timeout' '5' | Out-Null

	New-Item -Path $safeboot_reg -Name 'WaykNowService' -Value 'Service' -Force | Out-Null

	New-ItemProperty -Path "$safeboot_reg\WaykNowService" `
		-Name 'PrevBootName' -Value $bcd_default -PropertyType 'String' -Force | Out-Null
		New-ItemProperty -Path "$safeboot_reg\WaykNowService" `
		-Name 'SafeBootName' -Value $safeboot_name -PropertyType 'String' -Force | Out-Null
}

function Reset-WaykNowSafeMode
{ 
	$bcd_entries = Get-BcdEntries
	$prevboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'PrevBootName').PrevBootName
	$prevboot_id = Get-BcdIdByName $prevboot_name $bcd_entries
	& 'bcdedit' '/default' $prevboot_id | Out-Null

	$bcd_entries = Get-BcdEntries
	$safeboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'SafeBootName').SafeBootName
	$safeboot_id = Get-BcdIdByName $safeboot_name $bcd_entries
	& 'bcdedit' '/delete' $safeboot_id | Out-Null

	Remove-Item -Path "$safeboot_reg\WaykNowService" -Force -Recurse
}

Export-ModuleMember -Function Set-WaykNowSafeMode, Reset-WaykNowSafeMode
