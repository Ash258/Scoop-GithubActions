param (
    [Parameter(Mandatory)]
    [ValidateSet('Issue', 'PR', 'Push', '__TESTS__', 'Scheduled')]
    [String] $Type
)

#region Function pool
function Resolve-IssueTitle {
    <#
    .SYNOPSIS
        Parse issue title and return manifest name, version and problem.
    .PARAMETER Title
        Title to be parsed.
    .EXAMPLE Resolve-IssueTitle 'recuva@2.4: hash check failed'
    #>
    param([String] $Title)

    $result = $Title -match "(?<name>.+)@(?<version>.+):\s*(?<problem>.*)$"

    if ($result) {
        return $Matches.name, $Matches.version, $Matches.problem
    } else {
        return $null, $null, $null
    }
}

# ⬆⬆⬆⬆⬆⬆⬆⬆ OK ⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆








function Invoke-GithubRequest {
    param(
        [String[]] $Body,
        [String] $query,
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method
    )
    $Body = @{
        'body' = $Body -join "`r`n"
    }
    # TODO: handle without body, ...
    return Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $Body -Compress) -Method Post "$API_BASE_URl/repos/$REPOSITORY/issues/5/comments"
}

function Add-Comment {
    <#
    .SYNOPSIS
        Add comment into specific issue / PR
    #>
    param([Int] $ID, [String[]] $Message)
    # TODO:
}

function Add-Label {
    param([Ing] $ID, [String[]] $Labels)

    foreach ($label in $Labels) {
        Write-Log $label
    }
}

function Write-Log {
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    param ([String[]] $Message)
    Write-Output "`r`nLOG: $($Message -join "`r`n    ")"
}

# TODO: Rename?
function Initialize-Issue {
    Write-Log 'Issue initialized'
    # TODO: Test listing of /github/workspace ...

    # Only continue if new issue is created
    if ($EVENT.action -ne 'opened') {
        Write-Log 'Every issues action except ''opened'' are ignored.'
        exit 0
    }
    $envs = [Environment]::GetEnvironmentVariables().Keys
    $table = @()
    $table += '| Name | Value |'
    $table += '| :--- | :--- |'
    $envs | ForEach-Object {
        $table += "| $_ | $([Environment]::GetEnvironmentVariable($_))|"
    }

    $table = $table -join "`r`n"
    Write-Output $table

    $fileCont = Get-Content $env:GITHUB_EVENT_PATH -Raw
    $BODY = @{
        'body' = (@"
Hello from github actions now should be with correct encoding

$table

COntent:

$fileCont
"@)
    }
    # Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $BODY -Depth 8 -Compress) -Method Post "$API_BASE_URl/repos/Ash258/GithubActionsBucketForTesting/issues/5/comments"

}

function Initialize-PR {
    Write-Log 'PR initialized'
}

function Initialize-Push {
	Write-Log 'Push initialized'
}

function Initialize-Scheduled {
    Write-Log 'Scheduled initialized'

    @{
		'body' = @"
Scheduled comment each 5 minute - $(Get-Date)

WORKSPACE
$(Get-ChildItem $env:GITHUB_WORKSPACE)

HOME
$(Get-ChildItem $env:HOME)
"@
    }
    Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json @{ 'body' = "Scheduled comment each 5 minute - $(Get-Date)" }) -Method Post "$API_BASE_URl/repos/$REPOSITORY/issues/7/comments"
}
# endregion Function pool

# For dot sourcing whole file inside tests
if ($Type -eq '__TESTS__') { return }

$API_BASE_URl = 'https://api.github.com'
$API_VERSION = 'v3'
$API_HEADER = "Accept: application/vnd.github.$API_VERSION+json; application/vnd.github.antiope-preview+json"
$HEADER = @{
	'Authorization' = "token $env:GITHUB_TOKEN"
}

$global:EVENT = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
# user/repo
$global:REPOSITORY = $env:GITHUB_REPOSITORY

switch ($Type) {
    'Issue' { Initialize-Issue }
    'PR' { Initialize-PR }
    'Push' { Initialize-Push }
    'Scheduled' { Initialize-Scheduled }
}
