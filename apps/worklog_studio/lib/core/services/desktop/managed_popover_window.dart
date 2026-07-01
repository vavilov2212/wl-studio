import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
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
    required this.getMainWindowId,
    this.frameless = false,
    this.alwaysOnTop = false,
  });

  /// A short tag identifying this window's purpose (e.g. `'miniPanel'`,
  /// `'activity'`), passed through `create()`'s payload so the new
  /// engine's `main()` can tell which top-level widget to run.
  final String role;

  /// Computes this window's on-screen frame when shown via `show()`
  /// without an explicit `frameOverride`.
  final Future<Rect> Function() computeFrame;

  /// Returns the leader engine's window ID so it can be embedded in the
  /// creation arguments and used by the follower for IPC back to the leader.
  final String? Function() getMainWindowId;

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

  String? windowId;
  bool isVisible = false;
  bool followerReady = false;

  Future<void>? _creationInFlight;

  /// Cached HWND for this window, discovered via `FindWindowEx` at creation
  /// time. Cleared whenever [windowId] is reset (i.e. the native window has
  /// been destroyed and a new one will be created on next [show]).
  int? _cachedHwnd;

  static const _flutterWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

  int? _nativeHandle() => _cachedHwnd;

  /// Returns HWNDs of all Flutter windows owned by this process.
  Set<int> _allFlutterProcessHwnds() {
    final result = <int>{};
    final pid = win32.GetCurrentProcessId();
    final classPtr = _flutterWindowClass.toNativeUtf16();
    try {
      var hwnd = win32.FindWindowEx(0, 0, classPtr, nullptr);
      while (hwnd != 0) {
        final pidPtr = calloc<Uint32>();
        try {
          win32.GetWindowThreadProcessId(hwnd, pidPtr);
          if (pidPtr.value == pid) result.add(hwnd);
        } finally {
          calloc.free(pidPtr);
        }
        hwnd = win32.FindWindowEx(0, hwnd, classPtr, nullptr);
      }
    } finally {
      calloc.free(classPtr);
    }
    return result;
  }

  /// Finds the HWND of a Flutter window in this process NOT in [excludeHwnds].
  int? _findNewFlutterHwnd({required Set<int> excludeHwnds}) {
    final pid = win32.GetCurrentProcessId();
    final classPtr = _flutterWindowClass.toNativeUtf16();
    try {
      var hwnd = win32.FindWindowEx(0, 0, classPtr, nullptr);
      while (hwnd != 0) {
        if (!excludeHwnds.contains(hwnd)) {
          final pidPtr = calloc<Uint32>();
          try {
            win32.GetWindowThreadProcessId(hwnd, pidPtr);
            if (pidPtr.value == pid) return hwnd;
          } finally {
            calloc.free(pidPtr);
          }
        }
        hwnd = win32.FindWindowEx(0, hwnd, classPtr, nullptr);
      }
    } finally {
      calloc.free(classPtr);
    }
    return null;
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
    final result = win32.SetWindowPos(
      hwnd,
      0,
      0,
      0,
      0,
      0,
      win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOZORDER | win32.SWP_FRAMECHANGED,
    );
    if (result == 0) {
      debugPrint(
        'ManagedPopoverWindow($role): SetWindowPos (frameless) failed - '
        'GetLastError=${win32.GetLastError()}',
      );
    }
  }

  void _applyAlwaysOnTop() {
    final hwnd = _nativeHandle();
    if (hwnd == null) return;
    final result = win32.SetWindowPos(
      hwnd,
      win32.HWND_TOPMOST,
      0,
      0,
      0,
      0,
      win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOACTIVATE,
    );
    debugPrint(
      'ManagedPopoverWindow($role): SetWindowPos(HWND_TOPMOST) on hwnd=$hwnd '
      'result=$result${result == 0 ? " GetLastError=${win32.GetLastError()}" : ""}',
    );
  }

  void _applyFrame(int hwnd, Rect frame) {
    final result = win32.SetWindowPos(
      hwnd,
      0,
      frame.left.toInt(),
      frame.top.toInt(),
      frame.width.toInt(),
      frame.height.toInt(),
      win32.SWP_NOZORDER | win32.SWP_NOACTIVATE,
    );
    if (result == 0) {
      debugPrint(
        'ManagedPopoverWindow($role): SetWindowPos (frame) failed - '
        'GetLastError=${win32.GetLastError()}',
      );
    }
  }

  /// Explicitly grabs OS keyboard focus. Only call this from a real, direct
  /// user input event (e.g. a global hotkey callback) - Windows generally
  /// blocks `SetForegroundWindow` from a process that isn't already the
  /// foreground one, except right after that process just received input,
  /// which is exactly what a hotkey press is.
  void activate() {
    final hwnd = _nativeHandle();
    if (hwnd == null) return;
    final result = win32.SetForegroundWindow(hwnd);
    if (result == 0) {
      debugPrint('ManagedPopoverWindow($role): SetForegroundWindow failed for hwnd=$hwnd');
    }
  }

  /// Whether this window currently owns OS keyboard focus.
  bool get isForeground {
    final hwnd = _nativeHandle();
    return hwnd != null && hwnd == win32.GetForegroundWindow();
  }

  /// Ensures a popover engine exists, creating one if necessary - without
  /// showing it. A no-op if one already exists.
  ///
  /// Concurrent callers share the same in-flight `create()` call
  /// instead of each starting their own: a user-initiated `show()` and a
  /// background pre-warm tick can otherwise both observe `windowId == null`
  /// at the same time (the create call takes long enough to boot a whole
  /// engine) and each create their own window. Whichever one's create call
  /// resolves *second* would then silently overwrite `windowId` with its
  /// own (different, never-shown) window id - leaving this object pointing
  /// at a hidden window while the one actually on screen never receives
  /// any further snapshots, focus requests, or hide/show calls. Funnelling
  /// every creation through this one in-flight future makes that race
  /// impossible: only one `create()` call is ever outstanding, and
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
      // Snapshot existing Flutter HWNDs before creating so we can identify
      // the new window afterward without relying on title-based FindWindow.
      final existingHwnds = _allFlutterProcessHwnds();
      final controller = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            'role': role,
            'mainWindowId': getMainWindowId(),
          }),
        ),
      );
      windowId = controller.windowId;
      _cachedHwnd = _findNewFlutterHwnd(excludeHwnds: existingHwnds);
      debugPrint(
        'ManagedPopoverWindow($role): created window id=$windowId hwnd=$_cachedHwnd',
      );
    } catch (e) {
      debugPrint('ManagedPopoverWindow($role): failed to create window - $e');
    } finally {
      _creationInFlight = null;
      completer.complete();
    }
  }

  /// Checks whether the window ID still maps to a live native window by
  /// querying the plugin's own window registry via `WindowController.getAll()`.
  /// The registry is updated synchronously on window destroy, so a missing
  /// ID here means the window was closed (via its native title-bar X button
  /// or any other means), not merely that the follower engine hasn't
  /// initialised its method handler yet - avoiding the ambiguity that arises
  /// when checking via an IPC call whose `CHANNEL_UNREGISTERED` error
  /// conflates "window gone" with "channel not yet registered".
  Future<bool> isAlive() async {
    try {
      final all = await WindowController.getAll();
      final alive = all.any((c) => c.windowId == windowId);
      if (!alive) {
        debugPrint('ManagedPopoverWindow($role): window $windowId confirmed destroyed');
      }
      return alive;
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
      _resetWindowState();
    }
  }

  void _resetWindowState() {
    windowId = null;
    isVisible = false;
    _cachedHwnd = null;
  }

  /// Shows this window, creating it first if necessary. Uses
  /// [computeFrame] unless [frameOverride] is supplied.
  ///
  /// If [activate] is `false`, the window is shown without taking OS
  /// keyboard focus at all, via a direct `ShowWindow(..., SW_SHOWNA)` FFI
  /// call instead of the plugin's own `Show()` (a bare `ShowWindow(...,
  /// SW_SHOW)`, which can activate). An earlier version of this method
  /// used `SW_SHOW` unconditionally and then tried to *undo* an unwanted
  /// activation by calling `SetForegroundWindow` on whatever previously
  /// held focus - but that restore call itself reactivates that other
  /// window, and Windows draws the active window above a topmost-but-
  /// inactive one regardless of the topmost flag being correctly set.
  /// `SW_SHOWNA` avoids the problem at its source: it never touches the
  /// foreground window in the first place, so there is nothing to restore.
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

      final hwnd = _nativeHandle();
      if (hwnd != null) {
        _applyFrame(hwnd, frame);
        win32.ShowWindow(hwnd, activate ? win32.SW_SHOW : win32.SW_SHOWNA);
      } else {
        // Couldn't resolve the hwnd yet - fall back to the plugin's show(),
        // which may activate when we didn't want it to, but still shows the
        // window. Frame cannot be applied without the hwnd.
        await WindowController.fromWindowId(windowId!).show();
      }
      isVisible = true;

      if (frameless) _applyFrameless();
      if (alwaysOnTop) _applyAlwaysOnTop();
      debugPrint('ManagedPopoverWindow($role): show completed, windowId=$windowId');
    } catch (e) {
      debugPrint('ManagedPopoverWindow($role): error showing - $e');
    }
  }

  /// Hiding does not touch [followerReady] - the follower engine and its
  /// IPC channel stay fully alive while hidden, they just aren't visible.
  /// `'miniReady'` (the only thing that ever sets [followerReady] `true`)
  /// is sent exactly once, at the follower's cold boot - if `hide()` reset
  /// it here, every `followerReady`-gated message (focus-seeding, status
  /// updates) to this window would silently defer forever after the very
  /// first show/hide cycle, since nothing would ever set it back to `true`
  /// short of the window being destroyed and recreated from scratch.
  Future<void> hide() async {
    if (windowId != null) {
      try {
        await WindowController.fromWindowId(windowId!).hide();
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
      _resetWindowState();
      followerReady = false;
      await ensureExists();
      return;
    }
    // HWND_TOPMOST is "best effort" on Windows - activating a different,
    // ordinary window can still visually cover a topmost-but-unfocused
    // window on some Windows versions/configurations even though the flag
    // is correctly set (confirmed: SetWindowPos itself reports success).
    // Every real "Always On Top" utility deals with this the same way -
    // by re-asserting topmost periodically rather than trusting one call
    // to stick forever - so this watchdog tick (already running once a
    // second for liveness) re-applies it too while visible.
    if (alwaysOnTop && isVisible) _applyAlwaysOnTop();
  }

  // ─── Test seams ────────────────────────────────────────────────────────────

  @visibleForTesting
  int? get cachedHwndForTesting => _cachedHwnd;

  @visibleForTesting
  void setCachedHwndForTesting(int? hwnd) => _cachedHwnd = hwnd;

  /// Resets all native-window state as [reconcile] does when it detects
  /// destruction - exposed for tests that cannot drive a real Win32 window
  /// lifecycle.
  @visibleForTesting
  void resetWindowStateForTesting() => _resetWindowState();
}
