import 'dart:async';
import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:worklog_studio/core/services/desktop/native_window_coordinator.dart';

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

    if (_hwnd == null) {
      _registerClassIfNeeded();
      _createWindows(idleMinutes);
    } else {
      _updateHeader(idleMinutes);
      _setExpanded(false);
    }

    if (_hwnd == null) return; // window creation failed - do NOT call coordinator

    _coordinator.idleResolutionWillShow(); // only after window is valid
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
    if (win32.IsWindow(h) == win32.FALSE) {
      hide();
      _hwnd = null;
      _keepBtnHwnd = null;
      _discardBtnHwnd = null;
      _logBtnHwnd = null;
      _editHwnd = null;
      _confirmBtnHwnd = null;
      _headerHwnd = null;
      return;
    }

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
    final buf = win32.wsalloc(512);
    try {
      win32.GetWindowText(h, buf, 512);
      return buf.toDartString();
    } finally {
      calloc.free(buf);
    }
  }
}
