# Windows Scripts

Scripts in `apps/worklog_studio/tool/windows/`, invoked from `apps/worklog_studio/` (the same directory as `pubspec.yaml`).

---

## Table of Contents

- [Testing](#testing)
- [Version and Release](#version-and-release)
- [App Icons](#app-icons)
- [Tray Icons](#tray-icons)

---

## Testing

### run_tests.ps1

Runs the Flutter unit test suite with structured, colour-coded output grouped by file and test group. Uses `fvm flutter test --reporter json` under the hood and formats the JSON event stream live.

```powershell
# From apps\worklog_studio\:
.\tool\windows\run_tests.ps1                                       # all tests
.\tool\windows\run_tests.ps1 test/core/hotkey_service_test.dart   # specific file
.\tool\windows\run_tests.ps1 test/core/ test/feature/desktop/     # specific folders
```

What you see:

- Cyan file banners separating each test file
- Bold yellow group headers for each `group()` block
- Green `✓` / red `✗` per test with per-test millisecond timing
- `debugPrint` output shown in dim text directly below the test that emitted it
- A colour-coded summary line at the end (`N passed`, `N failed`, elapsed time)

Exits with code `1` if any test fails, so it can be used as a gate in scripts.

### Where tests run automatically

The bare `fvm flutter test test/core/ test/feature/ --reporter expanded` command is called in two other places:

| Trigger | Location |
|---|---|
| Every push/PR | `.github/workflows/release.yml` (GitHub CI) |
| Before each version bump | `tool/windows/bump.ps1` (blocks on failure) |

---

## Version and Release

### bump.ps1

Bumps the version string in `pubspec.yaml`, increments the build number, then runs the full test suite. Prints the before/after version and exits non-zero if tests fail.

```powershell
.\tool\windows\bump.ps1 dev      # 1.0.1 -> 1.0.2-dev.1  /  1.0.2-dev.3 -> 1.0.2-dev.4
.\tool\windows\bump.ps1 release  # 1.0.2-dev.5 -> 1.0.2
.\tool\windows\bump.ps1 patch    # 1.0.1 -> 1.0.2
.\tool\windows\bump.ps1 minor    # 1.0.1 -> 1.1.0
.\tool\windows\bump.ps1 major    # 1.0.1 -> 2.0.0
.\tool\windows\bump.ps1 2.3.0    # set exact version
```

After `bump.ps1` succeeds, run `publish.ps1` to commit and push - CI handles the actual Windows and macOS build and GitHub release.

### publish.ps1

Commits the `pubspec.yaml` change, creates a version tag (e.g. `v1.0.2-dev.4`), and pushes both to `origin`. Triggering CI is the intended side-effect.

```powershell
.\tool\windows\publish.ps1
```

### release.ps1

Creates a GitHub release for the current tag and uploads the packaged artifact. Use when CI is not configured or you need to publish manually.

```powershell
.\tool\windows\release.ps1
```

---

## App Icons

The app ships two icon variants: **prod** (default, committed as the live icon) and **dev** (same artwork with a red "DEV" ribbon). Both platforms' native build systems are not flavor-aware, so the live icon files (`windows\runner\resources\app_icon.ico` and `macos\Runner\Assets.xcassets\AppIcon.appiconset\*.png`) must be swapped on disk before building or running the target flavor.

### select_app_icon.ps1

Swaps the active app icon between `prod` and `dev`. The macOS equivalent is `tool/macos/select_app_icon.sh`.

```powershell
# From the repo root:
powershell apps/worklog_studio/tool/windows/select_app_icon.ps1 -Flavor dev
powershell apps/worklog_studio/tool/windows/select_app_icon.ps1 -Flavor prod
```

### When this runs automatically

You only need to call the script manually when running `flutter run` / `flutter build` directly from a terminal. Everywhere else it is wired up:

- **VS Code debugger (F5)**: `.vscode/launch.json` runs a `preLaunchTask` (`select-app-icon-dev` / `select-app-icon-prod` in `.vscode/tasks.json`) that picks the right script for your OS before every launch.
- **Packaged builds**: `tool/macos/build.sh` and the CI release workflow already call the matching script based on the version being built.
- **Git commits**: a pre-commit hook (`.githooks/pre-commit`) force-resets the live icon files back to prod before every commit, so a forgotten `-Flavor dev` from a local debug session is never committed by accident. `fvm exec melos bootstrap` wires this up automatically (`git config core.hooksPath .githooks` runs as a post-bootstrap hook in the root `pubspec.yaml`).

### Regenerating icon artwork

Only needed when the source artwork changes (`assets/branding/app_icon_prod_master.png`). After updating the prod master:

```powershell
pwsh apps/worklog_studio/tool/windows/generate_dev_icon_master.ps1
```
Re-draws the DEV ribbon over the new prod master.

```powershell
pwsh apps/worklog_studio/tool/windows/generate_dev_icon_set.ps1
```
Regenerates `AppIconDev.appiconset` and `app_icon_dev.ico`.

The prod-side `AppIconProd.appiconset` / `app_icon_prod.ico` backup files must be updated manually (copy the new live prod files over them) since they are the restore source for `select_app_icon.ps1 -Flavor prod`.

---

## Tray Icons

Tray icons (`assets/app_icon_idle.ico`, `assets/app_icon_running.ico`) are committed binaries. Regenerate them after editing the source PNGs:

```powershell
pwsh apps/worklog_studio/tool/windows/generate_tray_icons.ps1
```
Regenerates the prod tray icons from `assets/app_icon_idle.png` / `assets/app_icon_running.png`. Not run in CI - the `.ico` outputs are deterministic and already committed.

```powershell
pwsh apps/worklog_studio/tool/windows/generate_dev_tray_icons.ps1
```
Regenerates the dev tray icon variants (`app_icon_idle_dev.{png,ico}` / `app_icon_running_dev.{png,ico}`) with an amber badge dot (the "DEV" text used on the full app icon is not legible at tray size). The active flavor (`Flavor.development` / `Flavor.production`) picks the right asset at runtime - no manual swap required, unlike the app/dock icon.
