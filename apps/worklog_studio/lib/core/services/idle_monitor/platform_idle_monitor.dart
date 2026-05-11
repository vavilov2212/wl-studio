import 'dart:async';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';

@LazySingleton(as: IdleMonitor)
class PlatformIdleMonitor implements IdleMonitor {
  static const MethodChannel _channel = MethodChannel('worklog_studio/idle_monitor');
  
  final _eventController = StreamController<IdleEvent>.broadcast();

  PlatformIdleMonitor() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onIdleThresholdReached':
        final args = call.arguments as Map<dynamic, dynamic>;
        final idleSeconds = (args['idleSeconds'] as num).toInt();
        final timestampMs = (args['timestamp'] as num).toInt();
        _eventController.add(IdleThresholdReached(
          idleSeconds: idleSeconds,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
        ));
        break;
    }
  }

  @override
  Future<void> start({required int thresholdSeconds}) async {
    await _channel.invokeMethod('start', {'thresholdSeconds': thresholdSeconds.toDouble()});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  @override
  Stream<IdleEvent> get onIdleEvent => _eventController.stream;
}
