Import-Module $psScriptRoot\preRequisites.psm1;
Import-Module $psScriptRoot\docker.psm1;
Import-Module $psScriptRoot\git.psm1;

function Install-PrerequisiteSoftwares {
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Pre-requisite check";
    Initialize-SoftwarePrerequisites;
}

function Test-RunningAsAdmin {
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Check UAC";
    # Get the ID and security principal of the current user account
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID);

    # Get the security principal for the Administrator role
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole)) {
        # We are running "as Administrator" - so change the title and background color to indicate this
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
        $Host.UI.RawUI.BackgroundColor = "DarkBlue";
        Write-Host "";
        Write-Host "This script should not be run as Admin" -ForegroundColor Red;
        Write-Host "This Script will now terminate..." -ForegroundColor Red;
        Write-Host "";
        Pause;
        exit;
    }
}

function Get-CommandPath {
    param (
        [Parameter(Mandatory = $true)]
        $cmd
    ) 
    return get-command $cmd | % { $_.Path } ;
}

export-modulemember -function Install-PrerequisiteSoftwares;
export-modulemember -function Test-RunningAsAdmin;
export-modulemember -function Initialize-CheckoutFolders; 
export-modulemember -function Set-Docker-Prerequisites;
export-modulemember -function Get-Restarted;
export-modulemember -function Get-CommandPath;