Import-Module "$PSScriptRoot/../WaykAgent"

Describe 'Wayk Agent config' {
	InModuleScope WaykAgent {
		Mock Get-WaykAgentPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykAgentPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Disables Prompt for Permission (PFP)' {
				Set-WaykAgentConfig -Global -AllowPersonalPassword $false
				$(Get-WaykAgentConfig).AllowPersonalPassword | Should -Be $false
				Assert-MockCalled 'Get-WaykAgentPath'
			}
			It 'Sets server-only remote control mode' {
				Set-WaykAgentConfig -Global -ControlMode Both
				$(Get-WaykAgentConfig).ControlMode | Should -Be 'Both'
				Assert-MockCalled 'Get-WaykAgentPath'
			}
			It 'Sets friendly name with special characters' {
				Set-WaykAgentConfig -FriendlyName 'Señor Marc-André'
				$(Get-WaykAgentConfig).FriendlyName | Should -Be 'Señor Marc-André'
			}
			It 'Disables the version check' {
				Set-WaykAgentConfig -Global -VersionCheck $false
				$(Get-WaykAgentConfig).VersionCheck | Should -Be $false
				Set-WaykAgentConfig -Global -VersionCheck $true
				$(Get-WaykAgentConfig).VersionCheck | Should -Be $true
				Set-WaykAgentConfig -VersionCheck $false
				$(Get-WaykAgentConfig).VersionCheck | Should -Be $true
			}
			It 'Disables automatic updates' {
				Set-WaykAgentConfig -Global -AutoUpdateEnabled $false
				$(Get-WaykAgentConfig).AutoUpdateEnabled | Should -Be $false
				Set-WaykAgentConfig -Global -AutoUpdateEnabled $true
				$(Get-WaykAgentConfig).AutoUpdateEnabled | Should -Be $true
				Set-WaykAgentConfig -AutoUpdateEnabled $false
				$(Get-WaykAgentConfig).AutoUpdateEnabled | Should -Be $true
			}
			It 'Disables remote execution' {
				Set-WaykAgentConfig -Global -AccessControlExec 'Disable'
				Set-WaykAgentConfig -AccessControlExec 'Confirm'
				$(Get-WaykAgentConfig).AccessControlExec | Should -Be 'Disable'
			}
			It 'Sets generated password length' {
				Set-WaykAgentConfig -GeneratedPasswordLength 8
				$(Get-WaykAgentConfig).GeneratedPasswordLength | Should -Be 8
				{ Set-WaykAgentConfig -GeneratedPasswordLength 1 } | Should -Throw
				$(Get-WaykAgentConfig).GeneratedPasswordLength | Should -Be 8
			}
			It 'Sets the codec quality mode' {
				Set-WaykAgentConfig -QualityMode 'High'
				$(Get-WaykAgentConfig).QualityMode | Should -Be 'High'
			}
			It 'Sets the Wayk Den URL' {
				Set-WaykAgentConfig -DenUrl 'https://den.contoso.com'
				$(Get-WaykAgentConfig).DenUrl | Should -Be 'https://den.contoso.com'
			}
		}
	}
}
