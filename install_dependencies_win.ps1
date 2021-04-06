# install depdencies

if ($PSVersionTable.PSVersion.Major -lt 5)
{
    Write-Warning "Run this script with Powershell 5. It comes with WMF5 & .Net 4.5"
    Break
}

$wc = New-Object System.Net.WebClient

# add path to user path if not already in path
function Add-Path ($newPath) {
    $userPath=[Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$newPath*") {
        $userPath += if ($userPath) { ";$newPath" } else { "$newPath" }
        [Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
    }
    if ($env:PATH -notlike "*$newPath*") {
        $env:PATH += ";$newPath"
    }
}

# add $VarName variable with value $VarVal to env and persist it to user 
function Add-Env($VarName, $VarVal) {
    Set-Item "env:$VarName" $VarVal
    [Environment]::SetEnvironmentVariable("$VarName", $VarVal, "User")
}

Write-Host "Install started..." -fore cyan

$env:HTTP_PROXY="http://proxy.wdf.sap.corp:8080"
$env:HTTPS_PROXY=$env:HTTP_PROXY
$env:NO_PROXY="localhost"

# configure repositories
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Get-Packageprovider -Name chocolatey
Set-PackageSource -Name Chocolatey -Trusted

#Install-Module posh-p4 -Scope CurrentUser

# Install Python

Install-Package python -RequiredVersion 2.7.11 -ProviderName Chocolatey
Install-Package python -RequiredVersion 3.6.1 -ProviderName Chocolatey

Add-Path "C:\Python"
Add-Path "C:\Python\Scripts\"
Add-Env PYTHON2_EXE "C:\Python27\python.exe"

# Install jdk7

$source = "http://moo-repo.wdf.sap.corp:8080/static/monsoon/jdk/jdk-7u79-windows-x64.exe"
$archive = Join-Path $env:TEMP ($source.substring($source.lastindexOf('/') + 1))
$wc.DownloadFile($source, $archive)
echo "downloaded at: $archive"

Start-Process $archive -ArgumentList @(, "/s") -Wait
ri $archive
Add-Env JAVA_HOME (gci "C:\Program Files\Java" -Filter "*1.7*" | sort -Descending | select -First 1).FullName
Add-Path "$env:JAVA_HOME"

#Install git
Install-Package git -RequiredVersion 1.9.5 -ProviderName Chocolatey -ForceX86
Add-Path "C:\Program Files (x86)\Git\cmd"
Add-Path "C:\Program Files (x86)\usr\bin"

Install-Module posh-git -Scope CurrentUser

git config --global http.sslVerify false
git config --global core.autocrlf true

# Install 7zip

Install-Package 7zip.install -ProviderName Chocolatey -RequiredVersion 16.02.0.20160811
$env:PATH+=";C:\Program Files\7-Zip"

# install maven

$installPath = "C:"
$source = "http://apache.crihan.fr/dist/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.tar.gz"
$archive = Join-Path $env:TEMP ($source.substring($source.lastindexOf('/') + 1))

$wc.DownloadFile($source, $archive)

echo "downloaded at: $archive"

7z e $archive "-o$env:TEMP" -y
$tarArchive= $archive.substring(0, $archive.LastIndexOf('.'))
7z x -aoa -y $tarArchive "-o$installPath"

ri $tarArchive
ri $archive

Add-Env M2_HOME "C:\apache-maven-3.1.1"
Add-Env MAVEN_OPTS "-XX:PermSize=512m -XX:MaxPermSize=512m -Xms2g -Xmx2g"
Add-Path (Join-Path $env:M2_HOME 'bin')

# configure maven

#$source = ""
$mavenSettings = Join-Path $env:USERPROFILE ".m2"

New-Item -Force $mavenSettings -itemtype directory
$file = Join-Path $mavenSettings "settings.xml"

#echo "download at: $file"
#$wc.DownloadFile($source, $archive)

# install tomcat

$installPath = "C:"
$source = "http://apache.crihan.fr/dist/tomcat/tomcat-7/v7.0.77/bin/apache-tomcat-7.0.77-windows-x64.zip"
$archive = Join-Path $env:TEMP ($source.substring($source.lastindexOf('/') + 1))

$wc.DownloadFile($source, $archive)

echo "downloaded at: $archive"

mkdir $installPath -ErrorAction SilentlyContinue
7z x -aoa -y $archive "-o$installPath"

ri $archive

Add-Env CATALINA_HOME "C:\apache-tomcat-7.0.77"

# Install browsers

Install-Package googlechrome -ProviderName Chocolatey

# Install nodejs

$source = "https://github.com/coreybutler/nvm-windows/releases/download/1.1.3/nvm-setup.zip"
$archive = Join-Path $env:TEMP ($source.substring($source.lastindexOf('/') + 1))

$wc.DownloadFile($source, $archive)

echo "downloaded at: $archive"

7z x -aoa -y $archive "-o$env:TEMP"

$uninstallScript = (Join-Path $PSScriptRoot uninstall_cmdline.ps1)
&$uninstallScript -software "NVM for Windows*" | Out-Null

$nvmSetup = Join-Path $env:TEMP "nvm-setup.exe"
Start-Process $nvmSetup -ArgumentList @("/SILENT", "/SP-", "/SUPPRESSMSGBOXES") -Wait
ri $archive
ri $nvmSetup

$localNvmPath = Join-Path $env:APPDATA "nvm"
$defaultNodejsPath = "C:\Program Files\nodejs"
Add-Path $localNvmPath
Add-Env NVM_HOME $localNvmPath
ri $defaultNodejsPath -ErrorAction SilentlyContinue -Recurse -Force
nvm root $env:NVM_HOME
nvm install 4.5.0
nvm use 4.5.0
#create manually symlink if problem with nvm use, see https://github.com/coreybutler/nvm-windows/issues/266
$nodePath = Join-Path $localNvmPath "v4.5.0"
if ((-Not (Test-Path $nodePath) -or (-Not (Test-Path $defaultNodejsPath))))
{
    Start-Process powershell -Verb runAs -ArgumentList "-WindowStyle Hidden", "-Command `"&{ New-Item -Path `'$defaultNodejsPath`' -Value `'$nodePath`' -ItemType SymbolicLink }`"" -Wait -WindowStyle Hidden
}
Start-Sleep -s 3
Add-Path $defaultNodejsPath
Add-Path (Join-Path $env:APPDATA "npm")

$env:HTTP_PROXY=""
$env:HTTPS_PROXY=$env:HTTP_PROXY
$env:NO_PROXY=""
npm config rm proxy
npm config rm https-proxy

npm install -g wpm karma-cli gulp-cli webpack
Install-Package yarn -ProviderName Chocolatey

# Env

Write-Host "Set environment..." -fore cyan

Write-Host "Activate display of hidden files and hidden file extensions"
#see file extensions in Windows Explorer. Note: wont take effect on dekstop because need of refresh
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0
#see hidden files and folders
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

$PsFolder = Split-Path -Path $PROFILE
New-Item $PsFolder -Type directory -ErrorAction SilentlyContinue
$profileContent = gc $profile -ErrorAction SilentlyContinue
if (-Not [bool]($profileContent -like "*global:prompt*"))
{
'
function global:prompt {
    $realLASTEXITCODE = $LASTEXITCODE

    #git status
    Write-VcsStatus

    $global:LASTEXITCODE = $realLASTEXITCODE

    #override window title with current folder
    $AdminTxt = if ($isAdmin) { "Administrator: " } else { "" }
    $Host.UI.RawUI.WindowTitle = [string]::Format("{0}{1} - Windows Powershell", $AdminTxt, $pwd)
    
    $promptColor = if ($isAdmin) { "magenta" } else { "white" }
    Write-Host "$" -fore $promptColor -nonewline
    return " "
}
' >> $profile
}

if (-Not [bool]($profileContent -like "*SshAgent*"))
{
'
$r = Get-SshAgent
if ($r -eq 0)
{
    Start-SshAgent -Quiet
    gci ~/.ssh/ -exclude "*.pub","*.pem","known_hosts","config" | % { Add-SshKey $_.Fullname }
}
' >> $profile
}

Write-Host "script is restarting explorer to force env to be loaded"
$elementRunning = Get-Process "explorer"
if ($elementRunning)
{
    if ($elementRunning -isnot [system.array]) { $elementRunning = @($elementRunning) }

    $elementRunning | % { Stop-Process $_.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host "Finished" -fore blue
