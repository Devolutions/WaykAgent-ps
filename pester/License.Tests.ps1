Import-Module "$PSScriptRoot/../WaykNow"

Describe 'Wayk Now license' {
	InModuleScope WaykNow {
		Mock Get-WaykNowPath { Join-Path $TestDrive "Global" } -ParameterFilter { $PathType -eq "GlobalPath" }
		Mock Get-WaykNowPath { Join-Path $TestDrive "Local" } -ParameterFilter { $PathType -eq "LocalPath" }

		Context 'Empty configuration files' {
			BeforeAll {
				$GlobalPath = Get-WaykNowPath 'GlobalPath'
				$LocalPath = Get-WaykNowPath 'LocalPath'
				foreach ($DataPath in ($GlobalPath, $LocalPath)) {
					New-Item -Path $DataPath -ItemType Directory
					Set-Content -Path $(Join-Path $DataPath 'WaykNow.cfg') -Value '{}'
				}
			}
			It 'Sets an expired license' {
				Set-WaykNowLicense -License "4DQKM-QGMF4-K3YBJ-VHKN4-QKNKQ"
				$(Get-WaykNowLicense) | Should -Be "4DQKM-QGMF4-K3YBJ-VHKN4-QKNKQ"
				Assert-MockCalled 'Get-WaykNowPath'
			}
		}
	}
}
