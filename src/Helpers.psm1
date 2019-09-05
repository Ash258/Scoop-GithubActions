Join-Path $PSScriptRoot 'Variables.psm1' | Import-Module

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
        Do not leak GITHUB_TOKEN.
    #>
    return Get-ChildItem env: | Where-Object { ($_.Name -ne 'GITHUB_TOKEN') -and ($_.Name -ne 'SSH_KEY') }
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
        [Object] $Object,
        [Parameter(Mandatory)]
        [String] $Property
    )

    return $Object | Select-Object -ExpandProperty $Property
}

function Initialize-NeededSettings {
    <#
    .SYNOPSIS
        Initialize all settings, environment, configurations to work as expected.
    #>
    @('buckets', 'cache') | ForEach-Object { New-Item (Join-Path $env:SCOOP $_) -Force -ItemType Directory | Out-Null }

    if ($env:GITH_EMAIL) {
        git config --global user.email $env:GITH_EMAIL
    } else {
        Write-Log 'Pushing is not possible without email environment'
    }

    $user = ($env:GITHUB_REPOSITORY -split '/')[0]
    git config --global user.name $user
    # # TODO: Organization will work?
    # $rem = "https://${user}:$env:GITHUB_TOKEN@github.com/$env:GITHUB_REPOSITORY.git"
    # git remote 'set-url' --push origin $rem

    if (-not $env:HUB_VERBOSE) {
        $env:HUB_VERBOSE = '1'
        [System.Environment]::SetEnvironmentVariable('HUB_VERBOSE', $env:HUB_VERBOSE, 'Machine')
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

    # It should alwyas be one item. Just in case use -First
    $gciItem = Get-Childitem $MANIFESTS_LOCATION "$Name.*" | Select-Object -First 1
    $manifest = Get-Content $gciItem.Fullname -Raw | ConvertFrom-Json

    return $gciItem, $manifest
}

function New-DetailsCommentString {
    <#
    .SYNOPSIS
        Create code fenced block surrounded with <details>.
    .PARAMETER Summary
        Text of expand button.
    .PARAMETER Content
        Content of code fenced block.
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
``````
</details>
"@
}

function New-CheckListItem {
    <#
    .SYNOPSIS
        Create markdown check list item.
    .PARAMETER Item
        Name of list item.
    .PARAMETER OK
        Item will be marked as done.
    .PARAMETER IndentLevel
        Indentation level of item. Used for nested lists.
    .PARAMETER Simple
        Simple list item will be used instead of check list.
    #>
    param ([Parameter(Mandatory)][String] $Item, [Int] $IndentLevel = 0, [Switch] $OK, [Switch] $Simple)

    $ind = ' ' * 4 * $IndentLevel
    $char = if ($OK) { 'x' } else { ' ' }
    $check = if ($Simple) { '' } else { "[$char] " }

    return "$ind- $check$Item"
}

function Test-NestedBucket {
    <#
    .SYNOPSIS
        Test if bucket contains nested `bucket` folder.
        Buckets should contain nested folder for many reasons and in Actions main reason is to keep location checks low.
        Open new issue and exit with non zero exit code otherwise.
    #>

    if (Test-Path $MANIFESTS_LOCATION) {
        Write-Log 'Bucket contains nested bucket folder'
    } else {
        Write-Log 'Buckets without nested bucket folder are not supported.'

        $adopt = 'Adopt nested bucket structure'
        # Get opened issues
        $req = Invoke-GithubRequest "repos/$REPOSITORY/issues?state=open"
        # Filter issues with $adopt name
        $issues = ConvertFrom-Json $req.Content | Where-Object { $_.title -eq $adopt }

        if ($issues -and ($issues.Count -gt 0)) {
            Write-Log 'Issue already exists'
        } else {
            New-Issue -Title $adopt -Body @(
                'Buckets without nested `bucket` folder are not supported. You will not be able to use actions without it.',
                '',
                'See <https://github.com/Ash258/GenericBucket> for the most optimal bucket structure.'
            )
        }

        exit $NON_ZERO
    }
}

function Resolve-IssueTitle {
    <#
    .SYNOPSIS
        Parse issue title and return manifest name, version and problem.
    .PARAMETER Title
        Title to be parsed.
    .EXAMPLE
        Resolve-IssueTitle 'recuva@2.4: hash check failed'
    #>
    param([Parameter(Mandatory)][String] $Title)

    $result = $Title -match '(?<name>.+)@(?<version>.+):\s*(?<problem>.*)$'

    if ($result) {
        return $Matches.name, $Matches.version, $Matches.problem
    } else {
        return $null, $null, $null
    }
}

Export-ModuleMember -Function Write-Log, Get-EnvironmentVariables, New-Array, Add-IntoArray, Initialize-NeededSettings, `
    Expand-Property, Get-Manifest, New-DetailsCommentString, New-CheckListItem, Test-NestedBucket, Resolve-IssueTitle
