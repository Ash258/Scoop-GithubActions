param (
	[Parameter(Mandatory)]
	[ValidateSet('Issue', 'PR', 'Push')]
	[String] $Type
)

# region Function pool
function Invoke-GithubRequest {
	param([Object] $Body, [String] $query)
	# TODO:
	return Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $Body -Depth 8 -Compress) -Method Post "$API_BASE_URl/repos/Ash258/GithubActionsBucketForTesting/issues/5/comments"
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

function Resolve-IssueTitle {
	param([String] $Title)

	$Title -match "(?<name>\w)@(?<version>):\\s*(?<problem..*)$"

	return $Matches.name, $Matches.version, $Matches.problem
}

# TODO: Rename?
function Initialize-Issue {
	Write-Log 'Issue initialized'

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
# endregion Function pool

$API_BASE_URl = 'https://api.github.com'
$API_VERSION = 'v3'
$API_HEADER = "Accept: application/vnd.github.$API_VERSION+json; application/vnd.github.antiope-preview+json"
$HEADER = @{
	'Authorization' = "token $env:GITHUB_TOKEN"
}
$global:EVENT = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json

Write-Host -f Yellow $EVENT.action

switch ($Type) {
	'Issue' { Initialize-Issue }
	'PR' { Initialize-PR }
	'Push' { Initialize-Push }
}
