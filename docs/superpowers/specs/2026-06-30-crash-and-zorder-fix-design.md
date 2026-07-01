# Design: App Crash + Window Z-Order Fix

**Date:** 2026-06-30
**Branch:** dev

## Problem

Two independent bugs, both affecting the Windows desktop build:

1. **App quits silently** - confirmed repro: focus the activity window, press Enter. The entire OS process vanishes (tray icon gone, no crash dialog). Happens in release build v1.0.11-dev.8.

2. **Windows not appearing on top consistently** - both the mini panel and the activity window sometimes appear behind other apps when opened.

## Root Causes

### Crash

**RC-1: No global error handler.** `runner.dart` has no `runZonedGuarded` or `FlutterError.onError`. Any unhandled async exception in release mode kills the process silently with no log.

**RC-2: Followers run DB init before role detection.** `DatabaseProvider.getDatabase()` and `_initBackupService()` are called before `resolveStartupRole()` in `runner.dart`. This means the miniPanel and activity follower engines each open a SQLite connection and potentially trigger a file copy of the same database on startup - simultaneously with the leader. Any exception from this (file lock, copy conflict) escapes the outer `catch` in the runner and, with no zone error handler, kills the process.

### Z-order

**RC-3: HWND cache miss on first show.** `_nativeHandle()` in `ManagedPopoverWindow` calls `FindWindow` by title on every invocation. `setTitle()` is a plugin channel call - it returns when the Dart side completes, but Win32 may not have registered the title yet when `_applyAlwaysOnTop()` / `_applyFrameless()` call `FindWindow` immediately after `ShowWindow`. When `FindWindow` returns null, `SetWindowPos(HWND_TOPMOST)` is silently skipped.

**RC-4: Mini panel has no always-on-top mechanism.** `_miniPanelWindow` is constructed without `alwaysOnTop: true`, so it relies on `SW_SHOW` activation - which the existing code comments already document as inconsistent on Windows.

## Design

### Layer 1 - Error handling (`runner.dart`)

#### 1a. Role detection first

Add `final isFollower = args.firstOrNull == 'multi_window'` at the top of `run()`, before `_initDependencies()`. Gate the DB init + backup block behind `!isFollower`:

```dart
final isFollower = args.firstOrNull == 'multi_window';
try {
  if (!kIsWeb && !isFollower) {
    await getIt<UserRepository>();
    await _initBackupService();
    await DatabaseProvider.getDatabase();
  }
} catch (e, st) {
  l.e('Failed to bootstrap DB on startup', st);
}
```

Followers still go through `_initDependencies()` (DI wiring) and `_initRepositories()` (service locator), since they need those. Only the SQLite open and backup are skipped.

#### 1b. Global error zone

Set `FlutterError.onError` before `WidgetsFlutterBinding.ensureInitialized()`, then wrap the entire body of `run()` in `runZonedGuarded`. Both handlers call the same `_handleFatalError(error, stack)` helper which:

- Appends `[ISO-8601 timestamp]\n$error\n$stack\n---\n` to `%LOCALAPPDATA%\WorklogStudio\crash.log` via `dart:io`
- Also calls `l.e()` for debug-mode visibility
- Does NOT re-throw - goal is survival and a readable log, not a clean shutdown

The log file location: `Platform.environment['LOCALAPPDATA']` + `\WorklogStudio\crash.log`. Create the directory if it does not exist.

### Layer 2 - Window presentation

#### 2a. HWND caching in `ManagedPopoverWindow`

Add `int? _cachedHwnd` field. Modify `_nativeHandle()`:

```
if _cachedHwnd is set: return it
otherwise: call FindWindow
  on success: store in _cachedHwnd, return it
  on failure: log and return null
```

Clear `_cachedHwnd` in `reconcile()` alongside `windowId = null` (native window is gone, HWND is stale).

This means the `_applyAlwaysOnTop()` call inside `show()` reuses the HWND already resolved moments earlier for `ShowWindow` - no second `FindWindow` race.

#### 2b. Always-on-top for the mini panel

Add `alwaysOnTop: true` to the `_miniPanelWindow` constructor in `windows_desktop_service.dart`:

```dart
late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
  role: 'miniPanel',
  computeFrame: _computeFrameNearTray,
  alwaysOnTop: true,           // <-- add
);
```

No other changes needed - the watchdog re-assertion and `_applyAlwaysOnTop()` path already handle everything for the activity window; the mini panel just needs the flag.

## Files Changed

| File | Change |
|------|--------|
| `apps/worklog_studio/lib/runner/runner.dart` | Add `isFollower` guard, `runZonedGuarded`, `FlutterError.onError`, `_handleFatalError` |
| `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart` | Add `_cachedHwnd` field, update `_nativeHandle()` and `reconcile()` |
| `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` | Add `alwaysOnTop: true` to `_miniPanelWindow` |

## Test Plan

- `ManagedPopoverWindow` tests (via `WindowsDesktopService` test seams):
  - After `reconcile()` resets `windowId`, `_cachedHwnd` is also null
  - `miniPanelWindowForTesting.alwaysOnTop` is `true`
- Runner changes are wiring - verified manually by confirming the crash log file is created and follower engines no longer open SQLite connections on startup
- Z-order verified manually: open mini panel and activity window with another app in the foreground; both should appear on top

## Out of Scope

- Firebase Crashlytics integration (deferred)
- Any change to the Enter key flow itself - with RC-1 and RC-2 fixed the crash should be resolved; if it persists the crash log will identify the actual throw site
