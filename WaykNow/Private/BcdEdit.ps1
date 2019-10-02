
$safeboot_name = "Safe Mode with Wayk Now"
$safeboot_reg = "HKLM:SYSTEM\CurrentControlSet\Control\SafeBoot\Network"

function Get-BcdEntries(
	[string] $bcdeditTempPath
)
{
	$bcdedit_enum = $(Invoke-Process -FilePath $bcdeditTempPath -ArgumentList "/enum OSLOADER") | Out-String

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

function Get-BcdSafeBootByName(
	[string] $name,
	[string[]] $entries
){
	Foreach ($entry in $entries) {
		if ($entry -Match "\s.+${name}`r`n") {
			$result = $entry | Select-String -AllMatches -Pattern "safeboot+\s+(.+)`r`n"
			if($result){
				$name = $result.Matches.Groups[1]
				return $name
			}
		}
	}

	return $null
}

	
function Copy-BcdEditToTempDirectory(
	[string]$tempDirectory
	){
		$system32Path = [System.Environment]::SystemDirectory
		$bcdEditLocation = "$system32Path/bcdedit.exe"
		Copy-Item "$bcdEditLocation" -Destination "$tempDirectory"

		return "$tempDirectory/bcdedit.exe"
	}
