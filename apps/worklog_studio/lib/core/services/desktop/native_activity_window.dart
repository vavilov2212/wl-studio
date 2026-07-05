import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart' as win32;

/// A lightweight native Win32 floating window that replaces the
/// [desktop_multi_window] secondary Flutter engine for the activity prompt.
///
/// Uses a single Win32 EDIT child control for text input and a STATIC child
/// for the status line. No Flutter engine, no EGL context, no D3D11 surface -
/// so none of the ACCESS_VIOLATION crashes from flutter/flutter#155685 can
/// occur here.
///
/// Only one instance exists at runtime ([WindowsDesktopService] owns it).
class NativeActivityWindow {
  NativeActivityWindow({
    required this.onAccept,
    required this.onDismiss,
  });

  /// Called when the user presses Enter. The comment text from the EDIT
  /// control is passed directly - no IPC round-trip. Called after [hide].
  final void Function(String comment) onAccept;

  /// Called when the user presses Escape or the window is auto-dismissed.
  /// Called after [hide].
  final void Function() onDismiss;

  bool isVisible = false;

  // ── statics ──────────────────────────────────────────────────────────────

  static const _kClassName = 'WorklogActivityPrompt';
  static bool _classRegistered = false;

  // Native DefWindowProcW loaded once from user32.dll.
  // Using a C function pointer here (not a Dart Pointer.fromFunction / NativeCallable)
  // means Win32 message handling is entirely C++ with no Dart isolate involvement.
  // This avoids "Cannot invoke native callback outside an isolate" crashes that
  // fire whenever a Dart-based WndProc or SubclassProc is called while the Dart
  // VM is in native mode (e.g. inside another FFI call on the same thread).
  static final Pointer<NativeFunction<win32.WNDPROC>> _defWindowProcPtr =
      DynamicLibrary.open('user32.dll')
          .lookup<NativeFunction<win32.WNDPROC>>('DefWindowProcW');

  // ── instance ─────────────────────────────────────────────────────────────

  int? _hwnd;
  int? _editHwnd;
  int? _statusHwnd;
  int? _hFont; // GDI HFONT - held for control lifetime, deleted in dispose
  Timer? _countdownTimer;
  Timer? _keyPollTimer;
  // Tracked so _pollKeys can detect a resize and relayout children.
  int _lastClientW = 0;
  int _lastClientH = 0;

  // Prevents a burst of rapid Enter presses from triggering multiple accepts.
  // Reset by [show] so the next open always starts clean.
  bool _acceptHandled = false;

  // ── public API ────────────────────────────────────────────────────────────

  /// Total window size (including title bar and resize borders). Used by
  /// [WindowsDesktopService._computeActivityPromptFrame].
  static const windowSize = Size(440, 140);

  bool get isForeground {
    final h = _hwnd;
    return h != null && h == win32.GetForegroundWindow();
  }

  /// Shows the window at [frame], seeding the EDIT control with
  /// [currentComment] (select-all so the first keystroke replaces). If
  /// [activate] is false the window appears without stealing OS keyboard
  /// focus (passive/reminder show). [autoDismissAt] starts a visible
  /// countdown on the status line; pass null for an indefinite show.
  void show({
    required String currentComment,
    required Rect frame,
    bool activate = false,
    DateTime? autoDismissAt,
  }) {
    _acceptHandled = false;

    if (_hwnd == null) {
      _registerClassIfNeeded();
      _createWindows();
    }

    if (_hwnd == null) return; // creation failed

    _applyFrame(frame);
    _setCloak(false);
    if (win32.IsWindowVisible(_hwnd!) == win32.FALSE) {
      win32.ShowWindow(_hwnd!, activate ? win32.SW_SHOW : win32.SW_SHOWNA);
    }

    _setText(currentComment);
    _selectAll();

    if (activate) {
      win32.SetForegroundWindow(_hwnd!);
      if (_editHwnd != null) win32.SetFocus(_editHwnd!);
    }

    _updateCountdown(autoDismissAt);
    _startKeyPolling();
    isVisible = true;
  }

  /// Grabs OS keyboard focus and routes it to the EDIT control. Only safe
  /// to call immediately after a direct user input event (hotkey press) -
  /// Windows blocks [SetForegroundWindow] from background processes otherwise.
  void activate() {
    if (_hwnd != null) {
      win32.SetForegroundWindow(_hwnd!);
      if (_editHwnd != null) win32.SetFocus(_editHwnd!);
    }
  }

  /// Cancels any auto-dismiss countdown and shows the idle hint text,
  /// without hiding the window. Used when the user explicitly brings a
  /// reminder-opened prompt into focus (toggle hotkey) - once they've
  /// acknowledged it the countdown must stop.
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _setStatus('Enter to save, Esc to cancel');
  }

  /// Hides the window via [DWMWA_CLOAK] (DWM compositor only - the
  /// Win32 window stays "visible" at the OS level so no WM_SHOWWINDOW
  /// is ever sent to the process).
  void hide() {
    if (_hwnd != null) _setCloak(true);
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _stopKeyPolling();
    isVisible = false;
  }

  /// Reads the current text from the EDIT control directly via
  /// [GetWindowText] - no IPC, no async.
  String getText() {
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

  void dispose() {
    _countdownTimer?.cancel();
    _stopKeyPolling();
    if (_hwnd != null) {
      if (win32.IsWindow(_hwnd!) != win32.FALSE) {
        win32.DestroyWindow(_hwnd!);
      }
      _hwnd = null;
      _editHwnd = null;
      _statusHwnd = null;
    }
    if (_hFont != null) {
      win32.DeleteObject(_hFont!);
      _hFont = null;
    }
  }

  // ── Key polling ───────────────────────────────────────────────────────────

  void _startKeyPolling() {
    _keyPollTimer?.cancel();
    _keyPollTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _pollKeys(),
    );
  }

  void _stopKeyPolling() {
    _keyPollTimer?.cancel();
    _keyPollTimer = null;
  }

  // Called every 50 ms while the window is visible. GetAsyncKeyState bit 0
  // is set if the key was pressed since the last call for that key, giving
  // reliable edge detection without any Win32 callback or subclass.
  void _pollKeys() {
    final h = _hwnd;
    if (h == null || !isVisible) {
      _stopKeyPolling();
      return;
    }
    // DefWindowProcW handles WM_CLOSE by calling DestroyWindow. Detect that
    // the user clicked X so we can fire onDismiss without a Dart WndProc.
    if (win32.IsWindow(h) == win32.FALSE) {
      _hwnd = null;
      _editHwnd = null;
      _statusHwnd = null;
      _stopKeyPolling();
      isVisible = false;
      onDismiss();
      return;
    }
    // Relayout children if the user resized the window.
    final rect = calloc<win32.RECT>();
    try {
      win32.GetClientRect(h, rect);
      final w = rect.ref.right;
      final ht = rect.ref.bottom;
      if (w != _lastClientW || ht != _lastClientH) {
        _lastClientW = w;
        _lastClientH = ht;
        _relayoutChildren(w, ht);
      }
    } finally {
      calloc.free(rect);
    }

    // Only act when our window owns the OS foreground (EDIT is a child of h,
    // so GetForegroundWindow returns h when the EDIT has keyboard focus).
    if (win32.GetForegroundWindow() != h) return;

    if (!_acceptHandled) {
      if (win32.GetAsyncKeyState(win32.VK_RETURN) & 0x0001 != 0) {
        _acceptHandled = true;
        final text = getText();
        hide();
        onAccept(text);
        return;
      }
    }

    if (win32.GetAsyncKeyState(win32.VK_ESCAPE) & 0x0001 != 0) {
      hide();
      onDismiss();
    }
  }

  // ── Win32 setup ───────────────────────────────────────────────────────────

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
      if (atom == 0) {
        debugPrint(
          'NativeActivityWindow: RegisterClassEx failed - ${win32.GetLastError()}',
        );
      } else {
        _classRegistered = true;
      }
    } finally {
      calloc.free(wc);
      calloc.free(className);
    }
  }

  void _createWindows() {
    final className = _kClassName.toNativeUtf16();
    final titleStr = 'Worklog Studio'.toNativeUtf16();
    try {
      _hwnd = win32.CreateWindowEx(
        win32.WS_EX_TOPMOST,
        className,
        titleStr,
        // WS_CAPTION - draggable title bar with standard X-button margins.
        // WS_SYSMENU - close button (DefWindowProcW handles WM_CLOSE → DestroyWindow,
        //   detected in _pollKeys via IsWindow check).
        // WS_THICKFRAME - resizable; children relayout via _relayoutChildren called
        //   from the 50ms poll timer when client rect changes.
        win32.WS_CAPTION | win32.WS_SYSMENU | win32.WS_THICKFRAME,
        0,
        0,
        windowSize.width.toInt(),
        windowSize.height.toInt(),
        win32.NULL,
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
    } finally {
      calloc.free(className);
      calloc.free(titleStr);
    }

    if (_hwnd == null || _hwnd == 0) {
      debugPrint(
        'NativeActivityWindow: CreateWindowEx (parent) failed - ${win32.GetLastError()}',
      );
      _hwnd = null;
      return;
    }

    // Single-line comment EDIT - placeholder bounds; _relayoutChildren sizes it.
    final editClass = 'EDIT'.toNativeUtf16();
    final editEmpty = ''.toNativeUtf16();
    try {
      _editHwnd = win32.CreateWindowEx(
        0,
        editClass,
        editEmpty,
        win32.WS_CHILD | win32.WS_VISIBLE |
            win32.ES_LEFT | win32.ES_AUTOHSCROLL,
        0, 0, 1, 1,
        _hwnd!,
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
    } finally {
      calloc.free(editClass);
      calloc.free(editEmpty);
    }

    if (_editHwnd == 0) _editHwnd = null;

    // Status hint STATIC - placeholder bounds; _relayoutChildren sizes it.
    final staticClass = 'STATIC'.toNativeUtf16();
    final hintText = 'Enter to save, Esc to cancel'.toNativeUtf16();
    try {
      _statusHwnd = win32.CreateWindowEx(
        0,
        staticClass,
        hintText,
        win32.WS_CHILD | win32.WS_VISIBLE | win32.SS_LEFT,
        0, 0, 1, 1,
        _hwnd!,
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
    } finally {
      calloc.free(staticClass);
      calloc.free(hintText);
    }

    if (_statusHwnd == 0) _statusHwnd = null;

    // Segoe UI 11pt at 96 DPI. Negative lfHeight = character height in pixels.
    // Flutter loads NunitoSans as a private GDI resource but only into Skia,
    // so Segoe UI is the closest native match for a clean sans-serif look.
    final lf = calloc<win32.LOGFONT>();
    try {
      lf.ref.lfHeight = -15; // 11pt at 96 DPI
      lf.ref.lfWeight = 400; // FW_NORMAL
      lf.ref.lfQuality = win32.CLEARTYPE_QUALITY;
      lf.ref.lfCharSet = win32.DEFAULT_CHARSET;
      lf.ref.lfFaceName = 'Segoe UI';
      _hFont = win32.CreateFontIndirect(lf);
    } finally {
      calloc.free(lf);
    }
    if (_hFont != null && _hFont != 0) {
      if (_editHwnd != null) {
        win32.SendMessage(_editHwnd!, win32.WM_SETFONT, _hFont!, win32.TRUE);
      }
      if (_statusHwnd != null) {
        win32.SendMessage(_statusHwnd!, win32.WM_SETFONT, _hFont!, win32.TRUE);
      }
    }

    // Position children using the actual client rect so margins are exact
    // regardless of title-bar height and border widths at the current DPI.
    final rect = calloc<win32.RECT>();
    try {
      win32.GetClientRect(_hwnd!, rect);
      _lastClientW = rect.ref.right;
      _lastClientH = rect.ref.bottom;
    } finally {
      calloc.free(rect);
    }
    _relayoutChildren(_lastClientW, _lastClientH);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static const _kPad = 12;
  static const _kEditH = 26;
  static const _kStatusH = 16;

  // Positions EDIT and STATIC with uniform padding on all sides.
  // Called at creation time and whenever the poll timer detects a resize.
  void _relayoutChildren(int clientW, int clientH) {
    final contentW = clientW - _kPad * 2;
    if (contentW <= 0 || clientH <= _kPad * 2) return;
    if (_editHwnd != null) {
      win32.MoveWindow(_editHwnd!, _kPad, _kPad, contentW, _kEditH, win32.TRUE);
    }
    if (_statusHwnd != null) {
      win32.MoveWindow(
        _statusHwnd!,
        _kPad,
        clientH - _kPad - _kStatusH,
        contentW,
        _kStatusH,
        win32.TRUE,
      );
    }
  }

  void _applyFrame(Rect frame) {
    if (_hwnd == null) return;
    win32.SetWindowPos(
      _hwnd!,
      win32.HWND_TOPMOST,
      frame.left.toInt(),
      frame.top.toInt(),
      frame.width.toInt(),
      frame.height.toInt(),
      win32.SWP_NOACTIVATE,
    );
  }

  void _setCloak(bool cloak) {
    final h = _hwnd;
    if (h == null) return;
    final value = calloc<Int32>();
    try {
      value.value = cloak ? 1 : 0;
      win32.DwmSetWindowAttribute(h, win32.DWMWA_CLOAK, value.cast(), sizeOf<Int32>());
    } finally {
      calloc.free(value);
    }
  }

  void _setText(String text) {
    final h = _editHwnd;
    if (h == null) return;
    final ptr = text.toNativeUtf16();
    try {
      win32.SetWindowText(h, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  void _selectAll() {
    final h = _editHwnd;
    if (h == null) return;
    // EM_SETSEL goes to the built-in Win32 EDIT WndProc (C++ only, no Dart
    // callback involved) - safe to call from inside any FFI context.
    win32.SendMessage(h, win32.EM_SETSEL, 0, -1);
  }

  void _setStatus(String text) {
    final h = _statusHwnd;
    if (h == null) return;
    final ptr = text.toNativeUtf16();
    try {
      win32.SetWindowText(h, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  void _updateCountdown(DateTime? autoDismissAt) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (autoDismissAt == null) {
      _setStatus('Enter to save, Esc to cancel');
      return;
    }
    void tick() {
      final remaining = autoDismissAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _setStatus('Closing...');
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _setStatus('Closing in ${remaining}s - Enter to save, Esc to cancel');
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }
}
