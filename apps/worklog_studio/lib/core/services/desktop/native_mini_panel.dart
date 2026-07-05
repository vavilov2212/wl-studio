import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'native_mini_panel/mini_panel_layout.dart';
import 'native_mini_panel/mini_panel_painter.dart';
import 'native_mini_panel/mini_panel_state.dart';
import 'native_mini_panel/mini_panel_tooltip.dart';

export 'native_mini_panel/mini_panel_layout.dart';
export 'native_mini_panel/mini_panel_painter.dart' show MiniPanelFonts;
export 'native_mini_panel/mini_panel_state.dart';

/// A tray-style mini panel drawn entirely in GDI - no secondary Flutter engine.
///
/// Lifecycle: create once at app start, call [show]/[hide] to toggle, call
/// [update] whenever the [MiniPanelDisplayState] changes, call [dispose] on
/// app shutdown.
///
/// Callbacks fire on the Dart main isolate (inside the poll timer tick).
class NativeMiniPanel {
  NativeMiniPanel({
    required this.onStop,
    required this.onStart,
    required this.onSwitchActivity,
    required this.onOpenMainApp,
  });

  final void Function() onStop;
  final void Function(MiniPanelEntry entry) onStart;
  final void Function() onSwitchActivity;
  final void Function() onOpenMainApp;

  // Win32 window
  int? _hwnd;
  static const _kClassName = 'WorklogMiniPanelV1';
  static bool _classRegistered = false;

  // Native C pointer to DefWindowProcW - NOT a Dart Pointer.fromFunction.
  // Win32 sends WM_NCCREATE/WM_CREATE synchronously inside CreateWindowEx,
  // before it returns. A Dart callback here fires while the VM is inside
  // the FFI call and crashes with "Cannot invoke native callback outside
  // an isolate". Using the raw C pointer avoids any Dart re-entry.
  static final Pointer<NativeFunction<win32.WNDPROC>> _defWindowProcPtr =
      DynamicLibrary.open('user32.dll')
          .lookup<NativeFunction<win32.WNDPROC>>('DefWindowProcW');

  // Fonts (created once with the window)
  MiniPanelFonts? _fonts;

  // Truncation tooltip for the session card's task/project text.
  final MiniPanelTooltip _tooltip = MiniPanelTooltip();
  MiniPanelHit? _tooltipZone;
  DateTime? _tooltipHoverStart;
  static const _tooltipDelay = Duration(milliseconds: 400);

  // C-side message handling, exported by the Windows runner
  // (runner/mini_panel_messages.cpp). A Dart wndproc is NOT an option even
  // as a post-creation subclass: the platform message loop dispatches
  // messages while the isolate is not entered, which aborts the VM
  // ("Cannot invoke native callback outside an isolate"). The C wndproc
  // handles WM_MOUSEWHEEL / WM_SETCURSOR / WM_CLOSE synchronously and the
  // poll tick drains its atomics.
  static Pointer<NativeFunction<win32.WNDPROC>>? _panelWndProcPtr;
  static int Function()? _takeWheelDelta;
  static void Function(int)? _setCursorHand;
  static int Function()? _takeCloseRequested;
  static bool _nativeBindingsResolved = false;

  static void _resolveNativeBindings() {
    if (_nativeBindingsResolved) return;
    _nativeBindingsResolved = true;
    try {
      final exe = DynamicLibrary.executable();
      _panelWndProcPtr =
          exe.lookup<NativeFunction<win32.WNDPROC>>('MiniPanelWndProc');
      _takeWheelDelta = exe.lookupFunction<Int32 Function(), int Function()>(
          'MiniPanelTakeWheelDelta');
      _setCursorHand = exe.lookupFunction<Void Function(Int32),
          void Function(int)>('MiniPanelSetCursorHand');
      _takeCloseRequested =
          exe.lookupFunction<Int32 Function(), int Function()>(
              'MiniPanelTakeCloseRequested');
    } catch (_) {
      // Host executable without the helper (e.g. tests). Fall back to
      // DefWindowProc: wheel scroll, hand cursor, and close-to-hide degrade
      // gracefully (chevrons/arrow keys still scroll; X destroys and the
      // next show() recreates).
      _panelWndProcPtr = null;
      _takeWheelDelta = null;
      _setCursorHand = null;
      _takeCloseRequested = null;
    }
  }

  // State
  MiniPanelDisplayState _state = MiniPanelDisplayState.empty;
  int _scrollOffset = 0;

  // Interaction tracking
  HitRect? _hoveredHit;
  bool _lmbWasDown = false;
  bool _dirty = true;

  // Poll timer (50 ms = 20 fps; light duty for a small static panel)
  Timer? _pollTimer;

  static const _pollInterval = Duration(milliseconds: 50);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  // Window styles: an OS caption bar (draggable, with a close button) on a
  // topmost popup. Deliberately NOT WS_EX_TOOLWINDOW: tool windows get the
  // flat legacy caption (unpadded close button) and DWM refuses to round
  // their corners. Taskbar/Alt+Tab exclusion comes from being an owned
  // window instead (see [_ensureOwner]).
  static const _style = win32.WS_POPUP | win32.WS_CAPTION | win32.WS_SYSMENU;
  static const _exStyle = win32.WS_EX_TOPMOST;

  bool get isVisible =>
      _hwnd != null && win32.IsWindowVisible(_hwnd!) == win32.TRUE;

  void show(int anchorX, int anchorY) {
    // Safety net for the DefWindowProc fallback, where the OS close button
    // destroys the window: recreate when the handle is gone.
    if (_hwnd != null && win32.IsWindow(_hwnd!) == win32.FALSE) _hwnd = null;
    if (_hwnd == null) _createWindow();
    final h = _hwnd;
    if (h == null) return;

    _repositionNear(h, anchorX, anchorY);

    win32.ShowWindow(h, win32.SW_SHOWNOACTIVATE);
    win32.SetForegroundWindow(h);
    _dirty = true;
    _startPolling();
  }

  void hide() {
    final h = _hwnd;
    if (h != null) win32.ShowWindow(h, win32.SW_HIDE);
    _stopPolling();
    _hoveredHit = null;
    _lmbWasDown = false;
    _setCursorHand?.call(0);
    _dismissTooltip();
  }

  /// Push a new display state. Only triggers a repaint when the state changed.
  void update(MiniPanelDisplayState state) {
    if (_state == state) return;
    _state = state;
    _scrollOffset = 0; // reset scroll on new state
    _dismissTooltip();
    _dirty = true;
    // Resize window to fit new content
    final h = _hwnd;
    if (h != null && isVisible) _resizeToContent(h);
  }

  void dispose() {
    _stopPolling();
    _tooltip.dispose();
    _fonts?.destroy();
    _fonts = null;
    final h = _hwnd;
    if (h != null) {
      win32.DestroyWindow(h);
      _hwnd = null;
    }
    final owner = _ownerHwnd;
    if (owner != null) {
      win32.DestroyWindow(owner);
      _ownerHwnd = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Window creation
  // ---------------------------------------------------------------------------

  void _createWindow() {
    _registerClass();

    final className = _kClassName.toNativeUtf16();
    final title = 'Worklog Studio'.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        _exStyle,
        className,
        title,
        _style,
        0, 0,
        MiniPanelMetrics.panelW,
        MiniPanelMetrics.panelH(isRunning: false, entryCount: 0),
        _ensureOwner(),
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
      if (h == 0) return;
      _hwnd = h;
      _applyDwmStyle(h);
      _fonts ??= MiniPanelFonts.create();
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
  }

  // Hidden helper window that owns the panel.
  int? _ownerHwnd;

  /// Owned windows get no taskbar button and are skipped by Alt+Tab, which
  /// lets the panel keep a standard (padded, rounded) Windows 11 caption
  /// without resorting to WS_EX_TOOLWINDOW. Never shown; destroyed in
  /// [dispose].
  int _ensureOwner() {
    final existing = _ownerHwnd;
    if (existing != null && win32.IsWindow(existing) == win32.TRUE) {
      return existing;
    }
    final className = _kClassName.toNativeUtf16();
    final title = ''.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        0,
        className,
        title,
        win32.WS_POPUP,
        0, 0, 0, 0,
        win32.NULL,
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
      _ownerHwnd = h == 0 ? null : h;
      // 0 falls back to an unowned panel (taskbar button, but functional).
      return h;
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
  }

  /// Rounded corners and a subtle border matching border.primary, applied
  /// via DWM (Windows 11+; silently ignored on older builds).
  static void _applyDwmStyle(int hwnd) {
    final pref = calloc<Uint32>()..value = win32.DWMWCP_ROUND;
    final borderColor = calloc<Uint32>()..value = miniPanelBorderColorRef;
    try {
      win32.DwmSetWindowAttribute(
          hwnd, win32.DWMWA_WINDOW_CORNER_PREFERENCE, pref.cast(), 4);
      win32.DwmSetWindowAttribute(
          hwnd, win32.DWMWA_BORDER_COLOR, borderColor.cast(), 4);
    } finally {
      calloc.free(pref);
      calloc.free(borderColor);
    }
  }

  /// Converts a desired client size into the outer window size, accounting
  /// for the caption bar at the window's current DPI.
  (int, int) _outerSize(int hwnd, int clientW, int clientH) {
    final rect = calloc<win32.RECT>();
    try {
      rect.ref.left = 0;
      rect.ref.top = 0;
      rect.ref.right = clientW;
      rect.ref.bottom = clientH;
      win32.AdjustWindowRectExForDpi(
          rect, _style, win32.FALSE, _exStyle, win32.GetDpiForWindow(hwnd));
      return (rect.ref.right - rect.ref.left, rect.ref.bottom - rect.ref.top);
    } finally {
      calloc.free(rect);
    }
  }

  static void _registerClass() {
    if (_classRegistered) return;
    _classRegistered = true;
    _resolveNativeBindings();

    final className = _kClassName.toNativeUtf16();
    try {
      final wc = calloc<win32.WNDCLASSEX>();
      wc.ref.cbSize = sizeOf<win32.WNDCLASSEX>();
      wc.ref.style = win32.CS_HREDRAW | win32.CS_VREDRAW;
      wc.ref.lpfnWndProc = _panelWndProcPtr ?? _defWindowProcPtr;
      wc.ref.hInstance = win32.GetModuleHandle(nullptr);
      wc.ref.hCursor = win32.LoadCursor(win32.NULL, win32.IDC_ARROW);
      // Owned by the window class for the process lifetime - never freed.
      wc.ref.hbrBackground = win32.CreateSolidBrush(miniPanelCanvasColorRef);
      wc.ref.lpszClassName = className;
      win32.RegisterClassEx(wc);
      calloc.free(wc);
    } finally {
      calloc.free(className);
    }
  }

  // ---------------------------------------------------------------------------
  // Layout helpers
  // ---------------------------------------------------------------------------

  MiniPanelLayout _buildLayout() => MiniPanelLayout.compute(
        isRunning: _state.isRunning,
        entryCount: _state.entries.length,
        scrollOffset: _scrollOffset,
      );

  void _resizeToContent(int h) {
    final layout = _buildLayout();
    final (outerW, outerH) = _outerSize(h, layout.clientW, layout.clientH);
    final rect = calloc<win32.RECT>();
    try {
      win32.GetWindowRect(h, rect);
      win32.SetWindowPos(
        h,
        win32.HWND_TOPMOST,
        rect.ref.left,
        rect.ref.bottom - outerH,
        outerW,
        outerH,
        win32.SWP_NOACTIVATE,
      );
    } finally {
      calloc.free(rect);
    }
  }

  void _repositionNear(int h, int anchorX, int anchorY) {
    final layout = _buildLayout();
    final (panelW, panelH) = _outerSize(h, layout.clientW, layout.clientH);

    // Place above anchor by default; clamp to screen.
    final monitorRect = _nearestMonitorRect(anchorX, anchorY);
    int x = anchorX - panelW ~/ 2;
    int y = anchorY - panelH - 4;

    x = x.clamp(monitorRect.left, monitorRect.right - panelW);
    y = y.clamp(monitorRect.top, monitorRect.bottom - panelH);

    win32.SetWindowPos(
      h,
      win32.HWND_TOPMOST,
      x, y, panelW, panelH,
      win32.SWP_NOACTIVATE,
    );
  }

  ({int left, int top, int right, int bottom}) _nearestMonitorRect(
      int x, int y) {
    final pt = calloc<win32.POINT>();
    pt.ref.x = x;
    pt.ref.y = y;
    final hMon = win32.MonitorFromPoint(pt.ref, win32.MONITOR_DEFAULTTONEAREST);
    calloc.free(pt);

    final mi = calloc<win32.MONITORINFO>();
    mi.ref.cbSize = sizeOf<win32.MONITORINFO>();
    win32.GetMonitorInfo(hMon, mi);
    final r = (
      left: mi.ref.rcWork.left,
      top: mi.ref.rcWork.top,
      right: mi.ref.rcWork.right,
      bottom: mi.ref.rcWork.bottom,
    );
    calloc.free(mi);
    return r;
  }

  // ---------------------------------------------------------------------------
  // Poll timer
  // ---------------------------------------------------------------------------

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _onPollTick() {
    final h = _hwnd;
    if (h == null) return;
    // DefWindowProc fallback: the OS close button destroyed the window;
    // reset so the next show() recreates it.
    if (win32.IsWindow(h) == win32.FALSE) {
      _hwnd = null;
      _stopPolling();
      _hoveredHit = null;
      _lmbWasDown = false;
      return;
    }
    // OS close button (handled by the C wndproc): the window is already
    // hidden; finish the hide on the Dart side (stop polling, reset state).
    if ((_takeCloseRequested?.call() ?? 0) != 0) {
      hide();
      return;
    }

    if (win32.IsWindowVisible(h) == win32.FALSE) return;

    // Wheel scrolling accumulated by the C wndproc since the last tick.
    final wheelDelta = _takeWheelDelta?.call() ?? 0;
    if (wheelDelta != 0) _applyScroll(-wheelDelta ~/ 2);

    _pumpScrollMessages(h);
    _trackMouse(h);
    _trackKeys();

    // Timer ticks while running so elapsed time updates every second.
    if (_state.isRunning) _dirty = true;

    if (_dirty) {
      _dirty = false;
      final layout = _buildLayout();
      final fonts = _fonts;
      if (fonts != null) {
        MiniPanelPainter.paint(h, _state, layout, fonts, _hoveredHit);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll
  // ---------------------------------------------------------------------------

  void _pumpScrollMessages(int h) {
    final msg = calloc<win32.MSG>();
    try {
      while (win32.PeekMessage(msg, h, win32.WM_MOUSEWHEEL,
              win32.WM_MOUSEWHEEL, win32.PM_REMOVE) ==
          win32.TRUE) {
        final hiWord = (msg.ref.wParam >> 16) & 0xFFFF;
        final delta = hiWord >= 32768 ? hiWord - 65536 : hiWord;
        _applyScroll(-delta ~/ 2);
      }
    } finally {
      calloc.free(msg);
    }
  }

  void _applyScroll(int delta) {
    final layout = _buildLayout();
    final newOffset =
        (_scrollOffset + delta).clamp(0, layout.maxScrollOffset);
    if (newOffset != _scrollOffset) {
      _scrollOffset = newOffset;
      _dirty = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Keyboard (arrow keys for scroll)
  // ---------------------------------------------------------------------------

  bool _upWasDown = false;
  bool _downWasDown = false;

  void _trackKeys() {
    final h = _hwnd;
    if (h == null || win32.GetForegroundWindow() != h) return;

    final upNow =
        (win32.GetAsyncKeyState(win32.VK_UP) & 0x8000) != 0;
    final downNow =
        (win32.GetAsyncKeyState(win32.VK_DOWN) & 0x8000) != 0;

    // Rising edge = key just pressed
    if (upNow && !_upWasDown) _applyScroll(-MiniPanelMetrics.itemH);
    if (downNow && !_downWasDown) _applyScroll(MiniPanelMetrics.itemH);

    _upWasDown = upNow;
    _downWasDown = downNow;
  }

  // ---------------------------------------------------------------------------
  // Mouse tracking and click handling
  // ---------------------------------------------------------------------------

  void _trackMouse(int h) {
    final pt = calloc<win32.POINT>();
    try {
      if (win32.GetCursorPos(pt) == win32.FALSE) return;
      if (win32.ScreenToClient(h, pt) == win32.FALSE) return;

      final layout = _buildLayout();
      final hit = layout.hitTest(pt.ref.x, pt.ref.y);

      final lmbNow = (win32.GetAsyncKeyState(win32.VK_LBUTTON) & 0x8000) != 0;

      // Falling edge = click (button released while still over same hit)
      if (_lmbWasDown && !lmbNow && hit != null) {
        _handleClick(hit);
      }

      if (hit?.hit != _hoveredHit?.hit ||
          hit?.entryIndex != _hoveredHit?.entryIndex) {
        _hoveredHit = hit;
        _dirty = true;
      }

      _lmbWasDown = lmbNow;

      // Tell the C wndproc whether WM_SETCURSOR should show the hand cursor.
      _setCursorHand?.call(
          hit != null && clickableMiniPanelHits.contains(hit.hit) ? 1 : 0);

      _updateTooltip(h, hit);
    } finally {
      calloc.free(pt);
    }
  }

  /// Shows a tooltip with the full text after a short hover dwell over the
  /// session card's task/project/comment lines, but only when the text is
  /// actually truncated.
  void _updateTooltip(int h, HitRect? hit) {
    final zone = hit?.hit;
    final fonts = _fonts;
    final (text, measureFont) = switch (zone) {
      MiniPanelHit.sessionTitle => (_state.activeTitle, fonts?.title),
      MiniPanelHit.sessionSubtitle => (_state.activeSubtitle, fonts?.caption),
      MiniPanelHit.sessionComment => (_state.activeComment, fonts?.caption),
      _ => (null, null),
    };
    if (text == null || text.isEmpty || measureFont == null || fonts == null) {
      _dismissTooltip();
      return;
    }

    if (_tooltipZone != zone) {
      _tooltip.hide();
      _tooltipZone = zone;
      _tooltipHoverStart = DateTime.now();
      return;
    }
    if (_tooltip.isVisible) return;
    final start = _tooltipHoverStart;
    if (start == null || DateTime.now().difference(start) < _tooltipDelay) {
      return;
    }

    // Only show when the text overflows its line (i.e. it is ellipsized).
    final rect = hit!;
    if (MiniPanelPainter.measureTextWidth(measureFont, text) <=
        rect.x2 - rect.x1) {
      return;
    }

    final pt = calloc<win32.POINT>();
    try {
      pt.ref.x = rect.x1;
      pt.ref.y = rect.y2 + 4;
      win32.ClientToScreen(h, pt);
      _tooltip.show(text, pt.ref.x, pt.ref.y, fonts.caption);
    } finally {
      calloc.free(pt);
    }
  }

  void _dismissTooltip() {
    _tooltipZone = null;
    _tooltipHoverStart = null;
    _tooltip.hide();
  }

  void _handleClick(HitRect hit) {
    switch (hit.hit) {
      case MiniPanelHit.openMainBtn:
        onOpenMainApp();
      case MiniPanelHit.stopBtn:
        onStop();
      case MiniPanelHit.switchActivity:
        onSwitchActivity();
      case MiniPanelHit.scrollUp:
        _applyScroll(-MiniPanelMetrics.itemH);
      case MiniPanelHit.scrollDown:
        _applyScroll(MiniPanelMetrics.itemH);
      case MiniPanelHit.startBtn:
        if (hit.entryIndex >= 0 &&
            hit.entryIndex < _state.entries.length) {
          onStart(_state.entries[hit.entryIndex]);
        }
      case MiniPanelHit.sessionTitle:
      case MiniPanelHit.sessionSubtitle:
      case MiniPanelHit.sessionComment:
        break; // hover-only tooltip zones
    }
  }
}
