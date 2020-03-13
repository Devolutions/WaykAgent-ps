
. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/BcdEdit.ps1"
. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

New-Variable -Name 'SafeModeWithWaykNow' -Value 'Safe Mode with Wayk Now' -Option Constant

function Set-WaykNowSafeMode
{
    [CmdletBinding()]
    param()

    if (!(Get-IsWindows)) {
        throw (New-Object UnsupportedPlatformException("Windows"))
    }

	$tempDirectory = New-TemporaryDirectory
	$bcdEditTemporary = Copy-BcdEditToTempDirectory $tempDirectory
	
	$bcd_entries = Get-BcdEntries $bcdEditTemporary 
	$bcd_current = Get-BcdNameById '{current}' $bcd_entries
	$bcd_default = Get-BcdNameById '{default}' $bcd_entries
	$actualSafeBoot = Get-BcdSafeBootByName '{current}' $bcd_entries

	if ($null -ne $actualSafeBoot)
	{
		throw "The Set-WaykNowSafeMode is not possible when the computer is in safe mode"
	}

	if (([string]$bcd_default -eq $SafeModeWithWaykNow) -OR ([string]$bcd_current -eq $SafeModeWithWaykNow))
	{
		throw "Safe Mode with Wayk Now is already set"
	}

	# copy default boot entry
	if ($bcd_default) {
		$bcdedit_copy = $(Invoke-Process -FilePath "$bcdEditTemporary" -ArgumentList "/copy {default} /d `"${safeboot_name}`"")
	} else {
		$bcdedit_copy = $(Invoke-Process -FilePath "$bcdEditTemporary" -ArgumentList "/copy {current} /d `"${safeboot_name}`"")
	}

	$guid_pattern = '{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}}'
	$safeboot_id = $($bcdedit_copy | Select-String -AllMatches -Pattern $guid_pattern).Matches[0]

	# modify boot entry to "Safe Mode with Networking"
	& $bcdEditTemporary '/set' $safeboot_id 'safeboot' 'network' | Out-Null

	# make boot entry the new default
	& $bcdEditTemporary '/default' $safeboot_id | Out-Null

	# change the default boot timeout
	& $bcdEditTemporary '/timeout' '5' | Out-Null

	New-Item -Path $safeboot_reg -Name 'WaykNowService' -Value 'Service' -Force | Out-Null

	New-ItemProperty -Path "$safeboot_reg\WaykNowService" `
		-Name 'PrevBootName' -Value $bcd_default -PropertyType 'String' -Force | Out-Null
		New-ItemProperty -Path "$safeboot_reg\WaykNowService" `
		-Name 'SafeBootName' -Value $safeboot_name -PropertyType 'String' -Force | Out-Null

	Remove-Item -Path $tempDirectory -Force -Recurse
}

function Reset-WaykNowSafeMode
{
    [CmdletBinding()]
    param()

    if (!(Get-IsWindows)) {
        throw (New-Object UnsupportedPlatformException("Windows"))
    }

	$tempDirectory = New-TemporaryDirectory
	$bcdEditTemporary = Copy-BcdEditToTempDirectory $tempDirectory

	$bcd_entries = Get-BcdEntries $bcdEditTemporary
	$bcd_current = Get-BcdNameById '{current}' $bcd_entries
	$bcd_default = Get-BcdNameById '{default}' $bcd_entries

	if(!(([string]$bcd_default -eq $SafeModeWithWaykNow) -OR ([string]$bcd_current -eq $SafeModeWithWaykNow)))
	{
		throw "Safe Mode with Wayk Now is not set"
	}
	
	$bcd_entries = Get-BcdEntries $bcdEditTemporary 
	$prevboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'PrevBootName').PrevBootName
	
	if ($prevboot_name) {
		$prevboot_id = Get-BcdIdByName $prevboot_name $bcd_entries
		& $bcdEditTemporary '/default' $prevboot_id | Out-Null
	}

	$bcd_entries = Get-BcdEntries $bcdEditTemporary 
	$safeboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'SafeBootName').SafeBootName

	if ($safeboot_name) {
		$safeboot_id = Get-BcdIdByName $safeboot_name $bcd_entries
		& $bcdEditTemporary '/delete' $safeboot_id | Out-Null
	}
	
	Remove-Item -Path "$safeboot_reg\WaykNowService" -Force -Recurse

	Remove-Item -Path $tempDirectory -Force -Recurse
}

Export-ModuleMember -Function Set-WaykNowSafeMode, Reset-WaykNowSafeMode
