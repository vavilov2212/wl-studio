$ErrorActionPreference = "Stop"

Write-Host "Publishing (atomic push)..." -ForegroundColor Cyan

# ---------------------------------------------
# 1. Parse version
# ---------------------------------------------
$versionLine    = Get-Content pubspec.yaml | Select-String "^version: "
$currentVersion = ($versionLine -split ": ")[1].Trim()
$name           = ($currentVersion -split "\+")[0]
$tag            = "v$name"
$branch         = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "Tag:    $tag"
Write-Host "Branch: $branch"

# ---------------------------------------------
# 2. Guard: must be on dev or main
# ---------------------------------------------
if ($branch -notin @("dev", "main")) {
    Write-Host "ERROR: Must be on 'dev' or 'main' branch (current: $branch)" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------
# 3. Guard: must have uncommitted changes
# ---------------------------------------------
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "ERROR: No changes to publish" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------
# 4. Guard: tag must not already exist
# ---------------------------------------------
git fetch --tags
if (git tag -l $tag) {
    Write-Host "ERROR: Tag already exists: $tag" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------
# 5. Commit and push — CI handles the tag
# ---------------------------------------------
git add pubspec.yaml
git commit -m "release: windows $tag"
git push origin $branch

Write-Host "Pushed to $branch - CI will create tag $tag and build the release" -ForegroundColor Green
