param (
	[Parameter(Mandatory)]
	[ValidateSet('Issue', 'PR')]
	[String] $Type
)

function Invoke-GithubRequest {
	param([Object] $Body, [String] $query)
	# TODO:
	return Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $Body -Depth 8 -Compress) -Method Post "$URI/repos/Ash258/GithubActionsBucketForTesting/issues/5/comments"
}

function Add-Comment {
	<#
	.SYNOPSIS
		Add comment into specific issue / PR
	#>
	param([Int] $ID, [String] $Message)
}

function Write-Log {
	[Parameter(Mandatory, ValueFromRemainingArguments)]
	param ([String[]] $Message)
	Write-Output "LOG: $($Message -join "`r`n    ")"
}

$URI = 'https://api.github.com'
$API_VERSION = 'v3'
$API_HEADER = "Accept: application/vnd.github.$API_VERSION+json; application/vnd.github.antiope-preview+json"
$HEADER = @{
	'Authorization' = "token $env:GITHUB_TOKEN"
}

$EVENT = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json

if ($Type -eq 'Issue') {
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
	Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $BODY -Depth 8 -Compress) -Method Post "$URI/repos/Ash258/GithubActionsBucketForTesting/issues/5/comments"
}
