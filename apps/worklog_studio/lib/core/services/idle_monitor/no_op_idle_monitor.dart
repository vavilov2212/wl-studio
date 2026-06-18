import 'dart:async';
import 'idle_event.dart';
import 'idle_monitor.dart';

/// No-op [IdleMonitor] for platforms without a native channel implementation
/// (Windows, Linux, web). All calls are safe and do nothing.
class NoOpIdleMonitor implements IdleMonitor {
  const NoOpIdleMonitor();

  @override
  Future<void> start({required int thresholdSeconds}) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<IdleEvent> get onIdleEvent => const Stream.empty();
}
