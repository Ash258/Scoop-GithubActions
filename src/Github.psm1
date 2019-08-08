Join-Path $PSScriptRoot 'Helpers.psm1' | Import-Module

function Invoke-GithubRequest {
    <#
    .SYNOPSIS
        Invoke authenticated github API request.
    .PARAMETER Query
        Query to be executed.
    .PARAMETER Method
        Method to be used with request.
    .PARAMETER Body
        Additional body to be send.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Query,
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = 'Get',
        [Hashtable] $Body
    )

    $api_base_url = 'https://api.github.com'
    $parameters = @{
        'Headers' = @{
            # Authorization token is neeeded for posting comments and to increase limit of requests
            'Authorization' = "token $env:GITHUB_TOKEN"
        }
        'Method'  = $Method
        'Uri'     = "$api_base_url/$Query"
    }

    if ($Body) { $parameters.Add('Body', (ConvertTo-Json $Body -Depth 8 -Compress)) }

    Write-Log 'Github Request' $parameters
    Write-Log 'Request Body' $parameters.Body

    return Invoke-WebRequest @parameters
}

function Add-Comment {
    <#
    .SYNOPSIS
        Add comment into specific issue / PR.
        https://developer.github.com/v3/issues/comments/
    .PARAMETER ID
        ID of issue / PR.
    .PARAMETER Message
        String or array of string to be send as comment.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Alias('Comment')]
        [String[]] $Message
    )

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/comments" -Method Post -Body @{ 'body' = ($Message -join "`r`n") }
}

function Get-AllChangedFilesInPR {
    <#
    .SYNOPSIS
        Get list of all changed files inside pull request.
        https://developer.github.com/v3/pulls/#list-pull-requests-files
    .PARAMETER ID
        ID of pull request.
    .PARAMETER Filter
        Return only files which are not 'removed'.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [Switch] $Filter
    )

    $files = (Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls/$ID/files").Content | ConvertFrom-Json
    if ($Filter) { $files = $files | Where-Object { $_.status -ne 'removed' } }

    return $files | Select-Object -Property filename, status
}

function New-Issue {
    <#
    .SYNOPSIS
        Create new issue in current repository.
        https://developer.github.com/v3/issues/#create-an-issue
    .PARAMETER Title
        The title of issue.
    .PARAMETER Body
        Issue description.
    .PARAMETER Milestone
        Number of milestone to associate with issue.
        Authenticated user needs push access.
    .PARAMETER Label
        List of labels to be automatically added.
        Authenticated user needs push access.
    .PARAMETER Assignee
        List of user logins to be automatically assigned.
        Authenticated user needs push access.
    #>
    param(
        [Parameter(Mandatory)]
        [String] $Title,
        [String[]] $Body = '',
        [Int] $Milestone,
        [String[]] $Label = @(),
        [String[]] $Assignee = @()
    )

    $params = @{
        'title'     = $Title
        'body'      = ($Body -join "`r`n")
        'labels'    = $Label
        'assignees' = $Assignee
    }
    if ($Milestone) { $params.Add('milestone', $Milestone) }

    return Invoke-GithubRequest "repos/$REPOSITORY/issues" -Method 'Post' -Body $params
}

function Close-Issue {
    <#
    .SYNOPSIS
        Close issue / PR.
        https://developer.github.com/v3/issues/#edit-an-issue
    .PARAMETER ID
        ID of issue / PR.
    #>
    param([Parameter(Mandatory, ValueFromPipeline)][Int] $ID)

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID" -Method Patch -Body @{ 'state' = 'closed' }
}

function Add-Label {
    <#
    .SYNOPSIS
        Add label to issue / PR.
        https://developer.github.com/v3/issues/labels/#add-labels-to-an-issue
    .PARAMETER ID
        Id of issue / PR.
    .PARAMETER Label
        Label to be set.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [ValidateNotNullOrEmpty()] # > Must contains at least one label
        [String[]] $Label
    )

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels" -Method Post -Body @{ 'labels' = $Label }
}

function Remove-Label {
    <#
    .SYNOPSIS
        Remove label from issue / PR.
        https://developer.github.com/v3/issues/labels/#remove-a-label-from-an-issue
    .PARAMETER ID
        ID of issue / PR.
    .PARAMETER Label
        Label to be removed.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Int] $ID,
        [ValidateNotNullOrEmpty()]
        [String[]] $Label
    )

    $responses = New-Array
    $issueLabels = (Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels" | Select-Object -ExpandProperty Content | ConvertFrom-Json).name
    foreach ($lab in $Label) {
        if ($issueLabels -contains $lab) {
            # https://developer.github.com/v3/issues/labels/#list-labels-on-an-issue
            Add-IntoArray $responses (Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels/$label" -Method Delete)
        }
    }

    return $responses
}

Export-ModuleMember -Function Invoke-GithubRequest, Add-Comment, Get-AllChangedFilesInPR, New-Issue, Close-Issue, `
    Add-Label, Remove-Label
