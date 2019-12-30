Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Install-Scoop {
    $env:SCOOP = Join-Path $env:USERPROFILE 'SCOOP'
    $env:SCOOP_HOME = Join-Path $env:SCOOP 'apps\scoop\current'
    $env:SCOOP_GLOBAL = Join-Path $env:SystemDrive 'SCOOP'
    $env:SCOOP_DEBUG = 1

    [Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
    [Environment]::SetEnvironmentVariable('SCOOP_HOME', $env:SCOOP_HOME, 'User')
    [Environment]::SetEnvironmentVariable('SCOOP_GLOBAL', $env:SCOOP_GLOBAL, 'Machine')
    [Environment]::SetEnvironmentVariable('SCOOP_DEBUG', $env:SCOOP_DEBUG, 'Machine')

    Invoke-WebRequest 'https://raw.githubusercontent.com/scoopinstaller/install/master/install.ps1' -UseBasicParsing | Invoke-Expression
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

Export-ModuleMember -Function Initialize-MockedFunctionsFromCore
