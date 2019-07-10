<p align="center">
❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗ DO NOT USE YET. Wait for 1.0.0 tag release ❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗
</p>

You could participate in testing using `@stable` version or any of already released tags from release page.

# Github actions for scoop buckets

Set of automated actions you will ever need as bucket maintainer. Using `stable` tag instead of specific version is highly recommended.

## Implemented actions

### Excavator (`Excavator | Excavate`)

- Periodically execute automatic updates for all manifests.
- <https://github.com/ScoopInstaller/Excavator> alternative.
    - If you do not have custom server / device which could run docker or scheduled task for auto-pr 24/7.

### Pull requests (`Pull requests | PullRequestHandler`)

- When pull request is created following tests will be executed for all changed manifests.
    - Required properties
        - License
        - Description
    - Hashes for all download urls
    - Checkver functionality
    - Autoupdate functionality
- All checks could be executed with `/verify` comment. (<https://github.com/Ash258/GithubActionsBucketForTesting/pull/66>)

### Issues (`Issues | IssueHandler`)

- **Hash check fails**
    1. Run checkhashes and analyze result
        1. Hash mismatch
            1. List newest pull requests with name `<manifest>: Hash fix`
                1. If there are some
                    1. Select the latest one
                    1. Update PR description with closing directive of new issue
                    1. Comment on issue about this PR
                1. If none
                    1. Create new branch `<manifest>-hash-fix-<random>`
                    1. Commit changes
                    1. Create new PR
        1. No problem
            1. Comment on issue about hashes being right
            1. Remove label `hash-fix-needed`
            1. Close issue
- **Download failed**
    1. Get all urls in manifest
        1. Download them
            1. If there is error, add current url to list of broken urls
    1. Comment will be posted to issue

## Example workflow for everything you will ever need as bucket maintainer

```hcl
workflow "Issues" {
    on = "issues"
    resolves = ["IssueHandler"]
}

workflow "Pull requests" {
    on = "pull_request"
    resolves = ["PullRequestHandler"]
}

workflow "Pull requests comment" {
    on = "issue_comment"
    resolves = ["PullRequestHandler"]
}

workflow "Excavator" {
    on = "schedule(0 * * * *)" # Run auto-pr every hour, See: https://developer.github.com/actions/managing-workflows/creating-and-cancelling-a-workflow/#scheduling-a-workflow
    resolves = ["Excavate"]
}

action "IssueHandler" {
    uses = "Ash258/Scoop-GithubActions@stable"
    secrets = ["GITHUB_TOKEN"]
    env = {
        "GITH_EMAIL" = "youremail@email.com" # Email is needed for pushing to repository within action container
    }
}

action "PullRequestHandler" {
    uses = "Ash258/Scoop-GithubActions@stable"
    secrets = ["GITHUB_TOKEN"]
    env = {
        "GITH_EMAIL" = "youremail@email.com"
    }
}

action "Excavate" {
    uses = "Ash258/Scoop-GithubActions@stable"
    secrets = ["GITHUB_TOKEN"]
    env = {
        "SPECIAL_SNOWFLAKES" = "curl,brotli,jx" # Optional parameter
        "SKIP_UPDATED" = "1" # Optional parameter, Could be anything as value
        "GITH_EMAIL" = "youremail@email.com"
    }
}
```

## How to debug locally

```powershell
# LocalTestEnvironment.ps1

# Try to avoid all real requests into real repository
#    All events inside repository will use GithubActionsBucketForTesting repository for testing purpose
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', '<yourtoken>', 'Process')
[System.Environment]::SetEnvironmentVariable('GITHUB_EVENT_PATH', "$PSScriptRoot\cosi.json", 'Process')
[System.Environment]::SetEnvironmentVariable('GITHUB_REPOSITORY', 'Ash258/GithubActionsBucketForTesting', 'Process')
$DebugPreference = 'Continue'
git clone 'https://github.com/Ash258/GithubActionsBucketForTesting.git' '/github/workspace'
# Uncomment debug entries in Dockerfile
```

Execute `docker run -ti (((docker build -q .) -split ':')[1])` or `docker build . -t 'actions:master'; docker run -ti actions`.

## Issues

1. On issues.created
    1. Parse issue title
        1. `manifest@version: PROBLEM`
            1. `extract_dir error`
                1. Extract
                    1. If there is problem
                        1. Add label package-fix-needed and verified
                    1. If no, comment on issue and close it
        1. $env:GITHUB_EVENT_PATH, <https://developer.github.com/actions/creating-github-actions/accessing-the-runtime-environment/#environment-variables>
