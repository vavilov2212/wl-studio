$ErrorActionPreference = "Stop"

Write-Host "Starting Windows release build..." -ForegroundColor Cyan

# ─────────────────────────────────────────────
# CLI info
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "Available commands:"
Write-Host "  dev      - next dev version  (1.0.1 -> 1.0.2-dev.1)"
Write-Host "  release  - finalize dev      (1.0.2-dev.5 -> 1.0.2)"
Write-Host "  patch    - bump patch        (1.0.1 -> 1.0.2)"
Write-Host "  minor    - bump minor        (1.0.1 -> 1.1.0)"
Write-Host "  major    - bump major        (1.0.1 -> 2.0.0)"
Write-Host "  X.Y.Z    - set exact version"
Write-Host ""

$Type = $args[0]
if (-not $Type) {
    Write-Error "Please specify build type (dev, release, patch, minor, major, X.Y.Z)"
    exit 1
}

# ─────────────────────────────────────────────
# 1. Parse current version from pubspec.yaml
# ─────────────────────────────────────────────
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -match 'version:\s*([^\s+]+)\+(\d+)') {
    $currentName = $Matches[1]
    $buildNum    = [int]$Matches[2]
} else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}

$isDev = $false
$baseMajor, $baseMinor, $basePatch, $devNum = 0, 0, 0, 0

if ($currentName -match '^(\d+)\.(\d+)\.(\d+)-dev\.(\d+)$') {
    $baseMajor = [int]$Matches[1]; $baseMinor = [int]$Matches[2]
    $basePatch = [int]$Matches[3]; $devNum    = [int]$Matches[4]
    $isDev = $true
} elseif ($currentName -match '^(\d+)\.(\d+)\.(\d+)$') {
    $baseMajor = [int]$Matches[1]; $baseMinor = [int]$Matches[2]
    $basePatch = [int]$Matches[3]
} else {
    Write-Error "Unsupported version format: $currentName"
    exit 1
}

# ─────────────────────────────────────────────
# 2. Calculate new version
# ─────────────────────────────────────────────
switch ($Type) {
    "dev" {
        if ($isDev) { $devNum++; $newName = "$baseMajor.$baseMinor.$basePatch-dev.$devNum" }
        else        { $basePatch++; $newName = "$baseMajor.$baseMinor.$basePatch-dev.1" }
    }
    "release" { $newName = "$baseMajor.$baseMinor.$basePatch" }
    "patch"   { $basePatch++; $newName = "$baseMajor.$baseMinor.$basePatch" }
    "minor"   { $baseMinor++; $basePatch = 0; $newName = "$baseMajor.$baseMinor.$basePatch" }
    "major"   { $baseMajor++; $baseMinor = 0; $basePatch = 0; $newName = "$baseMajor.$baseMinor.$basePatch" }
    { $_ -match '^\d+\.\d+\.\d+$' } { $newName = $Type }
    Default   { Write-Error "Unknown command: $Type"; exit 1 }
}

$newBuild   = $buildNum + 1
$newVersion = "$newName+$newBuild"

Write-Host "----------------------------------------"
Write-Host "Version: $currentName+$buildNum -> $newVersion" -ForegroundColor Yellow
Write-Host "----------------------------------------"

# ─────────────────────────────────────────────
# 3. Update pubspec.yaml
# ─────────────────────────────────────────────
$pubspec = $pubspec -replace "version: .*", "version: $newVersion"
$pubspec | Set-Content pubspec.yaml -Encoding UTF8
Write-Host "pubspec.yaml updated" -ForegroundColor Green

# ─────────────────────────────────────────────
# 4. Build
# ─────────────────────────────────────────────
Write-Host "Building Windows..." -ForegroundColor Yellow
fvm flutter build windows --release

# ─────────────────────────────────────────────
# 5. Package ZIP
# ─────────────────────────────────────────────
$releaseDir  = "release/windows"
if (!(Test-Path $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null }

$zipPath     = "$releaseDir/worklog_studio_windows.zip"
$buildOutput = "build/windows/x64/runner/Release/*"

if (Test-Path $zipPath) { Remove-Item $zipPath }
Write-Host "Creating ZIP..." -ForegroundColor Yellow
Compress-Archive -Path $buildOutput -DestinationPath $zipPath

# ─────────────────────────────────────────────
# 6. Update appcast_windows.xml
# ─────────────────────────────────────────────
$fileSize    = (Get-Item $zipPath).Length
$repoUrl     = (git config --get remote.origin.url).Replace(".git","").Replace("git@github.com:","https://github.com/")
$downloadUrl = "$repoUrl/releases/download/v$newName/worklog_studio_windows_$newName.zip"

$appcastXml = @"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
  <title>Worklog Studio Windows Updates</title>
  <link>$repoUrl</link>
  <description>Latest updates for Worklog Studio (Windows)</description>
  <language>en</language>
  <item>
    <title>Version $newName</title>
    <sparkle:releaseNotesLink>$repoUrl/releases/tag/v$newName</sparkle:releaseNotesLink>
    <pubDate>$([DateTime]::Now.ToString("R"))</pubDate>
    <enclosure
      url="$downloadUrl"
      sparkle:version="$newBuild"
      sparkle:shortVersionString="$newName"
      length="$fileSize"
      type="application/octet-stream"/>
  </item>
</channel>
</rss>
"@

$appcastXml | Set-Content "release/appcast_windows.xml" -Encoding UTF8
Write-Host "appcast_windows.xml updated" -ForegroundColor Green
Write-Host "Build ready: $zipPath" -ForegroundColor Green
