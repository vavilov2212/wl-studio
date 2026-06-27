import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';

void main() {
  group('computePopoverFrame', () {
    test('anchors the popover above and right-aligned to the tray icon', () {
      const trayBounds = Rect.fromLTWH(1850, 1040, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
      );

      // Right edge aligns with the tray icon's horizontal center.
      expect(frame.right, trayBounds.center.dx);
      // Width/height match the requested popover size exactly.
      expect(frame.width, popoverSize.width);
      expect(frame.height, popoverSize.height);
      // Bottom edge sits a small gap above the tray icon's top edge.
      expect(frame.bottom, trayBounds.top - 8);
    });

    test('honors a custom gap', () {
      const trayBounds = Rect.fromLTWH(100, 900, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
        gap: 20,
      );

      expect(frame.bottom, trayBounds.top - 20);
    });
  });
}
