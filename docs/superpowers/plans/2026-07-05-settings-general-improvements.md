# Settings General Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-select the General sub-page when Settings is tapped in the sidebar, and display app version + GitHub release link on the General settings page.

**Architecture:** Three isolated edits across two existing files plus one file extension. No new dependencies, no new test files (all changes are UI-only or wrap already-untested `Process.run` calls, which are exempt per `apps/worklog_studio/CLAUDE.md`).

**Tech Stack:** Flutter/Dart, existing `SparkleBridge` native channel, existing `Process.run` pattern from `reveal_in_file_manager.dart`, UI kit `TextLink` component.

## Global Constraints

- Windows-only development environment; use backslashes in file paths when referencing from shell.
- Never run bare `flutter` or `dart` - always prefix with `fvm`.
- All hardcoded user-facing strings must end with `// TODO: l10n`.
- No new pubspec dependencies.
- Do not add `Co-Authored-By: Claude` to commit messages.

---

### Task 1: Add `openUrl` helper to existing file

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/reveal_in_file_manager.dart`

**Interfaces:**
- Produces: `Future<void> openUrl(String url)` — opens a URL in the default OS browser; best-effort, failures swallowed.

- [ ] **Step 1: Add `openUrl` to the existing file**

Append after the closing brace of `revealInFileManager` in `apps/worklog_studio/lib/core/services/desktop/reveal_in_file_manager.dart`:

```dart
/// Opens [url] in the default OS browser.
///
/// Best-effort convenience — failures are swallowed since this is never
/// part of a critical flow.
Future<void> openUrl(String url) async {
  if (kIsWeb) return;
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  } catch (_) {}
}
```

- [ ] **Step 2: Verify the file compiles**

```
cd apps/worklog_studio && fvm flutter analyze lib/core/services/desktop/reveal_in_file_manager.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add apps/worklog_studio/lib/core/services/desktop/reveal_in_file_manager.dart
git commit -m "feat: add openUrl helper alongside revealInFileManager"
```

---

### Task 2: Show app version and GitHub release link on General settings page

**Files:**
- Modify: `apps/worklog_studio/lib/feature/settings/general_settings_screen.dart`

**Interfaces:**
- Consumes: `SparkleBridge.getVersion()` → `Future<String>` (already imported).
- Consumes: `openUrl(String url)` from Task 1.
- Consumes: `TextLink` from `worklog_studio_style_system`.

- [ ] **Step 1: Add the version state field and load it in `initState`**

In `_GeneralSettingsScreenState`, add `String? _version` alongside the existing `_dbDirPath`/`_backupsDirPath` fields, and load it in `initState`:

```dart
// Add import at top of file:
import 'package:worklog_studio/core/services/desktop/reveal_in_file_manager.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
```

```dart
// In state class, add field:
String? _version;
```

```dart
// In initState, add alongside _loadDirPaths():
_loadVersion();
```

```dart
// Add the new method to the state class:
Future<void> _loadVersion() async {
  final version = await SparkleBridge.getVersion();
  if (!mounted) return;
  setState(() => _version = version);
}
```

- [ ] **Step 2: Add the version row to the `build` method**

In the `build` method of `_GeneralSettingsScreenState`, insert the version row between the page title and the "Check for updates" button. Replace:

```dart
Text('General', style: theme.commonTextStyles.displayLarge), // TODO: l10n
SizedBox(height: theme.spacings.x2l),
Row(
  children: [
    OutlinedButton.icon(
```

With:

```dart
Text('General', style: theme.commonTextStyles.displayLarge), // TODO: l10n
SizedBox(height: theme.spacings.md),
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'Version ', // TODO: l10n
      style: theme.commonTextStyles.caption.copyWith(
        color: theme.colorsPalette.text.secondary,
      ),
    ),
    Text(
      _version ?? '-',
      style: theme.commonTextStyles.captionBold.copyWith(
        color: theme.colorsPalette.text.primary,
      ),
    ),
    SizedBox(width: theme.spacings.md),
    TextLink(
      label: 'Release notes', // TODO: l10n
      onTap: () => openUrl('https://github.com/vavilov2212/worklog_studio/releases'),
      style: theme.commonTextStyles.caption,
    ),
  ],
),
SizedBox(height: theme.spacings.x2l),
Row(
  children: [
    OutlinedButton.icon(
```

- [ ] **Step 3: Verify the file compiles**

```
cd apps/worklog_studio && fvm flutter analyze lib/feature/settings/general_settings_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```
git add apps/worklog_studio/lib/feature/settings/general_settings_screen.dart
git commit -m "feat: show app version and GitHub release link on General settings page"
```

---

### Task 3: Auto-select General when Settings is tapped

**Files:**
- Modify: `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`

**Interfaces:**
- Consumes: `isSettingsRoute(AppRoute)` — already defined in the same file.
- Consumes: `widget.onRouteSelected(AppRoute)` — already wired up.

- [ ] **Step 1: Update the Settings parent item `onTap`**

In `_settingsNavGroup()` in `_SidebarNavigationState`, replace the existing `onTap` callback:

```dart
// BEFORE:
onTap: () {
  if (_collapsed) {
    setState(() {
      _collapsed = false;
      _settingsExpanded = true;
    });
  } else {
    setState(() => _settingsExpanded = !_settingsExpanded);
  }
},
```

```dart
// AFTER:
onTap: () {
  if (_collapsed) {
    setState(() {
      _collapsed = false;
      _settingsExpanded = true;
    });
  } else {
    setState(() => _settingsExpanded = !_settingsExpanded);
  }
  if (!isSettingsRoute(widget.currentRoute)) {
    widget.onRouteSelected(AppRoute.settingsGeneral);
  }
},
```

The guard `!isSettingsRoute(widget.currentRoute)` ensures that if the user is already on General or Hotkeys, tapping the Settings parent just toggles expansion without resetting the active page.

- [ ] **Step 2: Verify the file compiles**

```
cd apps/worklog_studio && fvm flutter analyze lib/feature/app/layout/app_shell.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add apps/worklog_studio/lib/feature/app/layout/app_shell.dart
git commit -m "feat: auto-select General settings when Settings nav item is tapped"
```
