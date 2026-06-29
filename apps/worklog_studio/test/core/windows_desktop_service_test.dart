// ignore_for_file: depend_on_referenced_packages
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';

void main() {
  group('WindowsDesktopService.fixedTrayAnchorForTesting', () {
    final service = WindowsDesktopService();
    const screenSize = Size(1920, 1080);

    test('anchors near the bottom-right corner of the screen', () {
      // Used unconditionally by showPopoverNearScreenCorner() (the
      // reminder's path), which has no live tray-icon context worth
      // trusting any more than usual.
      final anchor = service.fixedTrayAnchorForTesting(screenSize);

      expect(anchor.right, screenSize.width);
      expect(anchor.bottom, screenSize.height);
    });
  });

  group('WindowsDesktopService.sanitizeTrayBoundsForTesting', () {
    final service = WindowsDesktopService();
    const screenSize = Size(1920, 1080);

    test('returns the real bounds when they look sane', () {
      // Used by showPopover() (the tray-click/hotkey path), where a live
      // tray-icon position is worth asking for.
      const realBounds = Rect.fromLTWH(1850, 1040, 32, 32);

      final sanitized = service.sanitizeTrayBoundsForTesting(realBounds, screenSize);

      expect(sanitized, realBounds);
    });

    test('falls back to the fixed corner when bounds are null', () {
      final sanitized = service.sanitizeTrayBoundsForTesting(null, screenSize);

      expect(sanitized.right, screenSize.width);
      expect(sanitized.bottom, screenSize.height);
    });

    test('falls back to the fixed corner when bounds are degenerate', () {
      // Shell_NotifyIconGetRect on Windows can't resolve an icon hidden in
      // the notification area's overflow drawer and returns a near-zero
      // rect instead of failing outright - this must not be trusted as-is.
      const degenerateBounds = Rect.fromLTWH(0, 0, 0, 0);

      final sanitized = service.sanitizeTrayBoundsForTesting(degenerateBounds, screenSize);

      expect(sanitized.right, screenSize.width);
      expect(sanitized.bottom, screenSize.height);
    });
  });

  group('WindowsDesktopService.resolveStartupRole', () {
    test('returns tray and stores the window id for multi_window args', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole(['multi_window', '7', '{}']);

      expect(role, 'tray');
      expect(service.ownWindowIdForTesting, 7);
    });

    test('returns main for ordinary startup args', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([]);

      expect(role, 'main');
    });

    test('returns tray:activity when the payload role is activity', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([
        'multi_window',
        '9',
        '{"role":"activity"}',
      ]);

      expect(role, 'tray:activity');
    });

    test('returns plain tray when the payload role is miniPanel', () async {
      final service = WindowsDesktopService();

      final role = await service.resolveStartupRole([
        'multi_window',
        '9',
        '{"role":"miniPanel"}',
      ]);

      expect(role, 'tray');
    });
  });
}
