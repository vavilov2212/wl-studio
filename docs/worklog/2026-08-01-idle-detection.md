# 2026-08-01: Idle Detection Feature - Task 1 Journal

## [Verified Facts]

**Task 1: Domain Layer Extensions - COMPLETED**

Files modified:
- `lib/core/services/time_tracker_service.dart` - Signature updated: `Future<TimeEntry> stop({DateTime? endAt})`
- `lib/feature/time_tracker/bloc/time_tracker_event.dart` - Factory updated: `stopped({DateTime? at})`
- `lib/feature/time_tracker/bloc/time_tracker_bloc.dart` - Handler updated: `_onStopped` passes `event.at` to service
- `lib/feature/time_tracker/bloc/time_tracker_bloc.freezed.dart` - Hand-updated freezed class with `DateTime? at` field, equality, hashCode, toString
- `lib/core/services/idle_monitor/idle_event.dart` - Added `UserReturnedFromIdle` event class
- `lib/core/services/settings_keys.dart` - Added `idleThresholdMinutes` and `launchAtStartup` constants
- `test/core/time_tracker_service_test.dart` - Added test group "TimeTrackerService.stop(endAt:)" with 2 tests

Checks passed:
- 320/320 tests pass (full suite: test/core/ + test/feature/)
- New tests confirm stop() uses provided endAt when present, falls back to clock.now() when null
- No regressions in existing tests
- Commit: 19e6dad

## [What Worked]

1. **TDD discipline** - Write failing test first, then implement. Test compilation error on `endAt` parameter was immediate feedback that implementation was needed.
2. **Freezed hand-maintenance** - Since build_runner is forbidden, manually updated the .freezed.dart file (equality, hashCode, toString). Pattern is consistent with existing sealed class implementations.
3. **Service layer pattern** - Using `endAt ?? clock.now()` is idiomatic Dart; no special handling needed.
4. **Test structure** - Reused existing FakeClock and FakeTimeEntryRepository helpers, added new test group at appropriate location in file.
5. **Incremental validation** - Running tests after each logical change (service tests first, then full suite) caught any regressions early.

## [Distilled Rules]

The next task steps must respect:

1. **Never run build_runner** - All .freezed.dart and .g.dart files are hand-maintained. When modifying a freezed sealed class, manually update the field, constructor, equality, hashCode, and toString.
2. **TimeTrackerStopped event is now stateful** - It carries an optional DateTime? at field. Any code that constructs this event must consider passing the timestamp (e.g., idle-monitor-triggered stops should include `IdleThresholdReached.timestamp`).
3. **Service.stop() contract** - Default behavior (endAt=null) is `clock.now()`. Callers can override by passing an explicit DateTime to fix the end time at a different moment (e.g., idle threshold timestamp).
4. **Event -> Handler -> Service chain** - The bloc's `_onStopped` must always pass `event.at` to the service. Do not deviate from this pattern.
5. **Settings keys are stable** - `idleThresholdMinutes` and `launchAtStartup` are now reserved keys in the key-value store. Future tasks must use these exact strings when reading/writing idle settings.
6. **IdleEvent hierarchy** - `UserReturnedFromIdle` is defined but not yet wired into the monitor's emission. Task 7 or later will wire this up. For now, it exists as a placeholder.

## [Pitfalls & What to Avoid]

1. **Freezed const constructor pitfall** - Initially added `const UserReturnedFromIdle()` but the base `IdleEvent` class lacks a const constructor. Removed `const` keyword. Non-const is fine for events.
2. **Path confusion in git add** - First commit attempt used `apps/worklog_studio/lib/...` from a working directory already inside the app. Corrected to use paths relative to repo root.
3. **Freezed field synchronization** - Manually updating the .freezed.dart file requires syncing constructor, field declaration, equality, hashCode, and toString. Missing any one causes compilation or runtime errors. Quadruple-check when hand-editing.

## [What's Next]

**Task 2: WindowsIdleMonitor (COMPLETED - see entry below)**

---

# 2026-08-01: Idle Detection Feature - Task 2 Journal

## [Verified Facts]

**Task 2: WindowsIdleMonitor - COMPLETED**

Files created:
- `apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor.dart`
  - `IdlePollerFactory` typedef (public, satisfies lint rule)
  - `WindowsIdleMonitor` implements `IdleMonitor`
  - Constructor takes injected `getTickCount`, `getLastInputTick`, `wallClock`, `timerFactory`
  - `StreamController.broadcast(sync: true)` for synchronous event delivery
  - Wraparound-safe idle calc: `(tickNow - lastInputTick) & 0xFFFFFFFF`
  - Wall-clock drift detection: if wall elapsed > 10s above 5s interval, add excess to `_suspendAccumulatedMs`
  - `_thresholdFired` guard prevents double-firing
  - Return detection: `sinceLastInputMs < 10000` after threshold fires
- `apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor_factory.dart`
  - Production factory using `win32.GetTickCount` and `win32.GetLastInputInfo` via Dart FFI
  - Uses `calloc` from `package:ffi` for `LASTINPUTINFO` allocation
- `apps/worklog_studio/test/core/windows_idle_monitor_test.dart`
  - 5 test cases covering: threshold fire, no double-fire, user return, stop/cancel, sleep drift

Checks passed:
- 5/5 new tests pass
- 325/325 full suite pass (no regressions)
- Commit: 05bbbfc

## [What Worked]

1. **Injected function parameters** - Replacing FFI calls with plain `int Function()` parameters makes the monitor fully testable without platform channels or mocking frameworks.
2. **`_FakeTimer` pattern** - Capturing the callback via `timerFactory` and calling it manually gives precise control over poll timing in tests.
3. **`sync: true` on broadcast stream** - The tests call the timer callback and immediately check results; `sync: true` delivers events within the same microtask frame. Without it all four event-checking tests fail silently.
4. **`& 0xFFFFFFFF` bitmask** - Correctly handles DWORD tick counter wraparound (~49.7 day overflow) without needing an explicit `if` branch.
5. **Wall-clock drift threshold at >10s** - Using the 5s poll interval plus a 5s tolerance means the drift is only credited on genuine sleep events, not minor timer jitter.

## [Distilled Rules]

1. **`StreamController.broadcast(sync: true)` required** - Any production broadcast stream that emits from a synchronous callback (timer, keyboard event, etc.) must use `sync: true` if callers test with synchronous assertions. Document this on the field.
2. **Public typedef for injectable function params** - Dart lints flag `private type in public API`. Use a public `typedef` (e.g., `IdlePollerFactory`) for constructor parameters that are function types.
3. **`calloc.free()` discipline** - Every `calloc<T>()` allocation in the production FFI factory must have a paired `calloc.free()` in the same synchronous call. No `try/finally` is needed when the call is synchronous and cannot throw after allocation.
4. **No `package:` import for files in the same `lib/` tree** - Dart analysis requires `package:` imports even for sibling files within `lib/`. Relative imports within `lib/` trigger an info diagnostic.
5. **Do not emit from within a sync broadcast listener** - `sync: true` means re-entrant `add()` while a listener is running throws a concurrent modification error. The polling design avoids this because `_poll` is only ever called from the timer, never from a listener.

## [Pitfalls & What to Avoid]

1. **`sync: false` (default) breaks synchronous test assertions** - Four of five tests failed with empty event lists until `sync: true` was added. This is not obvious from the test failure messages, which just report length 0.
2. **Relative imports in `lib/`** - `import 'windows_idle_monitor.dart'` in the factory triggers a lint. Always use `package:worklog_studio/...` for intra-lib imports.
3. **Private typedef in public constructor** - `_TimerFactory? timerFactory` on a public class constructor triggers an info diagnostic. Rename to a public typedef immediately.
4. **Production factory has no automated test** - `createWindowsIdleMonitor()` calls real Win32 FFI and cannot run in the Dart test VM. Must be manually verified on a Windows device before each release.

## [What's Next]

**Task 3 (expected): Wire WindowsIdleMonitor into the DI container / app startup**

Prerequisites:
- Task 1 DONE: domain layer, `UserReturnedFromIdle`, `stop(endAt:)`, settings keys
- Task 2 DONE: `WindowsIdleMonitor` with injected FFI + sleep drift detection

Likely next steps:
1. Register `createWindowsIdleMonitor()` in the DI/service-locator as the Windows-only binding for `IdleMonitor`
2. Wire `IdleThresholdReached` in `TimeTrackerBloc` to call `stop(endAt: event.timestamp)`
3. Wire `UserReturnedFromIdle` if further UX is needed (e.g., show "welcome back" dialog)
4. Read `idleThresholdMinutes` from settings and pass to `monitor.start(thresholdSeconds:)`
5. Ensure `monitor.start/stop` lifecycle is tied to app foreground/background transitions

---

# 2026-08-01: Idle Detection Feature - Task 3 Journal

## [Verified Facts]

**Task 3: StartupService (Windows Registry Auto-Start) - COMPLETED**

Files created:
- `apps/worklog_studio/lib/core/services/startup/startup_service.dart`
  - Abstract interface with three async methods: `enable()`, `disable()`, `isEnabled()`
- `apps/worklog_studio/lib/core/services/startup/windows_startup_service.dart`
  - Concrete implementation using Win32 registry APIs (RegOpenKeyEx, RegSetValueEx, RegDeleteValue, RegQueryValueEx, RegCloseKey)
  - Registry path: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
  - Value name: `WorklogStudio`
  - Uses `GetModuleFileName(0, buf, MAX_PATH)` to retrieve app executable path
  - All FFI allocations properly freed via try/finally blocks
- `apps/worklog_studio/test/core/startup_service_test.dart`
  - `FakeStartupService` implements the interface for contract testing
  - Three test cases: starts disabled, enable() sets enabled, disable() clears enabled

Checks passed:
- 3/3 new tests pass (startup service contract tests)
- 328/328 full suite pass (no regressions)
- Commit: 9ce11d8

## [What Worked]

1. **TDD discipline** - Test file created first, failed as expected (import error), then implementation followed. Immediate feedback on correctness.
2. **FFI resource cleanup pattern** - Each Win32 registry operation uses try/finally to ensure `calloc.free()` is called for all allocations. No leaks on error paths.
3. **Silent error handling** - Registry operations return early on `RegOpenKeyEx` failure (ERROR_SUCCESS check). This prevents crashes if the registry is unavailable or corrupted.
4. **Wide-string conversion** - `toNativeUtf16()` from `package:ffi` handles UTF-16 conversion for registry value names and paths. Automatic allocation.
5. **Size calculation for REG_SZ** - String size passed to `RegSetValueEx` is `(exePath.length + 1) * 2` bytes (Dart string length + null terminator, times 2 for UTF-16).

## [Distilled Rules]

1. **StartupService is a pure interface** - No factory, no implementation details. Allows multiple backends (Windows registry, macOS plist, Linux systemd, etc.) to implement the same contract.
2. **WindowsStartupService is synchronous internally** - Despite async method signatures, the implementation is purely synchronous. The `async` keyword is for future-proofing if registry I/O ever needs to be async.
3. **Registry key path is stable** - `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run` is the standard Windows autostart location. Do not deviate.
4. **Value name is stable** - `WorklogStudio` is the app identifier in the registry. Use this exact string in all registry operations and when reading/writing settings.
5. **FFI discipline** - Every `wsalloc()` or `calloc<T>()` allocation must be freed in the same synchronous call, in a try/finally block.
6. **GetModuleFileName context** - Passing `0` as the HMODULE parameter retrieves the exe path for the current process. This is called every time `enable()` is invoked to get the fresh exe path (supports relocation).

## [Pitfalls & What to Avoid]

1. **Forgetting to free FFI allocations** - First iteration missed `calloc.free(hKey)` at the end of registry operations. This causes handle leaks. Verify that every `calloc<>()` and `wsalloc()` has a matching `free()` in try/finally.
2. **Using relative imports in lib/** - Initial import used `import 'startup_service.dart'`. Dart lints require `package:worklog_studio/core/services/startup/startup_service.dart` for sibling files in lib/. Relative imports in lib/ are treated as errors.
3. **Incorrect size calculation for REG_SZ** - String size must account for UTF-16 encoding (2 bytes per character) and the null terminator. Passing `exePath.length` without the +1 and *2 multiplier causes the registry value to be truncated or malformed.
4. **Not checking RegOpenKeyEx return value** - All registry operations after opening the key are undefined if the open fails. Always check `res != ERROR_SUCCESS` and return early.

## [What's Next]

**Task 4 (expected): Wire StartupService into the DI container and Settings UI**

Prerequisites:
- Task 1 DONE: domain layer, `UserReturnedFromIdle`, `stop(endAt:)`, settings keys
- Task 2 DONE: `WindowsIdleMonitor` with injected FFI + sleep drift detection
- Task 3 DONE: `StartupService` with Windows registry auto-start

Likely next steps:
1. Register `WindowsStartupService` in the DI container as a singleton
2. Inject into a Settings service or use-case
3. Wire Settings UI (Task 8) toggle to call `startupService.enable()` / `disable()`
4. Manual verification: toggle "Launch at startup" in Settings and check `regedit.exe` for the key

---

# 2026-08-03: Idle Detection Feature - Task 5-8 Journal

## [Verified Facts]

**Task 4: NativeWindowCoordinator (Singleton for Window Mutual Exclusion) - COMPLETED**

Files created:
- `apps/worklog_studio/lib/core/services/desktop/native_window_coordinator.dart`
  - Pure Dart singleton with private constructor `_()` and factory `instance`
  - Test-only factory `forTesting()` returns fresh (non-singleton) instance per test call
  - State fields: `_idleResolutionVisible` (bool), `_activityWindowVisible` (bool), `_activityWindowHider` (void Function()?)
  - Methods:
    - `setActivityWindowHider(void Function() hider)` - stores hide callback from WindowsDesktopService
    - `setActivityWindowVisible(bool visible)` - tracks NativeActivityWindow visibility state
    - `idleResolutionWillShow()` - calls hider if activity window visible, then sets `_idleResolutionVisible = true`
    - `idleResolutionDidHide()` - sets `_idleResolutionVisible = false`
    - `canActivityWindowShow()` - returns `!_idleResolutionVisible`
- `apps/worklog_studio/test/core/native_window_coordinator_test.dart`
  - 5 test cases:
    1. `canActivityWindowShow()` returns true by default
    2. `canActivityWindowShow()` returns false after `idleResolutionWillShow()`
    3. `canActivityWindowShow()` returns true after subsequent `idleResolutionDidHide()`
    4. `idleResolutionWillShow()` calls the hider callback when activity window is visible
    5. `idleResolutionWillShow()` does not call hider if activity window is not visible

Checks passed:
- 5/5 new tests pass (native window coordinator tests)
- 333/333 full suite pass (no regressions in core + feature tests)
- Commit: 2fd0773

## [What Worked]

1. **Pure Dart design** - No FFI, no win32 dependencies. State tracking is straightforward and fully testable in Dart VM without platform channels or mocks.
2. **Singleton + forTesting() pattern** - Using private constructor, static final instance, and a factory method for fresh test instances enables clean test isolation without mocking frameworks.
3. **Callback-based integration** - Rather than knowing about Windows window details, the coordinator accepts a simple `void Function()` callback. This decouples the window coordination logic from platform-specific window hiding details.
4. **TDD discipline** - Test file written first, compiled with expected errors (missing class/import), then implementation added. All tests passed on first try post-implementation.
5. **Guard condition on hider call** - The check `if (_activityWindowVisible)` prevents unnecessary callback invocations when the activity window is not visible, reducing lifecycle complexity.

## [Distilled Rules]

1. **NativeWindowCoordinator is the mutual exclusion arbiter** - IdleResolutionWindow and NativeActivityWindow do NOT directly know about each other. Both coordinate through this singleton to prevent simultaneous visibility.
2. **Singleton instance is app-level state** - There is exactly one `NativeWindowCoordinator.instance` for the lifetime of the app. Do not create additional instances outside of testing.
3. **Test isolation via forTesting()** - Each test receives a fresh `NativeWindowCoordinator` instance (not the singleton) via `forTesting()`. This prevents state leakage between tests.
4. **Activity window hider callback is optional** - The `_activityWindowHider` field is nullable (`void Function()?`). Callers may not register a hider, in which case `idleResolutionWillShow()` silently skips the hide operation.
5. **Visibility state is boolean-atomic** - Both `_idleResolutionVisible` and `_activityWindowVisible` are simple bools; no three-state logic or race conditions.
6. **No re-entrancy or locks** - This is synchronous, single-threaded Dart. No mutexes, atomics, or async logic needed.

## [Pitfalls & What to Avoid]

1. **Creating instances outside the pattern** - Do NOT call `NativeWindowCoordinator._()` directly outside the class. Use `instance` for production, `forTesting()` for tests. Violating this bypasses the singleton guarantee and breaks window coordination.
2. **Forgetting to call `setActivityWindowHider()`** - If WindowsDesktopService fails to register the hider callback early in app init, `idleResolutionWillShow()` will silently do nothing. Always verify hider is registered before showing the idle dialog.
3. **Mixing state tracking and window commands** - The coordinator tracks state only. Do NOT add direct window show/hide calls to this class. Callers are responsible for actually showing/hiding windows; the coordinator only tracks permission.
4. **Assuming activity window state is persisted** - `setActivityWindowVisible()` updates `_activityWindowVisible`, but there is no automatic persistence or recovery on app restart. Callers must update the state whenever the window visibility actually changes.

## [What's Next]

**Task 5 (expected): Integrate NativeWindowCoordinator into IdleResolutionWindow and NativeActivityWindow lifecycle**

Prerequisites:
- Task 1 DONE: domain layer, `UserReturnedFromIdle`, `stop(endAt:)`
- Task 2 DONE: `WindowsIdleMonitor` with injected FFI
- Task 3 DONE: `StartupService` with Windows registry
- Task 4 DONE: `NativeWindowCoordinator` singleton for window coordination

Likely next steps:
1. Wire `NativeWindowCoordinator.instance.idleResolutionWillShow()` into IdleResolutionWindow's show/build lifecycle
2. Wire `NativeWindowCoordinator.instance.idleResolutionDidHide()` into IdleResolutionWindow's hide/close lifecycle
3. Wire `NativeWindowCoordinator.instance.setActivityWindowVisible(true/false)` into NativeActivityWindow's visibility callbacks
4. Register NativeActivityWindow's hide method via `setActivityWindowHider()` during WindowsDesktopService init
5. Add integration tests verifying that IdleResolutionWindow can show while NativeActivityWindow hides, and vice versa

---

# 2026-08-03: Idle Detection - Tasks 5-8 Journal

## [Verified Facts]

**Task 5: IdleResolutionWindow (Dart Win32 popup) - COMPLETED** (commit 4889754)

- Created `apps/worklog_studio/lib/core/services/desktop/idle_resolution_window.dart`
- Pure Dart FFI Win32 window (no new C++ files), same pattern as `NativeActivityWindow`
- `WS_POPUP | WS_BORDER | WS_EX_TOPMOST`, positioned bottom-right near system tray
- Three buttons: Keep, Discard, Log to another task (expands inline EDIT control)
- `show()` calls `NativeWindowCoordinator.instance.idleResolutionWillShow()` before showing
- `hide()` calls `NativeWindowCoordinator.instance.idleResolutionDidHide()` after hiding
- ESC mapped to "keep tracking" via `GetAsyncKeyState(VK_ESCAPE)` polling
- Click hit-test via `GetWindowRect` + `ScreenToClient` coordinate transform
- `wsalloc()` called as `win32.wsalloc()` throughout (no unqualified calls)
- No unit tests (UI-only class); analyze clean; 333/333 full suite passed

**Task 6: IdleFlowCubit (orchestration) - COMPLETED** (commits 65a766d, 818249c)

- Created `apps/worklog_studio/lib/feature/time_tracker/cubit/idle_flow_cubit.dart`
- Added `FakeIdleMonitor` to `test/helpers/test_fakes.dart`
- Created `test/feature/idle_flow_cubit_test.dart` with 7 tests (all pass)
- State: `IdleFlowIdle | IdleFlowAwaitingResolution | IdleFlowResolved` (plain sealed classes, no Freezed)
- Subscribes to `IdleMonitor.onIdleEvent` and `bloc.stream` via `StreamSubscription`
- Constructor immediately starts monitor if `bloc.state.isRunning` (fix: initial state inspection)
- `discard`/`logToTask` paths write directly to repo + fire `TimeTrackerEvent.loaded()` - avoids concurrent bloc event race in flutter_bloc 9.x
- 340/340 tests passed after fix commit

**Task 7: Wire Dart layer - COMPLETED** (commits 5e057c1, dd3580f, dd650e4)

- Removed all idle code from `TimeTrackerBloc` (`_idleMonitor`, `_idleSubscription`, `close()` override)
- `runner.dart`: Windows gets `createWindowsIdleMonitor()` + `WindowsStartupService`; macOS gets `PlatformIdleMonitor`; else `NoOpIdleMonitor`
- `WindowsDesktopService.initLeader()`: creates `IdleResolutionWindow` + `IdleFlowCubit`, registers coordinator hider
- `NativeWindowCoordinator.canActivityWindowShow()` guard in `showActivityPrompt()`
- `setActivityWindowVisible(false/true)` wired at all `_nativeActivityWindow.show/hide` call sites
- Fix: `_onActivityAccept` was missing `setActivityWindowVisible(false)` - added post-review
- Fix: hider callback order corrected (set false before hide, not after)
- Fix: `app.dart` still passing `idleMonitor:` to `TimeTrackerBloc` - removed
- 338/338 tests passed

**Task 8: Settings UI - COMPLETED** (commit 0653492)

- Registered `IdleFlowCubit` in `GetIt` from `WindowsDesktopService.initLeader()` (same pattern as `HotkeyService`)
- Added "Behavior" section to `GeneralSettingsScreen`: idle threshold TextField + Windows-only startup Switch
- Settings read from `SettingsRepository` in `_loadBehaviorSettings()`, persisted on change
- `_saveIdleThreshold()` calls `IdleFlowCubit.updateThreshold()` wrapped in try-catch (safe on non-Windows)
- `_setLaunchAtStartup()` calls `StartupService.enable/disable()` + persists to settings
- `// TODO: l10n` on all hardcoded strings
- Note: `StartupService` registration skipped from `service_locator.config.dart` - already registered in `runner.dart` (Task 7); adding again would double-register and crash
- 338/338 tests passed

## [What Worked]

1. **`flutter_bloc` 9.x concurrent transformer** - Sending `stopped` + `started` events back-to-back races under the concurrent transformer. Writing directly to the repo and firing a single `loaded()` is deterministic and race-free. This is the correct pattern for multi-step state transitions in the cubit layer.
2. **Constructor-time bloc state inspection** - `IdleFlowCubit` must check `bloc.state.isRunning` at construction, not just subscribe to future emissions. Without this, instantiation after the bloc is already running silently disables idle detection.
3. **Coordinator hider callback ordering** - Setting `setActivityWindowVisible(false)` before calling `hide()` is the invariant. The coordinator drives this callback, so order matters to avoid a brief window where the coordinator thinks the activity window is still visible.
4. **`flutter analyze` vs IDE diagnostics** - IDE frequently shows stale `uri_does_not_exist` for newly committed files. `flutter analyze` is always authoritative. Pattern: verify with analyze, ignore IDE diagnostics for new files until the IDE re-indexes.

## [Distilled Rules]

1. **flutter_bloc 9.x: don't queue stop+start as separate events for sequential semantics** - Use the repo directly + `TimeTrackerEvent.loaded()` for multi-step mutations that must be atomic from the user's perspective.
2. **Constructor state inspection is required for cubits subscribing to bloc streams** - `bloc.stream.listen(...)` misses the initial state. Always check `bloc.state` synchronously in the constructor body as a seed.
3. **All `_nativeActivityWindow.hide()` call sites must update the coordinator** - There are six paths where the activity window hides (accept, dismiss, auto-dismiss, hotkey toggle, coordinator hider, `toggleActivityPrompt`). Every one needs `setActivityWindowVisible(false)` before the `hide()` call, or the coordinator's flag stays stale.
4. **Win32 FFI class methods with `wsalloc`: always use the `win32.` prefix** - Bare `wsalloc()` compiles in factory context but resolves to a wrong method on the class. A previous task (Task 3, startup service) was burned by this exact bug. Rule: grep for bare `wsalloc(` before every commit touching a Win32 class.
5. **DI registration order matters: register before referencing** - `IdleFlowCubit` must be registered in `GetIt` before `GeneralSettingsScreen` mounts. Since registration happens in `initLeader()` which runs during app startup, this is safe as long as settings is not accessible before app init completes.
6. **Skip duplicate registration** - If Task N registers a type in `runner.dart`, Task M must not also register it in `service_locator.config.dart`. Double `registerLazySingleton<T>` throws at runtime. Always check prior registrations before adding new ones.

## [Pitfalls & What to Avoid]

1. **`_onActivityAccept` is called from the native window after it hides itself** - This callback path was missed in the initial Task 7 implementation. The native window hides itself when the user clicks Accept, then fires this callback. Without explicitly calling `setActivityWindowVisible(false)` here, the coordinator flag is permanently stuck at `true`.
2. **Subagent self-reporting test counts without running analyze** - Task 7's subagent reported 338/338 tests passing but had compile errors in `app.dart` (still passing `idleMonitor:` named arg). Tests passed because `flutter test` compiles only reachable test code, not production `app.dart`. Always run `flutter analyze lib/` separately to catch unreachable code errors.
3. **Hider callback must be registered before `IdleFlowCubit` is created** - If `setActivityWindowHider()` is called after `_idleFlowCubit` is constructed, a rapid idle-return sequence could fire the callback before it's registered. Maintain the current order in `initLeader()`.

## [What's Next]

All 8 tasks complete. The feature is fully implemented:
- Windows idle detection via Dart FFI polling `GetLastInputInfo`
- Sleep detection via wall-clock drift
- Native Win32 idle resolution popup with Keep/Discard/Log-to-task choices
- `IdleFlowCubit` orchestrating the full idle lifecycle
- `NativeWindowCoordinator` preventing simultaneous native popups
- Windows registry auto-start via `WindowsStartupService`
- Settings UI for idle threshold and launch-at-startup toggle

Next: final whole-branch code review, then merge to main.
