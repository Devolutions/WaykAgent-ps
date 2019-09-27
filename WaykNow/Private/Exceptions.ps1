class RunAsAdministratorException : System.ApplicationException
{
    RunAsAdministratorException():base("You need to run as administrator to call this function")
    {
    }
}