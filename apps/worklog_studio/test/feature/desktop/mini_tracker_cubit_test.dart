import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/core/services/desktop/no_op_desktop_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/desktop/data/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_panel_command_bus.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';

class _RecordingDesktopService extends NoOpDesktopService {
  _RecordingDesktopService() : super.base();

  final List<dynamic> dispatched = [];
  int requestActivityPromptCalls = 0;

  @override
  void dispatchAction(covariant dynamic action) {
    dispatched.add(action);
  }

  @override
  void requestActivityPrompt() {
    requestActivityPromptCalls++;
  }
}

void main() {
  late _RecordingDesktopService desktopService;
  late MiniTrackerCubit cubit;

  setUp(() {
    desktopService = _RecordingDesktopService();
    DesktopServiceRegistry.overrideForTesting(desktopService);
    cubit = MiniTrackerCubit();
  });

  tearDown(() async {
    await cubit.close();
  });

  group('MiniTrackerCubit.updateComment', () {
    test('dispatches an updateComment TimerAction when a session is running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.updateComment('new comment');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.updateComment);
      expect(action.comment, 'new comment');
    });

    test('does nothing when no session is running', () {
      cubit.updateComment('ignored');

      expect(desktopService.dispatched, isEmpty);
    });
  });

  group('MiniTrackerCubit.restartWithComment', () {
    test('dispatches a start action with the given projectId, taskId and comment when running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
            projectId: 'p1',
            taskId: 't1',
            comment: 'old comment',
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.restartWithComment('p1', 't1', 'new comment');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.start);
      expect(action.projectId, 'p1');
      expect(action.taskId, 't1');
      expect(action.comment, 'new comment');
    });

    test('dispatches start even when project and task match the running entry', () {
      // Contrast with startTimer which no-ops in this case.
      // restartWithComment always fires to create a new time-entry boundary.
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
            projectId: 'p1',
            taskId: 't1',
            comment: 'old',
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.restartWithComment('p1', 't1', '');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.start);
    });

    test('does nothing when no session is running', () {
      cubit.restartWithComment('p1', 't1', 'new comment');

      expect(desktopService.dispatched, isEmpty);
    });
  });

  group('MiniPanelCommandBus', () {
    test('emit replays on the stream', () async {
      final bus = MiniPanelCommandBus();
      final received = <MiniPanelCommand>[];
      final sub = bus.stream.listen(received.add);

      bus.emit(MiniPanelCommand.focusComment);
      bus.emit(MiniPanelCommand.acceptComment);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.focusComment, MiniPanelCommand.acceptComment]);
      await sub.cancel();
      bus.dispose();
    });
  });

  group('MiniTrackerCubit.requestActivityPrompt', () {
    test('asks the desktop service to open the activity prompt when a session is running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.requestActivityPrompt();

      expect(desktopService.requestActivityPromptCalls, 1);
    });

    test('does nothing when no session is running', () {
      cubit.requestActivityPrompt();

      expect(desktopService.requestActivityPromptCalls, 0);
    });
  });

}
