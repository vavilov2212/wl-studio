import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/cubit/idle_flow_cubit.dart';

import '../helpers/test_fakes.dart';

// Minimal fake for IdleResolutionWindow -- no Win32, just callbacks.
class FakeIdleResolutionWindow {
  void Function()? lastOnKeep;
  void Function()? lastOnDiscard;
  void Function()? lastOnRequestLogToTask;
  int? lastIdleMinutes;
  int showCalls = 0;
  int hideCalls = 0;

  void show({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function() onRequestLogToTask,
  }) {
    showCalls++;
    lastIdleMinutes = idleMinutes;
    lastOnKeep = onKeep;
    lastOnDiscard = onDiscard;
    lastOnRequestLogToTask = onRequestLogToTask;
  }

  void hide() => hideCalls++;
}

class FakeReminderService {
  int reloadCalls = 0;
  Future<void> reloadInterval() async => reloadCalls++;
}

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerBloc bloc;
  late FakeIdleMonitor idleMonitor;
  late FakeIdleResolutionWindow resolutionWindow;
  late FakeReminderService reminderService;

  // Controllable "now" for the cubit so tests are deterministic.
  late DateTime fakeNow;

  IdleFlowCubit buildCubit({
    Future<IdleTaskSelection?> Function()? showTaskSelectionDialog,
  }) {
    return IdleFlowCubit(
      idleMonitor: idleMonitor,
      bloc: bloc,
      repository: repo,
      reloadReminderInterval: reminderService.reloadInterval,
      showResolutionWindow: resolutionWindow.show,
      hideResolutionWindow: resolutionWindow.hide,
      showTaskSelectionDialog: showTaskSelectionDialog,
      thresholdSeconds: 600,
      now: () => fakeNow,
    );
  }

  setUp(() {
    clock = FakeClock(DateTime(2025, 1, 1, 9));
    repo = FakeTimeEntryRepository();
    bloc = TimeTrackerBloc(service: TimeTrackerService(repository: repo, clock: clock));
    idleMonitor = FakeIdleMonitor();
    resolutionWindow = FakeIdleResolutionWindow();
    reminderService = FakeReminderService();
    fakeNow = DateTime(2025, 1, 1, 9, 10); // default: 9:10
  });

  tearDown(() async {
    await idleMonitor.close();
    await bloc.close();
  });

  group('IdleFlowCubit', () {
    late IdleFlowCubit cubit;

    setUp(() => cubit = buildCubit());
    tearDown(() => cubit.close());

    test('starts in idle state', () {
      expect(cubit.state, isA<IdleFlowIdle>());
    });

    test('ignores IdleThresholdReached when timer is not running', () {
      idleMonitor.emitThreshold(idleSeconds: 610);
      expect(cubit.state, isA<IdleFlowIdle>());
    });

    test('transitions to awaitingResolution when timer is running and threshold reached', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});

      expect(cubit.state, isA<IdleFlowAwaitingResolution>());
      final s = cubit.state as IdleFlowAwaitingResolution;
      expect(s.taskId, 't1');
      expect(s.projectId, 'p1');
    });

    test('shows resolution window with actual elapsed minutes on UserReturnedFromIdle', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      // Threshold fires at 9:10 with 600s idle - idle started at 9:00.
      final thresholdTime = DateTime(2025, 1, 1, 9, 10);
      idleMonitor.emitThreshold(idleSeconds: 600, timestamp: thresholdTime);
      await Future.microtask(() {});

      // User returns at 9:35 - fakeNow represents the cubit's current time.
      fakeNow = DateTime(2025, 1, 1, 9, 35);
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      expect(resolutionWindow.showCalls, 1);
      // Actual elapsed: 9:35 - 9:00 = 35 min (not just the 10-min threshold).
      expect(resolutionWindow.lastIdleMinutes, 35);
    });

    test('keep choice: emits resolved, reloads reminder, no bloc changes', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();
      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnKeep!();
      await Future.microtask(() {});

      expect(cubit.state, isA<IdleFlowResolved>());
      expect(reminderService.reloadCalls, 1);
      expect(bloc.state.isRunning, isTrue);
    });

    test('discard choice: stops at idleStartTime, restarts, reloads reminder', () async {
      final startAt = clock.now();
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: startAt, status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      clock.advance(const Duration(minutes: 11));

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      expect(cubit.state, isA<IdleFlowAwaitingResolution>());

      resolutionWindow.lastOnDiscard!();
      await pumpEventQueue();

      expect(reminderService.reloadCalls, 1);
      final active = await repo.getActive();
      expect(active, isNotNull);
      expect(active!.taskId, 't1');
    });

    test('logToTask with no dialog callback falls back to keep', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();
      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnRequestLogToTask!();
      await pumpEventQueue();

      expect(cubit.state, isA<IdleFlowResolved>());
      expect(reminderService.reloadCalls, 1);
      // Timer still running - keep was the fallback.
      expect(bloc.state.isRunning, isTrue);
    });

    test('discard is a no-op if the active entry changed since threshold', () async {
      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      // Simulate task switch: stop e1, start e2 (different entry).
      await repo.update(
        repo.all.first.copyWith(
          status: TimeEntryStatus.stopped,
          endAt: clock.now(),
        ),
      );
      repo.seed(TimeEntry(
        id: 'e2', taskId: 't2', projectId: 'p2',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));

      resolutionWindow.lastOnDiscard!();
      await pumpEventQueue();

      // Discard was a no-op: e2 is untouched and still the active entry.
      final active = await repo.getActive();
      expect(active?.id, 'e2');
      expect(active?.status, TimeEntryStatus.running);
      expect(cubit.state, isA<IdleFlowResolved>());
    });
  });

  group('IdleFlowCubit - logToTask with dialog', () {
    test('dialog confirmed: creates idle entry linked to selected task and restarts original', () async {
      final cubit = buildCubit(
        showTaskSelectionDialog: () async => const IdleTaskSelection(
          taskId: 'other-task',
          projectId: 'other-project',
          comment: 'Coffee break',
        ),
      );
      addTearDown(cubit.close);

      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      final thresholdTime = DateTime(2025, 1, 1, 9, 10);
      idleMonitor.emitThreshold(idleSeconds: 600, timestamp: thresholdTime);
      await Future.microtask(() {});
      fakeNow = DateTime(2025, 1, 1, 9, 35);
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnRequestLogToTask!();
      await pumpEventQueue();

      final all = repo.all;
      // Original entry stopped at idle start, idle entry created, new running entry.
      final idleEntry = all.firstWhere(
        (e) => e.taskId == 'other-task' && e.status == TimeEntryStatus.stopped,
        orElse: () => throw StateError('Idle entry not found'),
      );
      expect(idleEntry.projectId, 'other-project');
      expect(idleEntry.comment, 'Coffee break');

      final active = await repo.getActive();
      expect(active?.taskId, 't1');
      expect(cubit.state, isA<IdleFlowResolved>());
      expect(reminderService.reloadCalls, 1);
    });

    test('dialog dismissed: falls back to keep tracking', () async {
      final cubit = buildCubit(
        showTaskSelectionDialog: () async => null,
      );
      addTearDown(cubit.close);

      repo.seed(TimeEntry(
        id: 'e1', taskId: 't1', projectId: 'p1',
        startAt: clock.now(), status: TimeEntryStatus.running,
      ));
      bloc.add(const TimeTrackerLoaded());
      await pumpEventQueue();

      idleMonitor.emitThreshold(idleSeconds: 610);
      await Future.microtask(() {});
      idleMonitor.emitUserReturned();
      await Future.microtask(() {});

      resolutionWindow.lastOnRequestLogToTask!();
      await pumpEventQueue();

      expect(cubit.state, isA<IdleFlowResolved>());
      // Only one active entry: the original t1 is still running.
      final active = await repo.getActive();
      expect(active?.taskId, 't1');
    });
  });
}
