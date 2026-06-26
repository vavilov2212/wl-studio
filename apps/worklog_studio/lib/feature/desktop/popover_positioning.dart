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
