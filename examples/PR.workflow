workflow "Issues workflow" {
    on = "issue"
    resolves = ["IssueHandler"]
}

workflow "PR workflow" {
    on = "pr"
    resolves = ["PRHandler"]
}

action "IssueHandler" {
    uses = "Ash258/Scoop-GithubActions@v1.0.0"
    args = "Issue"
}

action "PRHandler" {
    uses = "Ash258/Scoop-GithubActions@v1.0.0"
    args = "PR"
}
