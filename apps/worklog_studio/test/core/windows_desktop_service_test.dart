// ignore_for_file: depend_on_referenced_packages
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';

void main() {
  group('WindowsDesktopService.fixedTrayAnchorForTesting', () {
    final service = WindowsDesktopService();
    const screenSize = Size(1920, 1080);

    test('anchors near the bottom-right corner of the screen', () {
      final anchor = service.fixedTrayAnchorForTesting(screenSize);

      expect(anchor.right, screenSize.width);
      expect(anchor.bottom, screenSize.height);
    });
  });

  group('WindowsDesktopService.sanitizeTrayBoundsForTesting', () {
    final service = WindowsDesktopService();
    const screenSize = Size(1920, 1080);

    test('returns the real bounds when they look sane', () {
      const realBounds = Rect.fromLTWH(1850, 1040, 32, 32);

      final sanitized =
          service.sanitizeTrayBoundsForTesting(realBounds, screenSize);

      expect(sanitized, realBounds);
    });

    test('falls back to the fixed corner when bounds are null', () {
      final sanitized =
          service.sanitizeTrayBoundsForTesting(null, screenSize);

      expect(sanitized.right, screenSize.width);
      expect(sanitized.bottom, screenSize.height);
    });

    test('falls back to the fixed corner when bounds are degenerate', () {
      const degenerateBounds = Rect.fromLTWH(0, 0, 0, 0);

      final sanitized = service.sanitizeTrayBoundsForTesting(
          degenerateBounds, screenSize);

      expect(sanitized.right, screenSize.width);
      expect(sanitized.bottom, screenSize.height);
    });
  });

  group('WindowsDesktopService.resolveStartupRole', () {
    test('always returns main - no secondary Flutter engine on Windows',
        () async {
      final service = WindowsDesktopService();

      expect(await service.resolveStartupRole([]), 'main');
      expect(await service.resolveStartupRole(['multi_window', '7', '{}']),
          'main');
      expect(await service.resolveStartupRole(['--some-flag']), 'main');
    });
  });
}
