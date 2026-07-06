# Settings - General Page Improvements

**Date:** 2026-07-05

## Problem

1. Clicking "Settings" in the sidebar expands the sub-nav but does not select any sub-item, leaving the user on whatever page they were on before with no active route under Settings.
2. The General settings page shows no app version information and no link to the GitHub releases page.

## Scope

Three small, contained changes. No new dependencies. No new test coverage required (all UI-only or wrapping already-untested `Process.run` calls).

---

## Change 1 - Auto-select General when Settings is tapped

**File:** `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`

In `_settingsNavGroup()`, the Settings parent item `onTap` has two branches:

- **Collapsed sidebar:** expands sidebar + opens settings group, but does not navigate.
- **Expanded sidebar:** toggles `_settingsExpanded`, does not navigate.

**Fix:** In both branches, after the expand/toggle, if the current route is not already a settings route (`!isSettingsRoute(widget.currentRoute)`), call `widget.onRouteSelected(AppRoute.settingsGeneral)`.

This means the first tap on Settings always lands on General. Subsequent taps (when already on a settings route) just toggle the expansion without changing the active page.

---

## Change 2 - Version display and GitHub release link

**File:** `apps/worklog_studio/lib/feature/settings/general_settings_screen.dart`

Add `String? _version` to `_GeneralSettingsScreenState`.

In `initState`, call `SparkleBridge.getVersion()` and store the result in `_version` (set via `setState` when the future resolves, guard with `mounted`).

Display above the existing "Check for updates" button:

```
Version 1.0.12-dev.6+86    [Release notes ↗]
[Check for updates]
```

- Version label: `caption` text style, `text.secondary` color.
- Version value: `captionBold` text style, `text.primary` color. Show a muted placeholder while loading.
- "Release notes" link: `TextLink` component from the UI kit, opens `https://github.com/vavilov2212/worklog_studio/releases` via `openUrl`.
- Version row and link are on the same horizontal line (a `Row` with `MainAxisSize.min`, spaced by `spacings.md`).

---

## Change 3 - openUrl helper

**File:** `apps/worklog_studio/lib/core/services/desktop/reveal_in_file_manager.dart`

Add `openUrl(String url)` function to the existing file. Implementation mirrors `revealInFileManager` using the same `Process.run` calls:

- Windows: `Process.run('explorer.exe', [url])`
- macOS: `Process.run('open', [url])`
- Linux: `Process.run('xdg-open', [url])`

No new file. Best-effort, failures swallowed (same contract as `revealInFileManager`).

---

## Non-changes

- The "Check for updates" button is kept as-is (already wired to `SparkleBridge.checkForUpdates()`).
- No button style migration - out of scope for this task.
- No `package_info_plus` - version comes from `SparkleBridge.getVersion()` which is already used.
- GitHub URL is hardcoded to the releases list (`/releases`), not a specific tag, so it remains valid regardless of tag naming conventions.
