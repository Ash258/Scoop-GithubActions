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

    it 'Checklist' {
        $trues = @(
            @('Alfa', $true),
            @('BETA', $true),
            @('COSI', $true)
        )

        $falses = @(
            @('Alfa', $false),
            @('BETA', $false),
            @('COSI', $false)
        )

        $trues | ForEach-Object { New-CheckListItem $_[0] -OK | Should -Be "- [x] $($_[0])" }

        $falses | ForEach-Object { New-CheckListItem $_[0] | Should -Be "- [ ] $($_[0])" }
    }

    # it 'Changed files in PR' {
    #     $files = Get-AllChangedFilesInPR 9

    #     $files.filename | Should -Be @('README.template.md', 'bucket/Added.json', 'bucket/FRD.json', 'bucket/PotPlayer.json')
    #     $files.status | Should -Be @('removed', 'added', 'removed', 'modified')
    # }
}
