
$ModuleName = 'WaykAgent'
Push-Location $PSScriptRoot

Remove-Item -Path .\package -Recurse -Force -ErrorAction SilentlyContinue

New-Item -Path "$PSScriptRoot\package\$module" -ItemType 'Directory' -Force | Out-Null
@('Public', 'Private') | foreach {
    New-Item -Path "$PSScriptRoot\package\${ModuleName}\$_" -ItemType 'Directory' -Force | Out-Null
}

Copy-Item "$PSScriptRoot\${ModuleName}\Private" -Destination "$PSScriptRoot\package\${ModuleName}" -Recurse -Force
Copy-Item "$PSScriptRoot\${ModuleName}\Public" -Destination "$PSScriptRoot\package\${ModuleName}" -Recurse -Force

Copy-Item "$PSScriptRoot\${ModuleName}\${ModuleName}.psd1" -Destination "$PSScriptRoot\package\${ModuleName}" -Force
Copy-Item "$PSScriptRoot\${ModuleName}\${ModuleName}.psm1" -Destination "$PSScriptRoot\package\${ModuleName}" -Force
