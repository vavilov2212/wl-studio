import 'package:worklog_studio/core/services/desktop/desktop_service_factory.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';

/// Holds the app-wide [IDesktopPlatformService] singleton.
///
/// Initialised once at startup by [DesktopServiceRegistry.init].
/// All call sites obtain the service via [DesktopServiceRegistry.instance].
///
/// Example:
/// ```dart
/// // Bootstrap (call once in runner.dart before runApp):
/// DesktopServiceRegistry.init();
///
/// // Usage anywhere:
/// await DesktopServiceRegistry.instance.initLeader(bloc, resolver, pts);
/// ```
class DesktopServiceRegistry {
  DesktopServiceRegistry._();

  static IDesktopPlatformService? _instance;

  /// The active platform service. Throws if [init] has not been called yet.
  static IDesktopPlatformService get instance {
    assert(
      _instance != null,
      'DesktopServiceRegistry.init() must be called before accessing instance.',
    );
    return _instance!;
  }

  /// Creates and stores the platform-appropriate service.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  static void init() {
    _instance ??= createDesktopService();
  }

  /// Replace the instance with [service].
  ///
  /// Intended for testing only — allows injecting a mock/fake without
  /// touching any production code path.
  // ignore: avoid_setters_without_getters
  static void overrideForTesting(IDesktopPlatformService service) {
    _instance = service;
  }
}
