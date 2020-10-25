function Get-WaykAgentUniqueId
{
    [CmdletBinding()]
    param(
    )

    $ConfigPath = Get-WaykAgentPath
    $ServerPath = Join-Path $ConfigPath "server"
    $UniqueIdFile = Join-Path $ServerPath ".unique"

    if (Test-Path $UniqueIdFile -PathType 'Leaf') {
        $UniqueId = Get-Content -Path $UniqueIdFile -Raw -Encoding UTF8
        return $UniqueId
    }
}
