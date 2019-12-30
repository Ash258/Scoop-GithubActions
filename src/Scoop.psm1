Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Install-Scoop {
    Write-Log 'Installing scoop'
    $f = Join-Path $env:USERPROFILE 'install.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -UseBasicParsing -OutFile $f
    & $f -RunAsAdmin
}

function Initialize-MockedFunctionsFromCore {
    # Remove functions imported from core
    $FUNCTIONS_TO_BE_REMOVED | ForEach-Object { Remove-Item function:$_ -Force }

    # Declare new one with same parameter list and same output type in global scope
    function global:Get-AppFilePath {
        param ([String] $App = 'Aria2', [String] $File = 'aria2c')

        return which $File
    }

    function global:Get-HelperPath {
        param([String] $Helper)

        $path = $null
        switch ($Helper) {
            'Aria2' { $path = Get-AppFilePath 'Aria2' 'aria2c' }
        }

        return $path
    }
}

Export-ModuleMember -Function Install-Scoop, Initialize-MockedFunctionsFromCore
