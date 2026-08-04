import 'dart:async';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';

typedef IdlePollerFactory = Timer Function(Duration, void Function());

class WindowsIdleMonitor implements IdleMonitor {
  WindowsIdleMonitor({
    required int Function() getTickCount,
    required int Function() getLastInputTick,
    DateTime Function()? wallClock,
    IdlePollerFactory? timerFactory,
  })  : _getTickCount = getTickCount,
        _getLastInputTick = getLastInputTick,
        _wallClock = wallClock ?? DateTime.now,
        _timerFactory = timerFactory ?? _defaultFactory;

  final int Function() _getTickCount;
  final int Function() _getLastInputTick;
  final DateTime Function() _wallClock;
  final IdlePollerFactory _timerFactory;

  final StreamController<IdleEvent> _controller =
      StreamController<IdleEvent>.broadcast(sync: true);

  Timer? _pollingTimer;
  int _thresholdMs = 600000;
  bool _thresholdFired = false;
  int _suspendAccumulatedMs = 0;
  DateTime? _lastPollTime;

  static Timer _defaultFactory(Duration d, void Function() cb) =>
      Timer.periodic(d, (_) => cb());

  @override
  Stream<IdleEvent> get onIdleEvent => _controller.stream;

  @override
  Future<void> start({required int thresholdSeconds}) async {
    _pollingTimer?.cancel();
    _thresholdMs = thresholdSeconds * 1000;
    _thresholdFired = false;
    _suspendAccumulatedMs = 0;
    _lastPollTime = _wallClock();
    _pollingTimer = _timerFactory(
      const Duration(seconds: 5),
      _poll,
    );
  }

  @override
  Future<void> stop() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _thresholdFired = false;
    _suspendAccumulatedMs = 0;
    _lastPollTime = null;
  }

  void _poll() {
    final now = _wallClock();
    final last = _lastPollTime;
    if (last != null) {
      final wallElapsedMs = now.difference(last).inMilliseconds;
      // If the wall clock jumped more than 10s beyond the 5s poll interval,
      // the system likely slept. Add the excess to the idle accumulator.
      if (wallElapsedMs > 10000) {
        _suspendAccumulatedMs += wallElapsedMs - 5000;
      }
    }
    _lastPollTime = now;

    final tickNow = _getTickCount();
    final lastInputTick = _getLastInputTick();
    // Wraparound-safe: both values are unsigned 32-bit millisecond counters.
    final sinceLastInputMs = (tickNow - lastInputTick) & 0xFFFFFFFF;

    // Reset sleep accumulator if user is actively typing.
    if (!_thresholdFired && sinceLastInputMs < 10000) {
      _suspendAccumulatedMs = 0;
    }

    final totalIdleMs = sinceLastInputMs + _suspendAccumulatedMs;

    if (!_thresholdFired && totalIdleMs >= _thresholdMs) {
      _thresholdFired = true;
      _controller.add(IdleThresholdReached(
        idleSeconds: totalIdleMs ~/ 1000,
        timestamp: now,
      ));
    } else if (_thresholdFired && sinceLastInputMs < 10000) {
      // Fresh input detected after threshold - user has returned.
      _thresholdFired = false;
      _suspendAccumulatedMs = 0;
      _controller.add(const UserReturnedFromIdle());
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
