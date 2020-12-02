Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Install-Scoop {
    <#
    .SYNOPSIS
        Install scoop using new installer.
        Switch to shovel if desired.
    #>
    Write-Log 'Installing scoop'
    $f = Join-Path $env:USERPROFILE 'install.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -UseBasicParsing -OutFile $f
    & $f -RunAsAdmin
    if ($env:SHOVEL) {
        Write-Log 'Switching to Shovel'
        scoop config 'SCOOP_REPO' 'https://github.com/Ash258/Scoop-Core.git'
        scoop update
    }

    if ($env:SCOOP_BRANCH) {
        scoop config 'SCOOP_BRANCH' $env:SCOOP_BRANCH
        scoop update
    }
}

Export-ModuleMember -Function Install-Scoop
