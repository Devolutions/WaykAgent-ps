Import-Module "$PSScriptRoot/../WaykAgent"

Describe 'Wayk Agent config' {
	InModuleScope WaykAgent {
		Mock Get-WaykAgentPath { Join-Path $TestDrive "config" }

		Context 'Empty configuration files' {
			It 'Disables the version check' {
				Set-WaykAgentConfig -VersionCheck $false
				$(Get-WaykAgentConfig).VersionCheck | Should -Be $false
				Set-WaykAgentConfig -VersionCheck $true
				$(Get-WaykAgentConfig).VersionCheck | Should -Be $true
			}
			It 'Disables automatic updates' {
				Set-WaykAgentConfig -AutoUpdateEnabled $false
				$(Get-WaykAgentConfig).AutoUpdateEnabled | Should -Be $false
				Set-WaykAgentConfig -AutoUpdateEnabled $true
				$(Get-WaykAgentConfig).AutoUpdateEnabled | Should -Be $true
			}
			It 'Disables remote execution' {
				Set-WaykAgentConfig -AccessControlExec 'Disable'
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
