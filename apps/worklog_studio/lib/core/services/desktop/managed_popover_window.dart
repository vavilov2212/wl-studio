import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart' as win32;

/// Manages the lifecycle of one `desktop_multi_window` secondary engine:
/// creation (serialized against concurrent callers), liveness detection,
/// and show/hide. `WindowsDesktopService` holds one instance per
/// independent floating window it owns (the mini panel, the activity
/// prompt) - each gets the exact same race-free creation and
/// close-via-X detection, instead of that logic being hand-duplicated
/// per window.
class ManagedPopoverWindow {
  ManagedPopoverWindow({
    required this.role,
    required this.computeFrame,
    this.frameless = false,
    this.alwaysOnTop = false,
  });

  /// A short tag identifying this window's purpose (e.g. `'miniPanel'`,
  /// `'activity'`), passed through `createWindow()`'s payload so the new
  /// engine's `main()` can tell which top-level widget to run.
  final String role;

  /// Computes this window's on-screen frame when shown via `show()`
  /// without an explicit `frameOverride`.
  final Future<Rect> Function() computeFrame;

  /// Strips the native title bar/border (no minimize/maximize/close, no
  /// resize handles) right after every `show()`. `desktop_multi_window`'s
  /// native window always starts as an ordinary `WS_OVERLAPPEDWINDOW` -
  /// fine for a window meant to look like part of the app's own chrome,
  /// wrong for a small floating prompt.
  final bool frameless;

  /// Keeps this window above all other windows without ever stealing OS
  /// keyboard focus as a side effect of merely showing it.
  /// `desktop_multi_window`'s own `Show()` is a bare Win32
  /// `ShowWindow(SW_SHOW)`, whose activation behavior is inconsistent for a
  /// window owned by a background process - intra-process activation is
  /// sometimes allowed and sometimes not, depending on which window last
  /// held the OS foreground - so the same `show()` call can either jump on
  /// top of everything and steal focus, or get left sitting behind whatever
  /// else is currently active. This corrects both problems deterministically
  /// via a direct `SetWindowPos(HWND_TOPMOST, SWP_NOACTIVATE)` call after
  /// every show, restoring focus to whatever held it immediately beforehand
  /// if `Show()` happened to grab it.
  final bool alwaysOnTop;

  int? windowId;
  bool isVisible = false;
  bool followerReady = false;

  Future<void>? _creationInFlight;

  /// Set once on the native window purely so [_nativeHandle] can find it
  /// again later via `FindWindow` - never shown to the user (this window
  /// either has no title bar at all once [frameless] strips it, or, for a
  /// non-frameless window, no Windows convention surfaces a popover's
  /// window title anywhere visible).
  String get _nativeTitle => 'WorklogStudioPopover_$role';

  int? _nativeHandle() {
    final titlePtr = _nativeTitle.toNativeUtf16();
    try {
      final hwnd = win32.FindWindow(nullptr, titlePtr);
      return hwnd == 0 ? null : hwnd;
    } finally {
      calloc.free(titlePtr);
    }
  }

  void _applyFrameless() {
    final hwnd = _nativeHandle();
    if (hwnd == null) return;
    final style = win32.GetWindowLongPtr(hwnd, win32.GWL_STYLE);
    final stripped = style &
        ~(win32.WS_CAPTION |
            win32.WS_THICKFRAME |
            win32.WS_SYSMENU |
            win32.WS_MINIMIZEBOX |
            win32.WS_MAXIMIZEBOX);
    win32.SetWindowLongPtr(hwnd, win32.GWL_STYLE, stripped);
    win32.SetWindowPos(
      hwnd,
      0,
      0,
      0,
      0,
      0,
      win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOZORDER | win32.SWP_FRAMECHANGED,
    );
  }

  void _applyAlwaysOnTop() {
    final hwnd = _nativeHandle();
    if (hwnd == null) return;
    win32.SetWindowPos(
      hwnd,
      win32.HWND_TOPMOST,
      0,
      0,
      0,
      0,
      win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOACTIVATE,
    );
  }

  /// Explicitly grabs OS keyboard focus. Only call this from a real, direct
  /// user input event (e.g. a global hotkey callback) - Windows generally
  /// blocks `SetForegroundWindow` from a process that isn't already the
  /// foreground one, except right after that process just received input,
  /// which is exactly what a hotkey press is.
  void activate() {
    final hwnd = _nativeHandle();
    if (hwnd == null) return;
    win32.SetForegroundWindow(hwnd);
  }

  /// Whether this window currently owns OS keyboard focus.
  bool get isForeground {
    final hwnd = _nativeHandle();
    return hwnd != null && hwnd == win32.GetForegroundWindow();
  }

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
      await WindowController.fromWindowId(windowId!).setTitle(_nativeTitle);
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
  ///
  /// If [activate] is `false`, the window is shown without taking OS
  /// keyboard focus: whatever held focus immediately before this call still
  /// holds it afterward, even if the underlying native `Show()` happened to
  /// activate this window as a side effect (see [alwaysOnTop]'s doc comment).
  Future<void> show({
    Future<Rect> Function()? frameOverride,
    bool activate = true,
  }) async {
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

      final previousForeground = activate ? null : win32.GetForegroundWindow();
      await controller.show();
      isVisible = true;

      if (frameless) _applyFrameless();
      if (alwaysOnTop) _applyAlwaysOnTop();
      if (!activate && previousForeground != null && previousForeground != 0) {
        win32.SetForegroundWindow(previousForeground);
      }
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
