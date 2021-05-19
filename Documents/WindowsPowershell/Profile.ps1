# Powershell profile
#    Zougi.

Import-Module PsColor
#Import-Module posh-git
#Import-Module posh-docker

function Call-Sublime { &"G:\Sublime Text 3\sublime_text.exe" $args }
New-Alias subl Call-Sublime

#New-Alias git hub

function Call-Elevate { Start-Process powershell -Verb runAs -ArgumentList @( "-nologo", "-noprofile", "-noexit", ".", "$profile", ";", "cd", "$pwd") }
New-Alias elevate Call-Elevate

$WindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

function global:prompt {

    $realLASTEXITCODE = $LASTEXITCODE

    #override window title with current folder
    $AdminTxt = if ($isAdmin) { "Administrator: " } else { "" }
    $Host.UI.RawUI.WindowTitle = [string]::Format("{0}{1} - Windows Powershell", $AdminTxt, $pwd)

    $promptColor = if ($isAdmin) { "magenta" } else { "white" }
    Write-Host ("%" + (get-item $pwd).Name) -fore "white" -nonewline
    #git status
    Write-VcsStatus
    Write-Host "$" -fore $promptColor -nonewline

    $global:LASTEXITCODE = $realLASTEXITCODE

    return " "
}
[int]$agentPid = Get-SshAgent
if ($agentPid -eq 0) {
    echo "start ssh-agent"
    Start-SshAgent -Quiet

    echo "add ssh keys"
    # bruteforce ssh authentication with the keys in .ssh
    # ugly: configure key from .ssh/config is the standard, but this one is handy
    gci ~/.ssh/ -exclude "*.pub","*.pem","known_hosts","config" | % { Add-SshKey $_.Fullname }
}

function Set-WorkingDirectory {
    param(
        $path
    )
    if ($path -eq $null) {
        $path = "~"
    }
    Set-Location $path
    if ((Test-Path $path) -And ($path -NotMatch '^[a-zA-Z][a-zA-Z]+:')) {
        $path = (Resolve-Path $path).toString().Replace("Microsoft.PowerShell.Core\FileSystem::", "")
        [System.IO.Directory]::SetCurrentDirectory($path)
    }
}
Set-WorkingDirectory $pwd
# change process working directory when cd. Useful with consoleZ "clone in new tab"
Remove-Item alias:\cd
New-Alias cd Set-WorkingDirectory

# Brighter colors for git prompt
$s = $global:GitPromptSettings
$s.LocalDefaultStatusForegroundColor = $s.LocalDefaultStatusForegroundBrightColor
$s.LocalWorkingStatusForegroundColor = $s.LocalWorkingStatusForegroundBrightColor
$s.BeforeIndexForegroundColor = $s.BeforeIndexForegroundBrightColor
$s.IndexForegroundColor = $s.IndexForegroundBrightColor
$s.WorkingForegroundColor = $s.WorkingForegroundBrightColor

$env:NODE_ENV = "dev"
Set-PSReadlineOption -BellStyle None