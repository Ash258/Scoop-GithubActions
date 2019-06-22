# TODO: Remove and make it automatically
param (
    [Parameter(Mandatory)]
    [ValidateSet('Issue', 'PR', 'Push', '__TESTS__', 'Scheduled')]
    [String] $Type
)

#region Variables pool
# Convert actual API response to object
$EVENT = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
# Event type for automatic handler detection
$EVENT_TYPE = $env:GITHUB_EVENT_NAME
# user/repo format
$REPOSITORY = $env:GITHUB_REPOSITORY
# Location of bucket
$BUCKET_ROOT = $env:GITHUB_WORKSPACE

# Backward compatability for manifests inside root of repository
$nestedBucket = Join-Path $BUCKET_ROOT 'bucket'
$MANIFESTS_LOCATION = if (Test-Path $nestedBucket) { $nestedBucket } else { $BUCKET_ROOT }
#endregion Variables pool

#region Function pool
function Resolve-IssueTitle {
    <#
    .SYNOPSIS
        Parse issue title and return manifest name, version and problem.
    .PARAMETER Title
        Title to be parsed.
    .EXAMPLE
        Resolve-IssueTitle 'recuva@2.4: hash check failed'
    #>
    param([String] $Title)

    $result = $Title -match '(?<name>.+)@(?<version>.+):\s*(?<problem>.*)$'

    if ($result) {
        return $Matches.name, $Matches.version, $Matches.problem
    } else {
        return $null, $null, $null
    }
}

function Write-Log {
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    param ([String[]] $Message)

    Write-Output ''
    $Message | ForEach-Object { Write-Output "LOG: $_" }
}

function New-CheckListItem {
    <#
    .SYNOPSIS
        Helper functino for creating markdown check lists.
    .PARAMETER Check
        Name of check.
    .PARAMETER OK
        Check was met.
    #>
    param ([String] $Check, [Switch] $OK)

    if ($OK) {
        return "- [x] $Check"
    } else {
        return "- [ ] $Check"
    }
}

function Invoke-GithubRequest {
    <#
    .SYNOPSIS
        Invoke authenticated github API request.
    .PARAMETER Query
        Query to be executed.
    .PARAMETER Method
        Method to be used with request
    .PARAMETER Body
        Additional body to be send.
    #>
    param(
        [Parameter(Mandatory)]
        [String] $Query,
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method = 'Get',
        [Hashtable] $Body
    )

    $api_base_url = 'https://api.github.com'
    $headers = @{
        # Authorization token is neeeded for posting comments and to increase limit of requests
        'Authorization' = "token $env:GITHUB_TOKEN"
    }
    $parameters = @{
        'Headers' = $headers
        'Method'  = $Method
        'Uri'     = "$api_base_url/$Query"
    }

    Write-Debug $parameters.Uri

    if ($Body) { $parameters.Add('Body', (ConvertTo-Json $Body -Depth 8 -Compress)) }

    return Invoke-WebRequest @parameters
}

function Add-Comment {
    <#
    .SYNOPSIS
        Add comment into specific issue / PR.
    .PARAMETER ID
        ID of issue / PR.
    .PARAMETER Message
        String or array of string to be send as comment.
    #>
    param(
        [Int] $ID,
        [Alias('Comment')]
        [String[]] $Message
    )

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/comments" -Method Post -Body @{ 'body' = ($Message -join "`r`n") }
}

function Add-Label {
    <#
    .SYNOPSIS
        Add label to issue / PR.
    .PARAMETER ID
        Id of issue / PR.
    .PARAMETER Label
        Label to be set.
    #>
    param([Int] $ID, [String[]] $Label)

    return Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/$ID/labels" -Method Post -Body @{ 'labels' = $Label }
}

function Get-AllChangedFilesInPR {
    <#
    .SYNOPSIS
        Get list of all changed files inside pull request.
    .PARAMETER ID
        ID of pull request.
    #>
    param([Int] $ID)

    $files = (Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls/$ID/files").Content | ConvertFrom-Json
    return $files | Select-Object -Property filename, status
}

# ⬆⬆⬆⬆⬆⬆⬆⬆ OK ⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆







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

    # Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $BODY -Depth 8 -Compress) -Method Post "$API_BASE_URl/repos/Ash258/GithubActionsBucketForTesting/issues/5/comments"
}

function Initialize-PR {
    <#
    .SYNOPSIS
        Handle pull requests actions.
    #>
	Write-Log 'PR initialized'

	# TODO: Get all changed files in PR
	# Since binaries do not return any data on success flow needs to be this:
	# Run check with force param
	# if error, then just
	# git status, if changed
	# run checkver
	# run checkhashes
	# run formatjson?

    $EVENT | Format-Table | Out-String
    # $checksStatus = @()

    # & "$env:SCOOP_HOME\bin\checkver.ps1"
	# $status = if ($LASTEXITCODE -eq 0) { 'x' } else { ' ' }

	# $body = @{
	# 	'body' = (@(
	# 			"- Properties",
	# 			"    - [$status] Description",
	# 			"    - [$status] License",
	# 			"- [$status] Checkver functional",
	# 			"- [$status] Autoupdate working",
	# 			"- [$status] Hashes are correct",
	# 			"- [$status] Manifest is formatted"
	# 		) -join "`r`n")
	# }

	# Write-Log $body.body
}

function Initialize-Push {
    Write-Log 'Push initialized'
}

function Initialize-Scheduled {
    Write-Log 'Scheduled initialized'

    Invoke-GithubRequest -Query "repos/$REPOSITORY/issues/7/comments" -Method Post -Body @{
        'body' = (@("Scheduled comment each hour - $(Get-Date)", 'WORKSPACE', "$(Get-ChildItem $env:GITHUB_WORKSPACE)") -join "`r`n")
    }
}
#endregion Function pool

#region Main
# For dot sourcing whole file inside tests
if ($Type -eq '__TESTS__') { return }

switch ($Type) {
    'Issue' { Initialize-Issue }
    'PR' { Initialize-PR }
    'Push' { Initialize-Push }
    'Scheduled' { Initialize-Scheduled }
}

Write-Host $EVENT_TYPE -f DarkRed
Write-Host $MANIFESTS_LOCATION -f DarkRed

# switch ($EVENT_TYPE) {
# 	'issues' { Initialize-Issue }
# 	'pull_requests' { Initialize-PR }
# 	'push' { Initialize-Push }
# 	'schedule' { Initialize-Scheduled }
# }
#endregion Main
