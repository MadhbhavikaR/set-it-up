# Take care of the legal stuff here

function Show-Legal {
    $license = Get-Content -Raw .\utils\resources\license;
    $disclaimer = Get-Content -Raw .\utils\resources\disclaimer;

    Show-Header;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Licence Agreement";
    Write-Host $license -ForegroundColor Yellow;
    Write-Host "";
    Pause;

    Show-Header;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Disclaimer";
    Write-Host $disclaimer -ForegroundColor Red;
    Write-Host "";
    Pause;
    Write-Host "";
    Write-Host "We assume you have read the Disclaimer before proceeding, press 'Ctrl+c'to abort..." -ForegroundColor Yellow;
    Write-Host "";
    Pause;

}

function Show-Header {
    Clear-Host;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Setup";
    $header = Get-Content -Raw .\utils\resources\header;
    Write-Host $header -ForegroundColor Green;
}

export-modulemember -function Show-Legal; 
export-modulemember -function Show-Header; 