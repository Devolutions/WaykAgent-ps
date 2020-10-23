Import-Module "$PSScriptRoot/../WaykClient"

Describe 'Wayk Client config' {
	InModuleScope WaykClient {
		Mock Get-WaykClientPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykClientPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Sets friendly name with special characters' {
				Set-WaykClientConfig -FriendlyName 'Señor Marc-André'
				$(Get-WaykClientConfig).FriendlyName | Should -Be 'Señor Marc-André'
			}
			It 'Sets the Wayk Den URL' {
				Set-WaykClientConfig -DenUrl 'https://den.contoso.com'
				$(Get-WaykClientConfig).DenUrl | Should -Be 'https://den.contoso.com'
			}
		}
	}
}
