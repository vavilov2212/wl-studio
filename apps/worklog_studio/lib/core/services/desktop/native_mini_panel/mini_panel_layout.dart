/// Pixel metrics - all dimensions in logical pixels (no DPI scaling applied;
/// the window itself is marked DPI-aware so Win32 gives us real pixels).
abstract final class MiniPanelMetrics {
  static const int panelW = 300;

  // Section heights
  static const int headerH = 44;
  static const int sessionH = 136; // shown only when running
  static const int listLabelH = 32;
  static const int itemH = 52;
  static const int scrollBarH = 24;
  static const int footerH = 32;

  // Padding
  static const int padH = 16; // horizontal content padding
  static const int padV = 8;

  // Badge circle
  static const int badgeD = 32; // diameter

  // Buttons
  static const int btnH = 28;
  static const int btnStopW = 64;
  static const int btnStartW = 64;
  static const int btnRadius = 6;

  // Max recent entries visible without scrolling
  static const int maxVisibleItems = 4;

  // Max total entries stored in state
  static const int maxEntries = 10;

  static int panelH({required bool isRunning, required int entryCount}) {
    final sessionBlock = isRunning ? sessionH : 0;
    final visibleItems = entryCount.clamp(0, maxVisibleItems);
    final listBlock = entryCount > 0 ? listLabelH + visibleItems * itemH : 0;
    final scrollBlock = entryCount > maxVisibleItems ? scrollBarH : 0;
    return headerH + sessionBlock + listBlock + scrollBlock + footerH;
  }
}

/// Named interactive regions. The painter fills [MiniPanelLayout.hitRects]
/// with one of these per interactive element.
enum MiniPanelHit {
  openMainBtn,     // header: open main app window
  closeBtn,        // header: hide/dismiss the mini panel
  stopBtn,         // session card: stop timer
  switchActivity,  // session card: switch activity link
  scrollUp,        // scroll arrow up
  scrollDown,      // scroll arrow down
  startBtn,        // per-item start buttons; use hitRects[i].tag
}

/// A rectangular hit region with optional data payload.
class HitRect {
  const HitRect({
    required this.hit,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.entryIndex = -1,
  });

  final MiniPanelHit hit;
  final int x1, y1, x2, y2;
  final int entryIndex; // only for [MiniPanelHit.startBtn]

  bool contains(int x, int y) =>
      x >= x1 && x <= x2 && y >= y1 && y <= y2;
}

/// Computed layout for a single frame.
///
/// Constructed by [NativeMiniPanel] before each paint and passed to the
/// painter so that both hit-testing and rendering share the same geometry.
class MiniPanelLayout {
  MiniPanelLayout.compute({
    required this.isRunning,
    required this.entryCount,
    required this.scrollOffset,
  })  : clientW = MiniPanelMetrics.panelW,
        clientH = MiniPanelMetrics.panelH(
          isRunning: isRunning,
          entryCount: entryCount,
        ),
        hitRects = [] {
    _compute();
  }

  final bool isRunning;
  final int entryCount;
  final int scrollOffset; // scroll offset in list pixels
  final int clientW;
  final int clientH;
  final List<HitRect> hitRects;

  // Section Y-offsets derived in _compute()
  late final int sessionTop;
  late final int listLabelTop;
  late final int listAreaTop;
  late final int listAreaBottom;
  late final int scrollBarTop;
  late final int footerTop;

  void _compute() {
    int y = MiniPanelMetrics.headerH;

    // Header: close button (far right) + open-main button (left of close)
    const btnSize = 28;
    const btnGap = 4;
    final closeBtnX = clientW - MiniPanelMetrics.padH - btnSize;
    final openMainBtnX = closeBtnX - btnGap - btnSize;
    hitRects.add(HitRect(
      hit: MiniPanelHit.closeBtn,
      x1: closeBtnX,
      y1: 8,
      x2: closeBtnX + btnSize,
      y2: MiniPanelMetrics.headerH - 8,
    ));
    hitRects.add(HitRect(
      hit: MiniPanelHit.openMainBtn,
      x1: openMainBtnX,
      y1: 8,
      x2: openMainBtnX + btnSize,
      y2: MiniPanelMetrics.headerH - 8,
    ));

    // Session card
    sessionTop = y;
    if (isRunning) {
      // Stop button: right side of the session card header row
      hitRects.add(HitRect(
        hit: MiniPanelHit.stopBtn,
        x1: clientW - MiniPanelMetrics.padH - MiniPanelMetrics.btnStopW,
        y1: y + MiniPanelMetrics.padV,
        x2: clientW - MiniPanelMetrics.padH,
        y2: y + MiniPanelMetrics.padV + MiniPanelMetrics.btnH,
      ));
      // Switch activity link at the bottom of the session card
      hitRects.add(HitRect(
        hit: MiniPanelHit.switchActivity,
        x1: MiniPanelMetrics.padH,
        y1: y + MiniPanelMetrics.sessionH - MiniPanelMetrics.padV - 20,
        x2: clientW - MiniPanelMetrics.padH,
        y2: y + MiniPanelMetrics.sessionH - MiniPanelMetrics.padV,
      ));
      y += MiniPanelMetrics.sessionH;
    }

    // List label
    listLabelTop = y;
    if (entryCount > 0) {
      y += MiniPanelMetrics.listLabelH;

      listAreaTop = y;
      final visibleItems = entryCount.clamp(0, MiniPanelMetrics.maxVisibleItems);
      listAreaBottom = y + visibleItems * MiniPanelMetrics.itemH;

      // Start buttons - use virtual Y before scroll to detect clicks
      for (int i = 0; i < entryCount; i++) {
        final itemVirtualY = i * MiniPanelMetrics.itemH - scrollOffset;
        final itemY = listAreaTop + itemVirtualY;
        if (itemY + MiniPanelMetrics.itemH < listAreaTop) continue;
        if (itemY > listAreaBottom) continue;
        final btnY1 = itemY + (MiniPanelMetrics.itemH - MiniPanelMetrics.btnH) ~/ 2;
        hitRects.add(HitRect(
          hit: MiniPanelHit.startBtn,
          x1: clientW - MiniPanelMetrics.padH - MiniPanelMetrics.btnStartW,
          y1: btnY1,
          x2: clientW - MiniPanelMetrics.padH,
          y2: btnY1 + MiniPanelMetrics.btnH,
          entryIndex: i,
        ));
      }

      y = listAreaBottom;
    } else {
      listAreaTop = y;
      listAreaBottom = y;
    }

    // Scroll arrows
    scrollBarTop = y;
    if (entryCount > MiniPanelMetrics.maxVisibleItems) {
      hitRects.add(HitRect(
        hit: MiniPanelHit.scrollUp,
        x1: MiniPanelMetrics.padH,
        y1: y + 4,
        x2: MiniPanelMetrics.padH + 24,
        y2: y + MiniPanelMetrics.scrollBarH - 4,
      ));
      hitRects.add(HitRect(
        hit: MiniPanelHit.scrollDown,
        x1: MiniPanelMetrics.padH + 32,
        y1: y + 4,
        x2: MiniPanelMetrics.padH + 56,
        y2: y + MiniPanelMetrics.scrollBarH - 4,
      ));
      y += MiniPanelMetrics.scrollBarH;
    }

    footerTop = y;
  }

  /// Max scroll offset so the last entry is fully visible.
  int get maxScrollOffset {
    if (entryCount <= MiniPanelMetrics.maxVisibleItems) return 0;
    return (entryCount - MiniPanelMetrics.maxVisibleItems) *
        MiniPanelMetrics.itemH;
  }

  HitRect? hitTest(int x, int y) {
    for (final r in hitRects.reversed) {
      if (r.contains(x, y)) return r;
    }
    return null;
  }
}
