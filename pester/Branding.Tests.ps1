Import-Module "$PSScriptRoot/../WaykNow"

Describe 'Wayk Now branding' {
	InModuleScope WaykNow {
		Mock Get-WaykNowPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykNowPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			It 'Sets a sample branding.zip file' {
				$BrandingZip = Join-Path $PSScriptRoot "../samples/branding.zip" -Resolve
				Set-WaykNowBranding -BrandingPath $BrandingZip
				Assert-MockCalled 'Get-WaykNowPath'
				$GlobalPath = Get-WaykNowPath 'GlobalPath'
				$BrandingPath = Join-Path $GlobalPath "branding.zip"
				Test-Path -Path $BrandingPath | Should -BeTrue
			}
		}
	}
}
