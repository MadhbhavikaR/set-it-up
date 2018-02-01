$Global:DOWNLOAD_FOLDER = "$env:USERPROFILE\Downloads\delete";
$Global:INSTALL_FOLDER = "$env:ProgramData";
$Global:PREPEND = "download_";
$Global:SUCCESS = "Successful";
$Global:FAIL = "Failed";

function Get-FileWCAsynchronous {
    param(
        [Parameter(Mandatory = $true)]
        $target
    )
    $file = $target | Split-Path -Leaf;
    $destination = Join-Path $Global:DOWNLOAD_FOLDER $file;
    if(-NOT (Test-Path $Global:DOWNLOAD_FOLDER)) {
        New-Item -Type Directory "$Global:DOWNLOAD_FOLDER";
    }

    return Start-Job -Name "$Global:PREPEND$file" -ScriptBlock {
        $wc = New-Object Net.WebClient;
        $wc.UseDefaultCredentials = $true;
        $target = $args[0];
        $destination = $args[1];
        $file = $args[2];
        $success = $args[3];
        $fail = $args[4];
        try {
            $wc.DownloadFile($target, $destination);
            Get-Item $destination | Unblock-File;
            return @("$success","$file","$target");
        }  
        catch [System.Net.WebException] {  
            return @("$fail","$file","$target");
        }   
        finally {    
            $wc.Dispose();
        }
    } -ArgumentList $target, $destination, $file, $Global:SUCCESS, $Global:FAIL;
}

<#
Returns true if a program with the specified display name is installed.
This function will check both the regular Uninstall location as well as the
"Wow6432Node" location to ensure that both 32-bit and 64-bit locations are
checked for software installations.

@param String $program The name of the program to check for.
@return Booleam Returns true if a program matching the specified name is installed.
#>
function Test-Installed {
    param(
        [Parameter(Mandatory = $true)]
        $program,
        [Parameter(Mandatory = $true)]
        $command,
        [Parameter(Mandatory = $true)]
        $minVersion
    )
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
            Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
            Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;
    if(-NOT ($x86 -or $x64)){
        try {
            $version = Invoke-Expression $command;
            return -NOT $version -lt $minVersion;
        } catch [System.Exception] {
            return $False; 
        }
    } else {
        return $True;
    }

    return $False;
}

function Test-RequiredSoftwares {
    $urlsList = @{};
    $preRequisiteSoftwares = Get-Content -Raw -Path $psScriptRoot\..\resources\prerequisiteData.json | ConvertFrom-Json;
    $architecture = if ([System.IntPtr]::Size -eq 4) { "32" } else { "64" };
    Write-Host "$architecture bit architecture detected..." -ForegroundColor Yellow;
    foreach ($software in $preRequisiteSoftwares.required) {
        $installed = Test-Installed $software.name $software.command $software.minVersion;
        $name = $software.displayName;
        
        if ($installed -eq $True ) {
            Write-Host "  $name is installed" -ForegroundColor Green;
        }
        else {
            Write-Host "  $name is not installed" -ForegroundColor Red;
            $url = $software.download;
            $type = $software.steps;
            if ($architecture -eq "32") {
                $url = $url.x32;
            }
            else {
                $url = $url.x64;
            }
            $urlsList.Add($url, $type);
        }
    }
    return $urlsList;
}

function Get-Softwares {
    param(
        [Parameter(Mandatory = $true)]
        $requiredSoftwares
    )
    $downloadSuccess = @{};
    $downloadFail = @{};
    $downloadedStatus = @{};

    foreach ($url in $($requiredSoftwares.KEYS.GetEnumerator())) { 
        $type = $requiredSoftwares.$url;
        $requiredSoftwares.Remove($url);
        # Software file name, job Object
        $requiredSoftwares.Set_Item(("$Global:PREPEND$($url | Split-Path -Leaf),$type"), (Get-FileWCAsynchronous $url));
    }

    if ($requiredSoftwares.count -gt 0) {
        Write-Host "";
        Write-Host "Downloading missing prerequisite software..." -ForegroundColor Yellow;
        Write-Host "Waiting for all downloads to complete..."  -ForegroundColor Yellow;
        Write-Host "  Depending on the number of softwares required and their download size, the wait may be long." -NoNewline;
        while ((Get-Job | Where-Object {$_.State -eq "Running"} | Where-Object {$_.name -like "$Global:PREPEND*"}).count -gt 0) {
            Start-Sleep -s 3;
            Write-Host "." -NoNewline;
        }
        Write-Host "";
        foreach ($job in $requiredSoftwares.KEYS.GetEnumerator()) { 
            $output = $job -split ',';
            $jobName = $output[0];
            $type = $output[1];
            $result = Receive-Job -Name $jobName;
            $status = $result[0];
            $file = $result[1];
            $url = $result[2];
            if ($status -eq $Global:SUCCESS) {
                Write-Host "  Download $Global:SUCCESS for $file" -ForegroundColor Green;
                $downloadSuccess.Add($file, $type); 
            }
            else {
                Write-Host "  Download $Global:FAIL for $file" -ForegroundColor Red;
                $downloadFail.Add($file, $type);
            }
        }
        $downloadedStatus.Add($Global:SUCCESS, $downloadSuccess);
        $downloadedStatus.Add($Global:FAIL, $downloadFail);
        (Get-Job | Where-Object {$_.name -like "$Global:PREPEND*"}) | Remove-Job;
        return $downloadedStatus;
    }
}

function Install-Softwares {
    param(
        [Parameter(Mandatory = $true)]
        $downloadedStatus
    )
    foreach ($file in $downloadedStatus.$Global:SUCCESS.KEYS.GetEnumerator()) {
        $stepsList = $downloadedStatus.$Global:SUCCESS.$file -split ' ';
        Write-Host "";
        $filePath = Join-Path $Global:DOWNLOAD_FOLDER $file;
        if ($stepsList -eq "EXE") {
            Write-Host "Installing $file..."  -ForegroundColor Yellow;
            Write-Host "  Please follow the prompts and act accordingly. Setup will continue once the software is installed...";
            $title = $host.ui.RawUI.WindowTitle;
            $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for other process...";
            $pid = Start-Process -FilePath $filePath -Wait;
            $host.ui.RawUI.WindowTitle = "$title";
        } elseif($stepsList[0] -eq "ZIP") {
            $installFolder = Join-Path $Global:INSTALL_FOLDER $stepsList[1];
            $binPath = Join-Path $installFolder $stepsList[2];
            if(Test-Path $installFolder){
                Write-Host "Installing $file..."  -ForegroundColor Yellow;
                Write-Host "  Looks like folder $installFolder already exists..." -ForegroundColor Red;
                Write-Host "  Do you want to Force install? [Y/N] : " -NoNewline;
                $key = $Host.UI.RawUI.ReadKey();
                Write-Host "";
                if( $key.Character -eq 'Y' -or $key.Character -eq 'y' ){
                    Remove-Item -Path $installFolder -Recurse;
                    Install-Zip $filePath;
                }
            } else { 
                Install-Zip $filePath;
            }
        }
    }

    if(Test-Path $Global:DOWNLOAD_FOLDER) {
        Remove-Item -Path $Global:DOWNLOAD_FOLDER -Recurse;
    }
}

function Install-Zip {
    param(
        [Parameter(Mandatory = $true)]
        $filePath
    )
    $file = $filePath | Split-Path -Leaf;
    Add-Type -assembly "system.io.compression.filesystem";
    Write-Host "";
    Write-Host "Extracting $file..."  -ForegroundColor Yellow;
    [io.compression.zipfile]::ExtractToDirectory($filePath, $Global:INSTALL_FOLDER);
    $registry = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment";
    $path=(Get-ItemProperty -Path "$registry" -Name PATH).Path;
    $newPath="$path;$binPath";
    Write-Host "  For setting up the environment variables on this system, the setup requires elevation, please provide the appropriate approval. Setup will continue once the software is installed...";
    $title = $host.ui.RawUI.WindowTitle;
    $host.ui.RawUI.WindowTitle = "Set-it-up! - Waiting for other process...";    
    Start-Process -FilePath "powershell.exe" -ArgumentList "&{ Set-ItemProperty -Path '$registry' -Name PATH -Value '$newPath'; }" -Verb runas -Wait;
    $host.ui.RawUI.WindowTitle = "$title";
}

function Initialize-SoftwarePrerequisites {
    Write-Host "";
    Write-Host "Performing prerequisite software checks..." -ForegroundColor Yellow;
    $downloadedStatus = Get-Softwares($(Test-RequiredSoftwares));
    if($downloadedStatus -ne $Null){
        Install-Softwares($downloadedStatus);
    }
    Start-Sleep -s 3;
}

export-modulemember -function Initialize-SoftwarePrerequisites; 