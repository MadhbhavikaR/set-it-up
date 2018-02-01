Clear-Host;
Import-Module $psScriptRoot\utils\modules\legal.psm1;
Import-Module $psScriptRoot\utils\modules\functions.psm1;

Test-RunningAsAdmin;
Show-Legal;
Show-Header;

$restartFlag = Get-Restarted;

if(-NOT (Test-Path $restartFlag)){
    # Set-DockerPrerequisites;
    Install-PrerequisiteSoftwares;
} else {
    Write-Host "For clearing the restart required flag for this setup on this system requires elevation, please provide the appropriate approval. Setup will continue once the software is installed...";
    $title = $host.ui.RawUI.WindowTitle;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for other process...";
    
    Start-Process -FilePath "powershell.exe" -ArgumentList "&{
        Remove-Item -Path $restartFlag;
    }" -Verb runas -Wait;
    $host.ui.RawUI.WindowTitle = "$title";
}
Show-Header;
Initialize-CheckoutFolders;
Write-Host "";
Pause;