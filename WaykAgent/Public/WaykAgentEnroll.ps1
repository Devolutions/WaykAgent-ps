
function Register-WaykAgent
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

    $WaykAgentCommand = Get-WaykAgentCommand

    if ($PSCmdlet.ParameterSetName -eq 'TokenId') {

        if ($TokenId -NotMatch '^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$') {
            Write-Warning "TokenId appears to be incorrectly formatted (UUID expected): $TokenId"
        }

        if ($DenUrl -NotMatch '^http([s]+)://(.+)$') {
            Write-Warning "DenUrl appears to be missing an 'https://' or 'http://' prefix: $DenUrl"
        }

        & $WaykAgentCommand 'enroll' '--token-id' $TokenId '--den-url' $DenUrl
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'TokenData') {
        & $WaykAgentCommand 'enroll' '--token' $TokenData
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'TokenPath') {
        if (-Not (Test-Path -Path $TokenPath -PathType Leaf)) {
            Write-Warning "TokenPath cannot be found: $TokenPath"
        }

        & $WaykAgentCommand 'enroll' '--token-file' $TokenPath
    }
}
