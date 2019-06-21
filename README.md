# Github actions for scoop buckets

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

When pull request is created there are few actions needed

When any of action failed comment and add label

1. Checkver
1. Checkhashes
1. Install??
1. Format
    1. This is covered by Appveyor
