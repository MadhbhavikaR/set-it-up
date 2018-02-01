function Get-Restarted {
    return (Join-Path $env:ProgramData restart);
}

function Set-Docker-Prerequisites {
    # Invoke-WebRequest "https://github.com/docker/compose/releases/download/1.17.0/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\docker\docker-compose.exe
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Docker";
    Write-Host "";
    Write-Host "Performing prerequisite checks for Docker..." -ForegroundColor Yellow;
    Write-Host "  For setting up the Hyper-V feature on this system, the setup requires elevation, please provide the appropriate approval. Setup will continue once the software is installed...";
    $title = $host.ui.RawUI.WindowTitle;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for other process...";

    Start-Process -FilePath "powershell.exe" -ArgumentList "&{
        `$result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V, Containers -All -NoRestart;
        if(`$result.RestartNeeded -eq `$True){
            New-Item $(Get-Restarted) -ItemType file;
        }
    }" -Verb runas -Wait;
    $host.ui.RawUI.WindowTitle = "$title";
    if(-NOT (Test-Path $(Get-Restarted))){
        Write-Host "";
        Write-Host "Initializing Docker Service...";
        $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for other process...";
        Start-Process -FilePath "powershell.exe" -ArgumentList "&{ Stop-Service com.docker* -Passthru; Start-Service com.docker* -Passthru }" -Verb runas -Wait;
        $host.ui.RawUI.WindowTitle = "$title";
    } else {
        Write-Host "";
        Write-Host "Restart of the OS is required for settings to take effect, Please save any work that needs to be saved before proceeding further..." -ForegroundColor Red;
        Write-Host "";
        Pause;
        Restart-Computer -Confirm;
    }
}

export-modulemember -function Set-Docker-Prerequisites;
export-modulemember -function Get-Restarted;