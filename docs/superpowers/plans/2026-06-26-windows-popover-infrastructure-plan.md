# Windows Native Popover Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Windows a real secondary always-on-top window/engine hosting `MiniPanel`, opened from a tray-icon click, matching what macOS already has via its native popover.

**Architecture:** Use the `desktop_multi_window` Flutter plugin to spawn a second Flutter engine/window in-process on Windows (no hand-written native C++), reusing the existing `IDesktopPlatformService` interface, `MiniPanel`/`MiniTrackerCubit`, and `TimerSnapshot`/`TimerAction` IPC models exactly as macOS already does, but over the plugin's own inter-window channel instead of a hand-rolled native `MethodChannel`.

**Tech Stack:** Flutter (Dart), `desktop_multi_window`, existing `tray_manager`/`window_manager`, `flutter_bloc`.

## Global Constraints

- Windows only. Do not modify any file under `apps/worklog_studio/macos/` or `macos_desktop_service.dart`.
- Run all Dart commands via `fvm` (`fvm flutter test`, `fvm flutter pub run build_runner build ...`). Never bare `flutter`/`dart`.
- Resolve dependencies via `fvm exec melos bootstrap` from the repo root (`d:\work\wl_studio`). Never `flutter pub get` inside the app directory.
- Mandatory TDD: write the failing test before the implementation for every new piece of testable logic (per `apps/worklog_studio/CLAUDE.md`). UI/window-manager orchestration that cannot be unit tested is explicitly called out per task instead of skipped silently.
- Never use an em dash or en dash in any code, comment, commit message, or this plan's own future edits. Use a plain hyphen.
- Never add a `Co-Authored-By: Claude` trailer to commit messages.
- Do not touch `*.freezed.dart` or `*.g.dart` files directly; if a `freezed`/generated model needs to change, edit the source annotation and regenerate.

---

## File Structure

- Modify: `apps/worklog_studio/pubspec.yaml` (add `desktop_multi_window`)
- Create: `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart` (pure frame-computation helper)
- Create: `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart` (`resolveStartupRole` signature)
- Modify: `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart` (signature only, no behavior change)
- Modify: `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart` (signature only)
- Modify: `apps/worklog_studio/lib/runner/runner.dart` (pass `args` through)
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_tray_service.dart` (public `restoreWindow()`, tray-click hook)
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` (full popover implementation)
- Create: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`

---

### Task 1: Add the `desktop_multi_window` dependency

**Files:**
- Modify: `apps/worklog_studio/pubspec.yaml`

**Interfaces:**
- Produces: the `desktop_multi_window` package available to import as `package:desktop_multi_window/desktop_multi_window.dart` in later tasks.

- [ ] **Step 1: Add the dependency**

In `apps/worklog_studio/pubspec.yaml`, in the `dependencies:` block, add a new line directly under the existing `tray_manager: ^0.2.3` line:

```yaml
  window_manager: ^0.4.3
  tray_manager: ^0.2.3
  desktop_multi_window: ^1.0.0
```

(If `fvm exec melos bootstrap` in the next step reports a newer stable version is required, bump the constraint to whatever it resolves to and re-run bootstrap.)

- [ ] **Step 2: Bootstrap and verify it resolves**

Run from the repo root (`d:\work\wl_studio`):

```bash
fvm exec melos bootstrap
```

Expected: completes without dependency resolution errors, and `apps/worklog_studio/pubspec.lock` now contains a `desktop_multi_window` entry.

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/pubspec.yaml apps/worklog_studio/pubspec.lock
git commit -m "build: add desktop_multi_window dependency for Windows popover"
```

---

### Task 2: Pure popover positioning helper

**Files:**
- Create: `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart`
- Test: `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`

**Interfaces:**
- Produces: `Rect computePopoverFrame({required Rect trayBounds, required Size popoverSize, double gap = 8})`, used by Task 5's `showPopover()`.

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';

void main() {
  group('computePopoverFrame', () {
    test('anchors the popover above and right-aligned to the tray icon', () {
      const trayBounds = Rect.fromLTWH(1850, 1040, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
      );

      // Right edge aligns with the tray icon's horizontal center.
      expect(frame.right, trayBounds.center.dx);
      // Width/height match the requested popover size exactly.
      expect(frame.width, popoverSize.width);
      expect(frame.height, popoverSize.height);
      // Bottom edge sits a small gap above the tray icon's top edge.
      expect(frame.bottom, trayBounds.top - 8);
    });

    test('honors a custom gap', () {
      const trayBounds = Rect.fromLTWH(100, 900, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
        gap: 20,
      );

      expect(frame.bottom, trayBounds.top - 20);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/popover_positioning_test.dart
```

Expected: FAIL with "Error: Couldn't resolve the package 'worklog_studio'" or "Target of URI doesn't exist: 'package:worklog_studio/feature/desktop/popover_positioning.dart'" (the file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart`:

```dart
import 'dart:ui';

/// Computes the on-screen frame for the Windows tray popover window.
///
/// The popover is right-aligned to the tray icon's horizontal center and
/// sits [gap] logical pixels above the icon's top edge, mirroring the
/// conventional Windows tray-flyout anchor point.
Rect computePopoverFrame({
  required Rect trayBounds,
  required Size popoverSize,
  double gap = 8,
}) {
  final right = trayBounds.center.dx;
  final left = right - popoverSize.width;
  final bottom = trayBounds.top - gap;
  final top = bottom - popoverSize.height;
  return Rect.fromLTRB(left, top, right, bottom);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
fvm flutter test test/feature/desktop/popover_positioning_test.dart
```

Expected: PASS, both tests green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/popover_positioning.dart apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart
git commit -m "feat: add pure popover frame positioning helper"
```

---

### Task 3: `resolveStartupRole` learns about process args

**Why:** `desktop_multi_window`'s secondary engine on Windows is launched with `main(args)` receiving `['multi_window', '<windowId>', '<payload>']`. Today `resolveStartupRole()` takes no arguments, so there's nowhere to detect this. This task changes the interface to accept the raw process `args`, updates every implementation, and updates the one call site.

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart:73-77`
- Modify: `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart:172-189`
- Modify: `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Modify: `apps/worklog_studio/lib/runner/runner.dart:75`
- Test: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`

**Interfaces:**
- Produces: `Future<String> resolveStartupRole(List<String> args)` on `IDesktopPlatformService`, returning `'tray'` when `args.first == 'multi_window'` (Windows) and storing the parsed window id on `WindowsDesktopService` via `@visibleForTesting int? get ownWindowIdForTesting`.
- Consumes (Task 5/6): `_ownWindowId` is read by `initFollower` later, so it must be set here.

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/windows_desktop_service_test.dart`:

```dart
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';

void main() {
  group('WindowsDesktopService.resolveStartupRole', () {
    test('returns tray and stores the window id for multi_window args', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole(['multi_window', '7', '{}']);

      expect(role, 'tray');
      expect(service.ownWindowIdForTesting, 7);
    });

    test('returns main for ordinary startup args', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([]);

      expect(role, 'main');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart
```

Expected: FAIL - `resolveStartupRole` currently takes zero arguments, so this is a compile error: "Too many positional arguments: 0 expected, but 1 found."

- [ ] **Step 3: Update the interface**

In `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart`, replace lines 71-77:

```dart
  // ── Startup role detection ────────────────────────────────────────────────

  /// Resolve the startup role of this process.
  ///
  /// Returns `'tray'` when the process was launched as the macOS popover
  /// engine; `'main'` otherwise.  Always returns `'main'` on Windows.
  Future<String> resolveStartupRole();
```

with:

```dart
  // ── Startup role detection ────────────────────────────────────────────────

  /// Resolve the startup role of this process from its raw startup [args].
  ///
  /// Returns `'tray'` when this process is a secondary popover engine
  /// (the macOS popover, or a Windows `desktop_multi_window` sub-window);
  /// `'main'` otherwise. Implementations that have no secondary-engine
  /// concept ignore [args] and always return `'main'`.
  Future<String> resolveStartupRole(List<String> args);
```

- [ ] **Step 4: Update `MacOSDesktopService` (signature only)**

In `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart`, find:

```dart
  @override
  Future<String> resolveStartupRole() async {
```

Replace with:

```dart
  @override
  Future<String> resolveStartupRole(List<String> args) async {
```

The body is unchanged - macOS still detects its role via the native `getEngineInfo` channel call, ignoring `args`.

- [ ] **Step 5: Update `NoOpDesktopService` (signature only)**

Read `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart` first to find the exact current line (it will be `Future<String> resolveStartupRole() async => 'main';` or similar), then change it to:

```dart
  @override
  Future<String> resolveStartupRole(List<String> args) async => 'main';
```

- [ ] **Step 6: Implement the real Windows logic**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add an import at the top:

```dart
import 'package:collection/collection.dart';
```

Add a field near the other private fields:

```dart
  int? _ownWindowId;

  /// Exposed for unit tests only - production code never reads this from
  /// outside the class.
  @visibleForTesting
  int? get ownWindowIdForTesting => _ownWindowId;
```

(Also add `import 'package:flutter/foundation.dart';` if not already present, for `@visibleForTesting`.)

Replace:

```dart
  /// Windows always runs as the main window - returns `'main'` immediately.
  @override
  Future<String> resolveStartupRole() async => 'main';
```

with:

```dart
  /// Returns `'tray'` when [args] indicate this process is a
  /// `desktop_multi_window` secondary engine, storing the parsed window id
  /// for [initFollower] to use later. Returns `'main'` otherwise.
  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = int.tryParse(args[1]);
      return 'tray';
    }
    return 'main';
  }
```

- [ ] **Step 7: Update the call site in runner.dart**

In `apps/worklog_studio/lib/runner/runner.dart`, find:

```dart
  // Role detection is now owned by the platform service itself.
  final role = await DesktopServiceRegistry.instance.resolveStartupRole();
```

Replace with:

```dart
  // Role detection is now owned by the platform service itself.
  final role = await DesktopServiceRegistry.instance.resolveStartupRole(args);
```

- [ ] **Step 8: Run test to verify it passes, and run the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: the new test passes; the full `test/core/` and `test/feature/` suites stay green (this confirms the macOS/no-op signature changes didn't break anything that calls them - note: nothing in the test suite currently calls `resolveStartupRole`, so this run is mainly a compile-check).

- [ ] **Step 9: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/lib/runner/runner.dart apps/worklog_studio/test/core/windows_desktop_service_test.dart
git commit -m "feat: detect Windows multi-window sub-engine via startup args"
```

---

### Task 4: `WindowsTrayService` gets a public restore method and a tray-click hook

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_tray_service.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Future<void> restoreWindow()` (public, was `_restoreWindow`), and `init(..., {Future<void> Function()? onTrayClick})`, used by Task 5.

- [ ] **Step 1: Rename `_restoreWindow` to a public `restoreWindow`**

In `apps/worklog_studio/lib/core/services/desktop/windows_tray_service.dart`, rename the method (currently around line 176):

```dart
  Future<void> _restoreWindow() async {
```

to:

```dart
  Future<void> restoreWindow() async {
```

Update its two existing call sites in the same file:

```dart
  @override
  void onTrayIconMouseDown() async {
    // Left-click: restore window to foreground.
    await _restoreWindow();
  }
```

and

```dart
      case 'open':
        _restoreWindow();
```

to call `restoreWindow()` instead of `_restoreWindow()` (the `onTrayIconMouseDown` body is fully replaced in the next step, so only update the `case 'open':` line here):

```dart
      case 'open':
        restoreWindow();
```

- [ ] **Step 2: Add the tray-click hook**

Add a field next to `_bloc`/`_resolver`:

```dart
  Future<void> Function()? _onTrayClick;
```

Change the `init` signature from:

```dart
  Future<void> init(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
```

to:

```dart
  Future<void> init(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState, {
    Future<void> Function()? onTrayClick,
  }) async {
```

Inside the body, right after `_resolver = resolver;`, add:

```dart
    _onTrayClick = onTrayClick;
```

Replace the `onTrayIconMouseDown` override:

```dart
  @override
  void onTrayIconMouseDown() async {
    // Left-click: restore window to foreground.
    await _restoreWindow();
  }
```

with:

```dart
  @override
  void onTrayIconMouseDown() async {
    // Left-click: open the popover if a hook is wired (Windows mini panel),
    // otherwise fall back to restoring the main window.
    if (_onTrayClick != null) {
      await _onTrayClick!();
    } else {
      await restoreWindow();
    }
  }
```

- [ ] **Step 3: Verify the app still compiles and existing tests stay green**

There is no existing test file for `WindowsTrayService` (it requires real `window_manager`/`tray_manager` platform channels to construct meaningfully, which aren't available in `flutter_test`). This is OS-level orchestration, exempt from the mandatory-test rule per the project's own convention for window/tray lifecycle code. Verify by running:

```bash
cd apps/worklog_studio
fvm flutter analyze lib/core/services/desktop/windows_tray_service.dart
```

Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_tray_service.dart
git commit -m "feat: let WindowsTrayService delegate tray clicks to a popover hook"
```

---

### Task 5: `WindowsDesktopService` leader side - popover window lifecycle

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`

**Interfaces:**
- Consumes: `computePopoverFrame` (Task 2), `WindowsTrayService.restoreWindow()`/`init(..., onTrayClick:)` (Task 4), `resolveStartupRole`/`_ownWindowId` (Task 3).
- Produces: working `showPopover()`, `hidePopover()`, `togglePopover()`, `initLeader()` (now also wires the multi-window method handler and snapshot broadcasting), `dispose()`. Also produces the private `_handleIncomingIpcMessage`/`_handleFollowerAction` pair and `_followerReady`/`_popoverWindowId` fields that Task 6 extends.

This task has no new automated test of its own - window creation, positioning, and show/hide are real OS calls that cannot run inside `flutter_test`. Task 2's positioning test and Task 6's message-handling test already cover the testable logic this task depends on and feeds into. Manual verification happens in Task 7.

- [ ] **Step 1: Replace the full file**

Read the current `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` first (it changed in Tasks 3 and 4 are in other files, so this file still has its original shape plus the Task 3 edits). Replace its entire contents with:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows implementation of [IDesktopPlatformService].
///
/// Owns a secondary `desktop_multi_window` engine that hosts the mini
/// tracker popover, mirroring the role [MacOSDesktopService] plays for its
/// native NSPanel popover - but using the `desktop_multi_window` plugin's
/// own inter-window channel instead of a hand-rolled native `MethodChannel`.
///
/// This file contains zero macOS-specific code.
class WindowsDesktopService implements IDesktopPlatformService {
  WindowsDesktopService._();

  static final WindowsDesktopService _instance = WindowsDesktopService._();
  factory WindowsDesktopService() => _instance;

  static const _popoverSize = Size(360, 520);

  final _navigationStreamController = StreamController<String>.broadcast();

  TimeTrackerBloc? _leaderBloc;
  EntityResolver? _resolver;
  ProjectTaskState? _projectTaskState;
  StreamSubscription<TimeTrackerBlocState>? _blocSubscription;

  MiniTrackerCubit? _followerCubit;

  int? _ownWindowId;
  int? _popoverWindowId;
  bool _isPopoverVisible = false;
  bool _isPopover = false;
  bool _followerReady = false;

  /// Exposed for unit tests only.
  @visibleForTesting
  int? get ownWindowIdForTesting => _ownWindowId;

  // ── IDesktopPlatformService ───────────────────────────────────────────────

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  @override
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
    _leaderBloc = bloc;
    _resolver = resolver;
    _projectTaskState = projectTaskState;

    await WindowsTrayService().init(
      bloc,
      resolver,
      projectTaskState,
      onTrayClick: togglePopover,
    );

    _blocSubscription = bloc.stream.listen((state) {
      _broadcastSnapshotIfReady(state);
    });

    projectTaskState.addListener(() {
      if (_leaderBloc != null) {
        _broadcastSnapshotIfReady(_leaderBloc!.state);
      }
    });

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });
  }

  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {
    _isPopover = true;
    _followerCubit = cubit;

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });

    try {
      await DesktopMultiWindow.invokeMethod(0, 'miniReady', null);
    } catch (e) {
      debugPrint('WindowsDesktopService: handshake miniReady failed - $e');
    }
  }

  @override
  Future<void> togglePopover() async {
    if (_isPopoverVisible) {
      await hidePopover();
    } else {
      await showPopover();
    }
  }

  @override
  Future<void> showPopover() async {
    final frame = await _computeFrame();
    if (_popoverWindowId == null) {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({}));
      _popoverWindowId = window.windowId;
      await window.setFrame(frame);
      await window.show();
    } else {
      final controller = WindowController.fromWindowId(_popoverWindowId!);
      await controller.setFrame(frame);
      await controller.show();
    }
    _isPopoverVisible = true;
  }

  @override
  Future<void> hidePopover() async {
    if (_popoverWindowId != null) {
      try {
        await WindowController.fromWindowId(_popoverWindowId!).hide();
      } catch (e) {
        debugPrint('WindowsDesktopService: error hiding popover - $e');
      }
    }
    _isPopoverVisible = false;
  }

  @override
  void openMainWindowFromTray({String? route}) {
    if (!_isPopover) return;
    try {
      DesktopMultiWindow.invokeMethod(0, 'openMainWindow', {'route': route});
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to open main window - $e');
    }
  }

  @override
  void dispatchAction(covariant dynamic action) {
    if (!_isPopover || action is! TimerAction) return;
    try {
      DesktopMultiWindow.invokeMethod(0, 'dispatchAction', action.toJson());
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to dispatch action - $e');
    }
  }

  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = int.tryParse(args[1]);
      return 'tray';
    }
    return 'main';
  }

  @override
  void dispose() {
    _blocSubscription?.cancel();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Rect> _computeFrame() async {
    final trayBounds =
        await trayManager.getBounds() ?? const Rect.fromLTWH(0, 0, 32, 32);
    return computePopoverFrame(
      trayBounds: trayBounds,
      popoverSize: _popoverSize,
    );
  }

  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
  ) async {
    try {
      switch (method) {
        case 'miniReady':
          _followerReady = true;
          if (_leaderBloc != null) {
            await _broadcastSnapshotIfReady(_leaderBloc!.state);
          }

        case 'openMainWindow':
          await WindowsTrayService().restoreWindow();
          if (arguments is Map) {
            final route = arguments['route'] as String?;
            if (route != null) {
              _navigationStreamController.add(route);
            }
          }

        case 'miniClosed':
          _followerReady = false;

        case 'dispatchAction':
          if (arguments != null) {
            final actionMap = Map<String, dynamic>.from(arguments as Map);
            final action = TimerAction.fromJson(actionMap);
            _handleFollowerAction(action);
          }

        case 'broadcastSnapshot':
          if (arguments != null) {
            final snapshotMap = Map<String, dynamic>.from(
              jsonDecode(arguments as String),
            );
            final snapshot = TimerSnapshot.fromJson(snapshotMap);
            _followerCubit?.updateFromSnapshot(snapshot);
          }
      }
    } catch (e) {
      debugPrint('WindowsDesktopService: IPC message handling failed - $e');
    }
  }

  void _handleFollowerAction(TimerAction action) {
    if (_leaderBloc == null) return;

    final isCurrentlyRunning = _leaderBloc!.state.isRunning;

    if (action.type == TimerActionType.start) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
        Future.delayed(const Duration(milliseconds: 200), () {
          _leaderBloc!.add(
            TimeTrackerStarted(
              projectId: action.projectId,
              taskId: action.taskId,
              comment: action.comment,
            ),
          );
        });
      } else {
        _leaderBloc!.add(
          TimeTrackerStarted(
            projectId: action.projectId,
            taskId: action.taskId,
            comment: action.comment,
          ),
        );
      }
    } else if (action.type == TimerActionType.stop) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
      }
    }
  }

  Future<void> _broadcastSnapshotIfReady(TimeTrackerBlocState state) async {
    if (!_followerReady || _popoverWindowId == null) return;

    final snapshot = TimerSnapshot(
      isRunning: state.isRunning,
      activeEntry: state.activeEntryOrNull,
      entries: state.allEntries,
      tasks: _projectTaskState?.tasks ?? [],
      projects: _projectTaskState?.projects ?? [],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final jsonStr = jsonEncode(snapshot.toJson());
      await DesktopMultiWindow.invokeMethod(
        _popoverWindowId!,
        'broadcastSnapshot',
        jsonStr,
      );
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot - $e');
    }
  }

  // ── Test seams ─────────────────────────────────────────────────────────────

  @visibleForTesting
  void setLeaderBlocForTesting(TimeTrackerBloc bloc) => _leaderBloc = bloc;

  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) =>
      _handleIncomingIpcMessage(method, arguments);
}
```

Note: `Size` and `Rect` come from `dart:ui`, which is exported transitively via `package:flutter/foundation.dart` in Flutter apps - no separate `dart:ui` import is needed here since `popover_positioning.dart` already imports it and `Rect`/`Size` are re-exported through the `flutter` package's `material.dart`/`foundation.dart` barrel in practice. If `fvm flutter analyze` reports `Rect`/`Size` as undefined in this file, add `import 'dart:ui';` explicitly at the top.

- [ ] **Step 2: Run the full existing test suite to confirm nothing broke**

```bash
cd apps/worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests pass, including the Task 3 `windows_desktop_service_test.dart` (its two tests on `resolveStartupRole` still exercise the same logic, now living in this rewritten file).

- [ ] **Step 3: Static analysis**

```bash
fvm flutter analyze lib/core/services/desktop/windows_desktop_service.dart
```

Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart
git commit -m "feat: implement Windows popover window lifecycle via desktop_multi_window"
```

---

### Task 6: Unit test the IPC message-handling logic

**Files:**
- Test: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`

**Interfaces:**
- Consumes: `WindowsDesktopService.setLeaderBlocForTesting` and `.handleIncomingIpcMessageForTesting` (Task 5), `TimeTrackerBloc`/`TimeTrackerService` (existing), `FakeClock`/`FakeTimeEntryRepository` (existing, `test/helpers/test_fakes.dart`).
- Produces: regression coverage for the `dispatchAction` → `TimerAction` → bloc-event path described in the spec.

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`:

```dart
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

import '../helpers/test_fakes.dart';

void main() {
  group('WindowsDesktopService IPC message handling', () {
    late FakeClock clock;
    late FakeTimeEntryRepository repo;
    late TimeTrackerBloc bloc;
    late WindowsDesktopService service;

    setUp(() {
      clock = FakeClock(DateTime(2025, 1, 1, 9));
      repo = FakeTimeEntryRepository();
      bloc = TimeTrackerBloc(
        service: TimeTrackerService(repository: repo, clock: clock),
      );
      service = WindowsDesktopService();
      service.setLeaderBlocForTesting(bloc);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('dispatchAction(start) starts tracking on the leader bloc', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'hello',
      });

      await bloc.stream.firstWhere((s) => s.isRunning);

      expect(bloc.state.isRunning, isTrue);
      expect(bloc.state.activeEntryOrNull?.projectId, 'p1');
      expect(bloc.state.activeEntryOrNull?.taskId, 't1');
      expect(bloc.state.activeEntryOrNull?.comment, 'hello');
    });

    test('dispatchAction(stop) stops a running entry', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': null,
      });
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'stop',
      });
      await bloc.stream.firstWhere((s) => !s.isRunning);

      expect(bloc.state.isRunning, isFalse);
    });

    test('dispatchAction(stop) is a no-op when nothing is running', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'stop',
      });

      // No event was added, so the bloc should still be in its initial idle
      // state - give the event loop a tick to prove no transition happened.
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRunning, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: FAIL - `setLeaderBlocForTesting`/`handleIncomingIpcMessageForTesting` already exist from Task 5, so if Task 5 was completed first this should actually compile and pass immediately. If it fails to compile, it means Task 5's test seams are missing - go back and add them before continuing.

- [ ] **Step 3: Run test to verify it passes**

```bash
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: all 3 tests PASS.

- [ ] **Step 4: Run the full suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart
git commit -m "test: cover WindowsDesktopService dispatchAction IPC handling"
```

---

### Task 7: Manual verification on Windows

**Files:** none (no code changes).

This task cannot be automated - it exercises real window creation, tray interaction, and inter-window IPC, none of which run inside `flutter test`.

- [ ] **Step 1: Build and run the dev flavor**

```bash
cd apps/worklog_studio
fvm flutter run -d windows -t lib/main_development.dart
```

- [ ] **Step 2: Verify tray-click opens the popover**

Click the tray icon. Expected: a small borderless window appears anchored just above the tray icon, showing `MiniPanel` (search box, "No active session running" or active session card, recent activity).

- [ ] **Step 3: Verify start/stop via the popover**

Search for an existing task and click its play button. Expected: the popover's active-session card updates to show the running timer; the tray icon switches to the "running" icon/tooltip; opening the main window (via the popover's desktop icon button) shows the same entry as running in the main UI.

Click the stop button in the popover. Expected: tracking stops, tray icon reverts to idle.

- [ ] **Step 4: Verify hide/reopen keeps state warm**

Click the tray icon again to close the popover, then click it once more to reopen. Expected: the popover reopens instantly (no re-fetch flash) and reflects the latest tracker state.

- [ ] **Step 5: Verify the popover doesn't overlap the taskbar**

With the taskbar in its default bottom position, confirm the popover's bottom edge sits above the taskbar, not behind or overlapping it.

- [ ] **Step 6: Record the outcome**

If any step fails, file the specific failure (which step, what happened instead) before moving on to the companion hotkey/comment-editing plan - that plan assumes this popover already works correctly from a tray click.
