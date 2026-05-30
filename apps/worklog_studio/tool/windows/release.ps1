$ErrorActionPreference = "Stop"

Write-Host "🚀 Manual GitHub release (Windows)..." -ForegroundColor Cyan

# 1. Get version
$versionLine = Get-Content pubspec.yaml | Select-String "^version: "
$currentVersion = ($versionLine -split ": ")[1]
$name = ($currentVersion -split "\+")[0]
$tag = "v$name"
$zipPath = "release/windows/worklog_studio_windows.zip"

# 2. Checks
if (!(git tag -l $tag)) {
    Write-Host "❌ Tag does not exist: $tag. Run publish.ps1 first." -ForegroundColor Red
    exit 1
}

if (!(Test-Path $zipPath)) {
    Write-Host "❌ ZIP not found: $zipPath" -ForegroundColor Red
    exit 1
}

# 3. Prerelease flag
$prereleaseFlag = ""
if ($tag -like "*dev*") {
    $prereleaseFlag = "--prerelease"
    Write-Host "⚠️ Creating PRE-release" -ForegroundColor Yellow
}

# 4. Changelog
$prevTag = git describe --tags --abbrev=0 "$tag^" 2>$null
if ([string]::IsNullOrWhiteSpace($prevTag)) {
    Write-Host "ℹ️ No previous tag found"
    $changelog = git log --pretty=format:"- %s"
} else {
    Write-Host "📜 Changelog from $prevTag to $tag"
    $changelog = git log "$($prevTag)..HEAD" --pretty=format:"- %s"
}

$tempFile = New-TemporaryFile
$changelog | Set-Content $tempFile -Encoding UTF8

# 5. Create Release
Write-Host "📤 Creating GitHub release..." -ForegroundColor Yellow
gh release create $tag $zipPath `
    --title "Release $name (Windows)" `
    --notes-file $tempFile `
    $prereleaseFlag

Remove-Item $tempFile

Write-Host "🎉 GitHub release created: $tag" -ForegroundColor Green