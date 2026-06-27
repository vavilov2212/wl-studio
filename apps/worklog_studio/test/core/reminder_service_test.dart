import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

import '../helpers/test_fakes.dart';

class _FakeCancelableTimer implements CancelableTimer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerBloc bloc;
  late Map<String, String> store;
  late int fireCalls;
  late int autoDismissCalls;
  late List<Duration> periodicDurations;
  late List<void Function()> periodicCallbacks;
  late List<_FakeCancelableTimer> periodicTimers;
  late List<Duration> oneShotDurations;
  late List<void Function()> oneShotCallbacks;
  late List<_FakeCancelableTimer> oneShotTimers;
  late ReminderService service;

  setUp(() {
    clock = FakeClock(DateTime(2025, 1, 1, 9));
    repo = FakeTimeEntryRepository();
    bloc = TimeTrackerBloc(service: TimeTrackerService(repository: repo, clock: clock));
    store = {};
    fireCalls = 0;
    autoDismissCalls = 0;
    periodicDurations = [];
    periodicCallbacks = [];
    periodicTimers = [];
    oneShotDurations = [];
    oneShotCallbacks = [];
    oneShotTimers = [];

    service = ReminderService(
      bloc: bloc,
      getSetting: (key) async => store[key],
      onFire: () async => fireCalls++,
      onAutoDismiss: () async => autoDismissCalls++,
      periodicTimerFactory: (duration, onTick) {
        periodicDurations.add(duration);
        periodicCallbacks.add(onTick);
        final timer = _FakeCancelableTimer();
        periodicTimers.add(timer);
        return timer;
      },
      oneShotTimerFactory: (duration, onFire) {
        oneShotDurations.add(duration);
        oneShotCallbacks.add(onFire);
        final timer = _FakeCancelableTimer();
        oneShotTimers.add(timer);
        return timer;
      },
    );
  });

  tearDown(() async {
    service.dispose();
    await bloc.close();
  });

  group('ReminderService.init', () {
    test('starts a periodic timer at the configured interval while running', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);
      store[SettingsKeys.reminderIntervalMinutes] = '5';

      await service.init();

      expect(periodicDurations, [const Duration(minutes: 5)]);
    });

    test('does not start a timer when the interval is unset', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.init();

      expect(periodicDurations, isEmpty);
    });

    test('does not start a timer when nothing is running', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';

      await service.init();

      expect(periodicDurations, isEmpty);
    });
  });

  group('ReminderService firing', () {
    test('on fire, calls onFire and schedules a 20s auto-dismiss', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      await service.init();

      periodicCallbacks.single();
      await Future<void>.delayed(Duration.zero);

      expect(fireCalls, 1);
      expect(oneShotDurations, [const Duration(seconds: 20)]);

      oneShotCallbacks.single();
      await Future<void>.delayed(Duration.zero);

      expect(autoDismissCalls, 1);
    });
  });

  group('ReminderService bloc transitions', () {
    test('starting tracking after init starts the reminder timer', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      await service.init();
      expect(periodicDurations, isEmpty);

      bloc.add(const TimeTrackerStarted(projectId: 'p1', taskId: 't1'));
      await bloc.stream.firstWhere((s) => s.isRunning);
      // The bloc-state listener's reaction (_onBlocState -> _startReminderTimer)
      // awaits an async getSetting() call, so it resolves on a later microtask
      // than the firstWhere future above. Without this, the assertion can run
      // before the listener has actually started the timer.
      await Future<void>.delayed(Duration.zero);

      expect(periodicDurations, [const Duration(minutes: 5)]);
    });

    test('stopping tracking cancels the reminder timer', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      bloc.add(const TimeTrackerStarted(projectId: 'p1', taskId: 't1'));
      await bloc.stream.firstWhere((s) => s.isRunning);
      await service.init();
      expect(periodicTimers, hasLength(1));

      bloc.add(TimeTrackerStopped());
      await bloc.stream.firstWhere((s) => !s.isRunning);

      expect(periodicTimers.single.cancelled, isTrue);
    });
  });

  group('ReminderService.reloadInterval', () {
    test('while running, restarts the timer with the newly configured interval', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      bloc.add(const TimeTrackerStarted(projectId: 'p1', taskId: 't1'));
      await bloc.stream.firstWhere((s) => s.isRunning);
      await service.init();
      expect(periodicDurations, [const Duration(minutes: 5)]);
      expect(periodicTimers.single.cancelled, isFalse);

      store[SettingsKeys.reminderIntervalMinutes] = '10';
      await service.reloadInterval();

      expect(periodicTimers.first.cancelled, isTrue);
      expect(periodicDurations, [
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      ]);
    });

    test('does nothing when nothing is running', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      await service.init();
      expect(periodicDurations, isEmpty);

      store[SettingsKeys.reminderIntervalMinutes] = '10';
      await service.reloadInterval();

      expect(periodicDurations, isEmpty);
    });
  });
}
