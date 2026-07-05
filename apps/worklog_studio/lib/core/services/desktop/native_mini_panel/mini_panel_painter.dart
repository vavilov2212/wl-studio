import 'dart:ffi';
import 'dart:io';

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
const _fwNormal = 400;
const _fwSemiBold = 600;
const _fwBold = 700;

// AddFontResourceEx flag: font visible only to this process.
const _frPrivate = 0x10;

// SelectClipRgn is not exported by the win32 package; bind it directly.
final _selectClipRgn = DynamicLibrary.open('gdi32.dll').lookupFunction<
    Int32 Function(IntPtr hdc, IntPtr hrgn),
    int Function(int hdc, int hrgn)>('SelectClipRgn');

// COLORREF palette (0x00BBGGRR) mirroring the style system's
// lightColorsPalette tokens (colors_palette.dart).
const _cCanvas = 0x00F1F4F5; // background.canvas #F5F4F1
const _cSurface = 0x00FFFFFF; // background.surface #FFFFFF
const _cSurfaceMuted = 0x00EAECEE; // background.surfaceMuted #EEECEA
const _cBorder = 0x00DBE0E2; // border.primary #E2E0DB
const _cTextPrimary = 0x00211E1C; // text.primary #1C1E21
const _cTextSecondary = 0x0063554B; // text.secondary #4B5563
const _cTextSecondary2 = 0x0074675E; // text.secondary2 #5E6774
const _cTextMuted = 0x00AFA39C; // text.muted #9CA3AF
const _cAccent = 0x00A55F18; // accent.primary #185FA5
const _cAccentMuted = 0x00FBF1E6; // accent.primaryMuted #E6F1FB
const _cDanger = 0x002626DC; // accent.danger #DC2626
const _cDangerHover = 0x001C1CB9; // darker danger for hover #B91C1C
const _cWhite = 0x00FFFFFF;

/// COLORREF of border.primary, exposed for the DWM window border.
const miniPanelBorderColorRef = _cBorder;

/// COLORREF of background.canvas, exposed for the window class background
/// brush so the first frame doesn't flash white.
const miniPanelCanvasColorRef = _cCanvas;

/// Tokens exposed for the tooltip popup window.
const miniPanelSurfaceColorRef = _cSurface;
const miniPanelTextPrimaryColorRef = _cTextPrimary;

/// Font handles bundled together. All fonts are owned and freed by the caller.
///
/// Headings use the app's bundled Nunito Sans (loaded process-private from
/// the Flutter asset bundle); body text uses Segoe UI as the stand-in for
/// the style system's Inter (which is not bundled).
class MiniPanelFonts {
  const MiniPanelFonts({
    required this.title,
    required this.timer,
    required this.body,
    required this.caption,
    required this.label,
    required this.icon,
  });

  final int title; // Nunito Sans SemiBold 20px (commonTextStyles.title)
  final int timer; // Nunito Sans SemiBold 30px (commonTextStyles.h2-ish)
  final int body; // Segoe UI 15px (body2)
  final int caption; // Segoe UI 12px (caption)
  final int label; // Segoe UI Bold 11px (overline section labels)
  final int icon; // Segoe MDL2 Assets 14px (header action button)

  static bool _appFontsLoaded = false;
  static String _headingFace = 'Segoe UI';

  static MiniPanelFonts create() {
    _ensureAppFonts();
    return MiniPanelFonts(
      title: _createFont(_headingFace, -20, _fwSemiBold),
      timer: _createFont(_headingFace, -30, _fwSemiBold),
      body: _createFont('Segoe UI', -15, _fwNormal),
      caption: _createFont('Segoe UI', -12, _fwNormal),
      label: _createFont('Segoe UI', -11, _fwBold),
      icon: _createFont('Segoe MDL2 Assets', -14, _fwNormal),
    );
  }

  /// Loads the style system's bundled Nunito Sans TTFs into this process so
  /// GDI can use them. Falls back to Segoe UI when the assets are missing.
  static void _ensureAppFonts() {
    if (_appFontsLoaded) return;
    _appFontsLoaded = true;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final fontDir = '$exeDir\\data\\flutter_assets\\packages'
        '\\worklog_studio_style_system\\fonts\\nunito_sans';
    const files = [
      'NunitoSans-Regular.ttf',
      'NunitoSans-SemiBold.ttf',
      'NunitoSans-Bold.ttf',
    ];

    var loaded = 0;
    for (final file in files) {
      final path = '$fontDir\\$file';
      if (!File(path).existsSync()) continue;
      final pPath = path.toNativeUtf16();
      try {
        if (win32.AddFontResourceEx(pPath, _frPrivate, nullptr) > 0) {
          loaded++;
        }
      } finally {
        calloc.free(pPath);
      }
    }
    if (loaded > 0) _headingFace = 'Nunito Sans';
  }

  void destroy() {
    win32.DeleteObject(title);
    win32.DeleteObject(timer);
    win32.DeleteObject(body);
    win32.DeleteObject(caption);
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
      _fillRect(memDC, 0, 0, w, h, _cCanvas);
      _paintHeader(memDC, layout, fonts, hoveredHit);
      if (state.isRunning) {
        _paintSessionCard(memDC, layout, state, fonts, hoveredHit);
      }
      if (state.entries.isNotEmpty) {
        _paintListCard(memDC, layout, state, fonts, hoveredHit);
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

  /// Measures the single-line pixel width of [text] in [font] (a HFONT).
  /// Used to decide whether truncated text needs a tooltip.
  static int measureTextWidth(int font, String text) {
    final hdc = win32.GetDC(win32.NULL);
    if (hdc == 0) return 0;
    final rect = calloc<win32.RECT>();
    final pText = text.toNativeUtf16();
    try {
      final oldFont = win32.SelectObject(hdc, font);
      // DT_CALCRECT (0x400): no drawing, just expand rect.right to fit.
      win32.DrawText(hdc, pText, -1, rect,
          0x400 | _dtSingleLine | _dtNoPrefix);
      win32.SelectObject(hdc, oldFont);
      return rect.ref.right - rect.ref.left;
    } finally {
      calloc.free(rect);
      calloc.free(pText);
      win32.ReleaseDC(win32.NULL, hdc);
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
    // Open main-app button (ghost icon button): MDL2 U+E7F4 TVMonitor (desktop monitor)
    final btn = _findRect(layout, MiniPanelHit.openMainBtn);
    final isHovered = hovered?.hit == MiniPanelHit.openMainBtn;
    if (isHovered) {
      _fillRoundRect(hdc, btn.x1, btn.y1, btn.x2, btn.y2,
          MiniPanelMetrics.radiusControl, _cSurfaceMuted, _cBorder);
    }
    win32.SelectObject(hdc, fonts.icon);
    _drawText(hdc, '', btn.x1, btn.y1, btn.x2, btn.y2, _cTextSecondary,
        _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static void _paintSessionCard(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    final top = layout.sessionTop;
    final bottom = top + MiniPanelMetrics.sessionCardH;
    _fillRoundRect(hdc, layout.cardX1, top, layout.cardX2, bottom,
        MiniPanelMetrics.radiusCard, _cSurface, _cBorder);

    final x1 = layout.contentX1;
    final x2 = layout.contentX2;

    // Overline label
    win32.SelectObject(hdc, fonts.label);
    _drawText(hdc, 'ACTIVE SESSION', x1, top + MiniPanelMetrics.sessionLabelY,
        x2, top + MiniPanelMetrics.sessionLabelY + 14, _cAccent,
        _dtLeft | _dtSingleLine | _dtNoPrefix);

    // Task / project / comment - always three lines with a clear visual
    // hierarchy (dark title, medium-gray project, light muted comment),
    // muted placeholders when a value is missing, ellipsized when too long.
    const ellipsized = _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix;

    win32.SelectObject(hdc, fonts.title);
    _drawText(hdc, state.activeTitle ?? 'No task', x1,
        top + MiniPanelMetrics.sessionTitleY, x2,
        top + MiniPanelMetrics.sessionTitleY + MiniPanelMetrics.sessionTitleH,
        state.activeTitle != null ? _cTextPrimary : _cTextMuted, ellipsized);

    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, state.activeSubtitle ?? 'No project', x1,
        top + MiniPanelMetrics.sessionSubtitleY, x2,
        top +
            MiniPanelMetrics.sessionSubtitleY +
            MiniPanelMetrics.sessionSubtitleH,
        state.activeSubtitle != null ? _cTextSecondary : _cTextMuted,
        ellipsized);

    _drawText(hdc, state.activeComment ?? 'No comment', x1,
        top + MiniPanelMetrics.sessionCommentY, x2,
        top +
            MiniPanelMetrics.sessionCommentY +
            MiniPanelMetrics.sessionCommentH,
        _cTextMuted, ellipsized);

    // Timer row: elapsed time left, stop icon button right
    final stopHit = _findRect(layout, MiniPanelHit.stopBtn);
    if (state.timerStartAt != null) {
      win32.SelectObject(hdc, fonts.timer);
      _drawText(hdc, _fmtElapsed(state.timerStartAt!), x1,
          top + MiniPanelMetrics.sessionTimerY, stopHit.x1 - 8,
          top + MiniPanelMetrics.sessionTimerY + MiniPanelMetrics.sessionTimerH,
          _cTextPrimary,
          _dtLeft | _dtVCenter | _dtSingleLine | _dtNoPrefix);
    }

    // Stop icon button: danger rounded square with a white stop glyph,
    // matching the main window's danger PrimaryButton with Icons.stop.
    final isStopHovered = hovered?.hit == MiniPanelHit.stopBtn;
    _fillRoundRect(hdc, stopHit.x1, stopHit.y1, stopHit.x2, stopHit.y2,
        MiniPanelMetrics.radiusCard,
        isStopHovered ? _cDangerHover : _cDanger,
        isStopHovered ? _cDangerHover : _cDanger);
    final scx = (stopHit.x1 + stopHit.x2) ~/ 2;
    final scy = (stopHit.y1 + stopHit.y2) ~/ 2;
    _fillRoundRect(hdc, scx - 6, scy - 6, scx + 6, scy + 6, 2, _cWhite, _cWhite);

    // "Switch Activity" link
    final switchHit = _findRect(layout, MiniPanelHit.switchActivity);
    final isSwitchHovered = hovered?.hit == MiniPanelHit.switchActivity;
    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, 'Switch Activity', switchHit.x1, switchHit.y1,
        switchHit.x2, switchHit.y2,
        isSwitchHovered ? _cAccent : _cTextSecondary,
        _dtLeft | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static void _paintListCard(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    final top = layout.listCardTop;
    _fillRoundRect(hdc, layout.cardX1, top, layout.cardX2,
        layout.listCardBottom, MiniPanelMetrics.radiusCard, _cSurface,
        _cBorder);

    // Overline label
    win32.SelectObject(hdc, fonts.label);
    _drawText(hdc, 'RECENT ACTIVITY', layout.contentX1, top + 12,
        layout.contentX2, top + 12 + 14, _cTextSecondary2,
        _dtLeft | _dtSingleLine | _dtNoPrefix);

    _paintListItems(hdc, layout, state, fonts, hovered);

    if (state.entries.length > MiniPanelMetrics.maxVisibleItems) {
      _paintScrollArrows(hdc, layout, hovered);
    }
  }

  static void _paintListItems(
    int hdc,
    MiniPanelLayout layout,
    MiniPanelDisplayState state,
    MiniPanelFonts fonts,
    HitRect? hovered,
  ) {
    const badgeD = MiniPanelMetrics.badgeD;
    const itemH = MiniPanelMetrics.itemH;

    final rowX1 = layout.cardX1 + 8;
    final rowX2 = layout.cardX2 - 8;
    final listTop = layout.listAreaTop;
    final listBottom = layout.listAreaBottom;

    // Clip scrolled rows to the list band so partially visible rows never
    // overdraw the card label or the scroll arrows.
    final clipRgn =
        win32.CreateRectRgn(layout.cardX1, listTop, layout.cardX2, listBottom);
    _selectClipRgn(hdc, clipRgn);

    for (int i = 0; i < state.entries.length; i++) {
      final entry = state.entries[i];
      final virtualY = i * itemH - layout.scrollOffset;
      final itemY = listTop + virtualY;

      if (itemY + itemH <= listTop) continue;
      if (itemY >= listBottom) break;

      final isRowHovered = hovered?.hit == MiniPanelHit.startBtn &&
          hovered?.entryIndex == i;

      // Hover highlight (accent.primaryMuted, radiuses.sm)
      if (isRowHovered) {
        _fillRoundRect(hdc, rowX1, itemY + 2, rowX2, itemY + itemH - 2,
            MiniPanelMetrics.radiusControl, _cAccentMuted, _cAccentMuted);
      }

      // Badge circle
      final badgeX = layout.contentX1;
      final badgeY = itemY + (itemH - badgeD) ~/ 2;
      _fillEllipse(hdc, badgeX, badgeY, badgeX + badgeD, badgeY + badgeD,
          entry.badgeBg);
      win32.SelectObject(hdc, fonts.label);
      _drawText(hdc, entry.badgeText, badgeX, badgeY, badgeX + badgeD,
          badgeY + badgeD, entry.badgeFg,
          _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);

      // Title and subtitle
      final textX = badgeX + badgeD + 12;
      final btnX1 = layout.contentX2 - MiniPanelMetrics.playBtnD;
      final textMaxX = btnX1 - 8;

      win32.SelectObject(hdc, fonts.body);
      _drawText(hdc, entry.title, textX, itemY + 8, textMaxX, itemY + 26,
          _cTextPrimary,
          _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);

      if (entry.subtitle != null) {
        win32.SelectObject(hdc, fonts.caption);
        // 18px row - anything less clips Cyrillic descenders.
        _drawText(hdc, entry.subtitle!, textX, itemY + 28, textMaxX,
            itemY + 46, _cTextMuted,
            _dtLeft | _dtSingleLine | _dtEndEllipsis | _dtNoPrefix);
      }

      // Play icon button: ghost while idle, accent-filled when the row is
      // hovered - mirrors the main window's ghost/primary PrimaryButton.
      final btnY1 = itemY + (itemH - MiniPanelMetrics.playBtnD) ~/ 2;
      final btnY2 = btnY1 + MiniPanelMetrics.playBtnD;
      if (isRowHovered) {
        _fillRoundRect(hdc, btnX1, btnY1, layout.contentX2, btnY2,
            MiniPanelMetrics.radiusControl, _cAccent, _cAccent);
      }
      _drawPlayTriangle(hdc, btnX1, btnY1, layout.contentX2, btnY2,
          isRowHovered ? _cWhite : _cTextSecondary);
    }

    _selectClipRgn(hdc, win32.NULL);
    win32.DeleteObject(clipRgn);
  }

  static void _paintScrollArrows(
    int hdc,
    MiniPanelLayout layout,
    HitRect? hovered,
  ) {
    final upHit = _findRect(layout, MiniPanelHit.scrollUp);
    final downHit = _findRect(layout, MiniPanelHit.scrollDown);

    final isUpHovered = hovered?.hit == MiniPanelHit.scrollUp;
    final isDownHovered = hovered?.hit == MiniPanelHit.scrollDown;

    _fillRoundRect(hdc, upHit.x1, upHit.y1, upHit.x2, upHit.y2,
        MiniPanelMetrics.radiusControl,
        isUpHovered ? _cSurfaceMuted : _cSurface, _cBorder);
    _drawArrow(hdc, upHit.x1, upHit.y1, upHit.x2, upHit.y2, true,
        isUpHovered ? _cTextPrimary : _cTextSecondary);

    _fillRoundRect(hdc, downHit.x1, downHit.y1, downHit.x2, downHit.y2,
        MiniPanelMetrics.radiusControl,
        isDownHovered ? _cSurfaceMuted : _cSurface, _cBorder);
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

    _fillRect(hdc, 0, top, w, top + h, _cAccentMuted);
    _drawHLine(hdc, 0, top, w, _cBorder);

    final todayStr = _fmtDuration(state.todayDuration);
    final weekStr = _fmtDuration(state.weekDuration);
    final statsText = 'Today $todayStr   |   Week $weekStr';

    win32.SelectObject(hdc, fonts.caption);
    _drawText(hdc, statsText, 0, top, w, top + h, _cTextMuted,
        _dtCenter | _dtVCenter | _dtSingleLine | _dtNoPrefix);
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  static HitRect _findRect(MiniPanelLayout layout, MiniPanelHit hit) {
    return layout.hitRects.firstWhere(
      (r) => r.hit == hit,
      orElse: () => HitRect(hit: hit, x1: 0, y1: 0, x2: 0, y2: 0),
    );
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

  /// Draws a filled play triangle centered in the given rect.
  static void _drawPlayTriangle(
      int hdc, int x1, int y1, int x2, int y2, int color) {
    final cx = (x1 + x2) ~/ 2;
    final cy = (y1 + y2) ~/ 2;

    final brush = win32.CreateSolidBrush(color);
    final pen = win32.CreatePen(_psNull, 0, color);
    win32.SelectObject(hdc, brush);
    win32.SelectObject(hdc, pen);

    final pts = calloc<win32.POINT>(3);
    try {
      pts[0].x = cx - 4;
      pts[0].y = cy - 6;
      pts[1].x = cx - 4;
      pts[1].y = cy + 6;
      pts[2].x = cx + 6;
      pts[2].y = cy;
      win32.Polygon(hdc, pts, 3);
    } finally {
      calloc.free(pts);
    }

    win32.DeleteObject(brush);
    win32.DeleteObject(pen);
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
}
