# Windows Installer and Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a per-user Inno Setup installer (.exe) and WinSparkle auto-update for the Windows app, producing both a ZIP and setup .exe on every GitHub Release.

**Architecture:** WinSparkle 0.8.0 binaries are committed to `windows/third_party/winsparkle/`. A new `updater_plugin.cpp` in the Flutter runner bridges the existing Dart `SparkleBridge` MethodChannel (`worklog_studio/updater`) to the WinSparkle C API. The Inno Setup script at `installer/worklog_studio.iss` packages the Flutter build output into a per-user setup .exe. CI compiles the installer, attaches both artifacts to the GitHub Release, then auto-commits an updated `appcast_windows.xml` pointing to the new installer .exe. `publish.ps1` no longer touches the appcast manually.

**Tech Stack:** WinSparkle 0.8.0 (C DLL, committed), Inno Setup 6.x (ISCC compiler, installed in CI via choco), Flutter Windows (C++17), GitHub Actions (ubuntu + windows runners), PowerShell

## Global Constraints

- Per-user install only: `PrivilegesRequired=lowest` in Inno Setup - never add UAC elevation
- No code signing - SmartScreen warning is acceptable
- `FLUTTER_VERSION` (e.g. `"1.0.12-dev.1"`) and `FLUTTER_VERSION_BUILD` (e.g. `81`) are already injected by Flutter's CMake build system into the runner binary - do not redefine them
- Never run `flutter run` or the `run` skill - use `fvm flutter build windows --release` and `fvm flutter analyze`
- WinSparkle version is locked at 0.8.0
- Appcast URL: `https://raw.githubusercontent.com/vavilov2212/worklog_studio/main/apps/worklog_studio/release/appcast_windows.xml`
- All commands run from `d:/work/wl_studio` (repo root) unless a `cd` is shown
- No `Co-Authored-By` trailer in commits

---

### Task 1: Commit WinSparkle 0.8.0 Binaries

**Files:**
- Create: `apps/worklog_studio/windows/third_party/winsparkle/WinSparkle.dll`
- Create: `apps/worklog_studio/windows/third_party/winsparkle/WinSparkle.lib`
- Create: `apps/worklog_studio/windows/third_party/winsparkle/WinSparkle.h`

**Interfaces:**
- Produces: `WinSparkle.h` header consumed by Tasks 3 and 4; `WinSparkle.lib` linked in Task 2; `WinSparkle.dll` copied to build output by Task 2's POST_BUILD step

- [ ] **Step 1: Download WinSparkle 0.8.0**

```powershell
Invoke-WebRequest `
  -Uri "https://github.com/vslavik/winsparkle/releases/download/v0.8.0/WinSparkle-0.8.0.zip" `
  -OutFile "$env:TEMP\WinSparkle-0.8.0.zip"
Expand-Archive -Path "$env:TEMP\WinSparkle-0.8.0.zip" -DestinationPath "$env:TEMP\winsparkle_extracted" -Force
```

- [ ] **Step 2: Copy files to target directory**

```powershell
New-Item -ItemType Directory -Force -Path "apps\worklog_studio\windows\third_party\winsparkle" | Out-Null

Copy-Item "$env:TEMP\winsparkle_extracted\WinSparkle-0.8.0\Release\WinSparkle.dll" `
  "apps\worklog_studio\windows\third_party\winsparkle\WinSparkle.dll"

Copy-Item "$env:TEMP\winsparkle_extracted\WinSparkle-0.8.0\Release\WinSparkle.lib" `
  "apps\worklog_studio\windows\third_party\winsparkle\WinSparkle.lib"

Copy-Item "$env:TEMP\winsparkle_extracted\WinSparkle-0.8.0\include\winsparkle.h" `
  "apps\worklog_studio\windows\third_party\winsparkle\WinSparkle.h"
```

- [ ] **Step 3: Verify files exist**

```powershell
Get-Item "apps\worklog_studio\windows\third_party\winsparkle\*" | Select-Object Name, Length
```

Expected output: three files - `WinSparkle.dll` (~500 KB), `WinSparkle.lib` (~10 KB), `WinSparkle.h` (~10 KB).

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/windows/third_party/winsparkle/
git commit -m "chore: add WinSparkle 0.8.0 binaries"
```

---

### Task 2: CMakeLists.txt - Link WinSparkle and Add updater_plugin

**Files:**
- Modify: `apps/worklog_studio/windows/runner/CMakeLists.txt`

**Interfaces:**
- Consumes: `windows/third_party/winsparkle/WinSparkle.lib` and `WinSparkle.dll` from Task 1
- Produces: `WinSparkle.dll` present in `build/windows/x64/runner/Release/` after build; `updater_plugin.cpp` compiled into the runner binary

- [ ] **Step 1: Add `updater_plugin.cpp` to the executable sources**

In `apps/worklog_studio/windows/runner/CMakeLists.txt`, find the `add_executable` block. Add `"updater_plugin.cpp"` after `"mini_panel_messages.cpp"`:

```cmake
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "mini_panel_messages.cpp"
  "updater_plugin.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)
```

- [ ] **Step 2: Add WinSparkle include path, link library, and POST_BUILD DLL copy**

After the existing `target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")` line, append:

```cmake
# WinSparkle auto-update
set(WINSPARKLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/winsparkle")
target_include_directories(${BINARY_NAME} PRIVATE "${WINSPARKLE_DIR}")
target_link_libraries(${BINARY_NAME} PRIVATE "${WINSPARKLE_DIR}/WinSparkle.lib")

# Copy WinSparkle.dll next to the executable at every build so it runs in place.
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${WINSPARKLE_DIR}/WinSparkle.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/WinSparkle.dll"
)
```

- [ ] **Step 3: Commit CMakeLists change (build verification comes after Task 3 creates the source file)**

```bash
git add apps/worklog_studio/windows/runner/CMakeLists.txt
git commit -m "build: link WinSparkle and add updater_plugin to Windows runner"
```

---

### Task 3: Implement UpdaterPlugin C++ Bridge

**Files:**
- Create: `apps/worklog_studio/windows/runner/updater_plugin.h`
- Create: `apps/worklog_studio/windows/runner/updater_plugin.cpp`

**Interfaces:**
- Consumes: `WinSparkle.h` via include path set in Task 2; `flutter::BinaryMessenger*` passed by the caller (Task 5)
- Produces: `UpdaterPlugin(flutter::BinaryMessenger* messenger)` public constructor consumed in Task 5; handles MethodChannel methods `checkForUpdates`, `checkSilently`, `getVersion` on channel `worklog_studio/updater`

- [ ] **Step 1: Create `apps/worklog_studio/windows/runner/updater_plugin.h`**

Full file content:

```cpp
#pragma once

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

class UpdaterPlugin {
 public:
  explicit UpdaterPlugin(flutter::BinaryMessenger* messenger);
  ~UpdaterPlugin() = default;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
```

- [ ] **Step 2: Create `apps/worklog_studio/windows/runner/updater_plugin.cpp`**

Full file content:

```cpp
#include "updater_plugin.h"

#include <windows.h>
#include <flutter/standard_method_codec.h>

#include "WinSparkle.h"

#include <string>

UpdaterPlugin::UpdaterPlugin(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger,
      "worklog_studio/updater",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

void UpdaterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "checkForUpdates") {
    win_sparkle_check_update_with_ui();
    result->Success();
  } else if (method == "checkSilently") {
    win_sparkle_check_update_without_ui();
    result->Success();
  } else if (method == "getVersion") {
    // FLUTTER_VERSION is injected at compile time by runner/CMakeLists.txt.
    result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
  } else {
    result->NotImplemented();
  }
}
```

- [ ] **Step 3: Build to verify no linker errors**

```bash
cd apps/worklog_studio
fvm flutter build windows --release
```

Expected: build succeeds. If `win_sparkle_check_update_with_ui` is unresolved, verify Task 2's `target_link_libraries` line and that `WinSparkle.lib` exists at the path. Confirm `WinSparkle.dll` appears in `build/windows/x64/runner/Release/`.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/windows/runner/updater_plugin.h \
        apps/worklog_studio/windows/runner/updater_plugin.cpp
git commit -m "feat: implement WinSparkle updater plugin for Windows"
```

---

### Task 4: Initialize WinSparkle in main.cpp

**Files:**
- Modify: `apps/worklog_studio/windows/runner/main.cpp`

**Interfaces:**
- Consumes: `WinSparkle.h` (include path set in Task 2); `FLUTTER_VERSION` macro (already defined in CMakeLists.txt as `"1.0.12-dev.1"` style string)
- Produces: WinSparkle configured with appcast URL, app details, and installer silent flags; initialized before the Flutter message loop; cleaned up on exit

- [ ] **Step 1: Add WinSparkle include to `main.cpp`**

After the `#include "utils.h"` line, add:

```cpp
#include "WinSparkle.h"
```

- [ ] **Step 2: Add a narrow-to-wide string helper before `wWinMain`**

Insert after the closing `}` of `WriteCrashDump` and before `int APIENTRY wWinMain`:

```cpp
// Converts a UTF-8 string literal to std::wstring for the WinSparkle wide-char API.
static std::wstring ToWide(const char* utf8) {
  int len = ::MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
  if (len <= 0) return {};
  std::wstring wide(static_cast<size_t>(len - 1), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide.data(), len);
  return wide;
}
```

- [ ] **Step 3: Initialize WinSparkle in `wWinMain` before the Flutter project is created**

Inside `wWinMain`, immediately after `::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);` and before `flutter::DartProject project(L"data");`, insert:

```cpp
  // WinSparkle: configure and start auto-update before the Flutter engine.
  // The raw GitHub URL is checked on every silent check; updates appear as
  // soon as CI pushes the updated appcast_windows.xml after a release.
  win_sparkle_set_appcast_url(
      "https://raw.githubusercontent.com/vavilov2212/worklog_studio/main"
      "/apps/worklog_studio/release/appcast_windows.xml");
  win_sparkle_set_app_details(
      L"vavilov2212",
      L"Worklog Studio",
      ToWide(FLUTTER_VERSION).c_str());
  // Inno Setup silent flags: upgrade happens in the background without UAC.
  win_sparkle_set_installer_arguments(L"/VERYSILENT /NORESTART");
  win_sparkle_init();
```

- [ ] **Step 4: Cleanup WinSparkle before exit**

Inside `wWinMain`, after `::CoUninitialize();` and before `return EXIT_SUCCESS;`, add:

```cpp
  win_sparkle_cleanup();
```

- [ ] **Step 5: Build to verify**

```bash
cd apps/worklog_studio
fvm flutter build windows --release
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/windows/runner/main.cpp
git commit -m "feat: initialize WinSparkle auto-update in Windows runner"
```

---

### Task 5: Register UpdaterPlugin in FlutterWindow

**Files:**
- Modify: `apps/worklog_studio/windows/runner/flutter_window.h`
- Modify: `apps/worklog_studio/windows/runner/flutter_window.cpp`

**Interfaces:**
- Consumes: `UpdaterPlugin(flutter::BinaryMessenger*)` constructor from Task 3; `flutter_controller_->engine()->messenger()` returns `flutter::BinaryMessenger*`
- Produces: `UpdaterPlugin` instance alive for the lifetime of `FlutterWindow`; MethodChannel `worklog_studio/updater` active and handling calls

- [ ] **Step 1: Add include and member to `flutter_window.h`**

Add `#include "updater_plugin.h"` after the `#include "win32_window.h"` line.

Add `std::unique_ptr<UpdaterPlugin> updater_plugin_;` to the private section after `flutter_controller_`:

```cpp
 private:
  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<UpdaterPlugin> updater_plugin_;
```

- [ ] **Step 2: Construct the plugin in `flutter_window.cpp::OnCreate()`**

After the `RegisterPlugins(flutter_controller_->engine());` call in `OnCreate()`, add:

```cpp
  updater_plugin_ = std::make_unique<UpdaterPlugin>(
      flutter_controller_->engine()->messenger());
```

- [ ] **Step 3: Build to verify**

```bash
cd apps/worklog_studio
fvm flutter build windows --release
```

Expected: build succeeds with no errors.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/windows/runner/flutter_window.h \
        apps/worklog_studio/windows/runner/flutter_window.cpp
git commit -m "feat: register WinSparkle updater plugin with Flutter engine"
```

---

### Task 6: Dart - Platform Guard and Startup Call

**Files:**
- Modify: `apps/worklog_studio/lib/core/sparkle/sparkle_bridge.dart`
- Modify: `apps/worklog_studio/lib/main.dart`

**Interfaces:**
- Consumes: `UpdaterPlugin` MethodChannel registered in Task 5
- Produces: `SparkleBridge` methods no-op silently on non-desktop platforms; `checkSilently()` called once after the first frame on app startup

- [ ] **Step 1: Establish green test baseline**

```bash
cd apps/worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests pass.

- [ ] **Step 2: Update `sparkle_bridge.dart` with platform guard**

Full replacement content for `apps/worklog_studio/lib/core/sparkle/sparkle_bridge.dart`:

```dart
import 'dart:io';

import 'package:flutter/services.dart';

class SparkleBridge {
  static const _channel = MethodChannel('worklog_studio/updater');

  static Future<void> checkForUpdates() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    await _channel.invokeMethod('checkForUpdates');
  }

  static Future<void> checkSilently() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    await _channel.invokeMethod('checkSilently');
  }

  static Future<String> getVersion() async {
    if (!Platform.isWindows && !Platform.isMacOS) return '';
    return await _channel.invokeMethod('getVersion');
  }
}
```

- [ ] **Step 3: Add `checkSilently` startup call to `main.dart`**

Full replacement content for `apps/worklog_studio/lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/sparkle/sparkle_bridge.dart';

import 'runner/runner.dart' as runner;

void main(List<String> args) async {
  AppEnvironment.init(config: const AppConfig(flavor: Flavor.production));

  // Schedule a background update check after the first frame so the Flutter
  // engine and platform channel are fully ready. Errors are swallowed -
  // a failed check must never crash the app.
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SparkleBridge.checkSilently().catchError((_) {});
  });

  await runner.run(args);
}
```

- [ ] **Step 4: Run flutter analyze**

```bash
cd apps/worklog_studio
fvm flutter analyze
```

Expected: no errors or warnings added by these changes.

- [ ] **Step 5: Run tests**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/core/sparkle/sparkle_bridge.dart \
        apps/worklog_studio/lib/main.dart
git commit -m "feat: wire WinSparkle checkSilently on app startup"
```

---

### Task 7: Inno Setup Installer Script

**Files:**
- Create: `apps/worklog_studio/installer/worklog_studio.iss`

**Interfaces:**
- Consumes: `{#SourceDir}` - absolute path to Flutter release build output (`build/windows/x64/runner/Release/`) injected via CLI define; `{#AppVersion}` - version string injected via CLI define
- Produces: `worklog_studio_setup_{#AppVersion}.exe` in the directory passed via `/O` CLI flag; per-user installer with Start Menu shortcut, Desktop shortcut (opt-in), and uninstaller

- [ ] **Step 1: Create the installer directory**

```bash
mkdir -p apps/worklog_studio/installer
```

- [ ] **Step 2: Create `apps/worklog_studio/installer/worklog_studio.iss`**

Full file content:

```iss
; Worklog Studio - Inno Setup installer script
;
; Compile with:
;   iscc /DAppVersion=1.0.12 /DSourceDir=C:\path\to\Release /Ooutput_dir worklog_studio.iss
;
; AppVersion and SourceDir MUST be provided as CLI defines.

#define AppName      "Worklog Studio"
#define AppPublisher "vavilov2212"
#define AppExeName   "worklog_studio.exe"
; This GUID identifies the app to Windows for upgrade detection.
; Never change it after the first public release.
#define AppId        "{{A3F8D201-7C4B-4E9A-BD6F-2E1C5A7F8D30}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppUpdatesURL=https://github.com/vavilov2212/worklog_studio/releases
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install: no UAC elevation required.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputBaseFilename=worklog_studio_setup_{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Prompt user to close the running app before upgrading (needed to replace the .exe).
CloseApplications=yes
CloseApplicationsFilter=*worklog_studio.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copies the entire Flutter release output recursively.
; WinSparkle.dll is already in SourceDir because CMakeLists.txt copies it there at build time.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent
```

- [ ] **Step 3: Build the Flutter app (installer needs the output)**

```bash
cd apps/worklog_studio
fvm flutter build windows --release
```

- [ ] **Step 4: Install Inno Setup if not present**

```powershell
if (-not (Get-Command iscc -ErrorAction SilentlyContinue)) {
    choco install innosetup -y
}
```

- [ ] **Step 5: Test the installer locally**

```powershell
cd apps/worklog_studio

$version   = (Select-String "^version:" pubspec.yaml).Line.Split(":")[1].Trim().Split("+")[0]
$sourceDir = Resolve-Path "build\windows\x64\runner\Release"
$outputDir = Resolve-Path "."

iscc /DAppVersion=$version /DSourceDir=$sourceDir /O"$outputDir" installer\worklog_studio.iss
```

Expected: `worklog_studio_setup_<version>.exe` appears in `apps/worklog_studio/`.

Run the installer to verify:
- No UAC prompt appears
- App installs to `%LocalAppData%\Programs\Worklog Studio\`
- Start Menu shortcut is created
- App appears under Settings > Apps

- [ ] **Step 6: Remove the test installer exe before committing**

```powershell
Remove-Item "apps\worklog_studio\worklog_studio_setup_*.exe" -ErrorAction SilentlyContinue
```

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/installer/worklog_studio.iss
git commit -m "feat: add Inno Setup installer script for Windows"
```

---

### Task 8: Update CI - Build Installer and Attach Both Artifacts

**Files:**
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: Flutter release build output from the existing `Build Windows release` step
- Produces: `build_number` tag job output (for Task 9); `windows-installer` artifact (`worklog_studio_setup_<version>.exe`) uploaded alongside existing `windows-release` ZIP; GitHub Release contains both ZIP and installer .exe

- [ ] **Step 1: Add `build_number` output to the tag job**

In the `tag` job, add `build_number` to the `outputs` block:

```yaml
    outputs:
      version:      ${{ steps.parse.outputs.version }}
      build_number: ${{ steps.parse.outputs.build_number }}
      tag:          ${{ steps.parse.outputs.tag }}
      prerelease:   ${{ steps.parse.outputs.prerelease }}
      tag_exists:   ${{ steps.check.outputs.exists }}
```

In the `Parse version from pubspec.yaml` step's run script, add `BUILD_NUMBER` extraction after the existing `VERSION` extraction, and emit it to `$GITHUB_OUTPUT`:

```bash
          BUILD_NUMBER=$(grep '^version:' apps/worklog_studio/pubspec.yaml \
            | sed 's/version: //' \
            | cut -d'+' -f2 \
            | tr -d '[:space:]')
          echo "build_number=$BUILD_NUMBER" >> $GITHUB_OUTPUT
```

- [ ] **Step 2: Add installer build steps to `build-windows` job**

After the existing `Upload artifact` step (the ZIP upload), add:

```yaml
      - name: Install Inno Setup
        run: choco install innosetup --no-progress -y

      - name: Build installer
        shell: pwsh
        run: |
          $version   = "${{ needs.tag.outputs.version }}"
          $sourceDir = Resolve-Path "apps/worklog_studio/build/windows/x64/runner/Release"
          $issScript = "apps/worklog_studio/installer/worklog_studio.iss"
          $outputDir = New-Item -ItemType Directory -Force -Path "installer_output" |
                         Select-Object -ExpandProperty FullName
          iscc "/DAppVersion=$version" "/DSourceDir=$sourceDir" "/O$outputDir" $issScript
          echo "INSTALLER_NAME=worklog_studio_setup_$version.exe" |
            Out-File -FilePath $env:GITHUB_ENV -Append

      - name: Upload installer artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-installer
          path: installer_output/${{ env.INSTALLER_NAME }}
          retention-days: 1
```

- [ ] **Step 3: Add `windows-installer` to the `release` job's needs and download steps**

The `release` job currently has `needs: [tag, build-windows, build-macos]` - no change needed.

After the existing `Download Windows artifact` step, add:

```yaml
      - name: Download Windows installer artifact
        uses: actions/download-artifact@v4
        with:
          name: windows-installer
```

- [ ] **Step 4: Add the installer to the `Create GitHub Release` files list**

Update the `files` block of the `Create GitHub Release` step:

```yaml
          files: |
            worklog_studio_windows_${{ needs.tag.outputs.version }}.zip
            worklog_studio_setup_${{ needs.tag.outputs.version }}.exe
            worklog_studio_macos_${{ needs.tag.outputs.version }}.zip
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: build Inno Setup installer and attach to GitHub Release"
```

---

### Task 9: Auto-Update Appcast in CI

**Files:**
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: downloaded `windows-installer` artifact (for `stat` file size); `needs.tag.outputs.version` and `needs.tag.outputs.build_number` from Task 8
- Produces: `apps/worklog_studio/release/appcast_windows.xml` committed and pushed to the release branch after each successful release; enclosure URL points to the installer .exe, `sparkle:version` is the build number

- [ ] **Step 1: Add appcast update step to the `release` job**

Add the following step after the `Create GitHub Release` step. The `release` job already has `permissions: contents: write`, so the `git push` will work.

```yaml
      - name: Update appcast_windows.xml
        run: |
          VERSION="${{ needs.tag.outputs.version }}"
          BUILD_NUMBER="${{ needs.tag.outputs.build_number }}"
          INSTALLER="worklog_studio_setup_${VERSION}.exe"
          SIZE=$(stat -c%s "$INSTALLER")
          URL="https://github.com/vavilov2212/worklog_studio/releases/download/v${VERSION}/${INSTALLER}"
          DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

          cat > apps/worklog_studio/release/appcast_windows.xml << APPCAST
          <?xml version="1.0" encoding="utf-8"?>
          <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <title>Worklog Studio Windows Updates</title>
            <link>https://github.com/vavilov2212/worklog_studio</link>
            <description>Latest updates for Worklog Studio (Windows)</description>
            <language>en</language>
            <item>
              <title>Version ${VERSION}</title>
              <sparkle:releaseNotesLink>https://github.com/vavilov2212/worklog_studio/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
              <pubDate>${DATE}</pubDate>
              <enclosure
                url="${URL}"
                sparkle:version="${BUILD_NUMBER}"
                sparkle:shortVersionString="${VERSION}"
                length="${SIZE}"
                type="application/octet-stream"/>
            </item>
          </channel>
          </rss>
          APPCAST

          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add apps/worklog_studio/release/appcast_windows.xml
          git commit -m "release: update appcast_windows.xml for v${VERSION}"
          git push origin HEAD:${{ github.ref_name }}
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: auto-update appcast_windows.xml after each Windows release"
```

---

### Task 10: Clean Up publish.ps1

**Files:**
- Modify: `apps/worklog_studio/tool/windows/publish.ps1`

**Interfaces:**
- CI now owns `appcast_windows.xml` updates (Task 9) so `publish.ps1` must no longer stage that file

- [ ] **Step 1: Remove `release/appcast_windows.xml` from the `git add` line**

Find:
```powershell
git add pubspec.yaml release/appcast_windows.xml
```

Replace with:
```powershell
git add pubspec.yaml
```

- [ ] **Step 2: Verify no other appcast references remain**

```bash
grep -n "appcast" apps/worklog_studio/tool/windows/publish.ps1
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/tool/windows/publish.ps1
git commit -m "chore: remove manual appcast update from publish.ps1 (CI handles it)"
```

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Inno Setup script at `installer/worklog_studio.iss` | 7 |
| Per-user install, no UAC | 7 |
| Start Menu + Desktop shortcuts | 7 |
| Uninstaller in Add/Remove Programs | 7 (Inno Setup default with AppId) |
| Upgrade in place via `CloseApplications` | 7 |
| WinSparkle.dll bundled in installer | 2 (CMake POST_BUILD), 7 (`{#SourceDir}\*`) |
| `updater_plugin.cpp` implementing MethodChannel | 3 |
| `WinSparkle.h`, `.dll`, `.lib` committed | 1 |
| WinSparkle init/cleanup in main.cpp | 4 |
| `win_sparkle_set_installer_arguments(/VERYSILENT /NORESTART)` | 4 |
| UpdaterPlugin registered with Flutter engine | 5 |
| `checkForUpdates` wired to settings button | Already done in `general_settings_screen.dart` |
| `checkSilently` called on startup | 6 |
| Platform guard in SparkleBridge | 6 |
| Appcast URL points to installer .exe | 9 |
| `sparkle:version` = build number | 9 |
| CI: install Inno Setup, compile .iss | 8 |
| CI: upload installer artifact | 8 |
| CI: attach both ZIP and installer to release | 8 |
| CI: auto-update appcast after release | 9 |
| `publish.ps1`: remove manual appcast step | 10 |
| `build_number` in tag job outputs | 8 |

**Type consistency:** `UpdaterPlugin(flutter::BinaryMessenger*)` defined in Task 3, consumed in Task 5 - match confirmed. `needs.tag.outputs.build_number` added in Task 8 Step 1, consumed in Task 9 Step 1 - match confirmed.
