# Worklog Studio

**Worklog Studio** — a lightweight, distraction-free desktop application designed for professionals to track work time and manage tasks efficiently. Built for speed and focus, it helps you stay in the flow without unnecessary complexity.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](https://apple.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Key Features
- **Effortless Time Tracking**: Start and stop sessions with minimal effort.
- **Fast Work Logs**: Designed for quick data entry to minimize friction.
- **Distraction-Free**: Minimal interface, allowing you to focus on your work.
- **Built for macOS**: Native-like feel with smooth performance.
- **Automatic Updates**: Seamless updates via Sparkle integration.

---

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev/)
- **Target Platform**: macOS
- **Backend**: Firebase (Authentication & Data)
- **Updates**: [Sparkle Framework](https://sparkle-project.org/)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- macOS environment.

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

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📦 Releases & Development
For information on building, packaging, and the automatic update process, please refer to the [Release Guide](apps/worklog_studio/tool/README.md).

---

## 📌 Status
*Work in progress. Current focus: stability, performance, and day-to-day usability.*
