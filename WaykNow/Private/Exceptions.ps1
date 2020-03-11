class RunAsAdministratorException : System.ApplicationException
{
    RunAsAdministratorException():base("You need to run as administrator to call this function")
    {
    }
}

class IncorrectPath : System.ApplicationException
{
    IncorrectPath():base("The path does not exist")
    {
    }
}

class UnsupportedPlatformException : System.ApplicationException
{
    UnsupportedPlatformException([string] $supportedPlatform):base("This feature is only supported on $supportedPlatform")
    {
    }
}

class SoftwareRequired : System.ApplicationException
{
    SoftwareRequired([string] $softwareRequired, [string] $downloadUrl):base("This software is required $softwareRequired, you can download at $downloadUrl")
    {
    }
}

class IncorrectFormat : System.ApplicationException
{
    IncorrectFormat([string] $actualFormat, $requiredFormat):base("The format $actualFormat is incompatible, the required format is $requiredFormat")
    {
    }
}

class NotConnectedException : System.ApplicationException
{
    NotConnectedException():base("You are not connected yet, use Connect-WaykNowDen")
    {
    }
}

class UnattendedNotFound : System.ApplicationException
{
    UnattendedNotFound():base("WaykNow unattended mode is not installed")
    {
    }
}