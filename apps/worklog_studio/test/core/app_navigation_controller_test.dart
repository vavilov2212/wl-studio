import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';

void main() {
  group('AppNavigationController', () {
    test('openTask is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openTask('t1'), returnsNormally);
    });

    test('openProject is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openProject('p1'), returnsNormally);
    });

    test('openHistoryEntry is a no-op before handlers are registered', () {
      final controller = AppNavigationController();
      expect(() => controller.openHistoryEntry('e1'), returnsNormally);
    });

    test('openTask calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (id) => receivedId = id,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );

      controller.openTask('t1');

      expect(receivedId, 't1');
    });

    test('openProject calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (_) {},
        openProject: (id) => receivedId = id,
        openHistoryEntry: (_) {},
      );

      controller.openProject('p1');

      expect(receivedId, 'p1');
    });

    test('openHistoryEntry calls the registered handler with the given id', () {
      final controller = AppNavigationController();
      String? receivedId;
      controller.registerHandlers(
        openTask: (_) {},
        openProject: (_) {},
        openHistoryEntry: (id) => receivedId = id,
      );

      controller.openHistoryEntry('e1');

      expect(receivedId, 'e1');
    });

    test('registerHandlers replaces previously registered handlers', () {
      final controller = AppNavigationController();
      var firstCalled = false;
      var secondCalled = false;

      controller.registerHandlers(
        openTask: (_) => firstCalled = true,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );
      controller.registerHandlers(
        openTask: (_) => secondCalled = true,
        openProject: (_) {},
        openHistoryEntry: (_) {},
      );

      controller.openTask('t1');

      expect(firstCalled, isFalse);
      expect(secondCalled, isTrue);
    });
  });
}
