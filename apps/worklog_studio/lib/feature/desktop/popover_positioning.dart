import 'dart:ui';

/// Computes the on-screen frame for the Windows tray popover window.
///
/// The popover is right-aligned to the tray icon's horizontal center and
/// sits [gap] logical pixels above the icon's top edge, mirroring the
/// conventional Windows tray-flyout anchor point.
Rect computePopoverFrame({
  required Rect trayBounds,
  required Size popoverSize,
  double gap = 8,
}) {
  final right = trayBounds.center.dx;
  final left = right - popoverSize.width;
  final bottom = trayBounds.top - gap;
  final top = bottom - popoverSize.height;
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Clamps [frame] so it sits fully within a screen of [screenSize],
/// preserving its width/height.
///
/// This is a defensive guarantee independent of [computePopoverFrame]'s
/// own anchoring math: the upstream tray-bounds query this is built on
/// (`Shell_NotifyIconGetRect` via `trayManager.getBounds()`) can report a
/// plausible-looking (non-zero width/height) but wrong position - e.g. an
/// icon hidden in the notification area's overflow drawer can resolve to
/// a position far from the real tray. Regardless of why the upstream
/// bounds were wrong, the popover should never render mostly off-screen.
Rect clampFrameToScreen(Rect frame, Size screenSize) {
  final maxLeft = (screenSize.width - frame.width).clamp(0.0, double.infinity);
  final maxTop = (screenSize.height - frame.height).clamp(0.0, double.infinity);
  final left = frame.left.clamp(0.0, maxLeft);
  final top = frame.top.clamp(0.0, maxTop);
  return Rect.fromLTWH(left, top, frame.width, frame.height);
}

/// Computes the on-screen frame for the dedicated activity prompt window:
/// horizontally centered, a fixed distance from the top of the screen.
///
/// Unlike [computePopoverFrame], this takes no tray bounds at all - the
/// activity prompt is fired unattended (by the reminder) as often as it is
/// fired directly (hotkey, a button in the mini panel), so there is no
/// "the user just clicked something at this exact spot" context worth
/// anchoring to. A fixed, screen-size-derived position is simpler and
/// avoids the unreliable-native-query problems `computePopoverFrame`'s
/// tray-relative anchoring has had to work around.
Rect computeActivityPromptFrame({
  required Size screenSize,
  required Size promptSize,
  double topMargin = 96,
}) {
  final left = (screenSize.width - promptSize.width) / 2;
  return Rect.fromLTWH(left, topMargin, promptSize.width, promptSize.height);
}
