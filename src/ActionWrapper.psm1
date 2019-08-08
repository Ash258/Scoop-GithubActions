Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module
Get-ChildItem $PSScriptRoot 'Action\*.psm1' -File | Select-Object -ExpandProperty Fullname | Import-Module

function Invoke-Action {
    switch ($EVENT_TYPE) {
        'issues' { Initialize-Issue }
        'pull_request' { Initialize-PR }
        'issue_comment' { Initialize-PR }
        'schedule' { Initialize-Scheduled }
        default { Write-Log 'Not supported event type' }
    }
}

Export-ModuleMember -Function Invoke-Action
