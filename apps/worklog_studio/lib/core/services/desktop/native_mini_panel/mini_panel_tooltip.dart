import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'mini_panel_painter.dart';

// DrawText flags (DT_* not exported by win32 package).
const _dtLeft = 0x00000000;
const _dtVCenter = 0x00000004;
const _dtSingleLine = 0x00000020;
const _dtEndEllipsis = 0x00008000;
const _dtNoPrefix = 0x00000800;

/// A tiny GDI-painted tooltip popup for the mini panel.
///
/// Shows a single line of text near an anchor point (screen coordinates),
/// sized to the text but clamped to the monitor work area; text that still
/// doesn't fit is ellipsized. Never takes focus and is transparent to the
/// mouse, so it can't steal hover from the panel.
class MiniPanelTooltip {
  static const _kClassName = 'WorklogMiniPanelTooltipV1';
  static bool _classRegistered = false;

  static final Pointer<NativeFunction<win32.WNDPROC>> _defWindowProcPtr =
      DynamicLibrary.open('user32.dll')
          .lookup<NativeFunction<win32.WNDPROC>>('DefWindowProcW');

  int? _hwnd;

  static const _padH = 10;
  static const _padV = 6;
  static const _tooltipH = 26;
  static const _screenMargin = 12;

  bool get isVisible =>
      _hwnd != null && win32.IsWindowVisible(_hwnd!) == win32.TRUE;

  /// Shows the tooltip with [text] just below the anchor (screen coords).
  /// [font] is the HFONT to render with (borrowed, not owned).
  void show(String text, int anchorX, int anchorY, int font) {
    if (_hwnd == null) _createWindow();
    final h = _hwnd;
    if (h == null) return;

    final work = _monitorWorkArea(anchorX, anchorY);
    final maxW = (work.right - work.left) - _screenMargin * 2;
    final textW = MiniPanelPainter.measureTextWidth(font, text);
    final w = (textW + _padH * 2).clamp(0, maxW);

    var x = anchorX.clamp(work.left, work.right - w);
    var y = anchorY;
    if (y + _tooltipH > work.bottom) y = anchorY - _tooltipH - 4;

    win32.SetWindowPos(h, win32.HWND_TOPMOST, x, y, w, _tooltipH,
        win32.SWP_NOACTIVATE | win32.SWP_SHOWWINDOW);
    _paint(h, text, font, w);
  }

  void hide() {
    final h = _hwnd;
    if (h != null && win32.IsWindow(h) == win32.TRUE) {
      win32.ShowWindow(h, win32.SW_HIDE);
    }
  }

  void dispose() {
    final h = _hwnd;
    if (h != null) {
      win32.DestroyWindow(h);
      _hwnd = null;
    }
  }

  void _createWindow() {
    _registerClass();
    final className = _kClassName.toNativeUtf16();
    final title = ''.toNativeUtf16();
    try {
      final h = win32.CreateWindowEx(
        win32.WS_EX_TOOLWINDOW |
            win32.WS_EX_TOPMOST |
            win32.WS_EX_NOACTIVATE |
            win32.WS_EX_TRANSPARENT,
        className,
        title,
        win32.WS_POPUP,
        0, 0, 10, _tooltipH,
        win32.NULL,
        win32.NULL,
        win32.GetModuleHandle(nullptr),
        nullptr,
      );
      if (h == 0) return;
      _hwnd = h;
      _applyRoundedCorners(h);
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
  }

  static void _applyRoundedCorners(int hwnd) {
    final pref = calloc<Uint32>()..value = win32.DWMWCP_ROUNDSMALL;
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

  static void _registerClass() {
    if (_classRegistered) return;
    _classRegistered = true;

    final className = _kClassName.toNativeUtf16();
    try {
      final wc = calloc<win32.WNDCLASSEX>();
      wc.ref.cbSize = sizeOf<win32.WNDCLASSEX>();
      wc.ref.lpfnWndProc = _defWindowProcPtr;
      wc.ref.hInstance = win32.GetModuleHandle(nullptr);
      // Owned by the window class for the process lifetime - never freed.
      wc.ref.hbrBackground = win32.CreateSolidBrush(miniPanelSurfaceColorRef);
      wc.ref.lpszClassName = className;
      win32.RegisterClassEx(wc);
      calloc.free(wc);
    } finally {
      calloc.free(className);
    }
  }

  static void _paint(int hwnd, String text, int font, int w) {
    final hdc = win32.GetDC(hwnd);
    if (hdc == 0) return;
    final rect = calloc<win32.RECT>();
    final pText = text.toNativeUtf16();
    try {
      rect.ref.left = 0;
      rect.ref.top = 0;
      rect.ref.right = w;
      rect.ref.bottom = _tooltipH;
      final brush = win32.CreateSolidBrush(miniPanelSurfaceColorRef);
      win32.FillRect(hdc, rect, brush);
      win32.DeleteObject(brush);

      rect.ref.left = _padH;
      rect.ref.right = w - _padH;
      rect.ref.top = _padV;
      rect.ref.bottom = _tooltipH - _padV;
      win32.SelectObject(hdc, font);
      win32.SetBkMode(hdc, win32.TRANSPARENT);
      win32.SetTextColor(hdc, miniPanelTextPrimaryColorRef);
      win32.DrawText(hdc, pText, -1, rect,
          _dtLeft | _dtVCenter | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);
    } finally {
      calloc.free(rect);
      calloc.free(pText);
      win32.ReleaseDC(hwnd, hdc);
    }
  }

  static ({int left, int top, int right, int bottom}) _monitorWorkArea(
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
}
