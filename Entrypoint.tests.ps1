# Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester, PSScriptAnalyzer -SkipPublisherCheck

. "$PSScriptRoot\Entrypoint.ps1" '__TESTS__'

describe 'Helper functoins test' {
	it 'Parse issue title' {
		@(
			@('xmake@2.2.7: extract_dir error', 'xmake', '2.2.7', 'extract_dir error'),
			@('IntelliJ-IDEA-Ultimate-EAP-portable@2019.2-192.5281.24: hash check failed', 'IntelliJ-IDEA-Ultimate-EAP-portable', '2019.2-192.5281.24', 'hash check failed')
		) | ForEach-Object {
			Resolve-IssueTitle $_[0] | Should -Be $_[1], $_[2], $_[3]
		}

		Resolve-IssueTitle 'šěš@:alfa' | Should -Be $null, $null, $null
	}
}
