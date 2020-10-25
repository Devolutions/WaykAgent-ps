Import-Module "$PSScriptRoot/../WaykAgent"

Describe 'Wayk Agent branding' {
	InModuleScope WaykAgent {
		Mock Get-WaykAgentPath { Join-Path $TestDrive "config" }

		Context 'Empty configuration files' {
			It 'Sets a sample branding.zip file' {
				$BrandingZip = Join-Path $PSScriptRoot "../samples/branding.zip" -Resolve
				Set-WaykAgentBranding -BrandingPath $BrandingZip
				Assert-MockCalled 'Get-WaykAgentPath'
				$ConfigPath = Get-WaykAgentPath 'GlobalPath'
				$BrandingPath = Join-Path $ConfigPath "branding.zip"
				Test-Path -Path $BrandingPath | Should -BeTrue
			}
		}
	}
}
