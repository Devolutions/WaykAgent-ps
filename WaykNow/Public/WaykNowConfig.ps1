. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"

enum ControlMode 
{
    Both = 0
    Client = 1
    Server = 2
}

enum PersonalPasswordType 
{
    Generated = 0
    Custom = 1
}

enum GeneratedPasswordCharSet 
{
    Numeric = 0
    Alphanumeric = 1
}

enum QualityMode 
{
    Low = 0
    Medium = 1
    High = 2
}

enum LoggingLevel 
{
    Trace = 0
    Debug = 1
    Info = 2
    Warn = 3
    Error = 4
    Fatal = 5
    Off = 6
}

enum AccessControl
{
    Allow = 1
    Confirm = 2
    Disable = 4
}

class WaykNowConfig
{
	# General
    [string] $FriendlyName
    [string] $Language
    [ControlMode] $ControlMode = [ControlMode]::Both
    [bool] $AutoLaunchOnUserLogon = $false
    [bool] $ShowMainWindowOnLaunch = $true
    [bool] $MinimizeToNotificationArea = $false
    [bool] $ElevationPrompt = $false

    # Security
    [bool] $AllowPersonalPassword = $true
    [bool] $AllowSystemAuth = $true
    [bool] $AllowNoPassword = $true
    [PersonalPasswordType] $PersonalPasswordType
    [string] $PersonalPassword
    [int32] $GeneratedPasswordLength = 6
    [bool] $GeneratedPasswordAutoReset = $true
    [GeneratedPasswordCharSet] $GeneratedPasswordCharSet = [GeneratedPasswordCharSet]::Alphanumeric

    # Connectivity
    [bool] $DenEnabled = $true
    [string] $DenUrl = "https://den.wayk.net"

    # Advanced
    [QualityMode] $QualityMode = [QualityMode]::Medium
    [LoggingLevel] $LoggingLevel
    [string] $LoggingFilter

    # Access Control
    [AccessControl] $AccessControlViewing = [AccessControl]::Allow
    [AccessControl] $AccessControlInteract = [AccessControl]::Allow
    [AccessControl] $AccessControlClipboard = [AccessControl]::Allow
    [AccessControl] $AccessControlFileTransfer = [AccessControl]::Allow
    [AccessControl] $AccessControlExec = [AccessControl]::Allow
    [AccessControl] $AccessControlChat = [AccessControl]::Allow

    [bool] $AnalyticsEnabled = $true
    [bool] $CrashReporterEnabled = $true
    [bool] $CrashReporterAutoUpload = $true
    [bool] $VersionCheck = $true
}

function Get-WaykNowConfigFile
{
    param(
        [switch] $Global
    )

    [WaykNowInfo]$WaykInfo = Get-WaykNowInfo

    if ($Global) {
        $ConfigFile = $WaykInfo.GlobalConfigFile
    } else {
        $ConfigFile = $WaykInfo.ConfigFile
    }

    return $ConfigFile
}

function Set-WaykNowConfig
{
    [CmdletBinding()]
    param(
        [switch] $Global,

        [string] $FriendlyName,
        [ValidateSet("en", "fr", "de", "zh-CN", "zh-TW")]
        [string] $Language,
        [ControlMode] $ControlMode,
        [bool] $AutoLaunchOnUserLogon,
        [bool] $ShowMainWindowOnLaunch,
        [bool] $MinimizeToNotificationArea,
        [bool] $ElevationPrompt,

        [bool] $AllowPersonalPassword,
        [bool] $AllowSystemAuth,
        [bool] $AllowNoPassword,
        [PersonalPasswordType]  $PersonalPasswordType,
        [string] $PersonalPassword,
        [ValidateRange(3,9)]
        [int32] $GeneratedPasswordLength,
        [GeneratedPasswordCharSet] $GeneratedPasswordCharSet,

        [bool] $DenEnabled,
        [string] $DenUrl,

        [QualityMode] $QualityMode,
        [LoggingLevel] $LoggingLevel,
        [string] $LoggingFilter,

        [AccessControl] $AccessControlViewing,
        [AccessControl] $AccessControlInteract,
        [AccessControl] $AccessControlClipboard,
        [AccessControl] $AccessControlFileTransfer,
        [AccessControl] $AccessControlExec,
        [AccessControl] $AccessControlChat,

        [bool] $AnalyticsEnabled,
        [bool] $CrashReporterEnabled,
        [bool] $CrashReporterAutoUpload,
        [bool] $VersionCheck
    )

    $ConfigFile = Get-WaykNowConfigFile -Global:$Global

    if (Test-Path $ConfigFile) {
        $json = Get-Content -Path $ConfigFile -Encoding UTF8 | ConvertFrom-Json
    } else {
        $json = '{}' | ConvertFrom-Json
    }

    $properties = [WaykNowConfig].GetProperties() | ForEach-Object { $_.Name }
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($properties -Contains $param.Key) {
            $json = Set-JsonValue $json $param.Key $param.Value
        }
    }

    $AccessControl = [pscustomobject]@{
        'Viewing' = $AccessControlViewing
        'Interact' = $AccessControlInteract
        'Clipboard' = $AccessControlClipboard
        'FileTransfer' = $AccessControlFileTransfer
        'Exec' = $AccessControlExec
        'Chat' = $AccessControlChat
    }

    # To ignore the null value on the json we remove the values who are not set if there are not in the json file
    # Access Control
    if ($null -eq $AccessControlViewing) {
        if ($json.AccessControl.Viewing)
        {
            $AccessControl.Viewing = $json.AccessControl.Viewing
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('Viewing')
        }
    }

    if ($null -eq $AccessControlInteract) {
        if ($json.AccessControl.Interact)
        {
            $AccessControl.Interact = $json.AccessControl.Interact
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('Interact')
        }
    }

    if ($null -eq $AccessControlClipboard) {
        if ($json.AccessControl.Clipboard)
        {
            $AccessControl.Clipboard = $json.AccessControl.Clipboard
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('Clipboard')
        }
    }

    if ($null -eq $AccessControlFileTransfer) {
        if ($json.AccessControl.FileTransfer)
        {
            $AccessControl.FileTransfer = $json.AccessControl.FileTransfer
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('FileTransfer')
        }
    }

    if ($null -eq $AccessControlExec) {
        if ($json.AccessControl.Exec)
        {
            $AccessControl.Exec = $json.AccessControl.Exec
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('Exec')
        }
    }

    if ($null -eq $AccessControlChat) {
        if ($json.AccessControl.Chat)
        {
            $AccessControl.Chat = $json.AccessControl.Chat
        }
        else
        {
            $AccessControl.PSObject.Properties.Remove('Chat')
        }
    }

    $json = Set-JsonValue $json 'AccessControl' $AccessControl

    New-Item -Path $(Split-Path $ConfigFile -Parent) -ItemType 'Directory' -Force | Out-Null

    $FileValue = $json | ConvertTo-Json
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($ConfigFile, $FileValue, $Utf8NoBomEncoding)
}

function Get-WaykNowConfig
{
    [CmdletBinding()]
    [OutputType('WaykNowConfig')]
    param(
        [switch] $Global = $false
    )

    if (-Not $Global) {
        $LocalConfigFile = Get-WaykNowConfigFile

        if (Test-Path $LocalConfigFile) {
            $LocalJson = Get-Content -Path $LocalConfigFile -Encoding UTF8 | ConvertFrom-Json
        }
    }

    $GlobalConfigFile = Get-WaykNowConfigFile -Global

    if (Test-Path $GlobalConfigFile) {
        $GlobalJson = Get-Content -Path $GlobalConfigFile -Encoding UTF8 | ConvertFrom-Json
    }

    $config = [WaykNowConfig]::new()
    [WaykNowConfig].GetProperties() | ForEach-Object {
        $Name = $_.Name
        $Property = $null

        if ($LocalJson -And $LocalJson.PSObject.Properties[$Name]) {
            $Property = $LocalJson.PSObject.Properties[$Name]
        }

        if ($GlobalJson -And $GlobalJson.PSObject.Properties[$Name]) {
            $Property = $GlobalJson.PSObject.Properties[$Name]
        }

        if ($Property) {
            $Value = $Property.Value
            $config.$Name = $Value
        }
    }

    return $config
}

Export-ModuleMember -Function Set-WaykNowConfig, Get-WaykNowConfig
