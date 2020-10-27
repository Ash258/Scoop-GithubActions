# Github actions for scoop buckets

Set of automated actions, which bucket maintainers can use to save time managing issues / pull requests. Using a `stable` tag instead of a specific version is highly recommended.

For a better/native implementation using a Windows image refer to [stable-win](https://github.com/Ash258/Scoop-GithubActions/tree/stable-win)/[main-win](https://github.com/Ash258/Scoop-GithubActions/tree/main-win) branches.
Linux based actions are no longer supported and maintained.

## Available actions

`GITH_EMAIL` environment is not required since [1.0.1](https://github.com/Ash258/Scoop-GithubActions/releases/tag/1.0.1), but it is recommended.
If email is not specified commits will not be pushed using your account, which will not add contributions. ([See](https://github.com/phips28/gh-action-bump-version/commit/adda5b22b3c785eb69d328f91dadb49a4c34a82e))

### Excavator (`Excavator`)

- ❗❗❗ [Protected master branches are not supported](https://github.community/t5/GitHub-Actions/How-to-push-to-protected-branches-in-a-GitHub-Action/m-p/30710/highlight/true#M526) ❗❗❗
- Periodically execute automatic updates for all manifests
- Refer to [help page](https://help.github.com/en/articles/events-that-trigger-workflows#scheduled-events) for configuration formats
- <https://github.com/ScoopInstaller/Excavator> alternative
    - No need to have custom device, which could run docker or scheduled task for auto-pr 24/7

### Issues (`Issues`)

As soon as a new issue **is created** or the **label `verify` is added** to an issue, the action is executed.
Based on the issue title, a specific sub-action is executed. It could be one of these:

- **Hash check fails**
    1. Checkhashes binary is executed
    1. Result is parsed
        1. Hash mismatch
            1. Pull requests with name `<manifest>@<version>: Hash fix` are listed
                1. There is already a PR
                    1. The newest one is selected
                    1. Description of this PR is updated with closing directive for created issue
                    1. Comment to issue is posted with reference to PR
                1. If none
                    1. New branch `<manifest>-hash-fix-<random>` is created
                    1. Changes are commited
                    1. New PR is created from this branch
            1. Labels `hash-fix-needed`, `verified` are added
        1. No problem
            1. Comment on issue is posted about hashes being right and possible causes
            1. Label `hash-fix-needed` is removed
            1. Issue is closed
        1. Binary error
            1. Label `package-fix-needed` is added
- **Download failed**
    1. All urls defined in manifest are retrieved
    1. Downloading of all urls is executed
    1. Comment to issue is posted
        1. If there is problematic URL
            1. List of these URLs is attached in comment
            1. Labels `package-fix-needed`, `verified`, `help-wanted` is added
        1. All URLs could be downloaded without problem
            1. Possible causes are attached in comment

### Pull requests (`Pull requests | PullRequestHandler`)

As soon as a **PR is created** or **someone posts the comment `/verify`** the set of these tests are executed:

- ❗❗ [Pull request created from forked repository cannot be finished due to different permission scope of token](https://github.com/Ash258/Scoop-GithubActions/issues/42) ❗❗
    - Manual `/verify` comment is needed

1. Required properties are in place
    - Manifest has to contain `License` and `Description` properties
1. Hashes of URLs match
    - Hashes specified in manifest have to match
1. Checkver functionality
    - Checkver has to finished successfully
    - Version in manifest has to match version from checkver binary (latest possible)
1. Autoupdate
    - Autoupdate has to finish successfully
    - Hashes extraction has to finish successfully
        - If there is a `hash` property inside `autoupdate` the output of the checkver binary cannot contain `Could not find hash`

- All checks could be executed with `/verify` comment. (<https://github.com/Ash258/GithubActionsBucketForTesting/pull/176>)

## Example workflows for all actions

- Names could be changed as needed
- `if` statements are not required
    - There are only time savers for going through lots of action logs
    - Save GitHub resources

```yml
#.github\workflows\schedule.yml
on:
  schedule:
  - cron: '*/30 * * * *'
name: Excavator
jobs:
  excavate:
    name: Excavate
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: Excavate
      uses: Ash258/Scoop-GithubActions@stable
      env:
        GITH_EMAIL: youremail@mail.com
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        SKIP_UPDATED: '1'

#.github\workflows\issues.yml
on:
  issues:
    types: [ opened, labeled ]
name: Issues
jobs:
  issueHandler:
    name: IssueHandler
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: IssueHandler
      uses: Ash258/Scoop-GithubActions@stable
      if: github.event.action == 'opened' || (github.event.action == 'labeled' && contains(github.event.issue.labels.*.name, 'verify'))
      env:
        GITH_EMAIL: youremail@mail.com # Not needed, but recommended
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

#.github\workflows\issue_commented.yml
on:
  issue_comment:
    types: [ created ]
name: Pull requests comment
jobs:
  pullRequestHandler:
    name: PullRequestHandler
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: PullRequestHandler
      uses: Ash258/Scoop-GithubActions@stable
      if: startsWith(github.event.comment.body, '/verify')
      env:
        GITH_EMAIL: youremail@mail.com # Not needed, but recommended
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

#.github\workflows\pull_request.yml
on:
  pull_request:
    types: [ opened ]
name: Pull requests
jobs:
  pullRequestHandler:
    name: PullRequestHandler
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: PullRequestHandler
      uses: Ash258/Scoop-GithubActions@stable
      env:
        GITH_EMAIL: youremail@mail.com # Not needed, but recommended
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## How to debug locally

```powershell
# LocalTestEnvironment.ps1

# Try to avoid all real requests into real repository
#    All events inside repository will use GithubActionsBucketForTesting repository for testing purpose
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', '<yourtoken>', 'Process')
[System.Environment]::SetEnvironmentVariable('GITHUB_EVENT_NAME', '<EVENT YOU WANT TO DEBUG>', 'Process')
# Create Cosi.json with any request from events folder
[System.Environment]::SetEnvironmentVariable('GITHUB_EVENT_PATH', "$PSScriptRoot\cosi.json", 'Process')
[System.Environment]::SetEnvironmentVariable('GITHUB_REPOSITORY', 'Ash258/GithubActionsBucketForTesting', 'Process')
$DebugPreference = 'Continue'
git clone 'https://github.com/Ash258/GithubActionsBucketForTesting.git' '/github/workspace'
# Uncomment debug entries in Dockerfile
```

Execute `docker run -ti (((docker build -q .) -split ':')[1])` or `docker build . -t 'actions:master'; docker run -ti actions`.
