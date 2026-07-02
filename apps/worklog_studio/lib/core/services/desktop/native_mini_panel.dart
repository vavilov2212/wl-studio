import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'native_mini_panel/mini_panel_layout.dart';
import 'native_mini_panel/mini_panel_painter.dart';
import 'native_mini_panel/mini_panel_state.dart';

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
  static final _defWindowProcPtr =
      Pointer.fromFunction<win32.WNDPROC>(_defWindowProc, 0);

  // Fonts (created once with the window)
  MiniPanelFonts? _fonts;

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

  bool get isVisible => _hwnd != null && win32.IsWindowVisible(_hwnd!) == win32.TRUE;

  void show(int anchorX, int anchorY) {
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
  }

  /// Push a new display state. Only triggers a repaint when the state changed.
  void update(MiniPanelDisplayState state) {
    if (_state == state) return;
    _state = state;
    _scrollOffset = 0; // reset scroll on new state
    _dirty = true;
    // Resize window to fit new content
    final h = _hwnd;
    if (h != null && isVisible) _resizeToContent(h);
  }

  void dispose() {
    _stopPolling();
    _fonts?.destroy();
    _fonts = null;
    final h = _hwnd;
    if (h != null) {
      win32.DestroyWindow(h);
      _hwnd = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Window creation
  // ---------------------------------------------------------------------------

  void _createWindow() {
    _registerClass();

    final className = _kClassName.toNativeUtf16();
    final title = ''.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        win32.WS_EX_TOOLWINDOW | win32.WS_EX_TOPMOST,
        className,
        title,
        win32.WS_POPUP,
        0, 0,
        MiniPanelMetrics.panelW,
        MiniPanelMetrics.panelH(isRunning: false, entryCount: 0),
        win32.NULL,
        win32.NULL,
        win32.NULL,
        nullptr,
      );
      if (h == 0) return;
      _hwnd = h;
      _fonts = MiniPanelFonts.create();
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
  }

  static void _registerClass() {
    if (_classRegistered) return;
    _classRegistered = true;

    final className = _kClassName.toNativeUtf16();
    try {
      final wc = calloc<win32.WNDCLASSEX>();
      wc.ref.cbSize = sizeOf<win32.WNDCLASSEX>();
      wc.ref.style = win32.CS_HREDRAW | win32.CS_VREDRAW;
      wc.ref.lpfnWndProc = _defWindowProcPtr;
      wc.ref.hInstance = win32.GetModuleHandle(nullptr);
      wc.ref.hbrBackground = win32.GetStockObject(win32.WHITE_BRUSH);
      wc.ref.lpszClassName = className;
      win32.RegisterClassEx(wc);
      calloc.free(wc);
    } finally {
      calloc.free(className);
    }
  }

  static int _defWindowProc(int hwnd, int msg, int wParam, int lParam) =>
      win32.DefWindowProc(hwnd, msg, wParam, lParam);

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
    final rect = calloc<win32.RECT>();
    try {
      win32.GetWindowRect(h, rect);
      win32.SetWindowPos(
        h,
        win32.HWND_TOPMOST,
        rect.ref.left,
        rect.ref.bottom - layout.clientH,
        layout.clientW,
        layout.clientH,
        win32.SWP_NOACTIVATE,
      );
    } finally {
      calloc.free(rect);
    }
  }

  void _repositionNear(int h, int anchorX, int anchorY) {
    final layout = _buildLayout();
    final panelW = layout.clientW;
    final panelH = layout.clientH;

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
    if (h == null || win32.IsWindowVisible(h) == win32.FALSE) return;

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
    } finally {
      calloc.free(pt);
    }
  }

  void _handleClick(HitRect hit) {
    switch (hit.hit) {
      case MiniPanelHit.desktopBtn:
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
    }
  }
}
