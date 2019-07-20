#region Variables pool
$EVENT_RAW = Get-Content $env:GITHUB_EVENT_PATH -Raw
# Convert actual API response to object
$EVENT = ConvertFrom-Json $EVENT_RAW
# Event type for automatic handler detection
$EVENT_TYPE = $env:GITHUB_EVENT_NAME

# user/repo format
$REPOSITORY = $env:GITHUB_REPOSITORY
# Location of bucket
$BUCKET_ROOT = $env:GITHUB_WORKSPACE
# Binaries from scoop. No need to rely on bucket specific binaries
$BINARIES_FOLDER = Join-Path $env:SCOOP_HOME 'bin'
$MANIFESTS_LOCATION = Join-Path $BUCKET_ROOT 'bucket'

$NON_ZERO = 258
$FUNCTIONS_TO_BE_REMOVED = 'Get-AppFilePath', 'Get-HelperPath'

#region Comments
# TODO: Add all possible comments, which could be repeated.
#endregion Comments
#endregion Variables pool

#region Function pool
#region ⬇⬇⬇⬇⬇⬇⬇⬇ OK ⬇⬇⬇⬇⬇⬇⬇⬇
#region DO NOT TOUCH
#region General Helpers
function Write-Log {
    <#
    .SYNOPSIS
        Persist message in docker log. For debug mainly.
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
        Write-Output "INFO: $Summary"
    } elseif (($Message.Count -eq 1) -and ($Message[0] -isnot [Hashtable])) {
        # Simple non hashtable object and summary should be one liner
        Write-Output "${Summary}: $Message"
    } else {
        # Detailed output using format table
        Write-Output "Log of ${Summary}:"
        $mess = ($Message | Format-Table -HideTableHeaders -AutoSize | Out-String).Trim() -split "`n"
        Write-Output ($mess | ForEach-Object { "    $_" })
    }

    Write-Output ''
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
        Return new array list for better operations.
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

function New-DetailsCommentString {
    <#
    .SYNOPSIS
        Create string surrounded with <details>.
    .PARAMETER Summary
        What should be displayed on expand button.
    .PARAMETER Content
        Content of details block.
    .PARAMETER Type
        Type of code fenced block (example `json`, `yml`, ...).
        Needs to be valid markdown code fenced block type.
    #>
    param([String] $Summary, [String[]] $Content, [String] $Type = 'text')

    return @"
<details>
<summary>$Summary</summary>

``````$Type
$($Content -join "`r`n")
</details>
``````
"@
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

function New-CheckListItem {
    <#
    .SYNOPSIS
        Helper functino for creating markdown check lists.
    .PARAMETER Item
        Name of list item.
    .PARAMETER OK
        Check was met.
    .PARAMETER IndentLevel
        Define nested list level.
    .PARAMETER Simple
        Simple list item will be used instead of check list.
    #>
    param ([String] $Item, [Switch] $OK, [Int] $IndentLevel = 0, [Switch] $Simple)

    $ind = ' ' * $IndentLevel * 4
    $char = if ($OK) { 'x' } else { ' ' }
    $item = if ($Simple) { '' } else { "[$char] " }

    return "$ind- $item$Item"
}
#endregion General Helpers

#region Github API
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
        https://developer.github.com/v3/issues/comments/
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
    param([Int] $ID, [Switch] $Filter)

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
    param([Int] $ID)

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
        [Int] $ID,
        [ValidateNotNullOrEmpty()] # > Must contain at least one label
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
        Array of labels to be removed.
    #>
    param(
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
#endregion Github API

#region Actions
function Initialize-Scheduled {
    <#
    .SYNOPSIS
        Excavator alternative. Based on schedule execute auto-pr function.
    #>
    Write-Log 'Scheduled initialized'

    $params = @{
        'Dir'         = $MANIFESTS_LOCATION
        'Upstream'    = "${REPOSITORY}:master"
        'Push'        = $true
        'SkipUpdated' = [bool] $env:SKIP_UPDATED
    }
    if ($env:SPECIAL_SNOWFLAKES) { $params.Add('SpecialSnowflakes', ($env:SPECIAL_SNOWFLAKES -split ',')) }

    & (Join-Path $BINARIES_FOLDER 'auto-pr.ps1') @params
    # TODO: Post some comment?? Or other way how to publish logs for non collaborators.

    Write-Log 'Auto pr - DONE'
}
#endregion Actions
#endregion DO NOT TOUCH

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

function Test-Hash {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Manifest,
        [Int] $IssueID
    )

    & (Join-Path $BINARIES_FOLDER 'checkhashes.ps1') -App $Manifest -Dir $MANIFESTS_LOCATION -Update
    # TODO: Resolve eror state handling from within binary
    # https://github.com/Ash258/GithubActionsBucketForTesting/runs/153999789

    $status = hub status --porcelain -uno
    Write-Log 'Status' $status

    $changes = hub diff --name-only
    if (($changes).Count -eq 1) {
        Write-Log 'Verified hash failed'

        $message = @('You are right. Thanks for reporting.')
        $prs = (Invoke-GithubRequest "repos/$REPOSITORY/pulls?state=open&base=master&sorting=updated").Content | ConvertFrom-Json
        $prs = $prs | Where-Object { $_.title -ceq "${Manifest}: Hash fix" }

        # There is alreay PR for
        if ($prs.Count -gt 0) {
            Write-Log 'PR - Update description'

            # Only take latest updated
            $pr = $prs | Select-Object  -First 1
            $prID = $pr.number
            $prBody = $pr.Body
            # TODO: Additional checks if this PR is really fixing same issue

            $message += ''
            $message += "There is already pull request to fix this issue. (#$prID)"

            Write-Log 'PR ID' $prID
            # Update PR description
            Invoke-GithubRequest "repos/$REPOSITORY/pulls/$prID" -Method Patch -Body @{ "body" = (@("- Closes #$IssueID", $prBody) -join "`r`n") }
        } else {
            Write-Log 'PR - Create new branch and post PR'

            $branch = "$manifest-hash-fix-$(Get-Random -Maximum 258258258)"
            hub checkout -B $branch

            hub add $changes
            hub commit -m "${Manifest}: hash fix"
            hub push origin $branch

            # Create new PR
            Invoke-GithubRequest -Query "repos/$REPOSITORY/pulls" -Method Post -Body @{
                'title' = "${Manifest}: Hash fix"
                'base'  = 'master'
                'head'  = $branch
                'body'  = "- Closes #$IssueID"
            }
        }

        Add-Label -ID $IssueID -Label 'verified', 'hash-fix-needed'
        Add-Comment -ID $IssueID -Message $message
    } else {
        Write-Log 'Cannot reproduce'

        Add-Comment -ID $IssueID -Message @(
            'Cannot reproduce',
            '',
            "Are you sure your scoop is up to date? Please run ``scoop update; scoop uninstall $Manifest; scoop install $Manifest``"
        )
        Remove-Label -ID $IssueID -Label 'hash-fix-needed'
        Close-Issue -ID $IssueID
    }
}

function Test-Downloading {
    param([String] $Manifest, [Int] $IssueID)

    $manifest_path = Get-Childitem $MANIFESTS_LOCATION "$Manifest\.*" | Select-Object -First 1 -ExpandProperty Fullname
    $manifest_o = Get-Content $manifest_path -Raw | ConvertFrom-Json

    $broken_urls = @()
    # dl_with_cache_aria2 $Manifest 'DL' $manifest_o (default_architecture) "/" $manifest_o.cookies $true

    # exit 0
    foreach ($arch in @('64bit', '32bit')) {
        $urls = @(url $manifest_o $arch)

        foreach ($url in $urls) {
            Write-Log 'url' $url

            try {
                dl_with_cache $Manifest 'DL' $url $null $manifest_o.cookies $true
            } catch {
                $broken_urls += $url
                continue
            }
        }
    }

    if ($broken_urls.Count -eq 0) {
        Write-Log 'All OK'

        $message = @(
            'Cannot reproduce.',
            '',
            'All files can be downloaded properly (Please keep in mind I can only download files without aria2 support (yet))',
            'Downloading problems could be caused by:'
            '',
            '- Proxy configuration',
            '- Network error',
            '- Site is blocked (Great Firewall of China for example)'
        )

        Add-Comment -ID $IssueID -Comment $message
        # TODO: Close??
    } else {
        Write-Log 'Broken URLS' $broken_urls

        $string = ($broken_urls | ForEach-Object { "- $_" }) -join "`r`n"
        Add-Label -ID $IssueID -Label 'package-fix-needed', 'verified', 'help-wanted'
        Add-Comment -ID $IssueID -Comment 'Thanks for reporting. You are right. Following URLs are not accessible:', '', $string
    }
}

function Initialize-PR {
    <#
    .SYNOPSIS
        Handle pull requests actions.
    #>
    Write-Log 'PR initialized'

    $commented = $false
    switch ($EVENT.action) {
        'opened' {
            Write-Log 'Opened PR'
        }
        'created' {
            Write-Log 'Commented PR'

            if ($EVENT.comment.body -like '/verify*') {
                Write-Log 'Verify comment'

                if ($EVENT.issue.pull_request) {
                    Write-Log 'Pull request comment'

                    $commented = $true
                    $EVENT = Invoke-GithubRequest "repos/$REPOSITORY/pulls/$($EVENT.issue.number)" | ConvertFrom-Json
                } else {
                    Write-Log 'Issue comment'
                    exit 0
                }
            } else {
                Write-Log 'Not supported comment body'
                exit 0
            }
        }
        default {
            Write-Log 'Only action ''opened'' is supported'
            exit 0
        }
    }

    #region Forked repo
    $head = if ($commented) { $EVENT.head } else { $EVENT.pull_request.head }
    if ($head.repo.fork) {
        Write-Log 'Forked repository'

        $REPOSITORY_forked = "$($head.repo.full_name):$($head.ref)"
        Write-Log 'Repo' $REPOSITORY_forked

        $cloneLocation = '/github/forked_workspace'
        git clone --branch $head.ref $head.repo.clone_url $cloneLocation
        $BUCKET_ROOT = $cloneLocation
        $buck = Join-Path $BUCKET_ROOT 'bucket'
        $MANIFESTS_LOCATION = if (Test-Path $buck) { $buck } else { $BUCKET_ROOT }

        Push-Location $cloneLocation
    }
    #endregion Forked repo

    Write-log 'Files in PR:'

    (Get-ChildItem $BUCKET_ROOT | Select-Object -ExpandProperty Basename) -join ', '
    (Get-ChildItem $MANIFESTS_LOCATION | Select-Object -ExpandProperty Basename) -join ', '

    $checks = @()
    $invalid = @()
    $prID = $EVENT.number
    # Do not run on removed files
    $files = Get-AllChangedFilesInPR $prID -Filter
    Write-Log 'PR Files' $files

    foreach ($file in $files) {
        Write-Log "Starting $($file.filename) checks"

        # Reset variables
        $manifest = $null
        $object = $null
        $statuses = [Ordered] @{ }

        # Convert path into gci item to hold all needed information
        $manifest = Get-ChildItem $BUCKET_ROOT $file.filename
        Write-Log 'Manifest' $manifest

        $object = Get-Content $manifest.Fullname -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -eq $object) {
            Write-Log 'Conversion failed'

            # Handling of configuration files (vscode, ...) will not be problem as soon as nested bucket folder is restricted
            Write-Log 'Extension' $manifest.Extension
            if ($manifest.Extension -eq '.json') {
                Write-Log 'Invalid JSON'
                $invalid += $manifest.Basename
            } else {
                Write-Log 'Not manifest at all'
            }
            Write-Log "Skipped $($file.filename)"
            continue
        }

        #region Property checks
        $statuses.Add('Description', ([bool] $object.description))
        $statuses.Add('License', ([bool] $object.license))
        # TODO: More advanced license checks
        #endregion Property checks

        #region Hashes
        Write-Log 'Hashes'

        $outputH = @(& (Join-Path $BINARIES_FOLDER 'checkhashes.ps1') -App $manifest.Basename -Dir $MANIFESTS_LOCATION *>&1)
        Write-Log 'Output' $outputH

        # everything should be all right when latest string in array will be OK
        $statuses.Add('Hashes', ($outputH[-1] -like 'OK'))

        Write-Log 'Hashes done'
        #endregion Hashes

        #region Checkver
        Write-Log 'Checkver'
        $outputV = @(& (Join-Path $BINARIES_FOLDER 'checkver.ps1') -App $manifest.Basename -Dir $MANIFESTS_LOCATION -Force *>&1)
        Write-log 'Output' $outputV

        # If there are more than 2 lines and second line is not version, there is problem
        $checkver = ((($outputV.Count -ge 2) -and ($outputV[1] -like "$($object.version)")))
        $statuses.Add('Checkver', $checkver)

        switch -Wildcard ($outputV[-1]) {
            'ERROR*' { $autoupdate = $false }
            "couldn't match*" { $autoupdate = $false }
            default { $autoupdate = $checkver }
        }
        $statuses.Add('Autoupdate', $autoupdate)

        Write-Log 'Checkver done'
        #endregion

        #region formatjson
        Write-Log 'Format'
        # TODO: implement format check using array compare if possible (or just strings with raws)
        # TODO: I am not sure if this will handle tabs and everything what could go wrong.
        #$raw = Get-Content $manifest.Fullname -Raw
        #$new_raw = $object | ConvertToPrettyJson
        #$statuses.Add('Format', ($raw -eq $new_raw))
        Write-Log 'Format done'
        #endregion formatjson

        $checks += [Ordered] @{ 'Name' = $manifest.Basename; 'Statuses' = $statuses }

        Write-Log "Finished $($file.filename) checks"
    }

    Write-Log 'Name of check' $checks.name
    Write-Log 'Statuses' $checks.Statuses
    Write-Log 'Invalids' $invalid

    # No checks at all
    # There were no manifests compatible
    if (($checks.Count -eq 0) -and ($invalid.Count -eq 0)) {
        Write-Log 'No compatible files in PR'
        exit 0
    }

    # Create nice comment to post
    $message = New-Array
    foreach ($check in $checks) {
        Add-IntoArray $message "### $($check.Name)"
        Add-IntoArray $message ''

        foreach ($status in $check.Statuses.Keys) {
            $b = $check.Statuses.Item($status)
            Write-Log $status $b

            if (-not $b) { $env:NON_ZERO_EXIT = $true }

            Add-IntoArray $message (New-CheckListItem $status -OK:$b)
        }
        Add-IntoArray $message ''
    }

    if ($invalid.Count -gt 0) {
        Write-Log 'PR contains invalid manifests'

        $env:NON_ZERO_EXIT = $true

        Add-IntoArray $message '### Invalid manifests'
        Add-IntoArray $message ''

        Add-IntoArray $message ($invalid | ForEach-Object { "- $_" })
    }

    # Add some more human friendly message
    if ($env:NON_ZERO_EXIT) {
        $message.Insert(0, 'Your changes does not pass some checks')
        Add-Label -ID $prID -Label 'package-fix-neeed'
    } else {
        $message.InsertRange(0, @('All changes looks good.', '', 'Wait for review from human collaborators.'))
        Remove-Label -ID $prID -Label 'package-fix-neeed'
        Add-Label -ID $prID -Label 'review-needed'
    }
    # TODO: Comment URL to action log
    # $url = "https://github.com/$REPOSITORY/runs/$RUN_ID"
    # Add-IntoArray $message "_You can find log of all checks in '$url'_"

    Add-Comment -ID $prID -Message $message

    Write-Log 'PR finished'
}

#endregion ⬆⬆⬆⬆⬆⬆⬆⬆ OK ⬆⬆⬆⬆⬆⬆⬆⬆














function Test-ExtractDir {
    param([String] $Manifest, [Int] $IssueID)

    # Load manifest
    $manifest_path = Get-Childitem $MANIFESTS_LOCATION "$Manifest\.*" | Select-Object -First 1 -ExpandProperty Fullname
    $manifest_o = Get-Content $manifest_path -Raw | ConvertFrom-Json

    $message = @()
    $failed = $false
    $version = 'EXTRACT_DIR'

    foreach ($arch in @('64bit', '32bit')) {
        $urls = @(url $manifest_o $arch)
        $extract_dirs = @(extract_dir $manifest_o $arch)

        Write-Log $urls
        Write-Log $extract_dirs

        for ($i = 0; $i -lt $urls.Count; ++$i) {
            $url = $urls[$i]
            $dir = $extract_dirs[$i]
            dl_with_cache $Manifest $version $url $null $manifest_o.cookie $true

            $cached = cache_path $Manifest $version $url | Resolve-Path | Select-Object -ExpandProperty Path
            Write-Log "FILEPATH $url, ${arch}: $cached"

            $full_output = @(7z l $cached | awk '{ print $3, $6 }' | grep '^D')
            $output = @(7z l $cached -ir!"$dir" | awk '{ print $3, $6 }' | grep '^D')

            $infoLine = $output | Select-Object -Last 1
            $status = $infoLine -match '(?<files>\d+)\s+files(,\s+(?<folders>\d+)\s+folders)?'
            if ($status) {
                $files = $Matches.files
                $folders = $Matches.folders
            }

            # There are no files and folders like
            if ($files -eq 0 -and (!$folders -or $folders -eq 0)) {
                Write-Log "No $dir in $url"

                $failed = $true
                $message += New-DetailsCommentString -Summary "Content of $arch $url" -Content $full_output
                Write-Log "$dir, $arch, $url FAILED"
            } else {
                Write-Log "Cannot reproduce $arch $url"

                Write-Log "$arch ${url}:"
                Write-Log $full_output
                Write-Log "$dir, $arch, $url OK"
            }
        }
    }

    if ($failed) {
        Write-Log 'Failed' $failed
        $message = 'You are right. Can reproduce', '', $message
        Add-Label -ID $IssueID -Label 'verified', 'package-fix-needed', 'help-wanted'
    } else {
        Write-Log 'Everything all right' $failed
        $message = "Cannot reproduce. Are you sure your scoop is updated? Try to run ``scoop update; scoop uninstall $Manifest; scoop install $Manifest``"
        $message += ''
        $message += 'See action log for more info'
    }

    Add-Comment -ID $IssueID -Message $message
}

function Initialize-MockedFunctionsFromCore {
    # Remove functions
    $FUNCTIONS_TO_BE_REMOVED | ForEach-Object { Remove-Item function:$_ }
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

function Initialize-Issue {
    Write-Log 'Issue initialized'
    Write-log 'ACTION' $EVENT.action

    if ($EVENT.action -ne 'opened') {
        Write-Log "Only action 'opened' is supported"
        exit 0
    }

    $title = $EVENT.issue.title
    $id = $EVENT.issue.number

    $problematicName, $problematicVersion, $problem = Resolve-IssueTitle $title
    if (($null -eq $problematicName) -or
        ($null -eq $problematicVersion) -or
        ($null -eq $problem)
    ) {
        Write-Log 'Not compatible issue title'
        exit 0
    }

    switch -Wildcard ($problem) {
        '*hash check*' {
            Write-Log 'Hash check failed'
            Test-Hash $problematicName $id
        }
        '*extract_dir*' {
            Write-Log 'Extract dir error'
            # TODO:
            # Test-ExtractDir $problematicName $id
        }
        '*download*failed*' {
            Write-Log 'Download failed'
            Test-Downloading $problematicName $id
        }
    }

    Write-Log 'Issue finished'
}

function Initialize-Push {
    Write-Log 'Push initialized'
    Write-Log 'Push finished'
}
#endregion Function pool

#region Main
# For dot sourcing whole file inside tests
if ($env:TESTS) { return }

if (Test-Path $MANIFESTS_LOCATION) {
    Write-Log 'Bucket contains nested bucket folder'
} else {
    Write-Log 'Buckets without nested bucket folder are not supported.'

    $adopt = 'Adopt nested bucket structure'
    $req = Invoke-GithubRequest "repos/$REPOSITORY/issues?state=open"
    $issues = ConvertFrom-Json $req.Content | Where-Object { $_.title -eq $adopt }

    Write-Log 'Count' $issues.Count

    if ($issues -and ($issues.Count -gt 0)) {
        Write-Log 'Issue already exists'
    } else {
        New-Issue -Title $adopt -Body @(
            'Buckets without nested bucket folder are not supported. You will not be able to use actions without it.',
            '',
            'See <https://github.com/Ash258/GenericBucket> for the most optimal bucket structure.'
        )
        exit $NON_ZERO
    }
}

Initialize-NeededSettings

# Load all scoop's modules.
# Dot sourcing needs to be done on highest scope possible to propagate into lower scopes
Write-Log 'Importing all modules'
Get-ChildItem (Join-Path $env:SCOOP_HOME 'lib') '*.ps1' | Select-Object -ExpandProperty Fullname | ForEach-Object { . $_ }
Initialize-MockedFunctionsFromCore

Write-Log 'FULL EVENT' $EVENT_RAW

switch ($EVENT_TYPE) {
    'issues' { Initialize-Issue }
    'pull_request' { Initialize-PR }
    'issue_comment' { Initialize-PR }
    'schedule' { Initialize-Scheduled }
    'push' { Initialize-Push }
    default { Write-Log 'Not supported event type' }
}

if ($env:NON_ZERO_EXIT) { exit $NON_ZERO }
#endregion Main
