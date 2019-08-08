$EVENT_RAW = Get-Content $env:GITHUB_EVENT_PATH -Raw
# Convert actual API response to object
$EVENT = ConvertFrom-Json $EVENT_RAW
# Event type for automatic handler detection
$EVENT_TYPE = $env:GITHUB_EVENT_NAME

# user/repo format
$REPOSITORY = $env:GITHUB_REPOSITORY
# Location of bucket
$BUCKET_ROOT = $env:GITHUB_WORKSPACE
# Binaries from scoop. No need to rely on bucket specific binaries
$BINARIES_FOLDER = Join-Path $env:SCOOP_HOME 'bin'
$MANIFESTS_LOCATION = Join-Path $BUCKET_ROOT 'bucket'

$NON_ZERO = 258
$FUNCTIONS_TO_BE_REMOVED = 'Get-AppFilePath', 'Get-HelperPath'

Export-ModuleMember -Variable EVENT, EVENT_TYPE, EVENT_RAW, REPOSITORY, BUCKET_ROOT, BINARIES_FOLDER, `
    MANIFESTS_LOCATION, NON_ZERO, FUNCTIONS_TO_BE_REMOVED
