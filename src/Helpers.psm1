Import-Module (Join-Path $PSScriptRoot 'Variables.psm1')

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
        $mess = ($Message | Format-Table -HideTableHeaders -AutoSize | Out-String).Trim() -split "`n"
        Write-Host ($mess | ForEach-Object { "`n    $_" })
    }

    Write-Host ''
}

function Get-EnvironmentVariables {
    <#
    .SYNOPSIS
        List all environment variables. Mainly debug purpose.
    #>
    return Get-ChildItem env: | Where-Object { $_.Name -ne 'GITHUB_TOKEN' }
}

function New-Array {
    <#
    .SYNOPSIS
        Create new Array list. More suitable for usage as it provides better operations.
    #>

    return New-Object System.Collections.ArrayList
}

function Add-IntoArray {
    <#
    .SYNOPSIS
        Append list with given item.
    .PARAMETER List
        List to be expanded.
    .PARAMETER Item
        Item to be added into list.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList] $List,
        [System.Object] $Item
    )

    $List.Add($Item) | Out-Null
}

function Expand-Property {
    <#
    .SYNOPSIS
        Shortcut for expanding property of object.
    .PARAMETER Object
        Base object.
    .PARAMETER Property
        Property to be expanded.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Hashtable] $Object,
        [Parameter(Mandatory)]
        [String] $Property
    )

    return $Object | Select-Object -ExpandProperty $Property
}

function Initialize-NeededSettings {
    <#
    .SYNOPSIS
        Initialize all settings, environment so everything work as expected.
    #>
    @('buckets', 'cache') | ForEach-Object { New-Item "$env:SCOOP/$_" -Force -ItemType Directory | Out-Null }
    git config --global user.name ($env:GITHUB_REPOSITORY -split '/')[0]
    if ($env:GITH_EMAIL) {
        git config --global user.email $env:GITH_EMAIL
    } else {
        Write-Log 'Pushing is not possible without email environment'
    }

    # Log all environment variables
    Write-Log 'Environment' (Get-EnvironmentVariables)
}

function Get-Manifest {
    <#
    .SYNOPSIS
        Parse manifest and return it's path and object representation.
    .PARAMETER Name
        Name of manifest to parse.
    #>
    param([Parameter(Mandatory)][String] $Name)

    $gciItem = Get-Childitem $MANIFESTS_LOCATION "$Name.*" | Select-Object -First 1
    $manifest = Get-Content $gciItem.Fullname -Raw | ConvertFrom-Json

    return $gciItem, $manifest
}

function New-DetailsCommentString {
    <#
    .SYNOPSIS
        Create string surrounded with <details>.
    .PARAMETER Summary
        What should be displayed on expand button.
    .PARAMETER Content
        Content of details block.
    .PARAMETER Type
        Type of code fenced block (json, yml, ...).
        Needs to be valid markdown code fenced block type.
    #>
    param([Parameter(Mandatory)][String] $Summary, [String[]] $Content, [String] $Type = 'text')

    return @"
<details>
<summary>$Summary</summary>

``````$Type
$($Content -join "`r`n")
</details>
``````
"@
}

Export-ModuleMember -Function Write-Log, Get-EnvironmentVariables, New-Array, Add-IntoArray, Initialize-NeededSettings, `
    Expand-Property, Get-Manifest, New-DetailsCommentString
