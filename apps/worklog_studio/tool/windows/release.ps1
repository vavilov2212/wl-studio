$ErrorActionPreference = "Stop"

Write-Host "🚀 Manual GitHub release (Windows)..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# 1. Parse version
# ─────────────────────────────────────────────
$versionLine    = Get-Content pubspec.yaml | Select-String "^version: "
$currentVersion = ($versionLine -split ": ")[1].Trim()
$name           = ($currentVersion -split "\+")[0]
$tag            = "v$name"
$zipPath        = "release/windows/worklog_studio_windows.zip"

# ─────────────────────────────────────────────
# 2. Guards
# ─────────────────────────────────────────────
git fetch --tags
if (!(git tag -l $tag)) {
    Write-Host "❌ Tag does not exist: $tag — run publish.ps1 first" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $zipPath)) {
    Write-Host "❌ ZIP not found: $zipPath — run build.ps1 first" -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────
# 3. Prerelease flag
# ─────────────────────────────────────────────
$prereleaseFlag = @()
if ($tag -like "*dev*") {
    $prereleaseFlag = @("--prerelease")
    Write-Host "⚠️  Creating PRE-release" -ForegroundColor Yellow
} else {
    Write-Host "✅ Creating RELEASE" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# 4. Changelog
# ─────────────────────────────────────────────
$prevTag = git describe --tags --abbrev=0 "$tag^" 2>$null
if ([string]::IsNullOrWhiteSpace($prevTag)) {
    Write-Host "ℹ️  No previous tag — using full log"
    $changelog = git log --pretty=format:"- %s"
} else {
    Write-Host "📜 Changelog: $prevTag → $tag"
    $changelog = git log "$($prevTag)..HEAD" --pretty=format:"- %s"
}

$tempFile = New-TemporaryFile
$changelog | Set-Content $tempFile -Encoding UTF8

# ─────────────────────────────────────────────
# 5. Rename ZIP to include version in filename
# ─────────────────────────────────────────────
$versionedZip = "release/windows/worklog_studio_windows_$name.zip"
Copy-Item $zipPath $versionedZip -Force

# ─────────────────────────────────────────────
# 6. Create GitHub release
# ─────────────────────────────────────────────
Write-Host "📤 Creating GitHub release..." -ForegroundColor Yellow
$ghArgs = @("release", "create", $tag, $versionedZip,
            "--title", "Release $name (Windows)",
            "--notes-file", $tempFile.FullName) + $prereleaseFlag

& gh @ghArgs

Remove-Item $tempFile
Write-Host "🎉 GitHub release created: $tag" -ForegroundColor Green
