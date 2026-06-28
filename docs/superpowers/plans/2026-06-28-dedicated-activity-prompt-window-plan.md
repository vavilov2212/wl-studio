# Dedicated Activity Prompt Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Windows a second, independent floating window - a small "what are you working on" text prompt, fixed top-center on screen - that coexists with the existing tray-anchored mini panel, with the global hotkeys and reminder retargeted to it.

**Architecture:** Generalize the single secondary-window lifecycle `WindowsDesktopService` already has (race-free creation, the targeted-ping liveness probe, the 1s prewarm watchdog) into a reusable `ManagedPopoverWindow` class, then instantiate two of them - one for the existing mini panel, one for the new activity prompt. Both follower engines reuse the existing `MiniTrackerCubit`/IPC plumbing; only their top-level widget differs, selected via a small role tag threaded through `desktop_multi_window`'s window-creation payload.

**Tech Stack:** Flutter (Dart), `desktop_multi_window` (existing dependency, no version change), `hotkey_manager` (existing).

## Global Constraints

- Windows only. Do not modify any file under `apps/worklog_studio/macos/` or `macos_desktop_service.dart`'s actual popover behavior - it gets only the no-op interface stub this plan requires for compilation.
- Run all Dart commands via `fvm` (`fvm flutter test`, `fvm flutter analyze`). Never bare `flutter`/`dart`.
- Resolve dependencies via `fvm exec melos bootstrap` from the repo root (`d:\work\wl_studio`). Never `flutter pub get` inside an app/package directory.
- Mandatory TDD: write the failing test before the implementation for every new piece of testable logic (per `apps/worklog_studio/CLAUDE.md`). Real native window/IPC orchestration that cannot run inside `flutter_test` is explicitly called out per task instead of skipped silently - this matches how the rest of `windows_desktop_service.dart` is already tested today.
- Never use an em dash or en dash in any code, comment, commit message, or this plan's own future edits. Use a plain hyphen.
- Never add a `Co-Authored-By: Claude` trailer to commit messages.
- Do not touch `*.freezed.dart` or `*.g.dart` files directly.
- All popover show/hide/toggle must go through the `ManagedPopoverWindow` methods this plan introduces (`ensureExists`/`show`/`hide`/`reconcile`/`isAlive`/`checkAndRewarm`) - never call `DesktopMultiWindow`/`WindowController` directly from new code outside that class, or the close-via-X reconciliation and creation-race-serialization already fixed for the mini panel will not apply to the activity window.
- `MiniApp`'s and the new `ActivityPromptApp`'s `Scaffold` must stay on an opaque `backgroundColor` (`Color(0xFFf8fafc)`) - `Colors.transparent` renders as solid black in these popovers (no DWM/layered-window support in the plugin on Windows).

---

## File Structure

- Modify: `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart` (add `computeActivityPromptFrame`)
- Modify: `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`
- Create: `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` (the bulk of this plan)
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`
- Create: `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart`
- Modify: `apps/worklog_studio/lib/feature/app/app.dart` (add `ActivityPromptApp`)
- Modify: `apps/worklog_studio/lib/runner/runner.dart` (widget selection)
- Modify: `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart` (add `requestActivityPrompt`)
- Modify: `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart` (no-op stub)
- Modify: `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart` (no-op stub)
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart` (add `requestActivityPrompt`)
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart` (add the button)

---

### Task 1: `computeActivityPromptFrame` pure positioning function

**Files:**
- Modify: `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart`
- Test: `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`

**Interfaces:**
- Produces: `Rect computeActivityPromptFrame({required Size screenSize, required Size promptSize, double topMargin = 96})`, used by Task 7's activity-window frame computation.

- [ ] **Step 1: Write the failing test**

Add to `apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart`, inside `void main()`, after the existing `group('clampFrameToScreen', ...)` block (before its closing `}` for `main`):

```dart
  group('computeActivityPromptFrame', () {
    test('centers horizontally and sits a fixed distance from the top', () {
      const screenSize = Size(1920, 1080);
      const promptSize = Size(420, 100);

      final frame = computeActivityPromptFrame(
        screenSize: screenSize,
        promptSize: promptSize,
      );

      expect(frame.left, (screenSize.width - promptSize.width) / 2);
      expect(frame.top, 96);
      expect(frame.width, promptSize.width);
      expect(frame.height, promptSize.height);
    });

    test('honors a custom top margin', () {
      const screenSize = Size(1920, 1080);
      const promptSize = Size(420, 100);

      final frame = computeActivityPromptFrame(
        screenSize: screenSize,
        promptSize: promptSize,
        topMargin: 40,
      );

      expect(frame.top, 40);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/popover_positioning_test.dart
```

Expected: FAIL with "The function 'computeActivityPromptFrame' isn't defined" (the function doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

In `apps/worklog_studio/lib/feature/desktop/popover_positioning.dart`, add after `clampFrameToScreen`:

```dart

/// Computes the on-screen frame for the dedicated activity prompt window:
/// horizontally centered, a fixed distance from the top of the screen.
///
/// Unlike [computePopoverFrame], this takes no tray bounds at all - the
/// activity prompt is fired unattended (by the reminder) as often as it is
/// fired directly (hotkey, a button in the mini panel), so there is no
/// "the user just clicked something at this exact spot" context worth
/// anchoring to. A fixed, screen-size-derived position is simpler and
/// avoids the unreliable-native-query problems `computePopoverFrame`'s
/// tray-relative anchoring has had to work around.
Rect computeActivityPromptFrame({
  required Size screenSize,
  required Size promptSize,
  double topMargin = 96,
}) {
  final left = (screenSize.width - promptSize.width) / 2;
  return Rect.fromLTWH(left, topMargin, promptSize.width, promptSize.height);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
fvm flutter test test/feature/desktop/popover_positioning_test.dart
```

Expected: PASS, all tests green (including the pre-existing `computePopoverFrame`/`clampFrameToScreen` groups).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/popover_positioning.dart apps/worklog_studio/test/feature/desktop/popover_positioning_test.dart
git commit -m "feat: add computeActivityPromptFrame pure positioning function"
```

---

### Task 2: Extract `ManagedPopoverWindow`

**Why:** `WindowsDesktopService` currently tracks exactly one secondary window's lifecycle inline via scattered fields (`_popoverWindowId`, `_isPopoverVisible`, `_followerReady`, `_creationInFlight`) and methods (`_ensurePopoverWindowExists`, `_isPopoverWindowAlive`, `_reconcilePopoverState`, `_checkAndRewarmPopover`). That logic took several rounds to get right (a window-creation race, a broken liveness probe, a watchdog that silently disabled itself) and must not be hand-duplicated for the second window this plan adds. This task moves it into a standalone, reusable class with **zero behavior change** - `WindowsDesktopService` ends this task with exactly the same externally-visible behavior it has now, just restructured. The optional `frameOverride` parameter on `show()` exists only so `showPopoverNearScreenCorner()` keeps working unchanged through this task - a later task removes it once nothing needs it anymore.

**Files:**
- Create: `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`

**Interfaces:**
- Produces: `class ManagedPopoverWindow` with constructor `ManagedPopoverWindow({required String role, required Future<Rect> Function() computeFrame})`, public mutable fields `windowId` (`int?`), `isVisible` (`bool`), `followerReady` (`bool`), and methods `Future<void> ensureExists()`, `Future<bool> isAlive()`, `Future<void> reconcile()`, `Future<void> show({Future<Rect> Function()? frameOverride})`, `Future<void> hide()`, `Future<void> checkAndRewarm()`. Used by Task 6 (second instance) and every later task that touches popover lifecycle.

This task has no automated test of its own - window creation, positioning, and show/hide are real OS calls that cannot run inside `flutter_test`, exactly like the code it's extracted from today. Verified by the full existing test suite staying green (a pure structural refactor cannot change any behavior the existing tests observe) plus static analysis.

- [ ] **Step 1: Create `managed_popover_window.dart`**

Create `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages the lifecycle of one `desktop_multi_window` secondary engine:
/// creation (serialized against concurrent callers), liveness detection,
/// and show/hide. `WindowsDesktopService` holds one instance per
/// independent floating window it owns (the mini panel, the activity
/// prompt) - each gets the exact same race-free creation and
/// close-via-X detection, instead of that logic being hand-duplicated
/// per window.
class ManagedPopoverWindow {
  ManagedPopoverWindow({required this.role, required this.computeFrame});

  /// A short tag identifying this window's purpose (e.g. `'miniPanel'`,
  /// `'activity'`), passed through `createWindow()`'s payload so the new
  /// engine's `main()` can tell which top-level widget to run.
  final String role;

  /// Computes this window's on-screen frame when shown via `show()`
  /// without an explicit `frameOverride`.
  final Future<Rect> Function() computeFrame;

  int? windowId;
  bool isVisible = false;
  bool followerReady = false;

  Future<void>? _creationInFlight;

  /// Ensures a popover engine exists, creating one if necessary - without
  /// showing it. A no-op if one already exists.
  ///
  /// Concurrent callers share the same in-flight `createWindow()` call
  /// instead of each starting their own: a user-initiated `show()` and a
  /// background pre-warm tick can otherwise both observe `windowId == null`
  /// at the same time (the create call takes long enough to boot a whole
  /// engine) and each create their own window. Whichever one's create call
  /// resolves *second* would then silently overwrite `windowId` with its
  /// own (different, never-shown) window id - leaving this object pointing
  /// at a hidden window while the one actually on screen never receives
  /// any further snapshots, focus requests, or hide/show calls. Funnelling
  /// every creation through this one in-flight future makes that race
  /// impossible: only one `createWindow()` call is ever outstanding, and
  /// every other caller just awaits its result.
  Future<void> ensureExists() async {
    if (windowId != null) return;
    if (_creationInFlight != null) {
      await _creationInFlight;
      return;
    }
    final completer = Completer<void>();
    _creationInFlight = completer.future;
    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({'role': role}));
      windowId = window.windowId;
      debugPrint('ManagedPopoverWindow($role): created window id=${window.windowId}');
    } catch (e) {
      debugPrint('ManagedPopoverWindow($role): failed to create window - $e');
    } finally {
      _creationInFlight = null;
      completer.complete();
    }
  }

  /// `getAllSubWindowIds()` has a native list-encoding bug on some Windows
  /// builds (throws `RangeError` on every call, not just when something is
  /// actually wrong), so it cannot be trusted as a liveness signal - see
  /// this method's git history for that dead end.
  ///
  /// Instead, this sends a harmless targeted IPC call straight to
  /// [windowId]. The native plugin's `HandleWindowChannelCall` looks the id
  /// up in its own window map *before* trying to reach the follower engine
  /// at all, and replies with the exact error `PlatformException(code:
  /// '-1', message: 'target window not found.')` only when that id has
  /// actually been erased from the map - which only happens via the native
  /// `OnWindowDestroy` callback, i.e. the window is genuinely gone (closed
  /// via its native titlebar X button, since the plugin gives us no way to
  /// intercept that). Any other failure (e.g. the follower engine exists
  /// but hasn't finished registering its method handler yet) is
  /// inconclusive, not proof of death - treating it as "alive" avoids
  /// forcing a brand-new engine (a multi-second Firebase/DB cold boot) on
  /// every single probe hiccup.
  Future<bool> isAlive() async {
    try {
      await DesktopMultiWindow.invokeMethod(windowId!, 'livenessPing', null);
      return true;
    } on PlatformException catch (e) {
      if (e.code == '-1' && e.message == 'target window not found.') {
        debugPrint('ManagedPopoverWindow($role): window $windowId confirmed destroyed - $e');
        return false;
      }
      debugPrint('ManagedPopoverWindow($role): inconclusive liveness probe, assuming alive - $e');
      return true;
    } catch (e) {
      debugPrint('ManagedPopoverWindow($role): inconclusive liveness probe, assuming alive - $e');
      return true;
    }
  }

  /// If a tracked window id no longer corresponds to a real window,
  /// resets state so the next `show()`/`ensureExists()` creates a fresh
  /// one instead of silently no-op'ing against a dead id.
  Future<void> reconcile() async {
    if (windowId != null && !await isAlive()) {
      windowId = null;
      isVisible = false;
    }
  }

  /// Shows this window, creating it first if necessary. Uses
  /// [computeFrame] unless [frameOverride] is supplied.
  Future<void> show({Future<Rect> Function()? frameOverride}) async {
    await reconcile();
    await ensureExists();

    if (windowId == null) {
      debugPrint('ManagedPopoverWindow($role): show aborted - no window available');
      return;
    }

    try {
      final frame = await (frameOverride ?? computeFrame)();
      debugPrint('ManagedPopoverWindow($role): show computed frame=$frame');
      final controller = WindowController.fromWindowId(windowId!);
      await controller.setFrame(frame);
      await controller.show();
      isVisible = true;
      debugPrint('ManagedPopoverWindow($role): show completed, windowId=$windowId');
    } catch (e) {
      debugPrint('ManagedPopoverWindow($role): error showing - $e');
    }
  }

  Future<void> hide() async {
    if (windowId != null) {
      try {
        await WindowController.fromWindowId(windowId!).hide();
        followerReady = false;
      } catch (e) {
        debugPrint('ManagedPopoverWindow($role): error hiding - $e');
      }
    }
    isVisible = false;
  }

  /// Checks liveness and re-warms a hidden replacement if this window was
  /// destroyed via its native close button, without waiting for a caller
  /// to try showing it first. No "skip while visible" shortcut on purpose:
  /// [isVisible] is only ever corrected by this object's own `hide()`/
  /// `reconcile()` calls, not by any native close callback, so right after
  /// a close-via-X it stays stuck at `true` forever - trusting it here
  /// would make this check skip itself permanently the moment it's needed
  /// most.
  Future<void> checkAndRewarm() async {
    if (windowId == null) {
      await ensureExists();
      return;
    }
    final alive = await isAlive();
    if (!alive) {
      debugPrint('ManagedPopoverWindow($role): watchdog detected destruction - re-warming');
      windowId = null;
      isVisible = false;
      followerReady = false;
      await ensureExists();
    }
  }
}
```

- [ ] **Step 2: Read the current `windows_desktop_service.dart` in full**

Read `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` end to end before editing - this step does not modify anything, it just makes sure you are working from the file's real current content rather than this plan's necessarily-slightly-stale quotes of it.

- [ ] **Step 3: Replace the popover-lifecycle fields and methods**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add the import:

```dart
import 'package:worklog_studio/core/services/desktop/managed_popover_window.dart';
```

Replace the fields block:

```dart
  int? _ownWindowId;
  int? _popoverWindowId;
  bool _isPopoverVisible = false;
  bool _isPopover = false;
  bool _followerReady = false;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

  Timer? _prewarmWatchdog;
  static const _prewarmCheckInterval = Duration(seconds: 1);
```

with:

```dart
  int? _ownWindowId;
  bool _isPopover = false;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

  late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
    role: 'miniPanel',
    computeFrame: _computeFrameNearTray,
  );

  Timer? _prewarmWatchdog;
  static const _prewarmCheckInterval = Duration(seconds: 1);
```

Replace `togglePopover()`:

```dart
  @override
  Future<void> togglePopover() async {
    // _isPopoverVisible only ever gets corrected by our own hidePopover()
    // call. If the user destroyed the popover via its native close button
    // instead, _isPopoverVisible is left stuck at true even though nothing
    // is on screen - reconcile against the plugin's live-window list before
    // deciding which branch to take, or the first click after a close-via-X
    // would silently call hidePopover() on an already-dead window (a no-op)
    // instead of actually reopening it.
    debugPrint('WindowsDesktopService: togglePopover called, _isPopoverVisible=$_isPopoverVisible');
    await _reconcilePopoverState();
    debugPrint('WindowsDesktopService: after reconcile, _isPopoverVisible=$_isPopoverVisible _popoverWindowId=$_popoverWindowId');
    if (_isPopoverVisible) {
      await hidePopover();
    } else {
      await showPopover();
      await requestFocusComment();
    }
  }

  @override
  Future<void> showPopover() => _showPopover(_computeFrameNearTray);

  /// Used by [ReminderService], which fires unattended on a timer rather
  /// than from a direct user click - there is no extra context here that
  /// would make a live tray-icon lookup any more trustworthy than usual,
  /// so this always anchors to the fixed screen-corner position instead
  /// of the icon-relative one [showPopover] uses.
  Future<void> showPopoverNearScreenCorner() => _showPopover(_computeFrameFixedCorner);

  Future<void> _showPopover(Future<Rect> Function() computeFrame) async {
    // See togglePopover()'s comment: the popover's native window has a
    // titlebar close button that the desktop_multi_window plugin gives no
    // way to suppress or intercept on Windows, so the user can destroy the
    // underlying window/engine at any time outside our control. Reusing a
    // destroyed window id is a silent no-op on the native side, which would
    // otherwise leave the popover permanently unopenable.
    await _reconcilePopoverState();
    await _ensurePopoverWindowExists();

    if (_popoverWindowId == null) {
      debugPrint('WindowsDesktopService: showPopover aborted - no popover window available');
      return;
    }

    try {
      final frame = await computeFrame();
      debugPrint('WindowsDesktopService: showPopover computed frame=$frame');
      final controller = WindowController.fromWindowId(_popoverWindowId!);
      await controller.setFrame(frame);
      await controller.show();
      _isPopoverVisible = true;
      debugPrint('WindowsDesktopService: showPopover completed successfully, windowId=$_popoverWindowId');
    } catch (e) {
      debugPrint('WindowsDesktopService: error showing popover - $e');
    }
  }

  Future<void> _reconcilePopoverState() async {
    if (_popoverWindowId != null && !await _isPopoverWindowAlive()) {
      _popoverWindowId = null;
      _isPopoverVisible = false;
    }
  }

  /// `getAllSubWindowIds()` has a native list-encoding bug on some Windows
  /// builds (throws `RangeError` on every call, not just when something is
  /// actually wrong), so it cannot be trusted as a liveness signal here -
  /// see the removed previous implementation's history for that dead end.
  ///
  /// Instead, this sends a harmless targeted IPC call straight to
  /// [_popoverWindowId]. The native plugin's `HandleWindowChannelCall`
  /// looks the id up in its own window map *before* trying to reach the
  /// follower engine at all, and replies with the exact error
  /// `PlatformException(code: '-1', message: 'target window not found.')`
  /// only when that id has actually been erased from the map - which only
  /// happens via the native `OnWindowDestroy` callback, i.e. the window is
  /// genuinely gone (closed via its native titlebar X button, since the
  /// plugin gives us no way to intercept that). Any other failure (e.g. the
  /// follower engine exists but hasn't finished registering its method
  /// handler yet) is inconclusive, not proof of death - treating it as
  /// "alive" avoids the previous bug where any probe hiccup forced a
  /// brand-new popover engine (a multi-second Firebase/DB cold boot) on
  /// every single toggle.
  Future<bool> _isPopoverWindowAlive() async {
    try {
      await DesktopMultiWindow.invokeMethod(_popoverWindowId!, 'livenessPing', null);
      return true;
    } on PlatformException catch (e) {
      if (e.code == '-1' && e.message == 'target window not found.') {
        debugPrint('WindowsDesktopService: popover window $_popoverWindowId confirmed destroyed - $e');
        return false;
      }
      debugPrint('WindowsDesktopService: inconclusive liveness probe, assuming alive - $e');
      return true;
    } catch (e) {
      debugPrint('WindowsDesktopService: inconclusive liveness probe, assuming alive - $e');
      return true;
    }
  }

  Future<void>? _creationInFlight;

  /// Ensures a popover engine exists, creating one if necessary - without
  /// showing it. Used both to pre-warm (startup, and after the watchdog
  /// detects a close-via-X) and as the creation step inside `showPopover()`.
  ///
  /// Concurrent callers share the same in-flight `createWindow()` call
  /// instead of each starting their own: a user-initiated `showPopover()`
  /// and the 1s watchdog's pre-warm tick can otherwise both observe
  /// `_popoverWindowId == null` at the same time (the create call takes
  /// long enough to boot a whole engine) and each create their own window.
  /// Whichever one's create call resolves *second* would then silently
  /// overwrite `_popoverWindowId` with its own (different, never-shown)
  /// window id - leaving the leader pointing at a hidden window while the
  /// one actually on screen never receives any further snapshots, focus
  /// requests, or hide/show calls. Funnelling every creation through this
  /// one in-flight future makes that race impossible: only one
  /// `createWindow()` call is ever outstanding, and every other caller
  /// just awaits its result.
  Future<void> _ensurePopoverWindowExists() async {
    if (_popoverWindowId != null) return;
    if (_creationInFlight != null) {
      await _creationInFlight;
      return;
    }
    final completer = Completer<void>();
    _creationInFlight = completer.future;
    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({}));
      _popoverWindowId = window.windowId;
      debugPrint('WindowsDesktopService: created popover window id=${window.windowId}');
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to create popover window - $e');
    } finally {
      _creationInFlight = null;
      completer.complete();
    }
  }

  /// Polls popover liveness so a close-via-X gets noticed - and a
  /// replacement engine gets pre-warmed - without waiting for the user to
  /// try reopening it first. Skips the check entirely while the popover is
  /// actually visible, since there is nothing to detect in that case.
  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(_prewarmCheckInterval, (_) => _checkAndRewarmPopover());
  }

  Future<void> _checkAndRewarmPopover() async {
    if (_popoverWindowId == null) {
      await _ensurePopoverWindowExists();
      return;
    }
    // No "skip while visible" shortcut here on purpose: _isPopoverVisible
    // is only ever corrected by our own hidePopover()/reconcile calls, not
    // by any native close callback, so right after a close-via-X it stays
    // stuck at true forever. Trusting it here would make the watchdog skip
    // its own check permanently the moment it's needed most.
    final alive = await _isPopoverWindowAlive();
    if (!alive) {
      debugPrint('WindowsDesktopService: watchdog detected popover destroyed via X - re-warming');
      _popoverWindowId = null;
      _isPopoverVisible = false;
      _followerReady = false;
      await _ensurePopoverWindowExists();
    }
  }

  @override
  Future<void> hidePopover() async {
    if (_popoverWindowId != null) {
      try {
        await WindowController.fromWindowId(_popoverWindowId!).hide();
        _followerReady = false;
      } catch (e) {
        debugPrint('WindowsDesktopService: error hiding popover - $e');
      }
    }
    _isPopoverVisible = false;
  }
```

with:

```dart
  @override
  Future<void> togglePopover() async {
    await _miniPanelWindow.reconcile();
    if (_miniPanelWindow.isVisible) {
      await hidePopover();
    } else {
      await showPopover();
      await requestFocusComment();
    }
  }

  @override
  Future<void> showPopover() => _miniPanelWindow.show();

  /// Used by [ReminderService], which fires unattended on a timer rather
  /// than from a direct user click - there is no extra context here that
  /// would make a live tray-icon lookup any more trustworthy than usual,
  /// so this always anchors to the fixed screen-corner position instead
  /// of the icon-relative one [showPopover] uses.
  Future<void> showPopoverNearScreenCorner() =>
      _miniPanelWindow.show(frameOverride: _computeFrameFixedCorner);

  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(
      _prewarmCheckInterval,
      (_) => _miniPanelWindow.checkAndRewarm(),
    );
  }

  @override
  Future<void> hidePopover() => _miniPanelWindow.hide();
```

Update every remaining reference to the old fields/methods elsewhere in the file:
- Replace every remaining `_popoverWindowId` with `_miniPanelWindow.windowId`.
- Replace every remaining `_isPopoverVisible` with `_miniPanelWindow.isVisible`.
- Replace every remaining `_followerReady` with `_miniPanelWindow.followerReady`.
- Replace the `initLeader` line `await _ensurePopoverWindowExists();` with `await _miniPanelWindow.ensureExists();`.
- In `dispose()`, the line `_prewarmWatchdog?.cancel();` stays as-is (the field name didn't change).

- [ ] **Step 4: Run the full existing test suite to confirm zero behavior change**

```bash
cd apps/worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests pass, identical to before this task (this is a pure structural refactor - if any test's behavior changed, something was extracted incorrectly).

- [ ] **Step 5: Static analysis**

```bash
fvm flutter analyze lib/core/services/desktop/managed_popover_window.dart lib/core/services/desktop/windows_desktop_service.dart
```

Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart
git commit -m "refactor: extract ManagedPopoverWindow from WindowsDesktopService"
```

---

### Task 3: `resolveStartupRole` parses a follower role tag

**Why:** `desktop_multi_window`'s `createWindow(arguments)` already threads a payload string through to the new engine's `main(args)` as `args[2]` (`ManagedPopoverWindow.ensureExists()`, added in Task 2, already passes `jsonEncode({'role': role})` there). This task makes `resolveStartupRole` read that payload back out, so `runner.dart` (Task 5) can tell a mini-panel follower apart from an activity-prompt follower.

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Test: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`

**Interfaces:**
- Produces: `resolveStartupRole` now returns `'tray:activity'` when the payload's `role` field is `'activity'`, and plain `'tray'` otherwise (including when the payload is missing, empty, or malformed) - `'main'` is unchanged. Used by Task 5's `runner.dart` widget selection.

- [ ] **Step 1: Write the failing test**

In `apps/worklog_studio/test/core/windows_desktop_service_test.dart`, add inside the existing `group('WindowsDesktopService.resolveStartupRole', ...)` block, after its two existing tests:

```dart
    test('returns tray:activity when the payload role is activity', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([
        'multi_window',
        '9',
        '{"role":"activity"}',
      ]);

      expect(role, 'tray:activity');
    });

    test('returns plain tray when the payload role is miniPanel', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([
        'multi_window',
        '9',
        '{"role":"miniPanel"}',
      ]);

      expect(role, 'tray');
    });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart
```

Expected: the first new test FAILS (`Expected: 'tray:activity' Actual: 'tray'`); the second new test and the two pre-existing tests pass unchanged (the current implementation already returns plain `'tray'` for any `multi_window` args, so the `miniPanel` case happens to already pass - that's fine, it documents the target behavior).

- [ ] **Step 3: Implement**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, replace:

```dart
  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = int.tryParse(args[1]);
      return 'tray';
    }
    return 'main';
  }
```

with:

```dart
  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = int.tryParse(args[1]);
      return _followerRole(args) == 'activity' ? 'tray:activity' : 'tray';
    }
    return 'main';
  }

  /// Reads the `role` field out of `createWindow()`'s payload (`args[2]`,
  /// per `desktop_multi_window`'s documented argument list), defaulting to
  /// `'miniPanel'` for a missing, empty, or malformed payload.
  String _followerRole(List<String> args) {
    if (args.length < 3) return 'miniPanel';
    try {
      final payload = jsonDecode(args[2]) as Map<String, dynamic>;
      return payload['role'] as String? ?? 'miniPanel';
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to parse follower role payload - $e');
      return 'miniPanel';
    }
  }
```

- [ ] **Step 4: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/test/core/windows_desktop_service_test.dart
git commit -m "feat: parse follower role tag in resolveStartupRole"
```

---

### Task 4: `ActivityPromptPanel` and `ActivityPromptApp`

**Files:**
- Create: `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart`
- Modify: `apps/worklog_studio/lib/feature/app/app.dart`

**Interfaces:**
- Consumes: `MiniTrackerCubit` (`commands`, `state`, `updateComment`), `MiniPanelCommand` (existing, from `mini_tracker_cubit.dart`), `DesktopServiceRegistry.instance.initFollower(cubit)` (existing).
- Produces: `class ActivityPromptPanel extends StatefulWidget` (the comment-only text field), `class ActivityPromptApp extends StatelessWidget` (the top-level app for this follower role). Used by Task 5's `runner.dart` widget selection.

This is UI-only work with no new business logic - exempt from the mandatory-test rule per `apps/worklog_studio/CLAUDE.md` ("UI-only changes are exempt"), exactly like `MiniPanel`/`MiniApp` today. Verified by static analysis and the manual checklist in Task 10.

- [ ] **Step 1: Create `activity_prompt_panel.dart`**

Create `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// The dedicated "what are you working on" prompt - a single comment text
/// field, shown in its own small floating window (see `ActivityPromptApp`).
/// Opened by the toggle hotkey, the reminder, or a button in `MiniPanel`;
/// Enter (Accept hotkey) commits, Escape (Dismiss hotkey) discards.
///
/// Unlike `MiniPanel`'s inline comment editor, this field is always in
/// "edit mode" by design - there is no view-mode/click-to-edit state here,
/// the whole window exists only to edit the comment. Its text is
/// (re)seeded from the persisted comment each time `MiniPanelCommand.
/// focusComment` arrives (i.e. each time this window is shown), not on
/// every snapshot rebuild, so an in-progress edit is never clobbered by an
/// unrelated snapshot update arriving while the window is open.
class ActivityPromptPanel extends StatefulWidget {
  const ActivityPromptPanel({super.key});

  @override
  State<ActivityPromptPanel> createState() => _ActivityPromptPanelState();
}

class _ActivityPromptPanelState extends State<ActivityPromptPanel> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  StreamSubscription<MiniPanelCommand>? _commandSub;
  String _lastPersistedComment = '';

  @override
  void initState() {
    super.initState();
    _commandSub = context.read<MiniTrackerCubit>().commands.listen(_handleCommand);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commandSub?.cancel();
    super.dispose();
  }

  void _commit() {
    context.read<MiniTrackerCubit>().updateComment(_commentController.text);
  }

  void _revert() {
    _commentController.text = _lastPersistedComment;
  }

  void _handleCommand(MiniPanelCommand command) {
    if (!mounted) return;
    switch (command) {
      case MiniPanelCommand.focusComment:
        _lastPersistedComment =
            context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        _commentController.text = _lastPersistedComment;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _commentFocusNode.requestFocus();
        });
      case MiniPanelCommand.acceptComment:
        _commit();
      case MiniPanelCommand.dismissComment:
        _revert();
      case MiniPanelCommand.autoDismissComment:
        // An automatic timeout should not silently discard an in-progress
        // edit the way a user-initiated dismiss does, so commit instead
        // when there is actually an unsaved change.
        if (_commentController.text != _lastPersistedComment) {
          _commit();
        } else {
          _revert();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.lg,
        vertical: theme.spacings.md,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFf8fafc),
        border: Border.all(color: theme.colorsPalette.border.primary.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Briefly describe what are you working on',
            ),
            onSubmitted: (_) => _commit(),
          ),
          SizedBox(height: theme.spacings.xs),
          Text(
            'Enter to submit, Esc to dismiss',
            style: theme.commonTextStyles.caption2.copyWith(
              color: theme.colorsPalette.text.muted,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add `ActivityPromptApp` to `app.dart`**

In `apps/worklog_studio/lib/feature/app/app.dart`, add this import alongside the existing `mini_panel.dart`/`mini_tracker_cubit.dart` imports:

```dart
import 'package:worklog_studio/feature/desktop/presentation/activity_prompt_panel.dart';
```

Then add, directly after the existing `MiniApp` class (before the `// ── Main application ──` comment):

```dart

// ── Activity prompt app (Windows tray engine, activity role only) ───────────

class ActivityPromptApp extends StatelessWidget {
  const ActivityPromptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MiniTrackerCubit>(
      create: (context) {
        final cubit = MiniTrackerCubit();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DesktopServiceRegistry.instance.initFollower(cubit);
        });
        return cubit;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appEnvironment.config.lightTheme,
        darkTheme: appEnvironment.config.lightTheme,
        home: const Scaffold(
          // See MiniApp's comment - the Windows popover has no layered/DWM
          // transparency support, so this stays opaque.
          backgroundColor: Color(0xFFf8fafc),
          body: ActivityPromptPanel(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/feature/desktop/presentation/activity_prompt_panel.dart lib/feature/app/app.dart
```

Expected: "No issues found!"

- [ ] **Step 4: Run the full test suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green (no behavior change to anything under test - these are new, currently-unreferenced widgets).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart apps/worklog_studio/lib/feature/app/app.dart
git commit -m "feat: add ActivityPromptPanel and ActivityPromptApp"
```

---

### Task 5: `runner.dart` widget selection

**Files:**
- Modify: `apps/worklog_studio/lib/runner/runner.dart`

**Interfaces:**
- Consumes: `resolveStartupRole`'s `'tray:activity'`/`'tray'`/`'main'` return values (Task 3), `ActivityPromptApp`/`MiniApp`/`MainApp` (Task 4, existing).

This is application bootstrap wiring with no new business logic - no automated test (there is none for this function today either; it is exercised only by actually launching the app on each role, which is exactly Task 10's manual checklist).

- [ ] **Step 1: Update the role-to-widget branch**

In `apps/worklog_studio/lib/runner/runner.dart`, replace:

```dart
  // Role detection is now owned by the platform service itself.
  final role = await DesktopServiceRegistry.instance.resolveStartupRole(args);
  debugPrint('Successfully resolved engine role: $role');

  final isPopover = role == 'tray';
  debugPrint('runApp starting with role: $role');

  if (isPopover) {
    runApp(const MiniApp());
  } else {
    runApp(const MainApp());
  }
```

with:

```dart
  // Role detection is now owned by the platform service itself.
  final role = await DesktopServiceRegistry.instance.resolveStartupRole(args);
  debugPrint('Successfully resolved engine role: $role');
  debugPrint('runApp starting with role: $role');

  if (role == 'tray:activity') {
    runApp(const ActivityPromptApp());
  } else if (role == 'tray') {
    runApp(const MiniApp());
  } else {
    runApp(const MainApp());
  }
```

- [ ] **Step 2: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/runner/runner.dart
```

Expected: "No issues found!"

- [ ] **Step 3: Run the full test suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/runner/runner.dart
git commit -m "feat: select ActivityPromptApp for the tray:activity startup role"
```

---

### Task 6: Add the second managed window and make IPC routing window-aware

**Why:** Up to this task, `WindowsDesktopService` still only manages `_miniPanelWindow` - the activity window does not exist yet as a concept inside it. This task adds a second `ManagedPopoverWindow` for it, generalizes the 1s prewarm watchdog to cover both, and makes the leader's incoming-message handling and outgoing snapshot broadcast aware of *which* follower window sent or should receive a message - previously there was only ever one follower, so `_handleIncomingIpcMessage`'s `'miniReady'`/`'miniClosed'` cases and `_broadcastSnapshotIfReady` didn't need to know which window they were talking about. Nothing outside this file targets the activity window yet after this task - that's Task 7.

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Test: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`

**Interfaces:**
- Produces: `_activityWindow` (a second `ManagedPopoverWindow`, role `'activity'`), `_windowForId(int windowId)` returning whichever of the two tracks that id (or `null`), `@visibleForTesting ManagedPopoverWindow get miniPanelWindowForTesting` and `@visibleForTesting ManagedPopoverWindow get activityWindowForTesting`. `handleIncomingIpcMessageForTesting` gains an optional `fromWindowId` parameter (default `0`, preserving every existing call site). Used by Task 7's accept/dismiss/focus/auto-dismiss retargeting.

- [ ] **Step 1: Write the failing test**

In `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`, add a new group after the existing `group('WindowsDesktopService follower-side command forwarding', ...)` block (this tests the **leader** side's window-aware routing, a different concern from the existing follower-side group):

```dart

  group('WindowsDesktopService leader-side window-aware routing', () {
    late WindowsDesktopService leaderService;

    setUp(() {
      leaderService = WindowsDesktopService();
      leaderService.miniPanelWindowForTesting.windowId = 101;
      leaderService.miniPanelWindowForTesting.followerReady = false;
      leaderService.activityWindowForTesting.windowId = 202;
      leaderService.activityWindowForTesting.followerReady = false;
    });

    test('miniReady from the mini panel window marks only that window ready', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 101,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isTrue);
      expect(leaderService.activityWindowForTesting.followerReady, isFalse);
    });

    test('miniReady from the activity window marks only that window ready', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 202,
      );

      expect(leaderService.activityWindowForTesting.followerReady, isTrue);
      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
    });

    test('miniClosed from a window clears only that window\'s readiness', () async {
      leaderService.miniPanelWindowForTesting.followerReady = true;
      leaderService.activityWindowForTesting.followerReady = true;

      await leaderService.handleIncomingIpcMessageForTesting(
        'miniClosed',
        null,
        fromWindowId: 101,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
      expect(leaderService.activityWindowForTesting.followerReady, isTrue);
    });

    test('miniReady from an unknown window id is a harmless no-op', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 999,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
      expect(leaderService.activityWindowForTesting.followerReady, isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: FAIL to compile - `miniPanelWindowForTesting`/`activityWindowForTesting` don't exist yet, and `handleIncomingIpcMessageForTesting` doesn't accept a `fromWindowId` argument yet.

- [ ] **Step 3: Add the second window and the test seams**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add the second field directly after `_miniPanelWindow`:

```dart
  late final ManagedPopoverWindow _activityWindow = ManagedPopoverWindow(
    role: 'activity',
    computeFrame: _computeActivityPromptFrame,
  );
```

Add the lookup helper near `_miniPanelWindow`'s declaration (or directly below it):

```dart
  ManagedPopoverWindow? _windowForId(int windowId) {
    if (_miniPanelWindow.windowId == windowId) return _miniPanelWindow;
    if (_activityWindow.windowId == windowId) return _activityWindow;
    return null;
  }
```

Add the activity-prompt frame computation next to the existing `_computeFrameNearTray`/`_computeFrameFixedCorner`:

```dart
  Future<Rect> _computeActivityPromptFrame() async {
    final view = PlatformDispatcher.instance.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    final frame = computeActivityPromptFrame(
      screenSize: screenSize,
      promptSize: _activityPromptSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  static const _activityPromptSize = Size(420, 100);
```

In the `// ── Test seams ──` section at the bottom of the class, add:

```dart
  @visibleForTesting
  ManagedPopoverWindow get miniPanelWindowForTesting => _miniPanelWindow;

  @visibleForTesting
  ManagedPopoverWindow get activityWindowForTesting => _activityWindow;
```

- [ ] **Step 4: Thread `fromWindowId` through the incoming-message handler**

Replace both `DesktopMultiWindow.setMethodHandler` registrations (one in `initLeader`, one in `initFollower`) - each currently reads:

```dart
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });
```

Replace both with:

```dart
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments, fromWindowId);
      return null;
    });
```

Replace the `'miniReady'` and `'miniClosed'` cases inside `_handleIncomingIpcMessage`'s switch - currently:

```dart
        case 'miniReady':
          _followerReady = true;
          if (_leaderBloc != null) {
            await _broadcastSnapshotIfReady(_leaderBloc!.state);
          }
          if (_pendingFocusComment) {
            _pendingFocusComment = false;
            await _invokeFollower('focusComment', null);
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
```

with:

```dart
        case 'miniReady':
          final readyWindow = _windowForId(fromWindowId);
          if (readyWindow != null) {
            readyWindow.followerReady = true;
            if (_leaderBloc != null) {
              await _broadcastSnapshotTo(readyWindow, _leaderBloc!.state);
            }
            if (readyWindow == _activityWindow && _pendingFocusComment) {
              _pendingFocusComment = false;
              await _invokeWindow(_activityWindow, 'focusComment', null);
            }
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
          _windowForId(fromWindowId)?.followerReady = false;
```

Update `_handleIncomingIpcMessage`'s signature and the rest of its switch (the `'focusComment'`/`'acceptComment'`/`'dismissComment'`/`'autoDismissComment'`/`'dispatchAction'`/`'broadcastSnapshot'` cases are unchanged - they don't depend on `fromWindowId` and stay exactly as they are today) - just the signature line itself:

```dart
  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
  ) async {
```

becomes:

```dart
  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
    int fromWindowId,
  ) async {
```

- [ ] **Step 5: Generalize snapshot broadcasting**

Replace `_broadcastSnapshotIfReady` (currently used from `initLeader`'s `bloc.stream.listen`/`projectTaskState.addListener` and from the `'miniReady'` case, all updated above to call a per-window version instead):

```dart
  Future<void> _broadcastSnapshotIfReady(TimeTrackerBlocState state) async {
    if (!_miniPanelWindow.followerReady || _miniPanelWindow.windowId == null) return;

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
        _miniPanelWindow.windowId!,
        'broadcastSnapshot',
        jsonStr,
      );
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot - $e');
    }
  }
```

with:

```dart
  Future<void> _broadcastSnapshotIfReady(TimeTrackerBlocState state) async {
    for (final window in [_miniPanelWindow, _activityWindow]) {
      if (window.followerReady && window.windowId != null) {
        await _broadcastSnapshotTo(window, state);
      }
    }
  }

  Future<void> _broadcastSnapshotTo(
    ManagedPopoverWindow window,
    TimeTrackerBlocState state,
  ) async {
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
      await DesktopMultiWindow.invokeMethod(window.windowId!, 'broadcastSnapshot', jsonStr);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot to ${window.role} - $e');
    }
  }
```

(`readyWindow != null` is already checked by the caller before `_broadcastSnapshotTo` is invoked from the `'miniReady'` case, and the for-loop above checks both conditions itself, so `_broadcastSnapshotTo` itself does not need to re-check readiness.)

- [ ] **Step 6: Generalize the prewarm watchdog and add a leader-side `_invokeWindow` helper**

Replace `_startPrewarmWatchdog`:

```dart
  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(
      _prewarmCheckInterval,
      (_) => _miniPanelWindow.checkAndRewarm(),
    );
  }
```

with:

```dart
  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(_prewarmCheckInterval, (_) async {
      await _miniPanelWindow.checkAndRewarm();
      await _activityWindow.checkAndRewarm();
    });
  }
```

Add a window-targeted version of the existing `_invokeFollower` helper (the existing one stays, used only by the mini panel's path until Task 7 retargets it):

```dart
  Future<void> _invokeWindow(ManagedPopoverWindow window, String method, dynamic arguments) async {
    if (window.windowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(window.windowId!, method, arguments);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to invoke "$method" on ${window.role} - $e');
    }
  }
```

In `initLeader`, add the activity window's pre-warm alongside the mini panel's existing one:

```dart
    // Boot the popover engine now, hidden, so the *first* open is instant
    // instead of paying the multi-second Firebase/DB cold-boot cost the
    // moment the user actually asks for it.
    await _miniPanelWindow.ensureExists();
    await _activityWindow.ensureExists();
    _startPrewarmWatchdog();
```

- [ ] **Step 7: Update the test seam's signature**

In the `// ── Test seams ──` section, replace:

```dart
  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) =>
      _handleIncomingIpcMessage(method, arguments);
```

with:

```dart
  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments, {
    int fromWindowId = 0,
  }) =>
      _handleIncomingIpcMessage(method, arguments, fromWindowId);
```

(The default of `0` keeps every existing call site in `windows_desktop_service_ipc_test.dart` - the `dispatchAction`/follower-command-forwarding groups - compiling and passing unchanged, since none of those cases read `fromWindowId`.)

- [ ] **Step 8: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 9: Static analysis**

```bash
fvm flutter analyze lib/core/services/desktop/windows_desktop_service.dart
```

Expected: "No issues found!"

- [ ] **Step 10: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart
git commit -m "feat: add activity window and make leader-side IPC routing window-aware"
```

---

### Task 7: Retarget hotkeys and the reminder to the activity window

**Why:** This is the behavioral heart of the plan: the toggle/accept/dismiss hotkeys and the reminder currently all operate on `_miniPanelWindow` (via `requestFocusComment`/`acceptCurrentComment`/`dismissCurrentComment`/`autoDismissCurrentComment`, and `ReminderService`'s `onFire`/`isPopoverOpen`). This task retargets all of them to `_activityWindow`, adds the leader-side `showActivityPrompt()`/`toggleActivityPrompt()` methods the hotkey and a later mini-panel button (Task 8) need, adds the cross-platform `requestActivityPrompt()` interface method a follower uses to ask the leader to open it, and removes the mini-panel-specific fixed-corner positioning path that only existed for the reminder's old mini-panel-targeting behavior.

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart`

**Interfaces:**
- Produces: `void requestActivityPrompt()` on `IDesktopPlatformService` (and all three implementations); `Future<void> showActivityPrompt()`, `Future<void> toggleActivityPrompt()` on `WindowsDesktopService`. `requestFocusComment`/`acceptCurrentComment`/`dismissCurrentComment`/`autoDismissCurrentComment` now target `_activityWindow` instead of `_miniPanelWindow`. Used by Task 8's `MiniTrackerCubit.requestActivityPrompt()`.

No automated test for the retargeting itself - this is real native window/IPC orchestration exactly like the methods it modifies, already exempt today. The interface addition's no-op stubs (macOS, `NoOpDesktopService`) are trivially correct by inspection, matching every other no-op method already in those files.

- [ ] **Step 1: Add `requestActivityPrompt` to the interface**

In `apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart`, add after the existing `dispatchAction` method (in the `// ── Action dispatch (macOS popover follower only) ──` section, which this also belongs to conceptually - it is sent the same way, follower to leader):

```dart

  // ── Activity prompt (Windows popover follower only, this iteration) ──────

  /// Ask the leader to open the dedicated activity prompt window.
  ///
  /// Called from a follower/popover. Windows-only this iteration - no-op
  /// on platforms without that window (macOS's equivalent is deferred to a
  /// follow-up spec).
  void requestActivityPrompt();
```

- [ ] **Step 2: Add the no-op stubs**

In `apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart`, add directly after the existing `dispatchAction` override:

```dart

  @override
  void requestActivityPrompt() {
    // Deferred to a follow-up spec - macOS's mini panel already has its
    // own inline comment editor and does not have a separate activity
    // prompt window yet.
  }
```

In `apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart`, add directly after the existing `dispatchAction` override:

```dart

  @override
  void requestActivityPrompt() {}
```

- [ ] **Step 3: Add the Windows implementation and the leader-side methods**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add directly after the existing `dispatchAction` override:

```dart

  @override
  void requestActivityPrompt() {
    if (!_isPopover) return;
    try {
      DesktopMultiWindow.invokeMethod(0, 'requestActivityPrompt', null);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to request activity prompt - $e');
    }
  }
```

Add the leader-side methods directly after `togglePopover()`/`showPopover()`/`showPopoverNearScreenCorner()` (which the next step removes, making room for these):

```dart

  /// Opens the activity prompt and focuses its comment field. A no-op if
  /// nothing is currently being tracked - there is nothing to comment on.
  Future<void> showActivityPrompt() async {
    if (_leaderBloc?.state.isRunning != true) return;
    await _activityWindow.show();
    await requestFocusComment();
  }

  /// Opens/closes the activity prompt - the target of the toggle hotkey.
  /// Closing just hides the window, mirroring how the mini panel's old
  /// toggle closed without sending an explicit discard signal: the field
  /// is simply not visible anymore, and nothing was ever persisted from
  /// an uncommitted edit either way.
  Future<void> toggleActivityPrompt() async {
    await _activityWindow.reconcile();
    if (_activityWindow.isVisible) {
      await _activityWindow.hide();
    } else {
      await showActivityPrompt();
    }
  }
```

Add the `'requestActivityPrompt'` case to `_handleIncomingIpcMessage`'s switch, directly after the existing `'openMainWindow'` case:

```dart
        case 'requestActivityPrompt':
          await showActivityPrompt();
```

- [ ] **Step 4: Remove the now-dead fixed-corner positioning path**

In the same file, remove `showPopoverNearScreenCorner()` entirely:

```dart
  /// Used by [ReminderService], which fires unattended on a timer rather
  /// than from a direct user click - there is no extra context here that
  /// would make a live tray-icon lookup any more trustworthy than usual,
  /// so this always anchors to the fixed screen-corner position instead
  /// of the icon-relative one [showPopover] uses.
  Future<void> showPopoverNearScreenCorner() =>
      _miniPanelWindow.show(frameOverride: _computeFrameFixedCorner);
```

Remove `_computeFrameFixedCorner()` entirely - it has no remaining caller after this task (the reminder no longer targets the mini panel at all):

```dart
  /// Used by [showPopoverNearScreenCorner] - fired unattended by
  /// [ReminderService], where there is no live tray-icon position worth
  /// trusting any more than usual, so this skips `trayManager.getBounds()`
  /// entirely and always anchors to a fixed synthetic point near the
  /// screen's bottom-right corner, where the system tray conventionally
  /// lives.
  Future<Rect> _computeFrameFixedCorner() async {
    final view = PlatformDispatcher.instance.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    final frame = computePopoverFrame(
      trayBounds: _fixedTrayAnchor(screenSize),
      popoverSize: _popoverSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }
```

Leave `_fixedTrayAnchor(Size screenSize)` itself in place - it is still used as `_sanitizeTrayBounds`'s fallback for the mini panel's near-tray positioning, and `fixedTrayAnchorForTesting` in `windows_desktop_service_test.dart` still tests it directly.

- [ ] **Step 5: Retarget `requestFocusComment`/`acceptCurrentComment`/`dismissCurrentComment`/`autoDismissCurrentComment`**

Replace:

```dart
  /// Asks the follower (popover) engine to put the comment field into edit
  /// mode and request keyboard focus. If the popover isn't ready yet (e.g.
  /// it was just created and hasn't sent `miniReady`), the request is
  /// deferred and replayed once `miniReady` arrives - see
  /// [_handleIncomingIpcMessage]'s `'miniReady'` case.
  Future<void> requestFocusComment() async {
    if (_miniPanelWindow.followerReady && _miniPanelWindow.windowId != null) {
      await _invokeFollower('focusComment', null);
    } else {
      _pendingFocusComment = true;
    }
  }

  /// Tells the follower to commit its current comment edit (if any), then
  /// hides the popover. The actual `TimerAction.updateComment` dispatch (if
  /// the comment changed) arrives asynchronously afterward over the existing
  /// `dispatchAction` channel - the popover engine stays alive while hidden,
  /// so this is safe even though we don't wait for it here.
  Future<void> acceptCurrentComment() async {
    await _invokeFollower('acceptComment', null);
    await hidePopover();
  }

  /// Tells the follower to discard its current comment edit (reverting the
  /// field to the last persisted value), then hides the popover.
  Future<void> dismissCurrentComment() async {
    await _invokeFollower('dismissComment', null);
    await hidePopover();
  }

  /// Tells the follower the reminder popover timed out automatically (as
  /// opposed to a user-initiated dismiss). Unlike [dismissCurrentComment],
  /// this preserves any unsaved comment edit by committing it instead of
  /// discarding it - see [MiniPanelCommand.autoDismissComment].
  Future<void> autoDismissCurrentComment() async {
    await _invokeFollower('autoDismissComment', null);
    await hidePopover();
  }

  Future<void> _invokeFollower(String method, dynamic arguments) async {
    if (_miniPanelWindow.windowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(_miniPanelWindow.windowId!, method, arguments);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to invoke follower "$method" - $e');
    }
  }
```

with:

```dart
  /// Asks the activity-prompt follower to put its comment field into edit
  /// mode and request keyboard focus. If it isn't ready yet (e.g. it was
  /// just created and hasn't sent `miniReady`), the request is deferred
  /// and replayed once `miniReady` arrives - see
  /// [_handleIncomingIpcMessage]'s `'miniReady'` case.
  Future<void> requestFocusComment() async {
    if (_activityWindow.followerReady && _activityWindow.windowId != null) {
      await _invokeWindow(_activityWindow, 'focusComment', null);
    } else {
      _pendingFocusComment = true;
    }
  }

  /// Tells the activity-prompt follower to commit its current comment
  /// edit (if any), then hides the window. The actual
  /// `TimerAction.updateComment` dispatch (if the comment changed) arrives
  /// asynchronously afterward over the existing `dispatchAction` channel -
  /// the window's engine stays alive while hidden, so this is safe even
  /// though we don't wait for it here.
  Future<void> acceptCurrentComment() async {
    await _invokeWindow(_activityWindow, 'acceptComment', null);
    await _activityWindow.hide();
  }

  /// Tells the activity-prompt follower to discard its current comment
  /// edit (reverting the field to the last persisted value), then hides
  /// the window.
  Future<void> dismissCurrentComment() async {
    await _invokeWindow(_activityWindow, 'dismissComment', null);
    await _activityWindow.hide();
  }

  /// Tells the activity-prompt follower the reminder timed out
  /// automatically (as opposed to a user-initiated dismiss). Unlike
  /// [dismissCurrentComment], this preserves any unsaved comment edit by
  /// committing it instead of discarding it - see
  /// [MiniPanelCommand.autoDismissComment].
  Future<void> autoDismissCurrentComment() async {
    await _invokeWindow(_activityWindow, 'autoDismissComment', null);
    await _activityWindow.hide();
  }
```

(`_invokeWindow` already exists from Task 6 - this task removes the now-redundant `_invokeFollower` by simply not having any remaining caller reference it, as shown above.)

- [ ] **Step 6: Rewire `HotkeyService` and `ReminderService` in `initLeader`**

Replace:

```dart
    _hotkeyService = HotkeyService(
      registrar: HotkeyManagerRegistrar(),
      getSetting: _settingsRepository.getString,
      setSetting: _settingsRepository.setString,
      onToggle: togglePopover,
      onAccept: acceptCurrentComment,
      onDismiss: dismissCurrentComment,
    );
```

with:

```dart
    _hotkeyService = HotkeyService(
      registrar: HotkeyManagerRegistrar(),
      getSetting: _settingsRepository.getString,
      setSetting: _settingsRepository.setString,
      onToggle: toggleActivityPrompt,
      onAccept: acceptCurrentComment,
      onDismiss: dismissCurrentComment,
    );
```

Replace:

```dart
    _reminderService = ReminderService(
      bloc: bloc,
      getSetting: _settingsRepository.getString,
      isPopoverOpen: () => _miniPanelWindow.isVisible,
      onFire: () async {
        await showPopoverNearScreenCorner();
        await requestFocusComment();
      },
      onAutoDismiss: autoDismissCurrentComment,
    );
```

with:

```dart
    _reminderService = ReminderService(
      bloc: bloc,
      getSetting: _settingsRepository.getString,
      isPopoverOpen: () => _activityWindow.isVisible,
      onFire: showActivityPrompt,
      onAutoDismiss: autoDismissCurrentComment,
    );
```

- [ ] **Step 7: Static analysis and full test suite**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/core/services/desktop/i_desktop_platform_service.dart lib/core/services/desktop/windows_desktop_service.dart lib/core/services/desktop/macos_desktop_service.dart lib/core/services/desktop/no_op_desktop_service.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: "No issues found!" and all tests green.

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/i_desktop_platform_service.dart apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/lib/core/services/desktop/macos_desktop_service.dart apps/worklog_studio/lib/core/services/desktop/no_op_desktop_service.dart
git commit -m "feat: retarget hotkeys and reminder to the activity prompt window"
```

---

### Task 8: `MiniTrackerCubit.requestActivityPrompt` and the mini-panel button

**Files:**
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart`
- Test: `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`

**Interfaces:**
- Consumes: `DesktopServiceRegistry.instance.requestActivityPrompt()` (Task 7).
- Produces: `MiniTrackerCubit.requestActivityPrompt()`, called by a new button in `MiniPanel`'s active-session card.

- [ ] **Step 1: Write the failing test**

In `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`, find the existing `_RecordingDesktopService` class:

```dart
class _RecordingDesktopService extends NoOpDesktopService {
  final List<dynamic> dispatched = [];

  @override
  void dispatchAction(covariant dynamic action) {
    dispatched.add(action);
  }
}
```

Replace it with:

```dart
class _RecordingDesktopService extends NoOpDesktopService {
  final List<dynamic> dispatched = [];
  int requestActivityPromptCalls = 0;

  @override
  void dispatchAction(covariant dynamic action) {
    dispatched.add(action);
  }

  @override
  void requestActivityPrompt() {
    requestActivityPromptCalls++;
  }
}
```

Add a new test group, after the existing `group('MiniTrackerCubit.commands', ...)` block:

```dart

  group('MiniTrackerCubit.requestActivityPrompt', () {
    test('asks the desktop service to open the activity prompt when a session is running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.requestActivityPrompt();

      expect(desktopService.requestActivityPromptCalls, 1);
    });

    test('does nothing when no session is running', () {
      cubit.requestActivityPrompt();

      expect(desktopService.requestActivityPromptCalls, 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart
```

Expected: FAIL to compile - `requestActivityPrompt` doesn't exist on `MiniTrackerCubit` yet, and `NoOpDesktopService.requestActivityPrompt` doesn't exist as an overridable member until Task 7 lands (if Task 7 is already done, this fails only on the missing `MiniTrackerCubit` method).

- [ ] **Step 3: Implement**

In `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`, add directly after `updateComment`:

```dart

  /// Opens the dedicated activity prompt window (see
  /// `ActivityPromptPanel`) - a no-op when nothing is currently being
  /// tracked, mirroring the leader-side guard in
  /// `WindowsDesktopService.showActivityPrompt()`.
  void requestActivityPrompt() {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.requestActivityPrompt();
  }
```

- [ ] **Step 4: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 5: Add the button to `MiniPanel`**

This is UI-only - exempt from the mandatory-test rule, same as the rest of `MiniPanel`'s widget tree.

In `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart`, inside `_buildActiveSession`, find the `InlineField` for the comment editor:

```dart
                  SizedBox(height: theme.spacings.lg),
                  InlineField(
                    label: 'Comment',
                    value: _commentController.text,
                    placeholder: 'Add a comment...',
                    controller: _commentFieldController,
                    textController: _commentController,
                    isTextArea: true,
                    viewModeMaxLines: 2,
                    editWidget: TextArea(
                      label: null,
                      hintText: 'Add a comment...',
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

Replace the closing `],\n                ),\n              ),` of that `Column`'s children list (i.e. add a new child right after the `InlineField`, before the children list closes) - the surrounding structure becomes:

```dart
                  SizedBox(height: theme.spacings.lg),
                  InlineField(
                    label: 'Comment',
                    value: _commentController.text,
                    placeholder: 'Add a comment...',
                    controller: _commentFieldController,
                    textController: _commentController,
                    isTextArea: true,
                    viewModeMaxLines: 2,
                    editWidget: TextArea(
                      label: null,
                      hintText: 'Add a comment...',
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      autofocus: true,
                    ),
                  ),
                  SizedBox(height: theme.spacings.sm),
                  PrimaryButton(
                    type: ButtonType.ghost,
                    size: ButtonSize.sm,
                    leftIconWidget: const Icon(Icons.chat_bubble_outline, size: 14),
                    onTap: () {
                      context.read<MiniTrackerCubit>().requestActivityPrompt();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/feature/desktop/presentation/mini_panel.dart lib/feature/desktop/presentation/mini_tracker_cubit.dart
```

Expected: "No issues found!"

- [ ] **Step 7: Run the full test suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart
git commit -m "feat: add a mini-panel button to open the activity prompt"
```

---

### Task 9: Manual verification on Windows

**Files:** none (no code changes).

This task cannot be automated - it exercises real window creation, global hotkeys, tray interaction, and inter-window IPC across two simultaneous secondary windows, none of which run inside `flutter test`.

- [ ] **Step 1: Build and run the dev flavor**

```bash
cd apps/worklog_studio
fvm flutter run -d windows -t lib/main_development.dart
```

- [ ] **Step 2: Verify the mini panel is unaffected**

Click the tray icon. Expected: the mini panel opens near the tray icon exactly as before - search box, active session card (if tracking), its own inline comment editor still works by clicking the comment field directly.

- [ ] **Step 3: Verify the toggle hotkey now opens the activity prompt**

Start tracking a task from the main window. Press `Ctrl+Shift+M`. Expected: a small window appears fixed near the top-center of the screen (not near the tray), already focused, showing the current comment (or empty if none) with the hint "Enter to submit, Esc to dismiss". The mini panel does **not** open.

Press `Ctrl+Shift+M` again. Expected: the activity prompt closes; the mini panel is unaffected either way.

- [ ] **Step 4: Verify Accept and Dismiss**

Reopen the activity prompt (`Ctrl+Shift+M`), type a new comment, press `Ctrl+Shift+Enter`. Expected: the prompt closes; checking the main window or the mini panel shows the new comment persisted.

Reopen, type a different comment, press `Ctrl+Shift+Escape`. Expected: the prompt closes; the comment is unchanged from the previous step's accepted value.

- [ ] **Step 5: Verify the reminder targets the activity prompt, not the mini panel**

In Settings, set the reminder interval to 1 minute. With tracking active, leave the app alone for slightly over a minute. Expected: the activity prompt opens on its own, focused - the mini panel is not affected. Leave it untouched for ~20 more seconds. Expected: it closes on its own (auto-dismiss), discarding an untouched empty edit or committing a typed-but-unsubmitted one.

While the activity prompt is already open (you opened it manually with the hotkey), wait long enough for the reminder interval to elapse again. Expected: the reminder does **not** re-fire or disrupt the window you already have open.

- [ ] **Step 6: Verify the mini-panel button**

Open the mini panel via the tray icon, with a session running. Click the new button below the comment field (chat-bubble icon). Expected: the activity prompt opens, focused, same as the hotkey path.

- [ ] **Step 7: Verify both windows can coexist**

With a session running, open the mini panel (tray click) and the activity prompt (hotkey) at the same time. Expected: both are visible simultaneously, neither closes or interferes with the other. Edit the comment via the activity prompt and accept it; expected: the mini panel's own comment display/editor reflects the new value (both read from the same underlying data, broadcast to both windows).

- [ ] **Step 8: Verify close-via-X recovery for both windows independently**

Close the mini panel via its native titlebar X button. Wait a couple of seconds, then click the tray icon again. Expected: it reopens (after the usual one-time cold-boot cost if the watchdog hadn't already re-warmed it).

Repeat for the activity prompt: open it, close it via its native X button, wait a couple of seconds, then press the toggle hotkey again. Expected: same recovery behavior.

- [ ] **Step 9: Verify the no-active-session guard**

Stop tracking (nothing running). Press `Ctrl+Shift+M`. Expected: nothing happens - no activity prompt appears.

- [ ] **Step 10: Record the outcome**

If any step fails, root-cause it by reading the actual `desktop_multi_window`/`hotkey_manager` native source under the pub cache rather than guessing, the same way every prior issue in this feature's development was diagnosed. Use `systematic-debugging` for any such investigation.

