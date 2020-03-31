Import-Module "$PSScriptRoot/../WaykNow"

Describe 'Wayk Now config' {
	InModuleScope WaykNow {
		Mock Get-WaykNowPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykNowPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Disables Prompt for Permission (PFP)' {
				Set-WaykNowConfig -Global -AllowPersonalPassword $false
				$(Get-WaykNowConfig).AllowPersonalPassword | Should -Be $false
				Assert-MockCalled 'Get-WaykNowPath'
			}
			It 'Sets server-only remote control mode' {
				Set-WaykNowConfig -Global -ControlMode Both
				$(Get-WaykNowConfig).ControlMode | Should -Be 'Both'
				Assert-MockCalled 'Get-WaykNowPath'
			}
			It 'Sets friendly name with special characters' {
				Set-WaykNowConfig -FriendlyName 'Señor Marc-André'
				$(Get-WaykNowConfig).FriendlyName | Should -Be 'Señor Marc-André'
			}
			It 'Disables the version check' {
				Set-WaykNowConfig -Global -VersionCheck $false
				$(Get-WaykNowConfig).VersionCheck | Should -Be $false
			}
			It 'Disables remote execution' {
				Set-WaykNowConfig -Global -AccessControlExec 'Disable'
				Set-WaykNowConfig -AccessControlExec 'Confirm'
				$(Get-WaykNowConfig).AccessControlExec | Should -Be 'Disable'
			}
			It 'Sets generated password length' {
				Set-WaykNowConfig -GeneratedPasswordLength 8
				$(Get-WaykNowConfig).GeneratedPasswordLength | Should -Be 8
				{ Set-WaykNowConfig -GeneratedPasswordLength 1 } | Should -Throw
				$(Get-WaykNowConfig).GeneratedPasswordLength | Should -Be 8
			}
		}
	}
}
