. "$PSScriptRoot/../Private/Invoke-Process.ps1"

enum ControlMode 
{
    AllRemoteControlMode = 0
    TakeRemoteControlClientOnly = 1
    AllowRemoteControlSeverOnly = 2
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

function Set-WaykNowConfig
(
    # Use global config file rather than user config file.
    [System.Nullable[bool]] $Global,

    # General
    [string] $FriendlyName,
    [string] $Language,
    [ControlMode] $ControlMode,
    [System.Nullable[bool]] $AutoLaunchOnUserLogon,
    [System.Nullable[bool]] $ShowMainWindowOnLaunch,
    [System.Nullable[bool]] $MinimizeToNotificationArea,
    [System.Nullable[bool]] $ElevationPrompt,

    # Security
    [System.Nullable[bool]] $AllowPersonalPassword,
    [System.Nullable[bool]] $AllowSystemAuth,
    [System.Nullable[bool]] $AllowNoPassword,
    [PersonalPasswordType]  $PersonalPasswordType,
    [string] $PersonalPassword,
    [int32] $GeneratedPasswordLength,
    [GeneratedPasswordCharSet] $GeneratedPasswordCharSet,

    # Connectivity
    [System.Nullable[bool]] $DenEnabled,
    [string] $DenUrl,

    # Advanced
    [QualityMode] $QualityMode,
    [LoggingLevel] $LoggingLevel,
    [string] $LoggingFilter,

    # Access Control
    [AccessControl] $AccessControlViewing,
    [AccessControl] $AccessControlInteract,
    [AccessControl] $AccessControlClipboard,
    [AccessControl] $AccessControlFileTransfer,
    [AccessControl] $AccessControlExec,
    [AccessControl] $AccessControlChat
)
{
    $config_file_path = ''
    if (Get-IsWindows) {
		$config_file_path = '%ProgramFiles%\Devolutions\Wayk Now\WaykNow.exe'
	} 
    elseif ($IsMacOS) {
		$config_file_path = '/Applications/WaykNow.app/Contents/MacOS/WaykNow'
	} 
    elseif ($IsLinux) {
		$config_file_path = '/usr/bin/wayk-now'
    }
    
    $globalOption = '';
    if($Global -ne $null) {
        $globalOption =  '--global';
    }

    # General
    if($FriendlyName) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<str>', 'FriendlyName', $FriendlyName) -Wait
    }

    if($Language) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<str>', 'Language', $Language) -Wait
    }

    if($null -ne $ControlMode) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'ControlMode', [int]$ControlMode) -Wait
    }

    if($AutoLaunchOnUserLogon -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'AutoLaunchOnUserLogon', $AutoLaunchOnUserLogon) -Wait
    }

    if($ShowMainWindowOnLaunch -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'ShowMainWindowOnLaunch', $ShowMainWindowOnLaunch) -Wait
    }

    if($MinimizeToNotificationArea -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'MinimizeToNotificationArea', $MinimizeToNotificationArea) -Wait
    }

    if($ElevationPrompt -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'ElevationPrompt', $ElevationPrompt) -Wait
    }

    # Security
    if($AllowPersonalPassword -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'AllowPersonalPassword', $AllowPersonalPassword) -Wait
    }

    if($AllowSystemAuth -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'AllowSystemAuth', $AllowSystemAuth) -Wait
    }

    if($AllowNoPassword -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'AllowNoPassword', $AllowNoPassword) -Wait
    }

    if($null -ne $PersonalPasswordType) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'PersonalPasswordType', [int]$PersonalPasswordType) -Wait
    }

    if($PersonalPassword) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<str>', 'PersonalPassword', $PersonalPassword) -Wait
    }

    if($GeneratedPasswordLength) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'GeneratedPasswordLength', $GeneratedPasswordLength) -Wait
    }

    if($null -ne $GeneratedPasswordCharSet) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'GeneratedPasswordCharSet', [int]$GeneratedPasswordCharSet) -Wait
    }

    # Connectivity
    if($DenEnabled -ne $null) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<bool>', 'DenEnabled', $DenEnabled) -Wait
    }

    if($DenUrl) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<str>', 'DenUrl', $DenUrl) -Wait
    }

    #Advanced
    if($null -ne $QualityMode) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'QualityMode', [int]$QualityMode) -Wait
    }

    if($null -ne $LoggingLevel) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'LoggingLevel', [int]$LoggingLevel) -Wait
    }

    if($LoggingFilter) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<str>', 'LoggingFilter', $LoggingFilter) -Wait
    }

    #Access Control
    if($null -ne $AccessControlViewing) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.Viewing', [int]$AccessControlViewing) -Wait
    }

    if($null -ne $AccessControlInteract) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.Interact', [int]$AccessControlInteract) -Wait
    }

    if($null -ne $AccessControlClipboard) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.Clipboard', [int]$AccessControlClipboard) -Wait
    }

    if($null -ne $AccessControlFileTransfer) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.FileTransfer', [int]$AccessControlFileTransfer) -Wait
    }

    if($null -ne $AccessControlExec) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.Exec', [int]$AccessControlExec) -Wait
    }

    if($null -ne $AccessControlChat) {
        Start-Process $config_file_path -ArgumentList @('config', $globalOption, '--type<int>', 'AccessControl.Chat', [int]$AccessControlChat) -Wait
    }
}

Export-ModuleMember -Function Set-WaykNowConfig