import 'idle_event.dart';

abstract class IdleMonitor {
  /// Start monitoring idle time in seconds
  Future<void> start({required int thresholdSeconds});

  /// Stop monitoring
  Future<void> stop();

  /// Stream of idle events
  Stream<IdleEvent> get onIdleEvent;
}
