param (
	[Parameter(Mandatory)]
	[ValidateSet('Issue', 'PR')]
	[String] $Type
)

function Invoke-GithubRequest {

}

function Add-Comment {
	<#
	.SYNOPSIS
		Add comment into specific issue / PR
	#>
	param([Int] $ID, [String] $Message)
}

$URI='https://api.github.com'
$API_VERSION='v3'
$API_HEADER="Accept: application/vnd.github.$API_VERSION+json; application/vnd.github.antiope-preview+json"

$HEADER = @{
	'Authorization' = "token $evn:GITHUB_TOKEN"
}

if ($Type -eq 'Issue') {
	$envs = [Environment]::GetEnvironmentVariables()
	$table = @()
	$table += '| Name | Value |'
	$table += '| :--- | :--- |'
	$envs | ForEach-Object {
		$table += "| $_ | $([Environment]::GetEnvironmentVariable($_))|"
	}

	$table = $table -join "`r`n"
	$BODY = @{
		'body' = ([System.Web.HttpUtility]::UrlEncode(("Hello from github actions")))
	}
	Invoke-WebRequest -Headers $HEADER -Body (ConvertTo-Json $BODY -Depth 8 -Compress) -Method Post "$URI/repos/Ash258/GithubActionsBucketForTesting/issues/1/comments"
}
