
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

function Cosi {
    Write-Log 'alfa'

    return 'cosi'
}

Export-ModuleMember -Function Write-Log, Cosi
