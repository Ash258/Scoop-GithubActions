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
	'Authorization' = "token $env:GITHUB_TOKEN"
}

if ($Type -eq 'Issue') {
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
