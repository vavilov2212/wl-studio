# Windows Installer and Auto-Update Design

**Date:** 2026-07-05
**Status:** Approved

## Overview

Replace the raw ZIP distribution on Windows with a proper Inno Setup installer and implement WinSparkle-based auto-update. Users download a `worklog_studio_setup_<version>.exe` from GitHub Releases, get a standard Windows install experience, and receive silent background update notifications from within the app.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Installer tool | Inno Setup | Simplest Flutter-compatible option, free, single .exe output |
| Install scope | Per-user (`%LocalAppData%`) | No UAC prompt; auto-update can replace files without elevation |
| Code signing | None (deferred) | SmartScreen warning accepted; signing deferred to a later release |
| Release artifacts | ZIP + installer .exe | ZIP kept for portability; installer .exe is the primary download |
| Auto-update library | WinSparkle | Matches existing `SparkleBridge` MethodChannel and `appcast_windows.xml` format |

## Section 1 - Installer (Inno Setup)

**Script location:** `apps/worklog_studio/installer/worklog_studio.iss`

**Behavior:**
- Installs to `{localappdata}\Programs\Worklog Studio\`
- No UAC elevation required
- Creates Start Menu shortcut and Desktop shortcut
- Registers uninstaller visible in "Add/Remove Programs" / "Apps and Features"
- Upgrade-in-place: re-running the installer over an existing version silently replaces all files
- Bundles `WinSparkle.dll` alongside the Flutter build output

**Version injection:** The version string is not hardcoded in the `.iss` file. CI passes it as a compiler define:
```
iscc /DAppVersion=<version> /DSourceDir=<flutter_build_output> worklog_studio.iss
```

**Output filename:** `worklog_studio_setup_<version>.exe`

## Section 2 - Auto-Update (WinSparkle)

### Native C++ bridge

**New file:** `apps/worklog_studio/windows/runner/updater_plugin.cpp`

Registers the `worklog_studio/updater` MethodChannel and implements:
- `checkForUpdates` - opens WinSparkle's native update dialog
- `checkSilently` - background check; dialog only shown if an update exists
- `getVersion` - returns current version string

### Initialization

In `apps/worklog_studio/windows/runner/main.cpp`, before `FlutterWindow` is created:
```cpp
win_sparkle_set_appcast_url("https://raw.githubusercontent.com/vavilov2212/worklog_studio/main/apps/worklog_studio/release/appcast_windows.xml");
win_sparkle_set_app_details(L"vavilov2212", L"Worklog Studio", L"<version>");
win_sparkle_init();
```
And `win_sparkle_cleanup()` on shutdown.

### WinSparkle integration method

WinSparkle is distributed as a pre-built DLL. Options:
- Download the DLL in CI as part of the build step (preferred - no binary in source)
- Commit the DLL to `apps/worklog_studio/windows/third_party/winsparkle/` (simpler, avoids network dependency in CI)

**Decision:** Commit the DLL to the repo under `windows/third_party/winsparkle/`. The DLL is small (~500 KB), stable, and avoids a fragile CI download step.

### Flutter usage

`SparkleBridge.checkSilently()` is called once on app startup (in `app.dart` or the top-level service locator setup). `SparkleBridge.checkForUpdates()` is wired to the "Check for Updates" button already present in `general_settings_screen.dart`.

### Update flow

1. App starts, `checkSilently()` fires in the background
2. WinSparkle fetches `appcast_windows.xml`
3. If the appcast version is newer: native Windows dialog - "Worklog Studio X.Y.Z is available"
4. User clicks "Install Update"
5. WinSparkle downloads the installer `.exe`, verifies it, runs it with `/VERYSILENT /NORESTART` (Inno Setup silent flags configured in WinSparkle via `win_sparkle_set_installer_arguments`)
6. Installer upgrades the app in place, relaunches

### Appcast entry format

The appcast `enclosure` URL points to the installer `.exe` (not the ZIP):
```xml
<enclosure
  url="https://github.com/vavilov2212/worklog_studio/releases/download/v<version>/worklog_studio_setup_<version>.exe"
  sparkle:version="<build_number>"
  sparkle:shortVersionString="<version>"
  length="<file_size_bytes>"
  type="application/octet-stream"/>
```

## Section 3 - CI and Release Workflow

### `release.yml` - `build-windows` job

Two steps added after the existing Flutter build:

```yaml
- name: Install Inno Setup
  run: choco install innosetup --no-progress -y

- name: Build installer
  shell: pwsh
  run: |
    $version = "${{ needs.tag.outputs.version }}"
    $sourceDir = "apps/worklog_studio/build/windows/x64/runner/Release"
    $issScript = "apps/worklog_studio/installer/worklog_studio.iss"
    $outputDir = "installer_output"
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    iscc /DAppVersion=$version /DSourceDir=$sourceDir /O$outputDir $issScript
    echo "INSTALLER_NAME=worklog_studio_setup_$version.exe" | Out-File -FilePath $env:GITHUB_ENV -Append
```

The installer output (`worklog_studio_setup_<version>.exe`) is placed in `installer_output/` and uploaded as a second artifact (`windows-installer`) alongside the existing ZIP.

### `release.yml` - `release` job

Downloads both `windows-release` (ZIP) and `windows-installer` artifacts and attaches both to the GitHub Release:
```yaml
files: |
  worklog_studio_windows_${{ needs.tag.outputs.version }}.zip
  worklog_studio_setup_${{ needs.tag.outputs.version }}.exe
  worklog_studio_macos_${{ needs.tag.outputs.version }}.zip
```

### `publish.ps1`

A new step is added after committing: update `release/appcast_windows.xml` with:
- New version string and build number
- Installer `.exe` URL on GitHub Releases
- File size in bytes (read from the built installer file)

The updated `appcast_windows.xml` is included in the same commit as `pubspec.yaml`.

### `bump.ps1`

No changes. Version bumping is already separate from release publishing.

## File Map

| File | Change |
|---|---|
| `apps/worklog_studio/installer/worklog_studio.iss` | New - Inno Setup script |
| `apps/worklog_studio/windows/runner/updater_plugin.cpp` | New - WinSparkle MethodChannel bridge |
| `apps/worklog_studio/windows/runner/updater_plugin.h` | New - header |
| `apps/worklog_studio/windows/runner/main.cpp` | Modified - WinSparkle init/cleanup |
| `apps/worklog_studio/windows/runner/CMakeLists.txt` | Modified - link WinSparkle, add updater_plugin |
| `apps/worklog_studio/windows/third_party/winsparkle/` | New - WinSparkle.dll + WinSparkle.h |
| `apps/worklog_studio/lib/core/sparkle/sparkle_bridge.dart` | No change needed |
| `apps/worklog_studio/lib/feature/settings/general_settings_screen.dart` | Minor - wire checkForUpdates button if not already wired |
| `apps/worklog_studio/release/appcast_windows.xml` | Updated per release |
| `.github/workflows/release.yml` | Modified - add installer build + upload steps |
| `apps/worklog_studio/tool/windows/publish.ps1` | Modified - update appcast_windows.xml |

## Out of Scope

- Code signing (deferred)
- Delta/binary-diff updates (full installer replacement is sufficient)
- macOS changes (already implemented)
- Windows Store / MSIX packaging
