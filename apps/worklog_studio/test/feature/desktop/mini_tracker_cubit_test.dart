import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/no_op_desktop_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';

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

  group('MiniTrackerCubit.commands', () {
    test('emitCommand replays on the commands stream', () async {
      final received = <MiniPanelCommand>[];
      final sub = cubit.commands.listen(received.add);

      cubit.emitCommand(MiniPanelCommand.focusComment);
      cubit.emitCommand(MiniPanelCommand.acceptComment);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.focusComment, MiniPanelCommand.acceptComment]);
      await sub.cancel();
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
