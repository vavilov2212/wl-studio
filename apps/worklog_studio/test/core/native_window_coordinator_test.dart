import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/native_window_coordinator.dart';

void main() {
  late NativeWindowCoordinator coordinator;

  setUp(() {
    // Fresh instance per test (not the singleton).
    coordinator = NativeWindowCoordinator.forTesting();
  });

  group('NativeWindowCoordinator', () {
    test('allows activity window when no idle dialog is showing', () {
      expect(coordinator.canActivityWindowShow(), isTrue);
    });

    test('blocks activity window when idle resolution is showing', () {
      coordinator.idleResolutionWillShow();
      expect(coordinator.canActivityWindowShow(), isFalse);
    });

    test('unblocks activity window after idle resolution hides', () {
      coordinator.idleResolutionWillShow();
      coordinator.idleResolutionDidHide();
      expect(coordinator.canActivityWindowShow(), isTrue);
    });

    test('idleResolutionWillShow hides registered activity window', () {
      bool hideCalled = false;
      coordinator.setActivityWindowHider(() => hideCalled = true);
      coordinator.setActivityWindowVisible(true);
      coordinator.idleResolutionWillShow();
      expect(hideCalled, isTrue);
    });

    test('does not call hider if activity window is not visible', () {
      bool hideCalled = false;
      coordinator.setActivityWindowHider(() => hideCalled = true);
      coordinator.setActivityWindowVisible(false);
      coordinator.idleResolutionWillShow();
      expect(hideCalled, isFalse);
    });
  });
}
