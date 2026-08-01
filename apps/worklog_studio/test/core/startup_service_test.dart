import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/startup/startup_service.dart';

class FakeStartupService implements StartupService {
  bool _enabled = false;
  @override Future<void> enable() async => _enabled = true;
  @override Future<void> disable() async => _enabled = false;
  @override Future<bool> isEnabled() async => _enabled;
}

void main() {
  group('StartupService contract', () {
    test('starts disabled', () async {
      final svc = FakeStartupService();
      expect(await svc.isEnabled(), isFalse);
    });

    test('enable() sets enabled', () async {
      final svc = FakeStartupService();
      await svc.enable();
      expect(await svc.isEnabled(), isTrue);
    });

    test('disable() clears enabled', () async {
      final svc = FakeStartupService();
      await svc.enable();
      await svc.disable();
      expect(await svc.isEnabled(), isFalse);
    });
  });
}
