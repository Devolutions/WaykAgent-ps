Import-Module "$PSScriptRoot/../WaykAgent"

Describe 'Wayk Agent branding' {
	InModuleScope WaykAgent {
		Mock Get-WaykAgentPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykAgentPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Sets a sample branding.zip file' {
				$BrandingZip = Join-Path $PSScriptRoot "../samples/branding.zip" -Resolve
				Set-WaykAgentBranding -BrandingPath $BrandingZip
				Assert-MockCalled 'Get-WaykAgentPath'
				$GlobalPath = Get-WaykAgentPath 'GlobalPath'
				$BrandingPath = Join-Path $GlobalPath "branding.zip"
				Test-Path -Path $BrandingPath | Should -BeTrue
			}
		}
	}
}
