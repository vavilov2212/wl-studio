# Idle Detection and Windows Auto-Start Design

**Date:** 2026-08-01
**Status:** Approved

---

## Overview

Adds two related features to Worklog Studio:

1. **Windows auto-start on boot** - registers the app in the Windows startup registry so it launches automatically when the user logs in.
2. **System-wide idle detection with resolution dialog** - polls for mouse/keyboard activity using Win32 APIs, accounts for sleep/wake cycles, and presents a native popup dialog when the user returns from an idle period while time tracking is active.

---

## 1. Architecture

### Approach: Separate `IdleFlowCubit`

Idle detection logic lives in a new `IdleFlowCubit` rather than inside `TimeTrackerBloc`. This keeps `TimeTrackerBloc` focused on entry CRUD and avoids expanding its state surface.

**Data flow:**

```
WindowsIdleMonitorPlugin (C++)
    |  MethodChannel: worklog_studio/idle_monitor
    v
IdleMonitor (Dart interface)
    |
    v
IdleFlowCubit
    |-- on threshold reached --> saves idleStartTime + current entry metadata
    |-- on user returned     --> triggers IdleResolutionWindow (C++) via MethodChannel
    |-- on resolution choice --> dispatches to TimeTrackerBloc
    v
TimeTrackerBloc  (timer start/stop/restart, entry creation)
```

`TimeTrackerBloc` loses its existing `_idleMonitor` field and `_idleSubscription` - those responsibilities move entirely to `IdleFlowCubit`.

---

## 2. Windows Idle Monitor Plugin (C++)

Replaces the current `NoOpIdleMonitor` on Windows with a real implementation.

### File location

`apps/worklog_studio/windows/runner/idle_monitor_plugin.h/.cpp`

Registered in `flutter_window.cpp` alongside `UpdaterPlugin`.

### MethodChannel

Name: `worklog_studio/idle_monitor`

| Direction | Name | Payload |
|-----------|------|---------|
| Dart -> C++ | `start` | `{ "thresholdSeconds": int }` |
| Dart -> C++ | `stop` | none |
| C++ -> Dart | `onIdleThresholdReached` | `{ "idleSeconds": int, "timestamp": int (epoch ms) }` |
| C++ -> Dart | `userReturnedFromIdle` | none |

### Idle polling

A dedicated background thread (created with `CreateThread`) polls `GetLastInputInfo` every 5 seconds. Idle duration is computed as `GetTickCount() - lastInputInfo.dwTime`. When this exceeds the configured threshold, `onIdleThresholdReached` is fired once and polling pauses until the user returns.

Return detection: after the threshold fires, the thread watches for the tick count to change (meaning a new input event occurred). When it does, it fires `userReturnedFromIdle` and resumes normal polling.

### Sleep/wake correction

The plugin registers for `WM_POWERBROADCAST` in the Win32 message loop (handled inside `FlutterWindow::MessageHandler`):

- `PBT_APMSUSPEND`: saves `suspendTime = GetTickCount64()`
- `PBT_APMRESUMESUSPEND`: computes `sleepDurationMs = GetTickCount64() - suspendTime` and adds it to an idle accumulator

This ensures that sleep time counts as idle time even though `GetLastInputInfo` tick count does not advance during sleep.

### `idle_event.dart` additions

`UserReturnedFromIdle` is added as a new `IdleEvent` subclass:

```dart
class UserReturnedFromIdle extends IdleEvent {
  const UserReturnedFromIdle();
}
```

`WindowsIdleMonitor` receives the `userReturnedFromIdle` MethodChannel callback and emits `UserReturnedFromIdle()` on its `onIdleEvent` stream. `IdleFlowCubit` filters the stream for this type to trigger the resolution window.

### Dart-side implementation

`WindowsIdleMonitor` (in `lib/core/services/idle_monitor/windows_idle_monitor.dart`) implements `IdleMonitor` and is registered as `@LazySingleton(as: IdleMonitor)` for Windows builds. The existing `NoOpIdleMonitor` registration in `runner.dart` is removed. The `service_locator.config.dart` file is updated by hand (build_runner is broken per POST_MORTEM 2.3).

---

## 3. Idle Resolution Window (C++)

A native Win32 popup window, consistent with `NativeActivityWindow` and `NativeMiniPanel`.

### File location

`apps/worklog_studio/windows/runner/idle_resolution_window.h/.cpp`

### MethodChannel

Name: `worklog_studio/idle_resolution`

| Direction | Name | Payload |
|-----------|------|---------|
| Dart -> C++ | `show` | `{ "idleMinutes": int }` |
| Dart -> C++ | `hide` | none |
| C++ -> Dart | `onResolutionChoice` | `{ "choice": "keep" \| "discard" \| "logToTask", "taskName": string? }` |

### Appearance

- Positioned bottom-right near the system tray (same anchor logic as `NativeActivityWindow`)
- Header: "You were away for X minutes"
- Three full-width stacked buttons:
  1. "Keep tracking" - idle time included, timer continues as-is
  2. "Discard idle time" - entry ends at idle start, new entry begins for same task
  3. "Log to another task..." - expands inline to show a task name text input field; user types/selects a task name, then confirms
- No close button; ESC maps to "Keep tracking" as a safe fallback
- The window is `WS_POPUP | WS_BORDER`, always on top, non-resizable

### Option 3 - task input

The expanded state shows a single-line edit control (`WC_EDIT`). On confirm, the typed task name is sent back in `onResolutionChoice` with `choice: "logToTask"` and `taskName: <value>`. Entry creation for that task is handled on the Dart side by `IdleFlowCubit`.

---

## 4. Mutual Exclusion of Native Windows

Both `IdleResolutionWindow` and `NativeActivityWindow` respond to "user just returned" events and must not appear simultaneously. The idle resolution dialog has higher priority.

### Coordinator

A `NativeWindowCoordinator` singleton (C++) holds a reference to the currently visible native popup window. Before any native window shows itself, it calls `NativeWindowCoordinator::canShow(WindowType)`. The coordinator returns `false` if a higher-priority window is already visible.

Priority order (highest first): `IdleResolutionWindow` > `NativeActivityWindow`.

### Behavior

- `IdleResolutionWindow.show()` is called: if `NativeActivityWindow` is visible, it is hidden first. The coordinator registers `IdleResolutionWindow` as the active window.
- `NativeActivityWindow.show()` is called: if `IdleResolutionWindow` is visible, the activity window cancels (does not queue or defer).
- After the user resolves the idle dialog, `IdleFlowCubit` calls `reminderService.resetTimer()` on the Dart side so the reminder interval restarts from zero. This prevents `NativeActivityWindow` from appearing immediately after idle resolution.

---

## 5. `IdleFlowCubit`

**Location:** `apps/worklog_studio/lib/feature/time_tracker/cubit/idle_flow_cubit.dart`

### State (hand-written Freezed)

```dart
@freezed
abstract class IdleFlowState with _$IdleFlowState {
  const factory IdleFlowState.idle() = _Idle;
  const factory IdleFlowState.awaitingResolution({
    required DateTime idleStartTime,
    required String taskId,
    required String projectId,
  }) = _AwaitingResolution;
  const factory IdleFlowState.resolved() = _Resolved;
}
```

### Responsibilities

- Subscribes to `IdleMonitor.onIdleEvent`
- On `IdleThresholdReached` while `TimeTrackerBloc` is running: records `idleStartTime` and current entry metadata, emits `awaitingResolution`
- On `userReturnedFromIdle` (forwarded from the Dart `IdleMonitor` stream): calls `idleResolutionChannel.show(idleMinutes)` to trigger the native window
- Listens to `worklog_studio/idle_resolution` MethodChannel for `onResolutionChoice`:
  - `keep`: emits `resolved`, no timer change
  - `discard`: dispatches `TimeTrackerStopped(at: idleStartTime)` then `TimeTrackerStarted(taskId, projectId)` to `TimeTrackerBloc`
  - `logToTask`: dispatches `TimeTrackerStopped(at: idleStartTime)`, creates an entry for the idle period under `taskName` (via `TimeEntryRepository` directly), then dispatches `TimeTrackerStarted(taskId, projectId)` to resume original task
- In all resolution paths, calls `reminderService.resetTimer()`

### DI registration

`IdleFlowCubit` is `@injectable`, provided via `get_it`. It is instantiated in `runner.dart` and started when `TimeTrackerBloc` starts. `service_locator.config.dart` is updated by hand.

---

## 6. Settings

### New `SettingsKeys` entries

```dart
static const String idleThresholdMinutes = 'idleThresholdMinutes';
static const String launchAtStartup = 'launchAtStartup';
```

### UI - `GeneralSettingsScreen`

Two new rows added to the existing settings screen:

**Idle threshold:**
- Label: "Mark as idle after"
- Control: numeric text field + "minutes" suffix label
- Default: 10, min: 1, max: 120
- On change: persisted via `SettingsRepository`, `IdleFlowCubit` restarts `IdleMonitor` with the new threshold

**Launch at startup:**
- Label: "Launch at startup"
- Control: toggle switch
- On enable: calls `StartupService.enable()`
- On disable: calls `StartupService.disable()`

---

## 7. Auto-Start (Registry)

### `StartupService`

**Location:** `apps/worklog_studio/lib/core/services/startup/startup_service.dart`

Thin Dart wrapper over a MethodChannel `worklog_studio/startup`.

```dart
abstract class StartupService {
  Future<void> enable();
  Future<void> disable();
  Future<bool> isEnabled();
}
```

`WindowsStartupService` is the concrete implementation registered for Windows.

### C++ handler

Registered in `flutter_window.cpp`. Reads/writes:

```
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
Value name: WorklogStudio
Value data: "<path-to-exe>"
```

`enable` - writes the value using `RegSetValueExW`.
`disable` - deletes the value using `RegDeleteValueW`.
`isEnabled` - queries the value with `RegQueryValueExW`, returns bool.

The exe path is obtained via `GetModuleFileNameW(NULL, ...)` at runtime so it is always correct regardless of install location.

---

## 8. Sequence Diagram - Idle Return Flow

```
User goes idle (>= threshold)
    WindowsIdleMonitorPlugin fires onIdleThresholdReached
    IdleFlowCubit receives event, records idleStartTime + entry metadata
    IdleFlowCubit emits awaitingResolution

User returns (mouse/keyboard activity detected)
    WindowsIdleMonitorPlugin fires userReturnedFromIdle
    IdleFlowCubit calls IdleResolutionWindow.show(idleMinutes)
    NativeWindowCoordinator: hides NativeActivityWindow if visible
    IdleResolutionWindow appears (native Win32, near tray)

User picks "Discard idle time"
    IdleResolutionWindow sends onResolutionChoice(choice: discard)
    IdleFlowCubit dispatches TimeTrackerStopped(at: idleStartTime)
    IdleFlowCubit dispatches TimeTrackerStarted(same task)
    IdleFlowCubit calls reminderService.resetTimer()
    IdleFlowCubit emits resolved
```

---

## 9. Files Changed / Created

### New files

| File | Purpose |
|------|---------|
| `windows/runner/idle_monitor_plugin.h/.cpp` | Win32 idle polling, sleep/wake, MethodChannel |
| `windows/runner/idle_resolution_window.h/.cpp` | Native idle resolution popup |
| `windows/runner/native_window_coordinator.h/.cpp` | Mutual exclusion for native popups |
| `windows/runner/startup_plugin.h/.cpp` | Registry read/write for auto-start |
| `lib/core/services/idle_monitor/windows_idle_monitor.dart` | Dart IdleMonitor for Windows |
| `lib/core/services/startup/startup_service.dart` | StartupService interface + Windows impl |
| `lib/feature/time_tracker/cubit/idle_flow_cubit.dart` | Orchestration cubit |

### Modified files

| File | Change |
|------|--------|
| `windows/runner/flutter_window.cpp` | Register new plugins, handle WM_POWERBROADCAST |
| `lib/core/services/idle_monitor/idle_event.dart` | Add `UserReturnedFromIdle` event |
| `lib/core/services/settings_keys.dart` | Add `idleThresholdMinutes`, `launchAtStartup` |
| `lib/feature/settings/presentation/general_settings_screen.dart` | Add idle threshold field + startup toggle |
| `lib/feature/time_tracker/bloc/time_tracker_bloc.dart` | Remove `_idleMonitor` field and `_idleSubscription` |
| `lib/runner/runner.dart` | Remove `NoOpIdleMonitor` registration, add `IdleFlowCubit` init |
| `lib/core/di/service_locator.config.dart` | Register `WindowsIdleMonitor`, `WindowsStartupService`, `IdleFlowCubit` |

---

## 10. Out of Scope

- macOS idle detection (existing `PlatformIdleMonitor` untouched)
- System tray badge or notification for idle (dialog is the only UI surface)
- Idle detection when no tracking session is active (cubit ignores events when timer is stopped)
- Persistence of "discard" or "log to task" history/analytics
