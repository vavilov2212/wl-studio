import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/windows_idle_monitor.dart';

void main() {
  late List<Duration> timerDurations;
  late List<void Function()> timerCallbacks;
  late List<bool> timerCancelled;

  Timer fakeFactory(Duration d, void Function() cb) {
    timerDurations.add(d);
    timerCallbacks.add(cb);
    timerCancelled.add(false);
    final index = timerCancelled.length - 1;
    return _FakeTimer(() => timerCancelled[index] = true);
  }

  setUp(() {
    timerDurations = [];
    timerCallbacks = [];
    timerCancelled = [];
  });

  WindowsIdleMonitor makeMonitor({
    required int Function() getTickCount,
    required int Function() getLastInputTick,
    DateTime Function()? wallClock,
  }) {
    return WindowsIdleMonitor(
      getTickCount: getTickCount,
      getLastInputTick: getLastInputTick,
      wallClock: wallClock ?? DateTime.now,
      timerFactory: fakeFactory,
    );
  }

  group('WindowsIdleMonitor', () {
    test('emits IdleThresholdReached when idle exceeds threshold', () async {
      int tick = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000; // 70 seconds elapsed, threshold is 60s
      timerCallbacks.single();

      expect(events, hasLength(1));
      expect(events.single, isA<IdleThresholdReached>());
      final evt = events.single as IdleThresholdReached;
      expect(evt.idleSeconds, 70);
      await sub.cancel();
    });

    test('does not fire threshold twice without user return', () async {
      int tick = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000;
      timerCallbacks.single();
      timerCallbacks.single(); // fire again

      expect(events.whereType<IdleThresholdReached>(), hasLength(1));
      await sub.cancel();
    });

    test('emits UserReturnedFromIdle after threshold when new input detected', () async {
      int tick = 0;
      int lastInput = 0;
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => lastInput,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 60);

      tick = 70000;
      timerCallbacks.single(); // fires threshold

      lastInput = 69000; // user moved mouse (new input tick near current tick)
      tick = 70500;
      timerCallbacks.single(); // detects return

      expect(events, hasLength(2));
      expect(events[0], isA<IdleThresholdReached>());
      expect(events[1], isA<UserReturnedFromIdle>());
      await sub.cancel();
    });

    test('stop() cancels polling timer', () async {
      final monitor = makeMonitor(
        getTickCount: () => 0,
        getLastInputTick: () => 0,
      );
      await monitor.start(thresholdSeconds: 60);
      expect(timerCancelled.single, isFalse);
      await monitor.stop();
      expect(timerCancelled.single, isTrue);
    });

    test('accumulates sleep time from wall-clock drift', () async {
      int tick = 0;
      DateTime wall = DateTime(2025, 1, 1, 9, 0, 0);
      final monitor = makeMonitor(
        getTickCount: () => tick,
        getLastInputTick: () => 0,
        wallClock: () => wall,
      );
      final events = <IdleEvent>[];
      final sub = monitor.onIdleEvent.listen(events.add);
      await monitor.start(thresholdSeconds: 300);

      // Poll 1: no drift, 60s idle - below threshold
      tick = 60000;
      wall = DateTime(2025, 1, 1, 9, 0, 5);
      timerCallbacks.single();
      expect(events, isEmpty);

      // Poll 2: wall clock jumped 250s (system slept) - accumulated = 245s
      tick = 65000; // GetTickCount only advanced 5s
      wall = DateTime(2025, 1, 1, 9, 4, 10); // wall advanced 245s
      timerCallbacks.single();
      // totalIdle = 65s (tick) + 245s (accumulated) = 310s > 300s threshold
      expect(events, hasLength(1));
      expect(events.single, isA<IdleThresholdReached>());
      await sub.cancel();
    });
  });
}

class _FakeTimer implements Timer {
  final void Function() _cancel;
  _FakeTimer(this._cancel);
  @override
  void cancel() => _cancel();
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}
