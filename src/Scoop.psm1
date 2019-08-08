Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Initialize-MockedFunctionsFromCore {
    # Remove functions
    $FUNCTIONS_TO_BE_REMOVED | ForEach-Object { Remove-Item function:$_ -Force }

    # Declare new one with same parameter list and same output type in global scope
    function global:Get-AppFilePath {
        param ([String] $App = 'Aria2', [String] $File = 'aria2c')

        return which $File
    }

    function global:Get-HelperPath {
        param([String] $Helper)

        switch ($Helper) {
            'Aria2' {
                return Get-AppFilePath 'Aria2' 'aria2c'
            }
        }
    }
}

Export-ModuleMember -Function Initialize-MockedFunctionsFromCore
