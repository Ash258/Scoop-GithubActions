❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗ DO NOT USE YET. Wait for 1.0 tag releae ❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗

# Github actions for scoop buckets

## Implemented actions

## Issues (`Issues | IssueHandler`)

- Hash check fails
    1. Run checkhashes and check if there were some changes
        1. Yes
            1. List newest pull requests with name `<manifest>: Hash fix`
                1. If there are some
                    1. Select the latest one
                    1. Update PR description with closing directive of new issue
                    1. Comment on issue about this PR
                1. If none
                    1. Create new branch `<manifest>-hash-fix-<random>`
                    1. Commit changes
                    1. Create new PR
        1. No
            1. Comment on issue about hashes being right
            1. Remove label `hash-fix-needed`
            1. Close issue

Example workflow for everything you will ever need as bucket maintainer [^1].

```hcl
workflow "Issues" {
  on = "issues"
  resolves = ["IssueHandler"]
}

workflow "Pull requests" {
  resolves = ["PullRequestHandler"]
  on = "pull_request"
}

workflow "Excavator" {
  on = "schedule(0 * * * *)"
  resolves = ["Excavate"]
}

action "IssueHandler" {
  uses = "Ash258/Scoop-GithubActions@master"
  args = "Issue"
  env = {
      "GITH_EMAIL" = "youremail@email.com"
  }
  secrets = ["GITHUB_TOKEN"]
}

action "PullRequestHandler" {
  uses = "Ash258/Scoop-GithubActions@master"
  args = "PR"
  env = {
      "GITH_EMAIL" = "youremail@email.com"
  }
  secrets = ["GITHUB_TOKEN"]
}

action "Excavate" {
  uses = "Ash258/Scoop-GithubActions@master"
  args = "Scheduled"
  env = {
      "GITH_EMAIL" = "youremail@email.com"
  }
  secrets = ["GITHUB_TOKEN"]
}

```

## How to debug locally

```powershell
$env:GITHUB_TOKEN = '<yourtoken>'
$env:GITHUB_EVENT_PATH = "<repo_root>\cosi.json"
.\Entrypoint.ps1 <Type>
# Try to avoid all real requests into repository
#    but GithubActionsBucketForTesting so feel free to do whatever you want with this repo
```

## Issues

1. On issues.created
    1. Parse issue title
        1. `manifest@version: PROBLEM`
            1. `hash check failed`
                1. Run checkhashes
                    1. If there is change push it
                    1. If no, comment on issue and close it
            1. `download via aria2 failed`
            1. `extract_dir error`
                1. Download
                1. Extract
                    1. If there is problem
                        1. Add label package-fix-needed and verified
                    1. If no, comment on issue and close it
        1. $env:GITHUB_EVENT_PATH, <https://developer.github.com/actions/creating-github-actions/accessing-the-runtime-environment/#environment-variables>

## Pull requests

Will be executed when pull_request is (opened, reopened)

Github action will check if these requirements are met

1. Properties
    1. Description
    1. License
1. Checkver
1. Checkhashes
1. Install❓❓
1. Format❓❓
    1. This is covered by Appveyor

## Excavator

This is not real replacement of excavator. (Until i resolve how to store/expose logs somehow)
Should work:

```HCL
workflow "Issues" {
    on = "issues"
    resolves = [ "IssueHandler" ]
}

action "IssueHandler" {
    uses = "Ash258/Scoop-GithubActions@master"
    args = "Issue"
    secrets = [ "GITHUB_TOKEN" ]
}

workflow "Pull requests" {
    on = "pull_requests"
    resolves = [ "PullRequestHandler" ]
}

action "PullRequestHandler" {
    uses = "Ash258/Scoop-GithubActions@master"
    args = "PR"
    secrets = [ "GITHUB_TOKEN" ]
}

workflow "Excavator" {
    on = "schedule(0 * * * *)"
    resolves = [ "Excavate" ]
}

# Post comment to specific issue each 5 minutes
action "Excavate" {
    uses = "Ash258/Scoop-GithubActions@master"
    args = "Scheduled"
    secrets = [ "GITHUB_TOKEN" ]
}
```

[^1]: Email is needed for pushing
