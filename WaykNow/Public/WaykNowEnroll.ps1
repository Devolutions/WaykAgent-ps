
function Register-WaykNow
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ParameterSetName='TokenId',
            HelpMessage="Wayk Den URL to be used for enrollment")]
        [string] $DenUrl,
        [Parameter(Mandatory=$True,ParameterSetName='TokenId',
            HelpMessage="Enrollment token id")]
        [string] $TokenId,
        [Parameter(Mandatory=$True,ParameterSetName='TokenData',
            HelpMessage="Enrollment token value")]
        [string] $TokenData,
        [Parameter(Mandatory=$True,ParameterSetName='TokenPath',
            HelpMessage="Enrollment token file path")]
        [string] $TokenPath
    )

    $WaykNowCommand = Get-WaykNowCommand

    if ($PSCmdlet.ParameterSetName -eq 'TokenId') {

        if ($TokenId -NotMatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
            Write-Warning "TokenId appears to be incorrectly formatted (UUID expected): $TokenId"
        }

        if ($DenUrl -NotMatch '^http([s]+)://(.+)$') {
            Write-Warning "DenUrl appears to be missing an 'https://' or 'http://' prefix: $DenUrl"
        }

        & $WaykNowCommand 'enroll' '--token-id' $TokenId '--den-url' $DenUrl
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'TokenData') {
        & $WaykNowCommand 'enroll' '--token' $TokenData
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'TokenPath') {
        if (-Not (Test-Path -Path $TokenPath -PathType Leaf)) {
            Write-Warning "TokenPath cannot be found: $TokenPath"
        }

        & $WaykNowCommand 'enroll' '--token-file' $TokenPath
    }
}

Export-ModuleMember -Function Register-WaykNow
