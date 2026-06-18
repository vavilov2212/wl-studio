# Swap the live Windows app icon (windows\runner\resources\app_icon.ico)
# between the prod and dev variants. Run this before `flutter run`/`flutter
# build -d windows` — the CMake/RC setup is not flavor-aware, so the icon
# must be swapped on disk ahead of time.
#
# Usage (from apps/worklog_studio/):
#   powershell tool/windows/select_app_icon.ps1 -Flavor dev
#   powershell tool/windows/select_app_icon.ps1 -Flavor prod

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Flavor
)

$ErrorActionPreference = "Stop"

$winLiveIco   = Join-Path $PSScriptRoot "..\..\windows\runner\resources\app_icon.ico"
$winSourceIco = Join-Path $PSScriptRoot "..\..\windows\runner\resources\app_icon_$Flavor.ico"

Copy-Item -Path $winSourceIco -Destination $winLiveIco -Force

Write-Host "Windows app icon switched to '$Flavor'." -ForegroundColor Green
