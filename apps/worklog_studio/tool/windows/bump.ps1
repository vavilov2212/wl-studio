$ErrorActionPreference = "Stop"

Write-Host "Bumping version..." -ForegroundColor Cyan

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
    Write-Error "Please specify bump type (dev, release, patch, minor, major, X.Y.Z)"
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
# 4. Run unit tests
# ─────────────────────────────────────────────
& "$PSScriptRoot\run_tests.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Version bumped to $newName. Run publish.ps1 to push - CI builds and releases Windows + macOS." -ForegroundColor Green
