$ErrorActionPreference = "Stop"

Write-Host "🚀 Publishing (atomic push)..." -ForegroundColor Cyan

$versionLine = Get-Content pubspec.yaml | Select-String "^version: "
$currentVersion = ($versionLine -split ": ")[1]
$name = ($currentVersion -split "\+")[0]
$tag = "v$name"

$branch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "🏷 Tag: $tag"
Write-Host "🌿 Branch: $branch"

# Check for changes
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "❌ No changes to release" -ForegroundColor Red
    exit 1
}

# Check if tag exists
git fetch --tags
if (git tag -l $tag) {
    Write-Host "❌ Tag already exists: $tag" -ForegroundColor Red
    exit 1
}

# Commit and Tag
git add pubspec.yaml release/appcast_windows.xml
git commit -m "release windows $tag"
git tag $tag

# Push
Write-Host "📤 Pushing to origin..." -ForegroundColor Yellow
git push origin $branch $tag --atomic

Write-Host "✅ Tag pushed successfully!" -ForegroundColor Green