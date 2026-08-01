# Idle Detection and Windows Auto-Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Windows auto-start on boot and system-wide idle detection with a native resolution dialog to Worklog Studio.

**Architecture:** A new `IdleFlowCubit` owns the idle lifecycle, sitting between `WindowsIdleMonitor` (Dart FFI polling `GetLastInputInfo`) and `TimeTrackerBloc`. A separate `IdleResolutionWindow` (Dart Win32 FFI, same pattern as `NativeActivityWindow`) pops near the system tray when the user returns. A `NativeWindowCoordinator` singleton prevents the idle dialog and `NativeActivityWindow` from appearing simultaneously. Registry auto-start uses `WindowsStartupService` (Dart Win32 FFI).

**Tech Stack:** Flutter/Dart, `win32` Dart package (FFI), `flutter_bloc` (Cubit), `freezed` (sealed classes written by hand), `get_it` DI.

## Global Constraints

- Never run `build_runner` - all generated code (`.freezed.dart`, `service_locator.config.dart`) is maintained by hand (POST_MORTEM 2.3)
- No new C++ runner files - all Win32 access uses the `win32` Dart FFI package (same as `NativeActivityWindow`)
- All business logic must be TDD: write failing test first, then implement
- UI-only changes (Win32 window layout, settings screen widgets) are exempt from TDD
- Never add `Co-Authored-By: Claude` to commit messages
- Use `fvm flutter test test/core/ test/feature/ --reporter expanded` from `apps/worklog_studio/`

---

### Task 1: Domain Layer Extensions

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/idle_monitor/idle_event.dart`
- Modify: `apps/worklog_studio/lib/core/services/settings_keys.dart`
- Modify: `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_event.dart`
- Modify: `apps/worklog_studio/lib/core/services/time_tracker_service.dart`
- Modify: `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart`
- Test: `apps/worklog_studio/test/core/time_tracker_service_test.dart`

**Interfaces:**
- Produces: `UserReturnedFromIdle` event class; `SettingsKeys.idleThresholdMinutes`; `SettingsKeys.launchAtStartup`; `TimeTrackerStopped` with optional `at`; `TimeTrackerService.stop({DateTime? endAt})`

- [ ] **Step 1: Write failing test for `TimeTrackerService.stop(endAt:)`**

Open `apps/worklog_studio/test/core/time_tracker_service_test.dart`. Add a new group:

```dart
group('TimeTrackerService.stop(endAt:)', () {
  test('uses provided endAt instead of clock.now()', () async {
    final clock = FakeClock(DateTime(2025, 1, 1, 9));
    final repo = FakeTimeEntryRepository();
    final service = TimeTrackerService(repository: repo, clock: clock);
    repo.seed(TimeEntry(
      id: 'e1',
      startAt: clock.now(),
      status: TimeEntryStatus.running,
    ));
    final explicitEnd = DateTime(2025, 1, 1, 8, 55); // 5 min before clock.now()
    await service.stop(endAt: explicitEnd);
    expect(repo.all.single.endAt, explicitEnd);
  });

  test('falls back to clock.now() when endAt is null', () async {
    final clock = FakeClock(DateTime(2025, 1, 1, 9));
    final repo = FakeTimeEntryRepository();
    final service = TimeTrackerService(repository: repo, clock: clock);
    repo.seed(TimeEntry(
      id: 'e1',
      startAt: DateTime(2025, 1, 1, 8),
      status: TimeEntryStatus.running,
    ));
    await service.stop();
    expect(repo.all.single.endAt, clock.now());
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
fvm flutter test test/core/time_tracker_service_test.dart --reporter expanded
```

Expected: FAIL - no `endAt` parameter on `stop()`.

- [ ] **Step 3: Add `UserReturnedFromIdle` to `idle_event.dart`**

In `apps/worklog_studio/lib/core/services/idle_monitor/idle_event.dart`, append:

```dart
class UserReturnedFromIdle extends IdleEvent {
  const UserReturnedFromIdle();
}
```

- [ ] **Step 4: Add keys to `settings_keys.dart`**

In `apps/worklog_studio/lib/core/services/settings_keys.dart`, inside `SettingsKeys`:

```dart
  static const idleThresholdMinutes = 'idleThresholdMinutes';
  static const launchAtStartup = 'launchAtStartup';
```

- [ ] **Step 5: Add `at` to `TimeTrackerStopped` event**

In `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_event.dart`, replace the `stopped` factory:

```dart
  /// Stops the currently active time entry. If [at] is provided the entry
  /// ends at that timestamp; otherwise the service uses [Clock.now()].
  const factory TimeTrackerEvent.stopped({DateTime? at}) = TimeTrackerStopped;
```

- [ ] **Step 6: Add `endAt` to `TimeTrackerService.stop()`**

In `apps/worklog_studio/lib/core/services/time_tracker_service.dart`, change the `stop` method signature and body:

```dart
  Future<TimeEntry> stop({DateTime? endAt}) async {
    final active = await repository.getActive();
    if (active == null) {
      throw StateError('No active timer to stop');
    }

    final stopped = active.copyWith(
      endAt: endAt ?? clock.now(),
      status: TimeEntryStatus.stopped,
    );

    await repository.update(stopped);
    return stopped;
  }
```

- [ ] **Step 7: Pass `event.at` in `_onStopped` in `time_tracker_bloc.dart`**

In `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart`, update `_onStopped`:

```dart
  Future<void> _onStopped(
    TimeTrackerStopped event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (!state.isRunning) return;
    await _reloadAndEmit(emit, () async {
      await _service.stop(endAt: event.at);
      _idleMonitor?.stop();
    });
  }
```

- [ ] **Step 8: Run tests to confirm green**

```
fvm flutter test test/core/time_tracker_service_test.dart --reporter expanded
```

Expected: all PASS.

- [ ] **Step 9: Run full suite to check for regressions**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
git add apps/worklog_studio/lib/core/services/idle_monitor/idle_event.dart \
        apps/worklog_studio/lib/core/services/settings_keys.dart \
        apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_event.dart \
        apps/worklog_studio/lib/core/services/time_tracker_service.dart \
        apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart \
        apps/worklog_studio/test/core/time_tracker_service_test.dart
git commit -m "feat: extend domain for idle detection (stop(endAt:), UserReturnedFromIdle, settings keys)"
```

---

### Task 2: `WindowsIdleMonitor`

**Files:**
- Create: `apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor.dart`
- Test: `apps/worklog_studio/test/core/windows_idle_monitor_test.dart`

**Interfaces:**
- Consumes: `IdleMonitor` (interface), `IdleThresholdReached`, `UserReturnedFromIdle`
- Produces: `WindowsIdleMonitor` class; injectable timer factory signature `typedef IdlePollerFactory = Timer Function(Duration, void Function())`

- [ ] **Step 1: Write failing tests**

Create `apps/worklog_studio/test/core/windows_idle_monitor_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/windows_idle_monitor.dart';

void main() {
  late List<Duration> timerDurations;
  late List<void Function()> timerCallbacks;
  late List<bool> timerCancelled;

  Timer fakeFactory(Duration d, void Function() cb) {
    timerDurations.add(d);
    timerCallbacks.add(cb);
    timerCancelled.add(false);
    final index = timerCancelled.length - 1;
    return _FakeTimer(() => timerCancelled[index] = true);
  }

  setUp(() {
    timerDurations = [];
    timerCallbacks = [];
    timerCancelled = [];
  });

  WindowsIdleMonitor makeMonitor({
    required int Function() getTickCount,
    required int Function() getLastInputTick,
    DateTime Function()? wallClock,
  }) {
    return WindowsIdleMonitor(
      getTickCount: getTickCount,
      getLastInputTick: getLastInputTick,
      wallClock: wallClock ?? DateTime.now,
      timerFactory: fakeFactory,
    );
  }

  group('WindowsIdleMonitor', () {
    test('emits IdleThresholdReached when idle exceeds threshold', () async {
      int tick = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000; // 70 seconds elapsed, threshold is 60s
      timerCallbacks.single();

      expect(events, hasLength(1));
      expect(events.single, isA<IdleThresholdReached>());
      final evt = events.single as IdleThresholdReached;
      expect(evt.idleSeconds, 70);
      await sub.cancel();
    });

    test('does not fire threshold twice without user return', () async {
      int tick = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000;
      timerCallbacks.single();
      timerCallbacks.single(); // fire again

      expect(events.whereType<IdleThresholdReached>(), hasLength(1));
      await sub.cancel();
    });

    test('emits UserReturnedFromIdle after threshold when new input detected', () async {
      int tick = 0;
      int lastInput = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => lastInput,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000;
      timerCallbacks.single(); // fires threshold

      lastInput = 69000; // user moved mouse (new input tick near current tick)
      tick = 70500;
      timerCallbacks.single(); // detects return

      expect(events, hasLength(2));
      expect(events[0], isA<IdleThresholdReached>());
      expect(events[1], isA<UserReturnedFromIdle>());
      await sub.cancel();
    });

    test('stop() cancels polling timer', () async {
      final monitor = makeMonitor(
        getTickCount: () => 0,
        getLastInputTick: () => 0,
      );
      await monitor.start(thresholdSeconds: 60);
      expect(timerCancelled.single, isFalse);
      await monitor.stop();
      expect(timerCancelled.single, isTrue);
    });

    test('accumulates sleep time from wall-clock drift', () async {
      int tick = 0;
      DateTime wall = DateTime(2025, 1, 1, 9, 0, 0);
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
        wallClock: () => wall,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 300);

      // Poll 1: no drift, 60s idle - below threshold
      tick = 60000;
      wall = DateTime(2025, 1, 1, 9, 0, 5);
      timerCallbacks.single();
      expect(events, isEmpty);

      // Poll 2: wall clock jumped 250s (system slept) - accumulated = 245s
      tick = 65000; // GetTickCount only advanced 5s
      wall = DateTime(2025, 1, 1, 9, 4, 10); // wall advanced 245s
      timerCallbacks.single();
      // totalIdle = 65s (tick) + 245s (accumulated) = 310s > 300s threshold
      expect(events, hasLength(1));
      expect(events.single, isA<IdleThresholdReached>());
      await sub.cancel();
    });
  });
}

class _FakeTimer implements Timer {
  final void Function() _cancel;
  _FakeTimer(this._cancel);
  @override
  void cancel() => _cancel();
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
fvm flutter test test/core/windows_idle_monitor_test.dart --reporter expanded
```

Expected: FAIL - file not found.

- [ ] **Step 3: Create `WindowsIdleMonitor`**

Create `apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor.dart`:

```dart
import 'dart:async';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';

typedef _TimerFactory = Timer Function(Duration, void Function());

class WindowsIdleMonitor implements IdleMonitor {
  WindowsIdleMonitor({
    required int Function() getTickCount,
    required int Function() getLastInputTick,
    DateTime Function()? wallClock,
    _TimerFactory? timerFactory,
  })  : _getTickCount = getTickCount,
        _getLastInputTick = getLastInputTick,
        _wallClock = wallClock ?? DateTime.now,
        _timerFactory = timerFactory ?? _defaultFactory;

  final int Function() _getTickCount;
  final int Function() _getLastInputTick;
  final DateTime Function() _wallClock;
  final _TimerFactory _timerFactory;

  final StreamController<IdleEvent> _controller =
      StreamController<IdleEvent>.broadcast();

  Timer? _pollingTimer;
  int _thresholdMs = 600000;
  bool _thresholdFired = false;
  int _suspendAccumulatedMs = 0;
  DateTime? _lastPollTime;

  static Timer _defaultFactory(Duration d, void Function() cb) =>
      Timer.periodic(d, (_) => cb());

  @override
  Stream<IdleEvent> get onIdleEvent => _controller.stream;

  @override
  Future<void> start({required int thresholdSeconds}) async {
    _pollingTimer?.cancel();
    _thresholdMs = thresholdSeconds * 1000;
    _thresholdFired = false;
    _suspendAccumulatedMs = 0;
    _lastPollTime = _wallClock();
    _pollingTimer = _timerFactory(
      const Duration(seconds: 5),
      _poll,
    );
  }

  @override
  Future<void> stop() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _thresholdFired = false;
    _suspendAccumulatedMs = 0;
    _lastPollTime = null;
  }

  void _poll() {
    final now = _wallClock();
    final last = _lastPollTime;
    if (last != null) {
      final wallElapsedMs = now.difference(last).inMilliseconds;
      // If the wall clock jumped more than 10s beyond the 5s poll interval,
      // the system likely slept. Add the excess to the idle accumulator.
      if (wallElapsedMs > 10000) {
        _suspendAccumulatedMs += wallElapsedMs - 5000;
      }
    }
    _lastPollTime = now;

    final tickNow = _getTickCount();
    final lastInputTick = _getLastInputTick();
    // Wraparound-safe: both values are unsigned 32-bit millisecond counters.
    final sinceLastInputMs = (tickNow - lastInputTick) & 0xFFFFFFFF;
    final totalIdleMs = sinceLastInputMs + _suspendAccumulatedMs;

    if (!_thresholdFired && totalIdleMs >= _thresholdMs) {
      _thresholdFired = true;
      _controller.add(IdleThresholdReached(
        idleSeconds: totalIdleMs ~/ 1000,
        timestamp: now,
      ));
    } else if (_thresholdFired && sinceLastInputMs < 10000) {
      // Fresh input detected after threshold - user has returned.
      _thresholdFired = false;
      _suspendAccumulatedMs = 0;
      _controller.add(const UserReturnedFromIdle());
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
```

- [ ] **Step 4: Create production factory in `runner.dart` area**

The production `WindowsIdleMonitor` needs real Win32 FFI calls. Create `apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor_factory.dart`:

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'windows_idle_monitor.dart';

WindowsIdleMonitor createWindowsIdleMonitor() {
  return WindowsIdleMonitor(
    getTickCount: win32.GetTickCount,
    getLastInputTick: () {
      final info = calloc<win32.LASTINPUTINFO>();
      info.ref.cbSize = sizeOf<win32.LASTINPUTINFO>();
      win32.GetLastInputInfo(info);
      final tick = info.ref.dwTime;
      calloc.free(info);
      return tick;
    },
  );
}
```

- [ ] **Step 5: Run tests**

```
fvm flutter test test/core/windows_idle_monitor_test.dart --reporter expanded
```

Expected: all PASS.

- [ ] **Step 6: Run full suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor.dart \
        apps/worklog_studio/lib/core/services/idle_monitor/windows_idle_monitor_factory.dart \
        apps/worklog_studio/test/core/windows_idle_monitor_test.dart
git commit -m "feat: add WindowsIdleMonitor with sleep-drift detection"
```

---

### Task 3: `StartupService`

**Files:**
- Create: `apps/worklog_studio/lib/core/services/startup/startup_service.dart`
- Create: `apps/worklog_studio/lib/core/services/startup/windows_startup_service.dart`
- Test: `apps/worklog_studio/test/core/startup_service_test.dart`

**Interfaces:**
- Produces: `abstract class StartupService { Future<void> enable(); Future<void> disable(); Future<bool> isEnabled(); }`; `WindowsStartupService implements StartupService`

- [ ] **Step 1: Write failing tests**

Create `apps/worklog_studio/test/core/startup_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/startup/startup_service.dart';

class FakeStartupService implements StartupService {
  bool _enabled = false;
  @override Future<void> enable() async => _enabled = true;
  @override Future<void> disable() async => _enabled = false;
  @override Future<bool> isEnabled() async => _enabled;
}

void main() {
  group('StartupService contract', () {
    test('starts disabled', () async {
      final svc = FakeStartupService();
      expect(await svc.isEnabled(), isFalse);
    });

    test('enable() sets enabled', () async {
      final svc = FakeStartupService();
      await svc.enable();
      expect(await svc.isEnabled(), isTrue);
    });

    test('disable() clears enabled', () async {
      final svc = FakeStartupService();
      await svc.enable();
      await svc.disable();
      expect(await svc.isEnabled(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
fvm flutter test test/core/startup_service_test.dart --reporter expanded
```

Expected: FAIL - import not found.

- [ ] **Step 3: Create `StartupService` abstract class**

Create `apps/worklog_studio/lib/core/services/startup/startup_service.dart`:

```dart
abstract class StartupService {
  Future<void> enable();
  Future<void> disable();
  Future<bool> isEnabled();
}
```

- [ ] **Step 4: Create `WindowsStartupService`**

Create `apps/worklog_studio/lib/core/services/startup/windows_startup_service.dart`:

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'startup_service.dart';

const _kValueName = 'WorklogStudio';

class WindowsStartupService implements StartupService {
  static const _kRunKey =
      r'Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  Future<void> enable() async {
    final exePath = _getExePath();
    if (exePath == null) return;
    _writeRunValue(exePath);
  }

  @override
  Future<void> disable() async {
    _deleteRunValue();
  }

  @override
  Future<bool> isEnabled() async {
    return _readRunValue() != null;
  }

  String? _getExePath() {
    final buf = wsalloc(win32.MAX_PATH);
    try {
      final len = win32.GetModuleFileName(0, buf, win32.MAX_PATH);
      if (len == 0) return null;
      return buf.toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  void _writeRunValue(String exePath) {
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_SET_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return;
      final name = _kValueName.toNativeUtf16();
      final value = exePath.toNativeUtf16();
      try {
        win32.RegSetValueEx(
          hKey.value,
          name,
          0,
          win32.REG_SZ,
          value.cast(),
          (exePath.length + 1) * 2,
        );
      } finally {
        calloc.free(name);
        calloc.free(value);
      }
      win32.RegCloseKey(hKey.value);
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }

  void _deleteRunValue() {
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_SET_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return;
      final name = _kValueName.toNativeUtf16();
      try {
        win32.RegDeleteValue(hKey.value, name);
      } finally {
        calloc.free(name);
      }
      win32.RegCloseKey(hKey.value);
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }

  String? _readRunValue() {
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_QUERY_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return null;
      final name = _kValueName.toNativeUtf16();
      final size = calloc<win32.DWORD>()..value = win32.MAX_PATH * 2;
      final buf = wsalloc(win32.MAX_PATH);
      try {
        final qRes = win32.RegQueryValueEx(
          hKey.value,
          name,
          nullptr,
          nullptr,
          buf.cast(),
          size,
        );
        win32.RegCloseKey(hKey.value);
        if (qRes != win32.ERROR_SUCCESS) return null;
        return buf.toDartString();
      } finally {
        calloc.free(name);
        calloc.free(size);
        calloc.free(buf);
      }
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }
}
```

- [ ] **Step 5: Run tests**

```
fvm flutter test test/core/startup_service_test.dart --reporter expanded
```

Expected: all PASS (tests use `FakeStartupService`, not the Win32 impl).

- [ ] **Step 6: Manual verification of `WindowsStartupService`**

This requires running the app. After Task 8 (Settings UI), toggle the "Launch at startup" switch and verify the registry key is created/deleted at `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run\WorklogStudio` using `regedit.exe`.

- [ ] **Step 7: Run full suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/core/services/startup/ \
        apps/worklog_studio/test/core/startup_service_test.dart
git commit -m "feat: add StartupService with Windows registry auto-start"
```

---

### Task 4: `NativeWindowCoordinator`

**Files:**
- Create: `apps/worklog_studio/lib/core/services/desktop/native_window_coordinator.dart`
- Test: `apps/worklog_studio/test/core/native_window_coordinator_test.dart`

**Interfaces:**
- Produces: `NativeWindowCoordinator` singleton with `registerActivityWindow(NativeActivityWindow)`, `idleResolutionWillShow()`, `idleResolutionDidHide()`, `bool canActivityWindowShow()`

- [ ] **Step 1: Write failing tests**

Create `apps/worklog_studio/test/core/native_window_coordinator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/native_window_coordinator.dart';

void main() {
  late NativeWindowCoordinator coordinator;

  setUp(() {
    // Fresh instance per test (not the singleton).
    coordinator = NativeWindowCoordinator.forTesting();
  });

  group('NativeWindowCoordinator', () {
    test('allows activity window when no idle dialog is showing', () {
      expect(coordinator.canActivityWindowShow(), isTrue);
    });

    test('blocks activity window when idle resolution is showing', () {
      coordinator.idleResolutionWillShow();
      expect(coordinator.canActivityWindowShow(), isFalse);
    });

    test('unblocks activity window after idle resolution hides', () {
      coordinator.idleResolutionWillShow();
      coordinator.idleResolutionDidHide();
      expect(coordinator.canActivityWindowShow(), isTrue);
    });

    test('idleResolutionWillShow hides registered activity window', () {
      bool hideCalled = false;
      coordinator.setActivityWindowHider(() => hideCalled = true);
      coordinator.setActivityWindowVisible(true);
      coordinator.idleResolutionWillShow();
      expect(hideCalled, isTrue);
    });

    test('does not call hider if activity window is not visible', () {
      bool hideCalled = false;
      coordinator.setActivityWindowHider(() => hideCalled = true);
      coordinator.setActivityWindowVisible(false);
      coordinator.idleResolutionWillShow();
      expect(hideCalled, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
fvm flutter test test/core/native_window_coordinator_test.dart --reporter expanded
```

Expected: FAIL - file not found.

- [ ] **Step 3: Create `NativeWindowCoordinator`**

Create `apps/worklog_studio/lib/core/services/desktop/native_window_coordinator.dart`:

```dart
class NativeWindowCoordinator {
  NativeWindowCoordinator._();

  static final NativeWindowCoordinator instance = NativeWindowCoordinator._();

  // Test-only constructor that returns a fresh (non-singleton) instance.
  factory NativeWindowCoordinator.forTesting() => NativeWindowCoordinator._();

  bool _idleResolutionVisible = false;
  bool _activityWindowVisible = false;
  void Function()? _activityWindowHider;

  // Called by WindowsDesktopService during init to wire up the hide callback.
  void setActivityWindowHider(void Function() hider) {
    _activityWindowHider = hider;
  }

  // WindowsDesktopService calls this whenever NativeActivityWindow visibility changes.
  void setActivityWindowVisible(bool visible) {
    _activityWindowVisible = visible;
  }

  // Called by IdleResolutionWindow before showing itself.
  void idleResolutionWillShow() {
    if (_activityWindowVisible) {
      _activityWindowHider?.call();
    }
    _idleResolutionVisible = true;
  }

  // Called by IdleResolutionWindow after it hides itself.
  void idleResolutionDidHide() {
    _idleResolutionVisible = false;
  }

  // NativeActivityWindow checks this before showing itself.
  bool canActivityWindowShow() => !_idleResolutionVisible;
}
```

- [ ] **Step 4: Run tests**

```
fvm flutter test test/core/native_window_coordinator_test.dart --reporter expanded
```

Expected: all PASS.

- [ ] **Step 5: Run full suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/native_window_coordinator.dart \
        apps/worklog_studio/test/core/native_window_coordinator_test.dart
git commit -m "feat: add NativeWindowCoordinator for idle/activity window mutual exclusion"
```

---

### Task 5: `IdleResolutionWindow`

**Files:**
- Create: `apps/worklog_studio/lib/core/services/desktop/idle_resolution_window.dart`

**Interfaces:**
- Consumes: `NativeWindowCoordinator`
- Produces: `IdleResolutionWindow` with `show({required int idleMinutes, required void Function() onKeep, required void Function() onDiscard, required void Function(String taskName) onLogToTask})`, `hide()`

Note: this is a Win32 UI class - no unit tests required. Manual verification in Task 7.

- [ ] **Step 1: Create `IdleResolutionWindow`**

Create `apps/worklog_studio/lib/core/services/desktop/idle_resolution_window.dart`:

```dart
import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart' as win32;
import 'native_window_coordinator.dart';

class IdleResolutionWindow {
  IdleResolutionWindow({
    NativeWindowCoordinator? coordinator,
  }) : _coordinator = coordinator ?? NativeWindowCoordinator.instance;

  final NativeWindowCoordinator _coordinator;

  static const _kClassName = 'WorklogIdleResolution';
  static bool _classRegistered = false;

  static final Pointer<NativeFunction<win32.WNDPROC>> _defWindowProcPtr =
      DynamicLibrary.open('user32.dll')
          .lookup<NativeFunction<win32.WNDPROC>>('DefWindowProcW');

  int? _hwnd;
  int? _keepBtnHwnd;
  int? _discardBtnHwnd;
  int? _logBtnHwnd;
  int? _editHwnd;
  int? _confirmBtnHwnd;
  int? _headerHwnd;
  int? _hFont;

  bool _expanded = false;
  bool isVisible = false;

  void Function()? _onKeep;
  void Function()? _onDiscard;
  void Function(String)? _onLogToTask;

  Timer? _pollTimer;

  static const _kW = 320;
  static const _kH = 160;
  static const _kHExpanded = 210;
  static const _kBtnH = 32;
  static const _kPad = 12;

  void show({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function(String taskName) onLogToTask,
  }) {
    _onKeep = onKeep;
    _onDiscard = onDiscard;
    _onLogToTask = onLogToTask;
    _expanded = false;

    _coordinator.idleResolutionWillShow();

    if (_hwnd == null) {
      _registerClassIfNeeded();
      _createWindows(idleMinutes);
    } else {
      _updateHeader(idleMinutes);
      _setExpanded(false);
    }

    if (_hwnd == null) return;

    _positionNearTray();
    win32.ShowWindow(_hwnd!, win32.SW_SHOWNA);
    win32.SetForegroundWindow(_hwnd!);
    isVisible = true;
    _startPolling();
  }

  void hide() {
    if (_hwnd != null) win32.ShowWindow(_hwnd!, win32.SW_HIDE);
    _pollTimer?.cancel();
    _pollTimer = null;
    isVisible = false;
    _coordinator.idleResolutionDidHide();
  }

  void dispose() {
    hide();
    if (_hwnd != null && win32.IsWindow(_hwnd!) != win32.FALSE) {
      win32.DestroyWindow(_hwnd!);
    }
    _hwnd = null;
    if (_hFont != null) {
      win32.DeleteObject(_hFont!);
      _hFont = null;
    }
  }

  void _registerClassIfNeeded() {
    if (_classRegistered) return;
    final className = _kClassName.toNativeUtf16();
    final wc = calloc<win32.WNDCLASSEX>();
    try {
      wc.ref.cbSize = sizeOf<win32.WNDCLASSEX>();
      wc.ref.style = win32.CS_HREDRAW | win32.CS_VREDRAW;
      wc.ref.lpfnWndProc = _defWindowProcPtr;
      wc.ref.hInstance = win32.GetModuleHandle(nullptr);
      wc.ref.hCursor = win32.LoadCursor(win32.NULL, win32.IDC_ARROW);
      wc.ref.hbrBackground = win32.COLOR_WINDOW + 1;
      wc.ref.lpszClassName = className;
      final atom = win32.RegisterClassEx(wc);
      if (atom != 0) _classRegistered = true;
    } finally {
      calloc.free(wc);
      calloc.free(className);
    }
  }

  void _createWindows(int idleMinutes) {
    final className = _kClassName.toNativeUtf16();
    final title = 'Worklog Studio'.toNativeUtf16();
    try {
      _hwnd = win32.CreateWindowEx(
        win32.WS_EX_TOPMOST,
        className,
        title,
        win32.WS_POPUP | win32.WS_BORDER,
        0, 0, _kW, _kH,
        win32.NULL, win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
    if (_hwnd == null || _hwnd == 0) { _hwnd = null; return; }

    _hFont = _createFont();

    _headerHwnd = _createStatic('You were away for $idleMinutes min', _hwnd!);
    _keepBtnHwnd = _createButton('Keep tracking', _hwnd!);
    _discardBtnHwnd = _createButton('Discard idle time', _hwnd!);
    _logBtnHwnd = _createButton('Log to another task...', _hwnd!);
    _editHwnd = _createEdit(_hwnd!);
    _confirmBtnHwnd = _createButton('Confirm', _hwnd!);

    _applyFont();
    _layoutChildren(false);
    _showExpansionControls(false);
  }

  int _createStatic(String text, int parent) {
    final cls = 'STATIC'.toNativeUtf16();
    final txt = text.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        0, cls, txt,
        win32.WS_CHILD | win32.WS_VISIBLE | win32.SS_LEFT,
        0, 0, 1, 1,
        parent, win32.NULL,
        win32.GetModuleHandle(nullptr), nullptr,
      );
      return h;
    } finally {
      calloc.free(cls);
      calloc.free(txt);
    }
  }

  int _createButton(String text, int parent) {
    final cls = 'BUTTON'.toNativeUtf16();
    final txt = text.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        0, cls, txt,
        win32.WS_CHILD | win32.WS_VISIBLE | win32.BS_PUSHBUTTON,
        0, 0, 1, 1,
        parent, win32.NULL,
        win32.GetModuleHandle(nullptr), nullptr,
      );
      return h;
    } finally {
      calloc.free(cls);
      calloc.free(txt);
    }
  }

  int _createEdit(int parent) {
    final cls = 'EDIT'.toNativeUtf16();
    final empty = ''.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        win32.WS_EX_CLIENTEDGE, cls, empty,
        win32.WS_CHILD | win32.ES_LEFT | win32.ES_AUTOHSCROLL,
        0, 0, 1, 1,
        parent, win32.NULL,
        win32.GetModuleHandle(nullptr), nullptr,
      );
      return h;
    } finally {
      calloc.free(cls);
      calloc.free(empty);
    }
  }

  int _createFont() {
    final lf = calloc<win32.LOGFONT>();
    try {
      lf.ref.lfHeight = -15;
      lf.ref.lfWeight = 400;
      lf.ref.lfQuality = win32.CLEARTYPE_QUALITY;
      lf.ref.lfCharSet = win32.DEFAULT_CHARSET;
      lf.ref.lfFaceName = 'Segoe UI';
      return win32.CreateFontIndirect(lf);
    } finally {
      calloc.free(lf);
    }
  }

  void _applyFont() {
    for (final h in [_headerHwnd, _keepBtnHwnd, _discardBtnHwnd, _logBtnHwnd,
                      _editHwnd, _confirmBtnHwnd]) {
      if (h != null && _hFont != null) {
        win32.SendMessage(h, win32.WM_SETFONT, _hFont!, win32.TRUE);
      }
    }
  }

  void _layoutChildren(bool expanded) {
    final h = _hwnd;
    if (h == null) return;
    final w = _kW - _kPad * 2;
    var y = _kPad;

    if (_headerHwnd != null) {
      win32.MoveWindow(_headerHwnd!, _kPad, y, w, 20, win32.TRUE);
      y += 24;
    }
    for (final btn in [_keepBtnHwnd, _discardBtnHwnd, _logBtnHwnd]) {
      if (btn != null) {
        win32.MoveWindow(btn, _kPad, y, w, _kBtnH, win32.TRUE);
        y += _kBtnH + 4;
      }
    }
    if (expanded) {
      if (_editHwnd != null) {
        win32.MoveWindow(_editHwnd!, _kPad, y, w - 70, 26, win32.TRUE);
      }
      if (_confirmBtnHwnd != null) {
        win32.MoveWindow(_confirmBtnHwnd!, _kW - _kPad - 64, y, 64, 26, win32.TRUE);
      }
    }
    win32.SetWindowPos(
      h, win32.HWND_TOPMOST,
      0, 0, _kW, expanded ? _kHExpanded : _kH,
      win32.SWP_NOMOVE | win32.SWP_NOZORDER,
    );
    win32.InvalidateRect(h, nullptr, win32.TRUE);
  }

  void _showExpansionControls(bool show) {
    final cmd = show ? win32.SW_SHOW : win32.SW_HIDE;
    if (_editHwnd != null) win32.ShowWindow(_editHwnd!, cmd);
    if (_confirmBtnHwnd != null) win32.ShowWindow(_confirmBtnHwnd!, cmd);
  }

  void _setExpanded(bool expanded) {
    _expanded = expanded;
    _showExpansionControls(expanded);
    _layoutChildren(expanded);
  }

  void _updateHeader(int idleMinutes) {
    final h = _headerHwnd;
    if (h == null) return;
    final text = 'You were away for $idleMinutes min'.toNativeUtf16();
    try {
      win32.SetWindowText(h, text);
    } finally {
      calloc.free(text);
    }
  }

  void _positionNearTray() {
    final h = _hwnd;
    if (h == null) return;
    final screenW = win32.GetSystemMetrics(win32.SM_CXSCREEN);
    final screenH = win32.GetSystemMetrics(win32.SM_CYSCREEN);
    final windowH = _expanded ? _kHExpanded : _kH;
    win32.SetWindowPos(
      h, win32.HWND_TOPMOST,
      screenW - _kW - 16,
      screenH - windowH - 48,
      _kW, windowH,
      win32.SWP_NOSIZE | win32.SWP_NOZORDER,
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());
  }

  void _poll() {
    final h = _hwnd;
    if (h == null || !isVisible) { _pollTimer?.cancel(); return; }
    if (win32.IsWindow(h) == win32.FALSE) { hide(); return; }

    // ESC = keep tracking (safe default)
    if (win32.GetAsyncKeyState(win32.VK_ESCAPE) & 0x0001 != 0) {
      hide();
      _onKeep?.call();
      return;
    }

    if (win32.GetAsyncKeyState(win32.VK_LBUTTON) & 0x0001 != 0) {
      final cursorPt = calloc<win32.POINT>();
      try {
        win32.GetCursorPos(cursorPt);
        win32.ScreenToClient(h, cursorPt);
        final x = cursorPt.ref.x;
        final y = cursorPt.ref.y;
        _handleClick(x, y);
      } finally {
        calloc.free(cursorPt);
      }
    }
  }

  void _handleClick(int x, int y) {
    if (_hitTest(_keepBtnHwnd, x, y)) {
      hide();
      _onKeep?.call();
    } else if (_hitTest(_discardBtnHwnd, x, y)) {
      hide();
      _onDiscard?.call();
    } else if (_hitTest(_logBtnHwnd, x, y)) {
      if (!_expanded) {
        _setExpanded(true);
        _positionNearTray();
      }
    } else if (_expanded && _hitTest(_confirmBtnHwnd, x, y)) {
      final taskName = _getEditText();
      if (taskName.isNotEmpty) {
        hide();
        _onLogToTask?.call(taskName);
      }
    }
  }

  bool _hitTest(int? btnHwnd, int clientX, int clientY) {
    if (btnHwnd == null) return false;
    final r = calloc<win32.RECT>();
    try {
      win32.GetWindowRect(btnHwnd, r);
      final topLeft = calloc<win32.POINT>()
        ..ref.x = r.ref.left
        ..ref.y = r.ref.top;
      final botRight = calloc<win32.POINT>()
        ..ref.x = r.ref.right
        ..ref.y = r.ref.bottom;
      try {
        win32.ScreenToClient(_hwnd!, topLeft);
        win32.ScreenToClient(_hwnd!, botRight);
        return clientX >= topLeft.ref.x &&
            clientX <= botRight.ref.x &&
            clientY >= topLeft.ref.y &&
            clientY <= botRight.ref.y;
      } finally {
        calloc.free(topLeft);
        calloc.free(botRight);
      }
    } finally {
      calloc.free(r);
    }
  }

  String _getEditText() {
    final h = _editHwnd;
    if (h == null) return '';
    final buf = wsalloc(512);
    try {
      win32.GetWindowText(h, buf, 512);
      return buf.toDartString();
    } finally {
      calloc.free(buf);
    }
  }
}
```

- [ ] **Step 2: Run full suite to ensure nothing broken**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/idle_resolution_window.dart
git commit -m "feat: add IdleResolutionWindow native Win32 popup"
```

---

### Task 6: `IdleFlowCubit`

**Files:**
- Create: `apps/worklog_studio/lib/feature/time_tracker/cubit/idle_flow_cubit.dart`
- Modify: `apps/worklog_studio/test/helpers/test_fakes.dart`
- Test: `apps/worklog_studio/test/feature/idle_flow_cubit_test.dart`

**Interfaces:**
- Consumes: `IdleMonitor`, `TimeTrackerBloc`, `TimeEntryRepository`, `ReminderService`, `IdleResolutionWindow`
- Produces: `IdleFlowCubit`, `IdleFlowState` sealed class

- [ ] **Step 1: Add `FakeIdleMonitor` to test helpers**

In `apps/worklog_studio/test/helpers/test_fakes.dart`, append:

```dart
// ---------------------------------------------------------------------------
// FakeIdleMonitor
// ---------------------------------------------------------------------------
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';

class FakeIdleMonitor implements IdleMonitor {
  final StreamController<IdleEvent> _controller =
      StreamController<IdleEvent>.broadcast();
  int? lastThresholdSeconds;
  bool stopped = false;

  @override
  Stream<IdleEvent> get onIdleEvent => _controller.stream;

  @override
  Future<void> start({required int thresholdSeconds}) async {
    stopped = false;
    lastThresholdSeconds = thresholdSeconds;
  }

  @override
  Future<void> stop() async => stopped = true;

  void emitThreshold({required int idleSeconds}) {
    _controller.add(IdleThresholdReached(
      idleSeconds: idleSeconds,
      timestamp: DateTime.now(),
    ));
  }

  void emitUserReturned() {
    _controller.add(const UserReturnedFromIdle());
  }

  Future<void> close() => _controller.close();
}
```

- [ ] **Step 2: Write failing tests**

Create `apps/worklog_studio/test/feature/idle_flow_cubit_test.dart`:

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/cubit/idle_flow_cubit.dart';

import '../helpers/test_fakes.dart';

// Minimal fake for IdleResolutionWindow — no Win32, just callbacks.
class FakeIdleResolutionWindow {
  void Function()? lastOnKeep;
  void Function()? lastOnDiscard;
  void Function(String)? lastOnLogToTask;
  int? lastIdleMinutes;
  int showCalls = 0;
  int hideCalls = 0;

  void show({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function(String taskName) onLogToTask,
  }) {
    showCalls++;
    lastIdleMinutes = idleMinutes;
    lastOnKeep = onKeep;
    lastOnDiscard = onDiscard;
    lastOnLogToTask = onLogToTask;
  }

  void hide() => hideCalls++;
}

class FakeReminderService {
  int reloadCalls = 0;
  Future<void> reloadInterval() async => reloadCalls++;
}

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerBloc bloc;
  late FakeIdleMonitor idleMonitor;
  late FakeIdleResolutionWindow resolutionWindow;
  late FakeReminderService reminderService;
  late IdleFlowCubit cubit;

  setUp(() {
    clock = FakeClock(DateTime(2025, 1, 1, 9));
    repo = FakeTimeEntryRepository();
    bloc = TimeTrackerBloc(service: TimeTrackerService(repository: repo, clock: clock));
    idleMonitor = FakeIdleMonitor();
    resolutionWindow = FakeIdleResolutionWindow();
    reminderService = FakeReminderService();
    cubit = IdleFlowCubit(
      idleMonitor: idleMonitor,
      bloc: bloc,
      repository: repo,
      reloadReminderInterval: reminderService.reloadInterval,
      showResolutionWindow: resolutionWindow.show,
      thresholdSeconds: 600,
    );
  });

  tearDown(() async {
    await cubit.close();
    await idleMonitor.close();
    await bloc.close();
  });

  group('IdleFlowCubit', () {
    test('starts in idle state', () {
      expect(cubit.state, isA<IdleFlowIdle>());
    });

    test('ignores IdleThresholdReached when timer is not running', () {
      idleMonitor.emitThreshold(idleSeconds: 610);
      expect(cubit.state, isA<IdleFlowIdle>());
    });

    test('transitions to awaitingResolution when timer is running and threshold reached', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await Future.microtask(() {});

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});

      expect(cubit.state, isA<IdleFlowAwaitingResolution>());
      final s = cubit.state as IdleFlowAwaitingResolution;
      expect(s.taskId, 't1');
      expect(s.projectId, 'p1');
    });

    test('shows resolution window on UserReturnedFromIdle', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await Future.microtask(() {});

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});

      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      expect(resolutionWindow.showCalls, 1);
      expect(resolutionWindow.lastIdleMinutes, 10);
    });

    test('keep choice: emits resolved, reloads reminder, no bloc changes', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await Future.microtask(() {});
      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnKeep!();
      await Future.microtask(() {});

      expect(cubit.state, isA<IdleFlowResolved>());
      expect(reminderService.reloadCalls, 1);
      // Timer still running
      expect(bloc.state.isRunning, isTrue);
    });

    test('discard choice: stops at idleStartTime, restarts, reloads reminder', () async {
      final startAt = clock.now();
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: startAt, status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await Future.microtask(() {});

      clock.advance(const Duration(minutes: 11));
      final idleStart = clock.now().subtract(const Duration(minutes: 1));

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      // Inject idleStartTime via cubit state
      expect(cubit.state, isA<IdleFlowAwaitingResolution>());

      resolutionWindow.lastOnDiscard!();
      await Future.microtask(() {});
      await pumpEventQueue();

      expect(reminderService.reloadCalls, 1);
      // Entry should have been stopped and restarted
      final active = await repo.getActive();
      expect(active, isNotNull);
      expect(active!.taskId, 't1');
    });

    test('logToTask choice: creates idle entry, restarts original task', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await Future.microtask(() {});
      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnLogToTask!('Break');
      await Future.microtask(() {});
      await pumpEventQueue();

      final all = repo.all;
      // Stopped original, created idle entry, started new entry for t1
      final idleEntry = all.firstWhere(
        (e) => e.comment == 'Break' && e.status == TimeEntryStatus.stopped,
        orElse: () => throw StateError('Idle entry not found'),
      );
      expect(idleEntry.comment, 'Break');
      final active = await repo.getActive();
      expect(active?.taskId, 't1');
      expect(reminderService.reloadCalls, 1);
    });
  });
}
```

- [ ] **Step 3: Run test to confirm it fails**

```
fvm flutter test test/feature/idle_flow_cubit_test.dart --reporter expanded
```

Expected: FAIL - `IdleFlowCubit` and `IdleFlowState` not found.

- [ ] **Step 4: Create `IdleFlowCubit`**

Create `apps/worklog_studio/lib/feature/time_tracker/cubit/idle_flow_cubit.dart`:

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:uuid/uuid.dart';

// ── State ────────────────────────────────────────────────────────────────────

sealed class IdleFlowState {
  const IdleFlowState();
}

class IdleFlowIdle extends IdleFlowState {
  const IdleFlowIdle();
}

class IdleFlowAwaitingResolution extends IdleFlowState {
  final DateTime idleStartTime;
  final String? taskId;
  final String? projectId;
  final int idleSeconds;

  const IdleFlowAwaitingResolution({
    required this.idleStartTime,
    required this.idleSeconds,
    this.taskId,
    this.projectId,
  });
}

class IdleFlowResolved extends IdleFlowState {
  const IdleFlowResolved();
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class IdleFlowCubit extends Cubit<IdleFlowState> {
  IdleFlowCubit({
    required IdleMonitor idleMonitor,
    required TimeTrackerBloc bloc,
    required TimeEntryRepository repository,
    required Future<void> Function() reloadReminderInterval,
    required void Function({
      required int idleMinutes,
      required void Function() onKeep,
      required void Function() onDiscard,
      required void Function(String taskName) onLogToTask,
    }) showResolutionWindow,
    int thresholdSeconds = 600,
  })  : _idleMonitor = idleMonitor,
        _bloc = bloc,
        _repository = repository,
        _reloadReminderInterval = reloadReminderInterval,
        _showResolutionWindow = showResolutionWindow,
        _thresholdSeconds = thresholdSeconds,
        super(const IdleFlowIdle()) {
    _idleSub = idleMonitor.onIdleEvent.listen(_onIdleEvent);
    _blocSub = bloc.stream.listen(_onBlocState);
  }

  final IdleMonitor _idleMonitor;
  final TimeTrackerBloc _bloc;
  final TimeEntryRepository _repository;
  final Future<void> Function() _reloadReminderInterval;
  final void Function({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function(String taskName) onLogToTask,
  }) _showResolutionWindow;
  int _thresholdSeconds;

  StreamSubscription<IdleEvent>? _idleSub;
  StreamSubscription<TimeTrackerBlocState>? _blocSub;
  bool _monitorRunning = false;

  final _uuid = const Uuid();

  void updateThreshold(int thresholdSeconds) {
    _thresholdSeconds = thresholdSeconds;
    if (_monitorRunning) {
      _idleMonitor.start(thresholdSeconds: thresholdSeconds);
    }
  }

  void _onBlocState(TimeTrackerBlocState state) {
    if (state.isRunning && !_monitorRunning) {
      _monitorRunning = true;
      _idleMonitor.start(thresholdSeconds: _thresholdSeconds);
    } else if (!state.isRunning && _monitorRunning) {
      _monitorRunning = false;
      _idleMonitor.stop();
      if (this.state is IdleFlowAwaitingResolution ||
          this.state is IdleFlowResolved) {
        emit(const IdleFlowIdle());
      }
    }
  }

  void _onIdleEvent(IdleEvent event) {
    if (event is IdleThresholdReached) {
      if (!_bloc.state.isRunning) return;
      if (this.state is IdleFlowAwaitingResolution) return;
      final active = _bloc.state.activeEntryOrNull;
      emit(IdleFlowAwaitingResolution(
        idleStartTime: event.timestamp.subtract(
          Duration(seconds: event.idleSeconds),
        ),
        idleSeconds: event.idleSeconds,
        taskId: active?.taskId,
        projectId: active?.projectId,
      ));
    } else if (event is UserReturnedFromIdle) {
      final s = state;
      if (s is! IdleFlowAwaitingResolution) return;
      _showResolutionWindow(
        idleMinutes: s.idleSeconds ~/ 60,
        onKeep: _onKeep,
        onDiscard: _onDiscard,
        onLogToTask: _onLogToTask,
      );
    }
  }

  void _onKeep() {
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  void _onDiscard() {
    final s = state;
    if (s is! IdleFlowAwaitingResolution) return;
    final taskId = s.taskId;
    final projectId = s.projectId;
    final idleStart = s.idleStartTime;
    _bloc.add(TimeTrackerEvent.stopped(at: idleStart));
    Future.microtask(() {
      _bloc.add(TimeTrackerEvent.started(
        taskId: taskId,
        projectId: projectId,
      ));
    });
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  void _onLogToTask(String taskName) {
    final s = state;
    if (s is! IdleFlowAwaitingResolution) return;
    final taskId = s.taskId;
    final projectId = s.projectId;
    final idleStart = s.idleStartTime;
    final idleEnd = DateTime.now();

    _bloc.add(TimeTrackerEvent.stopped(at: idleStart));
    Future.microtask(() async {
      // Create the idle period entry under the user-named task.
      await _repository.insert(TimeEntry(
        id: _uuid.v4(),
        comment: taskName,
        startAt: idleStart,
        endAt: idleEnd,
        status: TimeEntryStatus.stopped,
      ));
      _bloc.add(TimeTrackerEvent.started(
        taskId: taskId,
        projectId: projectId,
      ));
    });
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  @override
  Future<void> close() {
    _idleSub?.cancel();
    _blocSub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 5: Run tests**

```
fvm flutter test test/feature/idle_flow_cubit_test.dart --reporter expanded
```

Expected: all PASS.

- [ ] **Step 6: Run full suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/feature/time_tracker/cubit/idle_flow_cubit.dart \
        apps/worklog_studio/test/feature/idle_flow_cubit_test.dart \
        apps/worklog_studio/test/helpers/test_fakes.dart
git commit -m "feat: add IdleFlowCubit orchestration"
```

---

### Task 7: Wire the Dart Layer

**Files:**
- Modify: `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart`
- Modify: `apps/worklog_studio/lib/runner/runner.dart`
- Modify: `apps/worklog_studio/lib/core/services/service_locator/service_locator.config.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`

**Interfaces:**
- Consumes: `WindowsIdleMonitor` (Task 2), `StartupService` (Task 3), `NativeWindowCoordinator` (Task 4), `IdleResolutionWindow` (Task 5), `IdleFlowCubit` (Task 6)

- [ ] **Step 1: Remove idle code from `TimeTrackerBloc`**

In `apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart`:

Remove the import of `idle_monitor.dart` and `idle_event.dart`.
Remove `IdleMonitor? _idleMonitor;` and `StreamSubscription<IdleEvent>? _idleSubscription;` fields.
Remove the `idleMonitor` constructor parameter.
Remove the `_idleSubscription = ...` block from the constructor.
Remove the `close()` override that cancels `_idleSubscription`.
In `_onStarted`, remove `_idleMonitor?.stop()` and `_idleMonitor?.start(...)` lines.
In `_onStopped`, remove `_idleMonitor?.stop()` line.

The constructor becomes:
```dart
TimeTrackerBloc({required TimeTrackerService service})
    : _service = service,
      super(const TimeTrackerBlocState.idle()) {
  on<TimeTrackerLoaded>(_onLoaded);
  on<TimeTrackerStarted>(_onStarted);
  on<TimeTrackerStopped>(_onStopped);
  on<TimeTrackerActiveEntryUpdated>(_onActiveEntryUpdated);
  on<TimeTrackerEntryDeleted>(_onEntryDeleted);
  on<TimeTrackerEntryCreated>(_onEntryCreated);
  on<TimeTrackerEntryUpdated>(_onEntryUpdated);
}
```

`_onStarted` becomes:
```dart
Future<void> _onStarted(
  TimeTrackerStarted event,
  Emitter<TimeTrackerBlocState> emit,
) async {
  final wasRunning = state.isRunning;
  await _reloadAndEmit(emit, () async {
    if (wasRunning) await _service.stop();
    await _service.start(
      projectId: event.projectId,
      taskId: event.taskId,
      comment: event.comment,
    );
  });
}
```

`_onStopped` becomes:
```dart
Future<void> _onStopped(
  TimeTrackerStopped event,
  Emitter<TimeTrackerBlocState> emit,
) async {
  if (!state.isRunning) return;
  await _reloadAndEmit(emit, () => _service.stop(endAt: event.at));
}
```

- [ ] **Step 2: Run full test suite to verify nothing broke**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS. If `TimeTrackerBloc` is constructed elsewhere with `idleMonitor:` named arg, those must be removed too. Check test files:

```
fvm flutter test test/core/reminder_service_test.dart --reporter expanded
```

In `reminder_service_test.dart`, the bloc is created as:
`bloc = TimeTrackerBloc(service: TimeTrackerService(repository: repo, clock: clock));`
No `idleMonitor` arg - already correct.

- [ ] **Step 3: Update `runner.dart`**

In `apps/worklog_studio/lib/runner/runner.dart`:

Replace the `IdleMonitor` registration block in `_initRepositories()`:

```dart
// Remove these imports at the top:
// import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
// import 'package:worklog_studio/core/services/idle_monitor/no_op_idle_monitor.dart';
// import 'package:worklog_studio/core/services/idle_monitor/platform_idle_monitor.dart';

// Add these imports:
import 'package:worklog_studio/core/services/idle_monitor/windows_idle_monitor_factory.dart';
import 'package:worklog_studio/core/services/startup/windows_startup_service.dart';
```

Replace the `getIt.registerLazySingleton<IdleMonitor>` block with:

```dart
    if (!kIsWeb && Platform.isWindows) {
      getIt.registerLazySingleton<IdleMonitor>(
        () => createWindowsIdleMonitor(),
      );
      getIt.registerLazySingleton<StartupService>(
        () => WindowsStartupService(),
      );
    } else if (!kIsWeb && Platform.isMacOS) {
      getIt.registerLazySingleton<IdleMonitor>(
        () => PlatformIdleMonitor(),
      );
    } else {
      getIt.registerLazySingleton<IdleMonitor>(
        () => const NoOpIdleMonitor(),
      );
    }
```

Add `IdleFlowCubit` initialization after `DesktopServiceRegistry.init()` (in the non-follower branch):

```dart
    if (!isFollower) {
      // ... existing DB init code ...

      // IdleFlowCubit wires IdleMonitor to TimeTrackerBloc.
      // Reads threshold from settings; updates when settings change.
      final idleMonitor = getIt<IdleMonitor>();
      final settingsRepo = getIt<SettingsRepository>();
      final rawThreshold = await settingsRepo.getString(SettingsKeys.idleThresholdMinutes);
      final thresholdMinutes = int.tryParse(rawThreshold ?? '') ?? 10;

      // IdleResolutionWindow and IdleFlowCubit are created lazily by
      // WindowsDesktopService after the bloc is ready. Register factories.
      getIt.registerSingleton<IdleMonitor>(idleMonitor, signalsReady: false);
    }
```

Note: `IdleFlowCubit` itself is created inside `WindowsDesktopService.initLeader()` after `TimeTrackerBloc` is available (see Step 4).

- [ ] **Step 4: Wire `IdleFlowCubit` in `WindowsDesktopService`**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add to `initLeader()` after `_reminderService` setup:

```dart
    // Idle flow: create resolution window and cubit after bloc/reminder are ready.
    final idleResolutionWindow = IdleResolutionWindow();
    final rawThreshold = await _settingsRepository.getString(
      SettingsKeys.idleThresholdMinutes,
    );
    final thresholdSeconds = (int.tryParse(rawThreshold ?? '') ?? 10) * 60;

    _idleFlowCubit = IdleFlowCubit(
      idleMonitor: getIt<IdleMonitor>(),
      bloc: bloc,
      repository: getIt<TimeEntryRepository>(),
      reloadReminderInterval: _reminderService!.reloadInterval,
      showResolutionWindow: idleResolutionWindow.show,
      thresholdSeconds: thresholdSeconds,
    );
```

Add the field declaration at the top of `WindowsDesktopService`:
```dart
  IdleFlowCubit? _idleFlowCubit;
```

Wire the coordinator into `NativeActivityWindow.show()` calls. In `showActivityPrompt()` (find it in the file), add at the top:
```dart
    if (!NativeWindowCoordinator.instance.canActivityWindowShow()) return;
```

Register the activity window hider with the coordinator in `initLeader()`:
```dart
    NativeWindowCoordinator.instance.setActivityWindowHider(() {
      _nativeActivityWindow.hide();
    });
```

Update `NativeActivityWindow` visibility tracking - in `showActivityPrompt()` after `_nativeActivityWindow.show(...)`:
```dart
    NativeWindowCoordinator.instance.setActivityWindowVisible(true);
```

And in wherever `_nativeActivityWindow.hide()` is called, add:
```dart
    NativeWindowCoordinator.instance.setActivityWindowVisible(false);
```

Look for `onDismiss: _onActivityDismiss` - update `_onActivityDismiss`:
```dart
  void _onActivityDismiss() {
    NativeWindowCoordinator.instance.setActivityWindowVisible(false);
    // ... existing dismiss logic ...
  }
```

And update `_onActivityAccept`:
```dart
  void _onActivityAccept(String comment) {
    NativeWindowCoordinator.instance.setActivityWindowVisible(false);
    // ... existing accept logic ...
  }
```

Add required imports at the top of `windows_desktop_service.dart`:
```dart
import 'package:worklog_studio/core/services/desktop/idle_resolution_window.dart';
import 'package:worklog_studio/core/services/desktop/native_window_coordinator.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/time_tracker/cubit/idle_flow_cubit.dart';
```

- [ ] **Step 5: Run full test suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/time_tracker/bloc/time_tracker_bloc.dart \
        apps/worklog_studio/lib/runner/runner.dart \
        apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart
git commit -m "feat: wire IdleFlowCubit into app lifecycle, remove idle from TimeTrackerBloc"
```

---

### Task 8: Settings UI

**Files:**
- Modify: `apps/worklog_studio/lib/feature/settings/presentation/general_settings_screen.dart`

Note: UI-only task - no TDD required.

**Interfaces:**
- Consumes: `SettingsKeys.idleThresholdMinutes`, `SettingsKeys.launchAtStartup`, `StartupService`, `IdleFlowCubit`

- [ ] **Step 1: Read `general_settings_screen.dart` to understand existing pattern**

Read the file to understand how existing settings rows (reminder interval, hotkeys) are structured. Match the exact widget style used there.

- [ ] **Step 2: Add idle threshold setting row**

In `general_settings_screen.dart`, after the existing reminder interval row, add an idle threshold field:

```dart
// Idle threshold setting
_SettingsRow(
  label: 'Mark as idle after',
  child: Row(
    children: [
      SizedBox(
        width: 64,
        child: TextField(
          controller: _idleThresholdController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onSubmitted: (value) async {
            final minutes = int.tryParse(value);
            if (minutes == null || minutes < 1 || minutes > 120) return;
            await _settingsRepository.setString(
              SettingsKeys.idleThresholdMinutes,
              minutes.toString(),
            );
            final cubit = getIt<IdleFlowCubit>();  // if registered
            cubit?.updateThreshold(minutes * 60);
          },
        ),
      ),
      const SizedBox(width: 8),
      const Text('minutes'),
    ],
  ),
),
```

Initialize `_idleThresholdController` in `initState()` by reading the current value from `SettingsRepository`.

- [ ] **Step 3: Add launch at startup toggle row**

After the idle threshold row:

```dart
// Launch at startup setting (Windows only)
if (Platform.isWindows)
  FutureBuilder<bool>(
    future: getIt<StartupService>().isEnabled(),
    builder: (context, snapshot) {
      return _SettingsRow(
        label: 'Launch at startup',
        child: Switch(
          value: snapshot.data ?? false,
          onChanged: (enabled) async {
            final svc = getIt<StartupService>();
            if (enabled) {
              await svc.enable();
            } else {
              await svc.disable();
            }
            await _settingsRepository.setString(
              SettingsKeys.launchAtStartup,
              enabled.toString(),
            );
            setState(() {});
          },
        ),
      );
    },
  ),
```

Add required imports: `dart:io`, `package:worklog_studio/core/services/startup/startup_service.dart`, `package:worklog_studio/core/services/settings_keys.dart`.

Note: `StartupService` and `IdleFlowCubit` must be registered in `service_locator.config.dart` or `runner.dart` before this screen is accessible. Verify DI registration from Task 7 is in place before running the app.

- [ ] **Step 4: Register `StartupService` in `service_locator.config.dart`**

In `apps/worklog_studio/lib/core/services/service_locator/service_locator.config.dart`, add after the existing `lazySingleton` registrations:

```dart
import 'package:worklog_studio/core/services/startup/startup_service.dart'
    as _i_startup;
import 'package:worklog_studio/core/services/startup/windows_startup_service.dart'
    as _i_wss;
```

Inside `init()`:
```dart
    if (!kIsWeb && Platform.isWindows) {
      gh.lazySingleton<_i_startup.StartupService>(
        () => _i_wss.WindowsStartupService(),
      );
    }
```

- [ ] **Step 5: Run full suite**

```
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/settings/presentation/general_settings_screen.dart \
        apps/worklog_studio/lib/core/services/service_locator/service_locator.config.dart
git commit -m "feat: add idle threshold and launch-at-startup settings UI"
```

---

## Self-Review Checklist

**Spec coverage:**

| Spec section | Task |
|---|---|
| Windows auto-start (registry) | Task 3 + Task 8 |
| Idle polling (GetLastInputInfo) | Task 2 |
| Sleep correction | Task 2 (wall-clock drift) |
| UserReturnedFromIdle event | Task 1 |
| IdleResolutionWindow (native Win32 popup) | Task 5 |
| Mutual exclusion with NativeActivityWindow | Task 4 + Task 7 |
| Reset reminder timer after resolution | Task 6 (reloadReminderInterval) |
| IdleFlowCubit (keep/discard/logToTask) | Task 6 |
| Remove idle from TimeTrackerBloc | Task 7 |
| Settings UI (threshold + startup toggle) | Task 8 |
| stop(endAt:) for discard path | Task 1 |

All sections covered.

**Known implementation notes:**

- `IdleResolutionWindow` uses `win32.GetSystemMetrics(SM_CXSCREEN)` for tray positioning - this may not account for multi-monitor setups with taskbar on non-primary screen. Acceptable for v1.
- `FakeIdleMonitor` emits synchronously; tests use `Future.microtask(() {})` to yield the event loop for bloc/cubit state updates.
- `IdleFlowCubit` in `logToTask` path creates the idle entry with `comment: taskName` and no `projectId`/`taskId` - this is intentional for v1 (a free-text log entry).
- `WindowsStartupService` reads the exe path at runtime via `GetModuleFileName` ensuring correctness after install.
