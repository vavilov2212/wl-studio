import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/state/project_task_state.dart';

import '../helpers/test_fakes.dart';

void main() {
  final kNow = DateTime(2025, 1, 1, 9, 0, 0);

  late FakeClock clock;
  late FakeTimeEntryRepository timeRepo;
  late TimeTrackerBloc trackerBloc;
  late ProjectTaskState projectTaskState;

  setUp(() {
    clock = FakeClock(kNow);
    timeRepo = FakeTimeEntryRepository();
    final service = TimeTrackerService(repository: timeRepo, clock: clock);
    trackerBloc = TimeTrackerBloc(service: service, idleMonitor: null);
    projectTaskState = ProjectTaskState(
      projectRepository: FakeProjectRepository(),
      taskRepository: FakeTaskRepository(),
      clock: clock,
    );
  });

  tearDown(() async {
    await trackerBloc.close();
  });

  // Brings the bloc to a loaded-and-running state.
  Future<void> startRunning({
    String? projectId,
    String? taskId,
    String? comment,
  }) async {
    trackerBloc.add(TimeTrackerLoaded());
    await Future<void>.delayed(Duration.zero);
    trackerBloc.add(
      TimeTrackerStarted(projectId: projectId, taskId: taskId, comment: comment),
    );
    await Future<void>.delayed(Duration.zero);
  }

  group('TrackerPanelCubit', () {
    test('initial state has empty draftComment', () async {
      await Future<void>.delayed(Duration.zero); // let projectTaskState._init() settle
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );
      expect(cubit.state.draftComment, isEmpty);
      await cubit.close();
    });

    test('syncs draftComment from active running entry on construction', () async {
      await startRunning(comment: 'initial work');
      await Future<void>.delayed(Duration.zero); // projectTaskState._init()
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );
      expect(cubit.state.draftComment, 'initial work');
      await cubit.close();
    });

    test('updateComment emits new state but does not dispatch to bloc when not running',
        () async {
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      final stateBefore = trackerBloc.state;
      cubit.updateComment('my note', isRunning: false);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.draftComment, 'my note');
      expect(trackerBloc.state, stateBefore); // bloc unchanged
      await cubit.close();
    });

    test('updateComment emits new state and dispatches TimeTrackerActiveEntryUpdated when running',
        () async {
      await startRunning(comment: 'old note');
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      cubit.updateComment('new note', isRunning: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.draftComment, 'new note');
      expect(trackerBloc.state.activeEntryOrNull?.comment, 'new note');
      await cubit.close();
    });

    test('startTimer dispatches TimeTrackerStarted with current draft and comment',
        () async {
      trackerBloc.add(TimeTrackerLoaded());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero); // projectTaskState._init()
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      projectTaskState.updateDraft(projectId: 'proj-1', taskId: 'task-1');
      cubit.updateComment('doing stuff', isRunning: false);
      cubit.startTimer();
      await Future<void>.delayed(Duration.zero);

      expect(trackerBloc.state.isRunning, isTrue);
      expect(trackerBloc.state.activeEntryOrNull?.projectId, 'proj-1');
      expect(trackerBloc.state.activeEntryOrNull?.taskId, 'task-1');
      expect(trackerBloc.state.activeEntryOrNull?.comment, 'doing stuff');
      await cubit.close();
    });

    test('stopTimer dispatches TimeTrackerStopped, clears draft, and resets draftComment',
        () async {
      await startRunning(projectId: 'p1', comment: 'working');
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );
      expect(cubit.state.draftComment, 'working');

      cubit.stopTimer();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.draftComment, isEmpty);
      expect(trackerBloc.state.isRunning, isFalse);
      expect(projectTaskState.draftProjectId, isNull);
      await cubit.close();
    });

    test('updateProject updates projectTaskState without dispatching to bloc when not running',
        () async {
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      cubit.updateProject('proj-x', isRunning: false);
      await Future<void>.delayed(Duration.zero);

      expect(projectTaskState.draftProjectId, 'proj-x');
      expect(trackerBloc.state.isRunning, isFalse);
      await cubit.close();
    });

    test('updateProject updates projectTaskState and dispatches to bloc when running',
        () async {
      await startRunning(projectId: 'old-proj');
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      cubit.updateProject('new-proj', isRunning: true);
      await Future<void>.delayed(Duration.zero);

      expect(projectTaskState.draftProjectId, 'new-proj');
      expect(trackerBloc.state.activeEntryOrNull?.projectId, 'new-proj');
      await cubit.close();
    });

    test('updateTask updates projectTaskState without dispatching to bloc when not running',
        () async {
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );

      cubit.updateTask('task-y', isRunning: false);
      await Future<void>.delayed(Duration.zero);

      expect(projectTaskState.draftTaskId, 'task-y');
      expect(trackerBloc.state.isRunning, isFalse);
      await cubit.close();
    });

    test('reactive: syncs draftComment when bloc transitions to running after construction',
        () async {
      trackerBloc.add(TimeTrackerLoaded());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final cubit = TrackerPanelCubit(
        timeTrackerBloc: trackerBloc,
        projectTaskState: projectTaskState,
      );
      expect(cubit.state.draftComment, isEmpty);

      trackerBloc.add(TimeTrackerStarted(comment: 'reactive note'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.draftComment, 'reactive note');
      await cubit.close();
    });
  });
}
