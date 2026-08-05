# 2026-08-04: Idle Detection Feature - Session 2 Handoff

## [Branch State]

Branch: `dev`
Plan start commit: `db70914`
Latest commit: `ef2996e` (merge from remote dev)
All commits since plan start: 19e6dad, 483672e, 05bbbfc, 9ce11d8, 3449c7d, 2fd0773, 4889754, 65a766d, 818249c, 5e057c1, dd3580f, dd650e4, 0653492, be68473, b7e0121, ef2996e

Test suite: 339/339 passing (`fvm flutter test test/core/ test/feature/`)
`flutter analyze lib/`: clean

**All 8 implementation tasks COMPLETE. Final code review COMPLETE. All Critical/Important findings fixed. Branch ready to merge.**

---

## [Feature Summary]

Idle detection and Windows auto-start for Worklog Studio. When the user is idle longer than a configurable threshold, a Win32 popup asks what to do with the idle time. Three choices: keep tracking, discard idle time (stops entry at idle start and restarts), or log idle to a named task (splits entry). App can also auto-launch on Windows startup via registry.

---

## [Architecture: Key Files]

### New files

| File | Purpose |
|------|---------|
| `lib/core/services/idle_monitor/idle_event.dart` | `IdleThresholdReached`, `UserReturnedFromIdle` event classes |
| `lib/core/services/idle_monitor/idle_monitor.dart` | Abstract `IdleMonitor` interface + `NoOpIdleMonitor` |
| `lib/core/services/idle_monitor/windows_idle_monitor.dart` | Win32 `GetLastInputInfo` poll, sleep-drift detection via wall-clock |
| `lib/core/services/idle_monitor/windows_idle_monitor_factory.dart` | Platform factory for `WindowsIdleMonitor` |
| `lib/core/services/startup/startup_service.dart` | Abstract `StartupService` interface |
| `lib/core/services/startup/windows_startup_service.dart` | Registry `HKCU\...\Run` auto-start (path wrapped in quotes) |
| `lib/core/services/desktop/native_window_coordinator.dart` | Singleton mutex for activity-window / resolution-window mutual exclusion |
| `lib/core/services/desktop/idle_resolution_window.dart` | Win32 popup: Keep / Discard / Log-to-task buttons |
| `lib/feature/time_tracker/cubit/idle_flow_cubit.dart` | BLoC orchestrator between `IdleMonitor` and `TimeTrackerBloc` |

### Modified files

| File | Change |
|------|--------|
| `lib/core/services/settings_keys.dart` | Added `idleThresholdMinutes`, `launchAtStartup` |
| `lib/core/services/time_tracker_service.dart` | `stop({DateTime? endAt})` - supports explicit end time |
| `lib/feature/time_tracker/bloc/time_tracker_bloc.dart` | Removed `IdleMonitor` field; cubit owns it now |
| `lib/core/services/desktop/windows_desktop_service.dart` | Creates `IdleResolutionWindow` + `IdleFlowCubit`; registers cubit in get_it; `NativeWindowCoordinator` integration |
| `lib/runner/runner.dart` | Platform-conditional registration: `IdleMonitor` + `StartupService` |
| `lib/feature/app/app.dart` | Removed `idleMonitor:` param from `TimeTrackerBloc` construction |
| `lib/feature/settings/presentation/general_settings_screen.dart` | "Behavior" section: idle threshold TextField + Windows-only launch-at-startup Switch |

---

## [Critical Architectural Decisions]

### IdleFlowCubit owns IdleMonitor (not TimeTrackerBloc)
`TimeTrackerBloc` no longer holds an `IdleMonitor`. `IdleFlowCubit` subscribes to both the monitor stream and the bloc stream. It starts/stops the monitor based on bloc's `isRunning` state, and checks synchronously in its constructor in case the bloc is already running at creation time.

### Direct repo writes instead of bloc events for discard/logToTask
`flutter_bloc` 9.x concurrent transformer: sending `stopped` + `started` as two events is a race. Instead, `_onDiscard` and `_onLogToTask` write directly to the repository sequentially, then fire a single `TimeTrackerEvent.loaded()` to sync state. This is deterministic.

### Entry identity guard
`IdleFlowAwaitingResolution` stores `entryId`. `_onDiscard`/`_onLogToTask` call `_repository.getActive()` and compare IDs. If the entry changed (user switched tasks between threshold and resolution), the operation is a no-op - emits `IdleFlowResolved` and returns. Prevents negative-duration records.

### NativeWindowCoordinator mutex
`idle_resolution_window` and `native_activity_window` must not appear simultaneously. `NativeWindowCoordinator` is a Dart singleton with `idleResolutionWillShow()` / `idleResolutionDidHide()` / `canActivityWindowShow()`. Activity window checks the gate before showing; idle resolution window gates the activity window's hider callback.

Key ordering invariant: always call `setActivityWindowVisible(false)` BEFORE `hide()` at every call site. Reversed order leaves the coordinator flag stuck.

### coordinator.idleResolutionWillShow() only after successful CreateWindowEx
The coordinator call was moved to AFTER the `if (_hwnd == null) return;` guard so a failed window creation can't permanently lock the flag.

### IdleResolutionWindow stored as field, not local
`WindowsDesktopService._idleResolutionWindow` is a class field, disposed in `dispose()`. If it were a local variable in `initLeader()`, the HWND, font handle, and 50ms poll timer would leak on dispose.

### WindowsStartupService path quoting
Registry value is written as `"$exePath"` (double-quoted) to handle paths with spaces (e.g., `C:\Program Files\...`).

### Sleep detection
`WindowsIdleMonitor` tracks wall-clock drift: if `DateTime.now()` advanced more than 10s beyond the 5s poll interval, the machine likely slept. Excess is added to `_suspendAccumulatedMs`. Accumulator resets whenever fresh user activity is detected (`sinceLastInputMs < 10000`) to prevent spurious threshold from accumulated drift across multiple sleep/wake cycles.

### Dead HWND after Alt+F4
When `IsWindow(hwnd) == FALSE` in the poll loop, all child handles are nulled after calling `hide()`. This ensures the next `show()` takes the window-creation branch instead of calling Win32 APIs on a dead handle.

### hideResolutionWindow callback
`IdleFlowCubit` accepts an optional `hideResolutionWindow` callback. When the timer stops while `state is IdleFlowAwaitingResolution`, the cubit calls this to dismiss any orphaned topmost popup before emitting `IdleFlowIdle`.

### StartupService registration path
Registered in `runner.dart` (platform-conditional block), NOT in `service_locator.config.dart`. Do not register it there - double registration would crash at startup.

### IdleFlowCubit registration in get_it
Created in `WindowsDesktopService.initLeader()`, registered via `getIt.registerSingleton<IdleFlowCubit>(...)` so `GeneralSettingsScreen` can call `GetIt.I<IdleFlowCubit>().updateThreshold(...)`. Unregistered in `dispose()`.

---

## [Test Files Added/Modified]

- `test/core/time_tracker_service_test.dart` - Added `stop(endAt:)` tests
- `test/core/windows_idle_monitor_test.dart` - New: threshold, sleep detection, start/stop
- `test/core/windows_startup_service_test.dart` - New: enable/disable/isEnabled, quoting
- `test/core/native_window_coordinator_test.dart` - New: mutex logic, `forTesting()` factory
- `test/feature/idle_flow_cubit_test.dart` - New: 8 tests incl. entry-identity no-op path
- `test/helpers/test_fakes.dart` - Added `FakeIdleMonitor`, `FakeIdleResolutionWindow`

---

## [Pending / Deferred Minors]

These were parked and not fixed (non-blocking):
- `general_settings_screen.dart`: Idle threshold only saves via `onSubmitted` (Enter key); value silently discarded on focus-loss without Enter.
- `idle_resolution_window.dart`: `GetAsyncKeyState(VK_ESCAPE)` is global - pressing Esc in any foreground app dismisses the idle dialog.
- `windows_idle_monitor_test.dart`: sleep-accumulation test comment has math off by ~5s (logic and assertions correct).
- Minor cosmetic differences from the brief (TextField width 56 vs 64).

---

## [What's Next]

The branch is ready to merge to `main`. The push to remote timed out (SSH issue) - retry manually:

```
git push -u origin dev
```

Then open a PR from `dev` to `main`. No blocking issues remain.
