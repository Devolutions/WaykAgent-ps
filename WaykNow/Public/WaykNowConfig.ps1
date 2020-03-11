. "$PSScriptRoot/../Private/Invoke-Process.ps1"
. "$PSScriptRoot/../Private/Exceptions.ps1"
. "$PSScriptRoot/../Private/JsonHelper.ps1"

enum ControlMode 
{
    AllRemoteControlMode = 0
    TakeRemoteControlClientOnly = 1
    AllowRemoteControlServerOnly = 2
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
    [ControlMode] $ControlMode
    [string] $AutoLaunchOnUserLogon
    [string] $ShowMainWindowOnLaunch
    [string] $MinimizeToNotificationArea
    [string] $ElevationPrompt

    # Security
    [string] $AllowPersonalPassword
    [string] $AllowSystemAuth
    [string] $AllowNoPassword
    [PersonalPasswordType]  $PersonalPasswordType
    [string] $PersonalPassword
    [int32] $GeneratedPasswordLength
    [GeneratedPasswordCharSet] $GeneratedPasswordCharSet

    # Connectivity
    [string] $DenEnabled
    [string] $DenUrl

    # Advanced
    [QualityMode] $QualityMode
    [LoggingLevel] $LoggingLevel
    [string] $LoggingFilter

    # Access Control
    [AccessControl] $AccessControlViewing
    [AccessControl] $AccessControlInteract
    [AccessControl] $AccessControlClipboard
    [AccessControl] $AccessControlFileTransfer
    [AccessControl] $AccessControlExec
    [AccessControl] $AccessControlChat
}

<#
    .SYNOPSIS
        The `Set-WaykNowConfig` command, is used for modfy multiple settings from WaykNow.
#>
function Set-WaykNowConfig
(
    # Use global config file rather than user config file.
    [switch] $Global,

    # The Friendly Name is used for Prompt For Permission (PFP) authentication. It should be easily recognized by your peers. 
    [string] $FriendlyName,

    # Specifies the language of the application, "en" for English, "fr" for French, "de" German, "zh-CN" for Chinese Simplified, "zh-TW" for Chinese Traditional.
    [ValidateSet("en", "fr", "de", "zh-CN", "zh-TW")]
    [string] $Language,

    # Specifies the Remote Control Mode of WaykNow, AllRemoteControlMode: Both sides are displayed, TakeRemoteControlClientOnly: Only the client side is displayed and AllowRemoteControlServerOnly: Only the server side is displayed.    [ControlMode] $ControlMode,
    [ControlMode] $ControlMode,

    # Launch Wayk Now when you log on.
    [ValidateSet("true", "false")]
    [string] $AutoLaunchOnUserLogon,

    # Prevent the main application window from showing when Wayk Now starts. It can be quite useful when the application is automatically launched.
    [ValidateSet("true", "false")]
    [string] $ShowMainWindowOnLaunch,

    # Hide Wayk Now from the taskbar when minimized.
    [ValidateSet("true", "false")]
    [string] $MinimizeToNotificationArea,

    # Disable the prompt to elevate program permissions, and run Wayk Now without elevated program permissions.
    [ValidateSet("true", "false")]
    [string] $ElevationPrompt,

    # Enabled/disabled SRP: When Secure Remote Password is disabled, the password options are disabled as well.
    [ValidateSet("true", "false")]
    [string] $AllowPersonalPassword,

    # Setting to enabled/disabled SRD: Secure Remote Delegation is the method used for system authentication in the case of unattended remote access. On Windows, remote access is restricted to members of the built-in Administrators or Remote Desktop Users groups.
    [ValidateSet("true", "false")]
    [string] $AllowSystemAuth,

    # Setting to enabled/disabled PFP: Prompt for Permission authentication requests explicit consent from the remote user without the need for a password.
    [ValidateSet("true", "false")]
    [string] $AllowNoPassword,

    # Select your password type: 
    # - Generated Password 
    # Generate a strong, random password with our password generator which can be configured with the -GeneratedPasswordLength and -GeneratedPasswordCharSet section. 
    # - Custom Password 
    #Create a custom password of your own choosing.
    [PersonalPasswordType]  $PersonalPasswordType,

    #Create a custom password of your own choosing.
    [string] $PersonalPassword,

    # The generated password length, between 3 and 9
    [int32] $GeneratedPasswordLength,

    # The parameter used by the password generator:
    # The alphanumeric character set contains numbers and letters, excluding 0, O, 1, I for a total of 32 characters. This choice was made to avoid any possible confusion when communicating the password to the other user.
    [GeneratedPasswordCharSet] $GeneratedPasswordCharSet,

    # Connect to Wayk Den to enable simplified peer-to-peer connectivity with a 6-digit ID.
    [ValidateSet("true", "false")]
    [string] $DenEnabled,

    # Connect to the Wayk Den server with the URL
    [string] $DenUrl,

    # The quality mode allow to adjust the quality of the render to optimize performance.
    [QualityMode] $QualityMode,

    # This Logging level option affects the verbosity of the logging messages.
    [LoggingLevel] $LoggingLevel,

    # This Logging filter option filters the types of messages that are logged.
    # Do not use unless instructed.
    [string] $LoggingFilter,

    # The Access Control section allows you to restrict access to certain resources shared by the server. In other words, access control defines what can be done to your machine when someone else is connected. You can set each feature independently.
    #- Allow: The feature is enabled.
    #- Confirm: The feature is disabled, but can be enabled after user confirmation during the session.
    #- Disable: The feature is disabled. For security reasons or to enforce company policies, you may want to disable specific features.
    # The viewing access control
    [AccessControl] $AccessControlViewing,

    # The interaction access control
    [AccessControl] $AccessControlInteract,

    # The clipboard access control
    [AccessControl] $AccessControlClipboard,

    # The file transfer access control
    [AccessControl] $AccessControlFileTransfer,

    # The execution access control
    [AccessControl] $AccessControlExec,

    # The chat access control
    [AccessControl] $AccessControlChat
)
{
    $WaykInfo = Get-WaykNowInfo
    $json = Get-Content -Path $WaykInfo.ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($Global) {
        if (!(Get-IsWindows)) {
            Write-Host "Actually, the global settings is for windows only"
            return;
        }

        if (!(Get-Service "WaykNowService" -ErrorAction SilentlyContinue)) {
            Write-Host "The WaykNowService is not installed, do you have installed WaykNow with a .msi ?"
            return;
        }

        $json = Get-Content -Path $WaykInfo.GlobalConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    # General
    if ($FriendlyName) {
        $json = Set-JsonValue $json 'FriendlyName' $FriendlyName
    }

    if ($Language) {
        $json = Set-JsonValue $json 'Language' $Language
    }

    if ($null -ne $ControlMode) {
        $json = Set-JsonValue $json 'ControlMode' $ControlMode
    }

    if ($AutoLaunchOnUserLogon) {
        $json = Set-JsonValue $json 'AutoLaunchOnUserLogon' $AutoLaunchOnUserLogon
    }

    if ($ShowMainWindowOnLaunch) {
        $json = Set-JsonValue $json 'ShowMainWindowOnLaunch' $ShowMainWindowOnLaunch
    }

    if ($MinimizeToNotificationArea ) {
        $json = Set-JsonValue $json 'MinimizeToNotificationArea' $MinimizeToNotificationArea
    }

    if ($ElevationPrompt) {
        $json = Set-JsonValue $json 'ElevationPrompt' $ElevationPrompt
    }

    # Security
    if ($AllowPersonalPassword) {
        $json = Set-JsonValue $json 'AllowPersonalPassword' $AllowPersonalPassword
    }

    if ($AllowSystemAuth) {
        $json = Set-JsonValue $json 'AllowSystemAuth' $AllowSystemAuth
    }

    if ($AllowNoPassword) {
        $json = Set-JsonValue $json 'AllowNoPassword' $AllowNoPassword
    }

    if ($null -ne $PersonalPasswordType) {
        $json = Set-JsonValue $json 'PersonalPasswordType' $PersonalPasswordType
    }

    if ($PersonalPassword) {
        $json = Set-JsonValue $json 'PersonalPassword' $PersonalPassword
    }

    if ($GeneratedPasswordLength -And $GeneratedPasswordLength -ge 3 -And $GeneratedPasswordLength -le 9) {
        $json = Set-JsonValue $json 'GeneratedPasswordLength' $GeneratedPasswordLength
    }

    if ($null -ne $GeneratedPasswordCharSet) {
        $json = Set-JsonValue $json 'GeneratedPasswordCharSet' $GeneratedPasswordCharSet
    }

    # Connectivity
    if ($DenEnabled) {
        $json = Set-JsonValue $json 'DenEnabled' $DenEnabled
    }

    if ($DenUrl) {
        $json = Set-JsonValue $json 'DenUrl' $DenUrl
    }

    #Advanced
    if ($null -ne $QualityMode) {
        $json = Set-JsonValue $json 'QualityMode' $QualityMode
    }

    if ($null -ne $LoggingLevel) {
        $json = Set-JsonValue $json 'LoggingLevel' $LoggingLevel
    }

    if ($LoggingFilter) {
        $json = Set-JsonValue $json 'LoggingFilter' $LoggingFilter
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
    #Access Control
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

    if ($Global) {
        $fileValue = $json | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($WaykInfo.GlobalConfigFile, $fileValue, $Utf8NoBomEncoding)
    }
    else {
        $fileValue = $json | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($WaykInfo.ConfigFile, $fileValue, $Utf8NoBomEncoding)
    }
}

function Get-WaykNowConfig()
{
    [WaykNowInfo]$WaykInfo = Get-WaykNowInfo

    $GlobalServiceAvailable = $false;
    $LocalJson = '';
    $GlobalJson = '';

    if ((Get-IsWindows) -And (Get-Service "WaykNowService" -ErrorAction SilentlyContinue))
    {
        $GlobalServiceAvailable = $true
        $GlobalJson = Get-Content -Path $WaykInfo.GlobalConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    $LocalJson = Get-Content -Path $WaykInfo.ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    
    $WaykNowConfigObject = [WaykNowConfig]::New()
    $WaykNowConfigObject.FriendlyName = Get-NowOptionStr 'FriendlyName' $GlobalServiceAvailable $true $null $LocalJson $GlobalJson
    $WaykNowConfigObject.Language = Get-NowOptionStr 'Language' $GlobalServiceAvailable $true 'en' $LocalJson $GlobalJson
    $WaykNowConfigObject.ControlMode = Get-NowOptionInt 'ControlMode' $GlobalServiceAvailable $true ([int]([ControlMode]::AllRemoteControlMode)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AutoLaunchOnUserLogon = Get-NowOptionBool 'AutoLaunchOnUserLogon' $GlobalServiceAvailable $true $false $LocalJson $GlobalJson
    $WaykNowConfigObject.ShowMainWindowOnLaunch = Get-NowOptionBool 'ShowMainWindowOnLaunch' $GlobalServiceAvailable $true $true $LocalJson $GlobalJson
    $WaykNowConfigObject.MinimizeToNotificationArea = Get-NowOptionBool 'MinimizeToNotificationArea' $GlobalServiceAvailable $true $false $LocalJson $GlobalJson
    $WaykNowConfigObject.ElevationPrompt = Get-NowOptionBool 'ElevationPrompt' $GlobalServiceAvailable $true $false $LocalJson $GlobalJson
    $WaykNowConfigObject.AllowPersonalPassword = Get-NowOptionBool 'AllowPersonalPassword' $GlobalServiceAvailable $true $true $LocalJson $GlobalJson
    $WaykNowConfigObject.AllowSystemAuth = Get-NowOptionBool 'AllowSystemAuth' $GlobalServiceAvailable $true $true $LocalJson $GlobalJson
    $WaykNowConfigObject.AllowNoPassword = Get-NowOptionBool 'AllowNoPassword' $GlobalServiceAvailable $true $true $LocalJson $GlobalJson
    $WaykNowConfigObject.PersonalPasswordType = Get-NowOptionInt 'PersonalPasswordType' $GlobalServiceAvailable $true ([int]([PersonalPasswordType]::Generated)) $LocalJson $GlobalJson
    $WaykNowConfigObject.PersonalPassword = Get-NowOptionBool 'PersonalPassword' $GlobalServiceAvailable $true $true $LocalJson $GlobalJson
    $WaykNowConfigObject.GeneratedPasswordLength = Get-NowOptionInt 'GeneratedPasswordLength' $GlobalServiceAvailable $true 6 $LocalJson $GlobalJson
    $WaykNowConfigObject.GeneratedPasswordCharSet = Get-NowOptionInt 'GeneratedPasswordCharSet' $GlobalServiceAvailable $true ([int]([GeneratedPasswordCharSet]::Alphanumeric)) $LocalJson $GlobalJson
    $WaykNowConfigObject.DenEnabled = (Get-NowOptionBool 'DenEnabled' $GlobalServiceAvailable $false $true $LocalJson $GlobalJson)
    $WaykNowConfigObject.DenUrl = Get-NowOptionStr 'DenUrl' $GlobalServiceAvailable $true 'https://den.wayk.net' $LocalJson $GlobalJson
    $WaykNowConfigObject.QualityMode = Get-NowOptionInt 'QualityMode' $GlobalServiceAvailable $true ([int]([QualityMode]::Medium)) $LocalJson $GlobalJson
    $WaykNowConfigObject.LoggingLevel = Get-NowOptionInt 'LoggingLevel' $GlobalServiceAvailable $true ([int]([LoggingLevel]::Off)) $LocalJson $GlobalJson
    $WaykNowConfigObject.LoggingFilter = Get-NowOptionStr 'LoggingFilter' $GlobalServiceAvailable $true $null $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlViewing = Get-NowOptionInt 'AccessControl.Viewing' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlInteract = Get-NowOptionInt 'AccessControl.Interact' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlClipboard = Get-NowOptionInt 'AccessControl.Clipboard' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlFileTransfer = Get-NowOptionInt 'AccessControl.FileTransfer' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlExec = Get-NowOptionInt 'AccessControl.Exec' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson
    $WaykNowConfigObject.AccessControlChat = Get-NowOptionInt 'AccessControl.Chat' $GlobalServiceAvailable $true ([int]([AccessControl]::Allow)) $LocalJson $GlobalJson

    return $WaykNowConfigObject
}

function Get-NowOptionInt(
    [string] $propertiesName,
    [bool] $serviceAvailable,
    [bool] $virtual,
    [int] $defaultValue,
    [PSCustomObject] $localSettingsJson,
    [PSCustomObject] $globalSettingsJson
)
{
    $result = Get-GenericOption $propertiesName $serviceAvailable $virtual $localSettingsJson $globalSettingsJson
    if ($null -ne $result)
    {
        return $result
    }

    return $defaultValue
}

function Get-NowOptionStr(
    [string] $propertiesName,
    [bool] $serviceAvailable,
    [bool] $virtual,
    [string] $defaultValue,
    [PSCustomObject] $localSettingsJson,
    [PSCustomObject] $globalSettingsJson
)
{
    $result = Get-GenericOption $propertiesName $serviceAvailable $virtual $localSettingsJson $globalSettingsJson
    if ($null -ne $result)
    {
        return $result
    }

    return $defaultValue
}

function Get-NowOptionBool(
    [string] $propertiesName,
    [bool] $serviceAvailable,
    [bool] $virtual,
    [bool] $defaultValue,
    [PSCustomObject] $localSettingsJson,
    [PSCustomObject] $globalSettingsJson
)
{
    $result = Get-GenericOption $propertiesName $serviceAvailable $virtual $localSettingsJson $globalSettingsJson
    if ($null -ne $result)
    {
        return $result
    }

    return $defaultValue
}

function Get-GenericOption(
    [string] $propertiesName,
    [bool] $serviceAvailable,
    [bool] $virtual,
    [PSCustomObject] $localSettingsJson,
    [PSCustomObject] $globalSettingsJson
)
{
    $newPropertieNameGlobal = $globalSettingsJson;
    $newPropertieNameLocal = $localSettingsJson;
    if ($null -ne $globalSettingsJson)
    {
        $splitedValues =  $propertiesName.Split('.');
        
        foreach($split in $splitedValues)
        {
            $newPropertieNameGlobal = $newPropertieNameGlobal.$split
        }
    }
    if ($null -ne $localSettingsJson)
    {
        $splitedValues =  $propertiesName.Split('.');
        
        foreach($split in $splitedValues)
        {
            $newPropertieNameLocal = $newPropertieNameLocal.$split
        }
    }

    if ($serviceAvailable -And $virtual -And $newPropertieNameGlobal)
    {
        return $newPropertieNameGlobal
    }
    if ($newPropertieNameLocal)
    {
        return $newPropertieNameLocal
    }
}

Export-ModuleMember -Function Set-WaykNowConfig, Get-WaykNowConfig
