# Worklog Studio

**Worklog Studio** — a lightweight, distraction-free desktop application designed for professionals to track work time and manage tasks efficiently. Built for speed and focus, it helps you stay in the flow without unnecessary complexity.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](https://apple.com/)
[![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Tests](https://github.com/vavilov2212/worklog_studio/actions/workflows/release.yml/badge.svg)](https://github.com/vavilov2212/worklog_studio/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Key Features
- **Effortless Time Tracking**: Start and stop sessions with minimal effort.
- **Fast Work Logs**: Designed for quick data entry to minimize friction.
- **Distraction-Free**: Minimal interface, allowing you to focus on your work.
- **Built for macOS & Windows**: Native-like feel with smooth performance.
- **Automatic Updates**: Seamless updates via Sparkle integration.

---

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev/)
- **Target Platform**: macOS & Windows
- **Backend**: Firebase (Authentication & Data)
- **Updates**: [Sparkle Framework](https://sparkle-project.org/)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- macOS or Windows environment.

### Running Locally
1. Clone the repository:
   ```bash
   git clone https://github.com/vavilov2212/worklog_studio
   cd worklog_studio
   ```
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d macos
   flutter run -d windows
   ```

### Running Locally using fvm & melos
1. Clone the repository:
   ```bash
   git clone https://github.com/vavilov2212/worklog_studio
   cd worklog_studio
   ```
2. Add melos to PATH variable in the windows system environment variables:
   ```bash
   C:\Users\vavilov2212\AppData\Local\Pub\Cache\bin
   ```
3. Bootstrap project:
   ```bash
   dart pub global activate melos
   fvm flutter pub get
   fvm exec melos clean
   fvm exec melos bootstrap
   ```
4. Generate code (freezed, json_serializable, retrofit_generator):
   ```bash
   fvm exec melos exec -- "fvm dart run build_runner build --delete-conflicting-outputs"
   # OR if build_runner fails on build hooks
   fvm exec melos exec -- "fvm dart run build_runner build --delete-conflicting-outputs --force-jit"
   ```
   If still fails, then from the root dir:
   ```bash
   fvm dart run build_runner build --delete-conflicting-outputs --force-jit --build-filter="packages/worklog_studio_style_system/**"
   fvm dart run build_runner build --delete-conflicting-outputs --force-jit --build-filter="packages/vector_svg/**"
   fvm dart run build_runner build --delete-conflicting-outputs --force-jit --build-filter="apps/worklog_studio/**"
   ```
5. Run the app:
   ```bash
   fvm flutter run -d macos
   fvm flutter run -d windows
   ```

---

## 📦 Dependency Management (Melos)

This project uses a Dart workspace with Melos. Dependencies must be added consistently across packages — do not edit each `pubspec.yaml` manually.

### Add a dependency to all packages

```bash
melos exec -- flutter pub add intl:^0.20.2
```

This runs `flutter pub add` in every package in the workspace.

More about Melos: https://melos.invertase.dev/

---

### Add a dependency to a specific package

```bash
melos exec --scope="worklog_studio" -- flutter pub add http
```

or manually:

```bash
cd apps/worklog_studio
flutter pub add http
```

---

### Update dependencies

```bash
melos exec -- flutter pub upgrade
```

See Dart workspaces: https://dart.dev/tools/pub/workspaces

---

### Important notes

- Keep shared dependencies (e.g. `intl`, `http`, `collection`) on the same version across all packages
- Do not add dependencies to the root `pubspec.yaml` — it is not used for resolution
- Use Melos to avoid version conflicts

Flutter packages guide: https://docs.flutter.dev/packages-and-plugins/using-packages

---

## Troubleshooting

### Windows

#### Debug build

```bash
√ Built build\windows\x64\runner\Debug\worklog_studio.exe
Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.
Error launching application on Windows.
```
The error string error while loading shared libraries: ... cannot open shared object file is a dead giveaway about your terminal environment. This is a classic log output from Linux/POSIX systems.

Only Git Bash, MSYS2, or WSL would display this kind of text. A native Windows application compiled via MSVC is a pure Win32 binary. When you run it inside terminal emulators like Git Bash, their internal compatibility layer tries to handle the launch in its own way, gets confused by the paths to the dynamic-link libraries (.dll), and crashes with a Linux-style error message.

Choose PowerShell or Command Prompt.
In the newly opened native window, enter the launch command:

```powershell
cd apps/worklog_studio
fvm flutter run -d windows -t lib/main_development.dart --flavor development --no-enable-impeller --no-dds
``` 

#### PowerShell Script Execution

If you see an error like running scripts is disabled on this system when running .ps1 files, run this command in PowerShell to allow local scripts: 

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then try running your script again:

```powershell
cd apps\worklog_studio
.\tool\windows\build.ps1 dev
```

---

## 🎨 App Icons

The app ships two icon variants: **prod** (default, committed as the live icon) and **dev** (same artwork with a red "DEV" ribbon). Both platforms' native build systems are not flavor-aware, so the live icon files (`windows\runner\resources\app_icon.ico` and `macos\Runner\Assets.xcassets\AppIcon.appiconset\*.png`) must be swapped on disk before building/running the target flavor.

There's a separate, native switcher script per platform — no cross-platform runtime dependency required:
- **Windows**: `tool/windows/select_app_icon.ps1` (plain PowerShell, ships with Windows)
- **macOS**: `tool/macos/select_app_icon.sh` (plain bash, ships with macOS)

Switching the icon is automated:
- **VS Code debugger (F5)**: `.vscode/launch.json` runs a `preLaunchTask` (`select-app-icon-dev`/`select-app-icon-prod` in `.vscode/tasks.json`) before every launch, which picks the right script for your OS automatically.
- **Packaged builds**: `tool/windows/build.ps1`, `tool/macos/build.sh`, and the CI release workflow already call the matching script based on the version being built.
- **Git commits**: a pre-commit hook (`.githooks/pre-commit`) force-resets the live icon files back to prod before every commit, so a forgotten `-Flavor dev` switch from a local debug session never gets committed by accident. One-time setup after cloning: `git config core.hooksPath .githooks`.

### When to run this manually
Only needed when running `flutter run`/`flutter build` directly from a terminal instead of the VS Code debugger:
- Before `flutter run -d windows --flavor development` (switch to dev icon):
  ```powershell
  powershell apps/worklog_studio/tool/windows/select_app_icon.ps1 -Flavor dev
  ```
- Before `flutter run -d macos --flavor development`:
  ```bash
  bash apps/worklog_studio/tool/macos/select_app_icon.sh dev
  ```
- Pass `prod`/`-Flavor prod` the same way to switch back (or restore after a dev session).
- `tool/windows/build.ps1` and `tool/macos/build.sh` (and the CI release workflow) already call this automatically based on the version being built — no manual step needed for packaged releases.

### When to regenerate the icon artwork
Only needed if the source artwork changes (`assets/branding/app_icon_prod_master.png`). After updating the prod master:
```powershell
pwsh apps/worklog_studio/tool/windows/generate_dev_icon_master.ps1   # re-draws the DEV ribbon over the new prod master
pwsh apps/worklog_studio/tool/windows/generate_dev_icon_set.ps1      # regenerates AppIconDev.appiconset + app_icon_dev.ico
```
The prod-side `AppIconProd.appiconset` / `app_icon_prod.ico` backups must be updated manually (copy the new live prod files over them) since they are the restore source for `select_app_icon.ps1 -Flavor prod`.

Tray icons (`assets/app_icon_idle.ico`, `assets/app_icon_running.ico`) are also committed binaries — regenerate them locally with `pwsh apps/worklog_studio/tool/windows/generate_tray_icons.ps1` after editing `assets/app_icon_idle.png` / `assets/app_icon_running.png`. This is not run in CI since the `.ico` outputs are deterministic and already committed.

The tray icon also gets a DEV marker (small amber badge dot, since "DEV" text isn't legible at tray size) — `app_icon_idle_dev.{png,ico}` / `app_icon_running_dev.{png,ico}`, regenerated via `pwsh apps/worklog_studio/tool/windows/generate_dev_tray_icons.ps1`. The active flavor (`Flavor.development`/`Flavor.production`) picks the right asset at runtime — no manual swap needed, unlike the app/dock icon. macOS's idle tray state reuses the same `AppIcon.appiconset` as the dock icon, so it already shows the DEV ribbon for free once `select_app_icon.sh -Flavor dev` has been run; only the "running" tray state needed a dedicated dev asset (`AppDelegate.swift`).

---

## 🗄️ Database & Backups

The app stores its data in a local SQLite file (`worklog.db`) under the OS application-support directory. **Dev and prod flavors each get their own subfolder** (`Worklog_studio` vs `Worklog_studio-dev`, see `Flavor.appFolder` in `lib/core/environment/flavors.dart`), so running the dev build never touches the production database — they're fully isolated, no manual setup required.

### Backups
- **Automatic**: on every app start, the previous session's DB file is snapshotted into `<appFolder>/backups/` before a new connection opens (`BackupService.backupOnStartup`, wired in `lib/runner/runner.dart`). Safe by construction — the file is closed and untouched at that point.
- **Manual**: the Settings screen has "Backup now" (snapshot on demand) and "Restore from backup" (pick a timestamped snapshot, then restart the app for it to take effect — the live DB connection doesn't hot-swap).
- **Rotation**: only the 10 most recent backups are kept per flavor; older ones are pruned automatically after each backup (`BackupService`/`FileBackupRepository` in `lib/core/services/` and `lib/data/backup/`).

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📦 Releases & Development
For information on building, packaging, and the automatic update process, please refer to the [Release Guide](apps/worklog_studio/tool/README.md).

---

## 📌 Status
*Work in progress. Current focus: stability, performance, and day-to-day usability.*
