Import-Module $psScriptRoot\connectivity.psm1;
Import-Module $psScriptRoot\functions.psm1;

$Global:PREPEND = "git_";
$Global:SUCCESS = "Successful";
$Global:FAIL = "Failed";
$Global:USER = "";
$Global:PASS = "";

function Initialize-CheckoutFolders {
    $title = $host.ui.RawUI.WindowTitle;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Setting up Repositories...";
    $preRequisiteRepos = Get-Content -Raw -Path $psScriptRoot\..\resources\git.json | ConvertFrom-Json;
    $root = $preRequisiteRepos.baseFolder;
    $ping = $preRequisiteRepos.pingServer;
    $port = $preRequisiteRepos.pingPort;
    # Test-Connectivity $ping;
    Write-Host "";
    Write-Host "Make sure you are connected to Correct network or VPN" -ForegroundColor Yellow;
    Write-Host "";
    Pause;
    Get-Credentials;
    Write-Host "";
    Write-Host "Checking existing repositories..." -ForegroundColor Yellow;
    if (Test-Path $root) {
        Write-Host "  Target Path [$root] for repositories already exist..." -ForegroundColor Red;
    }
    else {
        Write-Host "Setting up folders [$root]..." -ForegroundColor Green;
        New-Item -ItemType Directory $root > $null;
    }
    Write-Host "Cloning required repositories..." -ForegroundColor Yellow;
    foreach ($item in $preRequisiteRepos.checkout) {
        $name = $item.name;
        $url = $item.url -replace "<user>:<password>" , "$($Global:USER):$($Global:PASS)";
        $run = $item.run;
        Get-Repository $root $url $name $run;
    }
    Write-Host "";
    Write-Host "Waiting for repository cloning to complete..."  -ForegroundColor Yellow;
    Write-Host "  Depending on the number of repositories and their download size, the wait may be long." -NoNewline;
    while ((Get-Job | Where-Object {$_.State -eq "Running"} | Where-Object {$_.name -like "$Global:PREPEND*"}).count -gt 0) {
        Start-Sleep -s 3;
        Write-Host "." -NoNewline;
    }
    Write-Host "";
    $host.ui.RawUI.WindowTitle = "$title";
    $wait = $False;
    foreach ($item in $preRequisiteRepos.checkout) {
        $name = $item.name;
        $url = $item.url;
        $run = $item.run;
        ( $result = Receive-Job -Name "$Global:PREPEND$name" ) > $null;
        $status = $result[0];
        $repoName = $result[1];
        $cloned = $result[2];
        # $results = $result[3];
        if ($status -eq $Global:SUCCESS) {
            Write-Host "  Repository download $Global:SUCCESS for $name" -ForegroundColor Green;
        }
        else {
            Write-Host "  Repository download $Global:FAIL for $name" -ForegroundColor Red;
            # foreach ($res in $results) {
            #     Write-Host "    $res" -ForegroundColor Red;
            # }
            Write-Host "    Please clone the repository under $root by following the below commands:" -ForegroundColor Red;
            Write-Host "      cd '$root'" -ForegroundColor Red;
            Write-Host "      git clone '$url'" -ForegroundColor Red;
            if (($run.count) -gt 0) {
                foreach ($command in $run) {
                    Write-Host "      $command" -ForegroundColor Red;
                }
            }
        }
    }
    (Get-Job | Where-Object {$_.name -like "$Global:PREPEND*"}) | Remove-Job;
    Write-Host "";
    if ($wait) {
        $title = $host.ui.RawUI.WindowTitle;
        $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for user manual steps...";
        Write-Host "Setup will wait for you to finish the cloning...";
        Write-Host "";
        Pause;
        $host.ui.RawUI.WindowTitle = "$title";
    }
    Start-Sleep -s 3;
}

function Get-Repository {
    param(
        [Parameter(Mandatory = $true)]
        $destination,
        [Parameter(Mandatory = $true)]
        $url,
        [Parameter(Mandatory = $true)]
        $name,
        [Parameter(Mandatory = $False)]
        $run = @{}
    )
    $repoName = [regex]::match($url, '^.*/(.*)\.git$').Groups[1].Value;
    $needCloning = -NOT (Test-Path $(Join-Path $destination $repoName));
    return Start-Job -Name "$Global:PREPEND$name" -ScriptBlock {
        $gitUrl = $args[0];
        $destination = $args[1];
        $run = $args[2];
        $needCloning = $args[3];
        $repoName = $args[4];
        $cloneDir = Join-Path $destination $repoName;
        # $result = New-Object System.Collections.ArrayList;
        if ($needCloning) {
            $pathToGit = Get-LocationPath git |
            # mintty.exe --Title <title> --class CLASS --dir directory --exec "/usr/bin/bash" --login -i -c "echo 'Hello World!'"
            #  mintty.exe" --Title "Hello World" --class "123" --dir "$destination" --exec "/usr/bin/bash" --login -i -c "git -C $destination clone $gitUrl"
            # $output = Invoke-Expression "git -C $destination clone --quiet $gitUrl";
            # $result.Add($output) > $null;
        }
        if ((Test-Path $cloneDir) -AND ($run.count -gt 0)) {
            foreach ($command in $run) {
                $output = Invoke-Expression "$command";
                # $result.Add($output) > $null;
            }
            # return @("$Global:SUCCESS", "$repoName", $needCloning, $result); 
            return @("$Global:SUCCESS", "$repoName", $needCloning); 
        }
        else {
            # return @("$Global:FAIL", "$repoName", $needCloning, $result); 
            return @("$Global:FAIL", "$repoName", $needCloning); 
        }
    } -ArgumentList $url, $destination, $run, $needCloning, $repoName -erroraction 'silentlycontinue';
}


function Get-Credentials {
    Write-Host "";
    $Global:USER = Read-Host -Prompt "Enter Git username";
    $Global:PASS = Read-Host -AsSecureString -Prompt "Enter Git password";
    $Global:PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Global:PASS));
}

export-modulemember -function Initialize-CheckoutFolders; 