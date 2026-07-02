import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'mini_panel_layout.dart';
import 'mini_panel_state.dart';

// DrawText format flags (DT_* not exported by win32 package).
const _dtLeft = 0x00000000;
const _dtCenter = 0x00000001;
const _dtVCenter = 0x00000004;
const _dtSingleLine = 0x00000020;
const _dtEndEllipsis = 0x00008000;
const _dtNoPrefix = 0x00000800;

// CreatePen styles.
const _psSolid = 0;
const _psNull = 5;

// Font weight constants (not exported by win32 package).
const _fwLight = 300;
const _fwNormal = 400;
const _fwBold = 700;

// COLORREF palette (0x00BBGGRR).
const _cBg = 0x00F8F6F4;           // canvas background
const _cHeaderBg = 0x00FFFFFF;      // header and section bg
const _cSessionBg = 0x00FFFFFF;
const _cItemBg = 0x00F8F6F4;
const _cItemBgHover = 0x00EEE9E5;
const _cBorder = 0x00DBD4CE;        // separator lines
const _cTextPrimary = 0x001C1E21;   // #21201C
const _cTextSecondary = 0x005B5550; // muted body
const _cTextMuted = 0x009C9389;     // captions, labels
const _cAccent = 0x00A55F18;        // blue-ish accent (links)
// #16A34A in RGB → R=0x16 G=0xA3 B=0x4A → COLORREF = 0x004AA316
const _cGreenColorRef = 0x004AA316;
const _cGreenHover = 0x003D8015;    // darker green for hover
const _cRedColorRef = 0x002626DC;   // #DC2626 → R=DC G=26 B=26 → 0x002626DC
const _cRedHover = 0x001C1CB9;
const _cFooterBg = 0x00EEE5DB;      // light warm tint
const _cTimerText = 0x004AA316;     // large timer = green
const _cBtnTextLight = 0x00FFFFFF;  // text on colored buttons

/// Font handles bundled together. All fonts are owned and freed by the caller.
class MiniPanelFonts {
  const MiniPanelFonts({
    required this.body,
    required this.bodyBold,
    required this.caption,
    required this.timerLarge,
    required this.label,
    required this.icon,
  });

  final int body;       // Segoe UI 11pt
  final int bodyBold;   // Segoe UI Bold 11pt
  final int caption;    // Segoe UI 9pt
  final int timerLarge; // Segoe UI 24pt
  final int label;      // Segoe UI Bold 9pt (section labels)
  final int icon;       // Segoe MDL2 Assets 13pt (header action buttons)

  static MiniPanelFonts create() {
    return MiniPanelFonts(
      body: _createFont('Segoe UI', -15, _fwNormal),
      bodyBold: _createFont('Segoe UI', -15, _fwBold),
      caption: _createFont('Segoe UI', -12, _fwNormal),
      timerLarge: _createFont('Segoe UI', -32, _fwLight),
      label: _createFont('Segoe UI', -11, _fwBold),
      icon: _createFont('Segoe MDL2 Assets', -13, _fwNormal),
    );
  }

  void destroy() {
    win32.DeleteObject(body);
    win32.DeleteObject(bodyBold);
    win32.DeleteObject(caption);
    win32.DeleteObject(timerLarge);
    win32.DeleteObject(label);
    win32.DeleteObject(icon);
  }

  static int _createFont(String face, int height, int weight) {
    final lf = calloc<win32.LOGFONT>();
    try {
      lf.ref.lfHeight = height;
      lf.ref.lfWeight = weight;
      lf.ref.lfCharSet = win32.DEFAULT_CHARSET;
      lf.ref.lfQuality = win32.CLEARTYPE_QUALITY;
      lf.ref.lfFaceName = face;
      return win32.CreateFontIndirect(lf);
    } finally {
      calloc.free(lf);
    }
  }
}

/// Stateless GDI double-buffered painter for [NativeMiniPanel].
///
/// All methods are static - the class is a pure namespace for painting logic.
abstract final class MiniPanelPainter {
  static void paint(
    int hwnd,
    MiniPanelDisplayState state,
    MiniPanelLayout layout,
    MiniPanelFonts fonts,
    HitRect? hoveredHit,
  ) {
    final w = layout.clientW;
    final h = layout.clientH;

    final screenDC = win32.GetDC(hwnd);
    if (screenDC == 0) return;

    final memDC = win32.CreateCompatibleDC(screenDC);
    final bitmap = win32.CreateCompatibleBitmap(screenDC, w, h);
    final oldBitmap = win32.SelectObject(memDC, bitmap);

    try {
      _fillRect(memDC, 0, 0, w, h, _cBg);
      _paintHeader(memDC, layout, fonts, hoveredHit);
      if (state.isRunning) {
        _paintSession(memDC, layout, state, fonts, hoveredHit);
      }
      if (state.entries.isNotEmpty) {
        _paintListLabel(memDC, layout, fonts);
        _paintListItems(memDC, layout, state, fonts, hoveredHit);
      }
      if (state.entries.length > MiniPanelMetrics.maxVisibleItems) {
        _paintScrollArrows(memDC, layout, hoveredHit);
      }
      _paintFooter(memDC, layout, state, fonts);

      win32.BitBlt(screenDC, 0, 0, w, h, memDC, 0, 0, win32.SRCCOPY);
    } finally {
      win32.SelectObject(memDC, oldBitmap);
      win32.DeleteObject(bitmap);
      win32.DeleteDC(memDC);
      win32.ReleaseDC(hwnd, screenDC);
    }
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  static void _paintHeader(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    final w = layout.clientW;
    const h = MiniPanelMetrics.headerH;

    _fillRect(hdc, 0, 0, w, h, _cHeaderBg);
    _drawHLine(hdc, 0, h - 1, w, _cBorder);

    // "Worklog Studio" label - leave room for two right-side buttons
    win32.SelectObject(hdc, fonts.bodyBold);
    _drawText(hdc, 'Worklog Studio', MiniPanelMetrics.padH, 0, w - 80, h,
        _cTextPrimary, _dtLeft | _dtVCenter | _dtSingleLine | _dtNoPrefix);

    // Close button (far right): MDL2 U+E711 Cancel
    _paintHeaderBtn(hdc, layout, fonts, hovered, MiniPanelHit.closeBtn,
        '');

    // Open main-app button (left of close): MDL2 U+E8A5 OpenWith
    _paintHeaderBtn(hdc, layout, fonts, hovered, MiniPanelHit.openMainBtn,
        '');
  }

  static void _paintHeaderBtn(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelFonts fonts,
    HitRect? hovered,
    MiniPanelHit hit,
    String glyph,
  ) {
    final btn = layout.hitRects.firstWhere(
      (r) => r.hit == hit,
      orElse: () => HitRect(hit: hit, x1: 0, y1: 0, x2: 0, y2: 0),
    );
    final isHovered = hovered?.hit == hit;
    _fillRoundRect(hdc, btn.x1, btn.y1, btn.x2, btn.y2, 4,
        isHovered ? _cItemBgHover : _cHeaderBg, _cBorder);
    win32.SelectObject(hdc, fonts.icon);
    _drawText(hdc, glyph, btn.x1, btn.y1, btn.x2, btn.y2, _cTextSecondary,
        _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static void _paintSession(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    final w = layout.clientW;
    final top = layout.sessionTop;
    const sh = MiniPanelMetrics.sessionH;
    const pad = MiniPanelMetrics.padH;
    const padV = MiniPanelMetrics.padV;

    _fillRect(hdc, 0, top, w, top + sh, _cSessionBg);
    _drawHLine(hdc, 0, top + sh - 1, w, _cBorder);

    // Row 1: title + stop button
    final isStopHovered = hovered?.hit == MiniPanelHit.stopBtn;
    final stopHit = layout.hitRects.firstWhere(
      (r) => r.hit == MiniPanelHit.stopBtn,
      orElse: () => HitRect(
          hit: MiniPanelHit.stopBtn, x1: 0, y1: 0, x2: 0, y2: 0),
    );
    _fillRoundRect(hdc, stopHit.x1, stopHit.y1, stopHit.x2, stopHit.y2,
        MiniPanelMetrics.btnRadius,
        isStopHovered ? _cRedHover : _cRedColorRef, _cRedColorRef);
    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, 'Stop', stopHit.x1, stopHit.y1, stopHit.x2, stopHit.y2,
        _cBtnTextLight, _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);

    final titleR = stopHit.x1 - pad;
    win32.SelectObject(hdc, fonts.bodyBold);
    _drawText(hdc, state.activeTitle ?? '', pad, top + padV, titleR,
        top + padV + 20, _cTextPrimary,
        _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);

    // Row 2: started-at line
    if (state.timerStartAt != null) {
      win32.SelectObject(hdc, fonts.caption);
      _drawText(
          hdc, _fmtStartTime(state.timerStartAt!),
          pad, top + padV + 22, w - pad, top + padV + 40,
          _cTextMuted,
          _dtLeft | _dtSingleLine | _dtNoPrefix);
    }

    // Row 3: large elapsed timer (centered)
    if (state.timerStartAt != null) {
      final elapsed = _fmtElapsed(state.timerStartAt!);
      win32.SelectObject(hdc, fonts.timerLarge);
      _drawText(hdc, elapsed, pad, top + padV + 44, w - pad, top + padV + 90,
          _cTimerText,
          _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
    }

    // Row 4: "Switch Activity" link
    final switchHit = layout.hitRects.firstWhere(
      (r) => r.hit == MiniPanelHit.switchActivity,
      orElse: () => HitRect(
          hit: MiniPanelHit.switchActivity, x1: 0, y1: 0, x2: 0, y2: 0),
    );
    final isSwitchHovered = hovered?.hit == MiniPanelHit.switchActivity;
    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, 'Switch Activity', pad,
        switchHit.y1, w - pad, switchHit.y2,
        isSwitchHovered ? _cAccent : _cTextSecondary,
        _dtLeft | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static void _paintListLabel(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelFonts fonts,
  ) {
    final w = layout.clientW;
    final top = layout.listLabelTop;
    const h = MiniPanelMetrics.listLabelH;
    const pad = MiniPanelMetrics.padH;

    _fillRect(hdc, 0, top, w, top + h, _cHeaderBg);

    win32.SelectObject(hdc, fonts.label);
    _drawText(hdc, 'RECENT TASKS', pad, top, w - pad, top + h,
        _cTextMuted, _dtLeft | _dtVCenter | _dtSingleLine | _dtNoPrefix);

    _drawHLine(hdc, 0, top + h - 1, w, _cBorder);
  }

  static void _paintListItems(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    final w = layout.clientW;
    const pad = MiniPanelMetrics.padH;
    const badgeD = MiniPanelMetrics.badgeD;
    const itemH = MiniPanelMetrics.itemH;

    // Clip painting to the list area
    final listTop = layout.listAreaTop;
    final listBottom = layout.listAreaBottom;

    for (int i = 0; i < state.entries.length; i++) {
      final entry = state.entries[i];
      final virtualY = i * itemH - layout.scrollOffset;
      final itemY = listTop + virtualY;

      if (itemY + itemH <= listTop) continue;
      if (itemY >= listBottom) break;

      // Item background
      final isRowHovered = hovered?.hit == MiniPanelHit.startBtn &&
          hovered?.entryIndex == i;
      final bg = isRowHovered ? _cItemBgHover : _cItemBg;
      final paintTop = itemY.clamp(listTop, listBottom);
      final paintBottom = (itemY + itemH).clamp(listTop, listBottom);
      _fillRect(hdc, 0, paintTop, w, paintBottom, bg);
      _drawHLine(hdc, pad, itemY + itemH - 1, w - pad, _cBorder);

      // Badge circle
      const badgeX = pad;
      final badgeY = itemY + (itemH - badgeD) ~/ 2;
      _fillEllipse(hdc, badgeX, badgeY, badgeX + badgeD, badgeY + badgeD,
          entry.badgeBg);
      win32.SelectObject(hdc, fonts.label);
      _drawText(hdc, entry.badgeText, badgeX, badgeY, badgeX + badgeD,
          badgeY + badgeD, entry.badgeFg,
          _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);

      // Title and subtitle
      final textX = pad + badgeD + 8;
      final btnX = w - pad - MiniPanelMetrics.btnStartW;
      final textMaxX = btnX - 8;

      win32.SelectObject(hdc, fonts.body);
      _drawText(hdc, entry.title, textX, itemY + 8, textMaxX,
          itemY + 8 + 18, _cTextPrimary,
          _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);

      if (entry.subtitle != null) {
        win32.SelectObject(hdc, fonts.caption);
        _drawText(hdc, entry.subtitle!, textX, itemY + 28, textMaxX,
            itemY + 28 + 16, _cTextMuted,
            _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);
      }

      // Start button
      final startHit = layout.hitRects.firstWhere(
        (r) => r.hit == MiniPanelHit.startBtn && r.entryIndex == i,
        orElse: () => HitRect(
            hit: MiniPanelHit.startBtn, x1: 0, y1: 0, x2: 0, y2: 0),
      );
      if (startHit.x1 != 0) {
        // Clamp button to visible area
        final btnTop = startHit.y1.clamp(listTop, listBottom);
        final btnBottom = startHit.y2.clamp(listTop, listBottom);
        if (btnBottom > btnTop) {
          _fillRoundRect(hdc, startHit.x1, btnTop, startHit.x2, btnBottom,
              MiniPanelMetrics.btnRadius,
              isRowHovered ? _cGreenHover : _cGreenColorRef, _cGreenColorRef);
          win32.SelectObject(hdc, fonts.caption);
          _drawText(hdc, 'Start', startHit.x1, startHit.y1, startHit.x2,
              startHit.y2, _cBtnTextLight,
              _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
        }
      }
    }
  }

  static void _paintScrollArrows(
    int hdc,
    MiniPanelLayout layout,
    HitRect? hovered,
  ) {
    final top = layout.scrollBarTop;
    const h = MiniPanelMetrics.scrollBarH;
    _fillRect(hdc, 0, top, layout.clientW, top + h, _cHeaderBg);
    _drawHLine(hdc, 0, top + h - 1, layout.clientW, _cBorder);

    final upHit = layout.hitRects.firstWhere(
      (r) => r.hit == MiniPanelHit.scrollUp,
      orElse: () =>
          HitRect(hit: MiniPanelHit.scrollUp, x1: 0, y1: 0, x2: 0, y2: 0),
    );
    final downHit = layout.hitRects.firstWhere(
      (r) => r.hit == MiniPanelHit.scrollDown,
      orElse: () =>
          HitRect(hit: MiniPanelHit.scrollDown, x1: 0, y1: 0, x2: 0, y2: 0),
    );

    final isUpHovered = hovered?.hit == MiniPanelHit.scrollUp;
    final isDownHovered = hovered?.hit == MiniPanelHit.scrollDown;

    // Up arrow button
    _fillRoundRect(hdc, upHit.x1, upHit.y1, upHit.x2, upHit.y2, 4,
        isUpHovered ? _cItemBgHover : _cHeaderBg, _cBorder);
    _drawArrow(hdc, upHit.x1, upHit.y1, upHit.x2, upHit.y2, true,
        isUpHovered ? _cTextPrimary : _cTextSecondary);

    // Down arrow button
    _fillRoundRect(hdc, downHit.x1, downHit.y1, downHit.x2, downHit.y2, 4,
        isDownHovered ? _cItemBgHover : _cHeaderBg, _cBorder);
    _drawArrow(hdc, downHit.x1, downHit.y1, downHit.x2, downHit.y2, false,
        isDownHovered ? _cTextPrimary : _cTextSecondary);
  }

  static void _paintFooter(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
  ) {
    final w = layout.clientW;
    final top = layout.footerTop;
    const h = MiniPanelMetrics.footerH;
    const pad = MiniPanelMetrics.padH;

    _drawHLine(hdc, 0, top, w, _cBorder);
    _fillRect(hdc, 0, top + 1, w, top + h, _cFooterBg);

    final todayStr = _fmtDuration(state.todayDuration);
    final weekStr = _fmtDuration(state.weekDuration);
    final statsText = 'Today $todayStr  |  Week $weekStr';

    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, statsText, pad, top, w - pad, top + h,
        _cTextSecondary, _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  // ---------------------------------------------------------------------------
  // GDI primitives
  // ---------------------------------------------------------------------------

  static void _fillRect(int hdc, int x1, int y1, int x2, int y2, int color) {
    final rect = calloc<win32.RECT>();
    try {
      rect.ref.left = x1;
      rect.ref.top = y1;
      rect.ref.right = x2;
      rect.ref.bottom = y2;
      final brush = win32.CreateSolidBrush(color);
      win32.FillRect(hdc, rect, brush);
      win32.DeleteObject(brush);
    } finally {
      calloc.free(rect);
    }
  }

  static void _fillRoundRect(
    int hdc,
    int x1,
    int y1,
    int x2,
    int y2,
    int radius,
    int fillColor,
    int borderColor,
  ) {
    final brush = win32.CreateSolidBrush(fillColor);
    final pen = win32.CreatePen(_psSolid, 1, borderColor);
    win32.SelectObject(hdc, brush);
    win32.SelectObject(hdc, pen);
    win32.RoundRect(hdc, x1, y1, x2, y2, radius * 2, radius * 2);
    win32.DeleteObject(brush);
    win32.DeleteObject(pen);
  }

  static void _fillEllipse(
      int hdc, int x1, int y1, int x2, int y2, int fillColor) {
    final brush = win32.CreateSolidBrush(fillColor);
    final pen = win32.CreatePen(_psNull, 0, fillColor);
    win32.SelectObject(hdc, brush);
    win32.SelectObject(hdc, pen);
    win32.Ellipse(hdc, x1, y1, x2, y2);
    win32.DeleteObject(brush);
    win32.DeleteObject(pen);
  }

  static void _drawHLine(int hdc, int x1, int y, int x2, int color) {
    _fillRect(hdc, x1, y, x2, y + 1, color);
  }

  static void _drawText(
    int hdc,
    String text,
    int x1,
    int y1,
    int x2,
    int y2,
    int textColor,
    int format,
  ) {
    final rect = calloc<win32.RECT>();
    final pText = text.toNativeUtf16();
    try {
      rect.ref.left = x1;
      rect.ref.top = y1;
      rect.ref.right = x2;
      rect.ref.bottom = y2;
      win32.SetBkMode(hdc, win32.TRANSPARENT);
      win32.SetTextColor(hdc, textColor);
      win32.DrawText(hdc, pText, -1, rect, format);
    } finally {
      calloc.free(rect);
      calloc.free(pText);
    }
  }

  /// Draws a simple up or down arrow using line primitives (Polyline).
  static void _drawArrow(
      int hdc, int x1, int y1, int x2, int y2, bool up, int color) {
    final cx = (x1 + x2) ~/ 2;
    final cy = (y1 + y2) ~/ 2;
    const aw = 5; // half-width of arrowhead
    const ah = 4; // height

    final pen = win32.CreatePen(_psSolid, 2, color);
    final oldPen = win32.SelectObject(hdc, pen);

    final pts = calloc<win32.POINT>(3);
    try {
      if (up) {
        pts[0].x = cx - aw; pts[0].y = cy + ah ~/ 2;
        pts[1].x = cx;      pts[1].y = cy - ah ~/ 2;
        pts[2].x = cx + aw; pts[2].y = cy + ah ~/ 2;
      } else {
        pts[0].x = cx - aw; pts[0].y = cy - ah ~/ 2;
        pts[1].x = cx;      pts[1].y = cy + ah ~/ 2;
        pts[2].x = cx + aw; pts[2].y = cy - ah ~/ 2;
      }
      win32.Polyline(hdc, pts, 3);
    } finally {
      calloc.free(pts);
    }

    win32.SelectObject(hdc, oldPen);
    win32.DeleteObject(pen);
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  static String _fmtElapsed(DateTime startAt) {
    final d = DateTime.now().difference(startAt);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _fmtStartTime(DateTime startAt) {
    final t = startAt.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return 'Started at $h:$m $ampm';
  }
}
