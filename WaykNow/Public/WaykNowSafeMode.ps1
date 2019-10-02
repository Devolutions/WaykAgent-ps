
. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/BcdEdit.ps1"
. "$PSScriptRoot/../Private/PlatformHelpers.ps1"

function Set-WaykNowSafeMode
{
	if((Get-IsWindows)){
		if(!(Get-IsRunAsAdministrator)) {
			throw (New-Object RunAsAdministratorException)
		}

		$tempDirectory = New-TemporaryDirectory
		$system32Path = [System.Environment]::SystemDirectory
		$bcdEditTemporary = "$system32Path/bcdedit.exe"

		Copy-Item "$bcdEditTemporary" -Destination "$tempDirectory"

		$bcd_entries = Get-BcdEntries
		$bcd_current = Get-BcdNameById '{current}' $bcd_entries
		$bcd_default = Get-BcdNameById '{default}' $bcd_entries
		$actualSafeBoot = Get-BcdSafeBootByName '{current}' $bcd_entries

		if($null -ne $actualSafeBoot)
		{
			throw "The Set-WaykNowSafeMode is not possible when the computer is in safe mode"
		}

		if(([string]$bcd_default -eq "Safe Mode with Wayk Now") -OR ([string]$bcd_current -eq "Safe Mode with Wayk Now"))
		{
			throw "Safe Mode with Wayk Now is already set"
		}

		# copy default boot entry
		if($bcd_default){
			$bcdedit_copy = $(Invoke-Process -FilePath "$bcdEditTemporary" -ArgumentList "/copy {default} /d `"${safeboot_name}`"")
		}
		else{
			$bcdedit_copy = $(Invoke-Process -FilePath "$bcdEditTemporary" -ArgumentList "/copy {current} /d `"${safeboot_name}`"")
		}

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
	}else{
        throw (New-Object UnsuportedPlatformException("Windows"))
    }
}

function Reset-WaykNowSafeMode
{
	if((Get-IsWindows)){
		if(!(Get-IsRunAsAdministrator)) {
			throw (New-Object RunAsAdministratorException)
		}

		$bcd_entries = Get-BcdEntries
		$bcd_current = Get-BcdNameById '{current}' $bcd_entries
		$bcd_default = Get-BcdNameById '{default}' $bcd_entries

		if(!(([string]$bcd_default -eq "Safe Mode with Wayk Now") -OR ([string]$bcd_current -eq "Safe Mode with Wayk Now")))
		{
			throw "Safe Mode with Wayk Now is not set"
		}
		
		$bcd_entries = Get-BcdEntries
		$prevboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'PrevBootName').PrevBootName
		if($prevboot_name)
		{
			$prevboot_id = Get-BcdIdByName $prevboot_name $bcd_entries
			& 'bcdedit' '/default' $prevboot_id | Out-Null
		}

		$bcd_entries = Get-BcdEntries
		$safeboot_name = $(Get-ItemProperty -Path "$safeboot_reg\WaykNowService" -Name 'SafeBootName').SafeBootName
		if($safeboot_name){
			$safeboot_id = Get-BcdIdByName $safeboot_name $bcd_entries
			& 'bcdedit' '/delete' $safeboot_id | Out-Null
		}
		
		Remove-Item -Path "$safeboot_reg\WaykNowService" -Force -Recurse

	}else{
		throw (New-Object UnsuportedPlatformException("Windows"))
	}
}

Export-ModuleMember -Function Set-WaykNowSafeMode, Reset-WaykNowSafeMode
