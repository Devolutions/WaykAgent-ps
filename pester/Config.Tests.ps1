Import-Module "$PSScriptRoot/../WaykNow"

Describe 'set wayk now config' {
	Mock Get-WaykNowPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
	Mock Get-WaykNowPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

	It 'Gets local and global wayk now paths' {
		$GlobalPath = Get-WaykNowPath GlobalPath
		$LocalPath = Get-WaykNowPath LocalPath
		Write-Host $GlobalPath
		Write-Host $LocalPath
	}
	It 'Disables Prompt for Permission (PFP)' {
		Set-WaykNowConfig -AllowPersonalPassword false
		$(Get-WaykNowConfig).AllowPersonalPassword | Should -Be false
	}
	It 'Sets server-only remote control mode' {
		Set-WaykNowConfig -ControlMode AllowRemoteControlServerOnly
		$(Get-WaykNowConfig).ControlMode | Should -Be 'AllowRemoteControlServerOnly'
	}
}
