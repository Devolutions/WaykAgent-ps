Import-Module "$PSScriptRoot/../WaykNow"

Describe 'Wayk Now config' {
	InModuleScope WaykNow {
		Mock Get-WaykNowPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykNowPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Disables Prompt for Permission (PFP)' {
				Set-WaykNowConfig -AllowPersonalPassword false
				$(Get-WaykNowConfig).AllowPersonalPassword | Should -Be false
				Assert-MockCalled 'Get-WaykNowPath'
			}
			It 'Sets server-only remote control mode' {
				Set-WaykNowConfig -ControlMode AllowRemoteControlServerOnly
				$(Get-WaykNowConfig).ControlMode | Should -Be 'AllowRemoteControlServerOnly'
				Assert-MockCalled 'Get-WaykNowPath'
			}
		}
	}
}
