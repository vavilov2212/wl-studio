/// Pixel metrics - all dimensions in logical pixels (no DPI scaling applied;
/// the window itself is marked DPI-aware so Win32 gives us real pixels).
///
/// Values mirror the app's style-system tokens:
/// spacings.md = 12, spacings.lg = 16, radiuses.md = 10, radiuses.sm = 6.
abstract final class MiniPanelMetrics {
  static const int panelW = 320;

  // Outer padding between cards and the panel edge (spacings.md).
  static const int padOuter = 12;

  // Inner card content padding (spacings.lg).
  static const int padCard = 16;

  // Corner radii (radiuses.md / radiuses.sm).
  static const int radiusCard = 10;
  static const int radiusControl = 6;

  // Section heights
  static const int headerH = 36; // slim strip with the open-main button
  static const int sessionCardH = 200; // shown only when running
  static const int listLabelH = 34; // label row inside the recent card
  static const int itemH = 52;
  static const int scrollBarH = 24;
  static const int listCardPadBottom = 8;
  static const int footerH = 32;
  static const int sectionGap = 12;

  // Session card internal Y offsets (from card top). Caption rows are 18px
  // tall - Segoe UI at 12px needs ~17px of cell height, less clips Cyrillic
  // descenders.
  static const int sessionLabelY = 16;
  static const int sessionTitleY = 36; // task line
  static const int sessionTitleH = 26;
  static const int sessionSubtitleY = 68; // project line
  static const int sessionSubtitleH = 18;
  static const int sessionCommentY = 92; // comment line
  static const int sessionCommentH = 18;
  static const int sessionTimerY = 118;
  static const int sessionTimerH = 40;
  static const int sessionSwitchY = 166;
  static const int sessionSwitchH = 18;

  // Badge circle
  static const int badgeD = 32; // diameter

  // Icon buttons
  static const int stopBtnD = 40; // session card stop button (square)
  static const int playBtnD = 28; // per-item play button (square)
  static const int headerBtnD = 28; // header open-main button (square)

  // Max recent entries visible without scrolling
  static const int maxVisibleItems = 4;

  // Max total entries stored in state
  static const int maxEntries = 10;

  static int listCardH({required int entryCount}) {
    if (entryCount <= 0) return 0;
    final visibleItems = entryCount.clamp(0, maxVisibleItems);
    final scrollBlock = entryCount > maxVisibleItems ? scrollBarH : 0;
    return listLabelH + visibleItems * itemH + scrollBlock + listCardPadBottom;
  }

  static int panelH({required bool isRunning, required int entryCount}) {
    final sessionBlock = isRunning ? sessionCardH + sectionGap : 0;
    final listCard = listCardH(entryCount: entryCount);
    final listBlock = listCard > 0 ? listCard + sectionGap : 0;
    return headerH + sessionBlock + listBlock + footerH;
  }
}

/// Named interactive regions. The painter fills [MiniPanelLayout.hitRects]
/// with one of these per interactive element.
enum MiniPanelHit {
  openMainBtn, // header: open main app window
  stopBtn, // session card: stop timer
  switchActivity, // session card: switch activity link
  scrollUp, // scroll arrow up
  scrollDown, // scroll arrow down
  startBtn, // per-item rows; use hitRects[i].entryIndex
  sessionTitle, // session card: task title (hover-only, for tooltip)
  sessionSubtitle, // session card: project name (hover-only, for tooltip)
  sessionComment, // session card: comment (hover-only, for tooltip)
}

/// Hits that trigger an action on click (and get the hand cursor).
/// [MiniPanelHit.sessionTitle]/[MiniPanelHit.sessionSubtitle] are hover-only
/// tooltip zones.
const clickableMiniPanelHits = {
  MiniPanelHit.openMainBtn,
  MiniPanelHit.stopBtn,
  MiniPanelHit.switchActivity,
  MiniPanelHit.scrollUp,
  MiniPanelHit.scrollDown,
  MiniPanelHit.startBtn,
};

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
  late final int listCardTop;
  late final int listCardBottom;
  late final int listAreaTop;
  late final int listAreaBottom;
  late final int scrollBarTop;
  late final int footerTop;

  // Card horizontal bounds shared by painter and hit rects.
  int get cardX1 => MiniPanelMetrics.padOuter;
  int get cardX2 => clientW - MiniPanelMetrics.padOuter;
  int get contentX1 => cardX1 + MiniPanelMetrics.padCard;
  int get contentX2 => cardX2 - MiniPanelMetrics.padCard;

  void _compute() {
    // Header strip: open-main button on the right, vertically centered.
    const headerBtnY =
        (MiniPanelMetrics.headerH - MiniPanelMetrics.headerBtnD) ~/ 2;
    final openMainBtnX =
        clientW - MiniPanelMetrics.padOuter - MiniPanelMetrics.headerBtnD;
    hitRects.add(HitRect(
      hit: MiniPanelHit.openMainBtn,
      x1: openMainBtnX,
      y1: headerBtnY,
      x2: openMainBtnX + MiniPanelMetrics.headerBtnD,
      y2: headerBtnY + MiniPanelMetrics.headerBtnD,
    ));

    int y = MiniPanelMetrics.headerH;

    // Session card
    sessionTop = y;
    if (isRunning) {
      // Hover-only zones for truncation tooltips on task/project/comment.
      hitRects.add(HitRect(
        hit: MiniPanelHit.sessionTitle,
        x1: contentX1,
        y1: y + MiniPanelMetrics.sessionTitleY,
        x2: contentX2,
        y2: y + MiniPanelMetrics.sessionTitleY + MiniPanelMetrics.sessionTitleH,
      ));
      hitRects.add(HitRect(
        hit: MiniPanelHit.sessionSubtitle,
        x1: contentX1,
        y1: y + MiniPanelMetrics.sessionSubtitleY,
        x2: contentX2,
        y2: y +
            MiniPanelMetrics.sessionSubtitleY +
            MiniPanelMetrics.sessionSubtitleH,
      ));
      hitRects.add(HitRect(
        hit: MiniPanelHit.sessionComment,
        x1: contentX1,
        y1: y + MiniPanelMetrics.sessionCommentY,
        x2: contentX2,
        y2: y +
            MiniPanelMetrics.sessionCommentY +
            MiniPanelMetrics.sessionCommentH,
      ));
      hitRects.add(HitRect(
        hit: MiniPanelHit.stopBtn,
        x1: contentX2 - MiniPanelMetrics.stopBtnD,
        y1: y + MiniPanelMetrics.sessionTimerY,
        x2: contentX2,
        y2: y + MiniPanelMetrics.sessionTimerY + MiniPanelMetrics.stopBtnD,
      ));
      hitRects.add(HitRect(
        hit: MiniPanelHit.switchActivity,
        x1: contentX1,
        y1: y + MiniPanelMetrics.sessionSwitchY,
        x2: contentX2,
        y2: y + MiniPanelMetrics.sessionSwitchY + MiniPanelMetrics.sessionSwitchH,
      ));
      y += MiniPanelMetrics.sessionCardH + MiniPanelMetrics.sectionGap;
    }

    // Recent activity card
    listCardTop = y;
    if (entryCount > 0) {
      listAreaTop = y + MiniPanelMetrics.listLabelH;
      final visibleItems =
          entryCount.clamp(0, MiniPanelMetrics.maxVisibleItems);
      listAreaBottom = listAreaTop + visibleItems * MiniPanelMetrics.itemH;

      // Whole row is clickable - use virtual Y before scroll to detect clicks.
      for (int i = 0; i < entryCount; i++) {
        final itemVirtualY = i * MiniPanelMetrics.itemH - scrollOffset;
        final itemY = listAreaTop + itemVirtualY;
        if (itemY + MiniPanelMetrics.itemH < listAreaTop) continue;
        if (itemY > listAreaBottom) continue;
        hitRects.add(HitRect(
          hit: MiniPanelHit.startBtn,
          x1: cardX1 + 4,
          y1: itemY.clamp(listAreaTop, listAreaBottom),
          x2: cardX2 - 4,
          y2: (itemY + MiniPanelMetrics.itemH).clamp(listAreaTop, listAreaBottom),
          entryIndex: i,
        ));
      }

      y = listAreaBottom;

      // Scroll arrows
      scrollBarTop = y;
      if (entryCount > MiniPanelMetrics.maxVisibleItems) {
        hitRects.add(HitRect(
          hit: MiniPanelHit.scrollUp,
          x1: contentX1,
          y1: y + 2,
          x2: contentX1 + 24,
          y2: y + MiniPanelMetrics.scrollBarH - 2,
        ));
        hitRects.add(HitRect(
          hit: MiniPanelHit.scrollDown,
          x1: contentX1 + 32,
          y1: y + 2,
          x2: contentX1 + 56,
          y2: y + MiniPanelMetrics.scrollBarH - 2,
        ));
        y += MiniPanelMetrics.scrollBarH;
      }

      y += MiniPanelMetrics.listCardPadBottom;
      listCardBottom = y;
      y += MiniPanelMetrics.sectionGap;
    } else {
      listAreaTop = y;
      listAreaBottom = y;
      scrollBarTop = y;
      listCardBottom = y;
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
