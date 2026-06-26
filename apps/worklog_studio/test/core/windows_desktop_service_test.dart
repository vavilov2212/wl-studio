// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';

void main() {
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
  });
}
