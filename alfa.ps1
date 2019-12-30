
function Write-Log {
    <#
    .SYNOPSIS
        Persist message in docker log. For debug mainly. Write-Host is more suitable because then write-log is not interfering with pipes.
    .PARAMETER Summary
        Header of log.
    .PARAMETER Message
        Array of objects to be saved into docker log.
    #>
    param(
        [String] $Summary = '',
        [Parameter(ValueFromPipeline)]
        [Object[]] $Message
    )

    # If it is only summary it is informative log
    if ($Summary -and ($null -eq $Message)) {
        Write-Host "INFO: $Summary"
    } elseif (($Message.Count -eq 1) -and ($Message[0] -isnot [Hashtable])) {
        # Simple non hashtable object and summary should be one liner
        Write-Host "${Summary}: $Message"
    } else {
        # Detailed output using format table
        Write-Host "Log of ${Summary}:"
        $mess = (($Message | Format-Table -HideTableHeaders -AutoSize | Out-String).Trim()) -split "`r`n"
        Write-Host ($mess | ForEach-Object { "`n    $_" })
    }

    Write-Host ''
}

function Get-EnvironmentVariables {
    <#
    .SYNOPSIS
        List all environment variables. Mainly debug purpose.
        Do not leak GITHUB_TOKEN.
    #>
    return Get-ChildItem env: | Where-Object { (($_.Name -ne 'GITHUB_TOKEN') -and ($_.Name -notlike 'ACTIONS_*')) -and ($_.Name -ne 'SSH_KEY') }
}

Write-Log 'env' (Get-EnvironmentVariables)

((Get-EnvironmentVariables) -split "`n").Count
