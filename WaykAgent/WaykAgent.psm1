$module = 'WaykAgent'
$manifest = Import-PowerShellDataFile -Path "$PSScriptRoot/$module.psd1"

Export-ModuleMember -Cmdlet @($manifest.CmdletsToExport)

$Public = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -Recurse)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -Recurse)

Foreach ($Import in @($Public + $Private))
{
    Try
    {
        . $Import.FullName
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

if (Get-IsWindows) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
}

$LegacyFunctionNames = @($manifest.AliasesToExport) | Where-Object { $_ -Match 'WaykNow' }

Foreach ($FunctionName in $LegacyFunctionNames) {
    $OldFunctionName = $FunctionName
    $NewFunctionName = $FunctionName -Replace 'WaykNow', 'WaykAgent'
    New-Alias -Name $OldFunctionName -Value $NewFunctionName
}

Export-ModuleMember -Alias $LegacyFunctionNames
