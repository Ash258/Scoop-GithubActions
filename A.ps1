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
		# Simple string and summary should be one liner
	} elseif (($Message.Count -eq 1) -and ($Message[0] -isnot [Hashtable])) {
		Write-Output "${Summary}: $Message"
	} else {
		Write-Output "Log of ${Summary}:"
		$mess = ($Message | Format-Table -HideTableHeaders -AutoSize | Out-String).Trim() -split "`r`n"
		Write-Output ($mess | ForEach-Object { "    $_" })
	}

	Write-Output ''
}

Write-Log 'Detailed info' @('array')
Write-Log 'Detailed info' ('array', 'two')
Write-Log 'Detailed info' @{ 'object' = 'child' }
Write-Log 'Detailed info' @{ 'object' = 'child'; 'second' = 'prop' }
Write-Log 'Detailed info' @{ 'object' = 'child'; 'nestedaaaaaaaa' = @{'propaaaaaaaa' = 'nes' } }
Write-Log 'Detailed info' @(@{ 'object' = 'child'; 'second' = 'prop' }, @{ 'ahoj' = 'child'; 'second' = 'prop' })

Write-Log 'Simple line, prefixed with INFO'
Write-Log 'Simple line, prefixed with INFO' $null

Write-Log 'ahoj' 'simple string on same line as summary'
Write-Log 'Ahoj' $true

Write-Log 'Environment' (Get-ChildItem Env: | Where-Object { $_.Name -ne 'PSModulePath' } | Select-Object -First 8)
