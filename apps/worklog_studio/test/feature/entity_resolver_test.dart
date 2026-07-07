import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

import '../helpers/test_fakes.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Project _project(String id, {String name = 'Project'}) => Project(
      id: id,
      name: name,
      description: '',
      createdAt: DateTime(2025, 1, 1),
    );

Task _task(String id, String projectId, {String title = 'Task'}) => Task(
      id: id,
      projectId: projectId,
      title: title,
      description: '',
      status: TaskStatus.open,
      createdAt: DateTime(2025, 1, 1),
    );

TimeEntry _entry(String id, {String? projectId, String? taskId}) => TimeEntry(
      id: id,
      startAt: DateTime(2025, 1, 1, 9),
      status: TimeEntryStatus.stopped,
      endAt: DateTime(2025, 1, 1, 10),
      projectId: projectId,
      taskId: taskId,
    );

Future<(TimeTrackerBloc, ProjectTaskState)> _buildDeps({
  List<TimeEntry> entries = const [],
  List<Project> projects = const [],
  List<Task> tasks = const [],
}) async {
  final clock = FakeClock(DateTime(2025, 1, 1, 9));
  final timeEntryRepo = FakeTimeEntryRepository();
  for (final e in entries) {
    timeEntryRepo.seed(e);
  }

  final bloc = TimeTrackerBloc(
    service: TimeTrackerService(repository: timeEntryRepo, clock: clock),
  )..add(TimeTrackerLoaded());
  // Wait for bloc to process TimeTrackerLoaded
  await Future<void>.delayed(Duration.zero);

  final projectRepo = FakeProjectRepository();
  final taskRepo = FakeTaskRepository();
  for (final p in projects) {
    await projectRepo.insert(p);
  }
  for (final t in tasks) {
    await taskRepo.insert(t);
  }

  final projectTaskState = ProjectTaskState(
    projectRepository: projectRepo,
    taskRepository: taskRepo,
    clock: clock,
  );
  await Future<void>.delayed(Duration.zero); // let _init complete

  return (bloc, projectTaskState);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('EntityResolver - TimeEntry resolution', () {
    test('getResolvedTimeEntry returns null for an unknown id', () async {
      final (bloc, pts) = await _buildDeps();
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getResolvedTimeEntry('nonexistent'), isNull);
      resolver.dispose();
      await bloc.close();
    });

    test('getResolvedTimeEntry resolves task and project for a known entry', () async {
      final (bloc, pts) = await _buildDeps(
        entries: [_entry('e1', projectId: 'p1', taskId: 't1')],
        projects: [_project('p1', name: 'Alpha')],
        tasks: [_task('t1', 'p1', title: 'First Task')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      final result = resolver.getResolvedTimeEntry('e1');

      expect(result, isNotNull);
      expect(result!.id, 'e1');
      expect(result.projectName, 'Alpha');
      expect(result.taskTitle, 'First Task');
      resolver.dispose();
      await bloc.close();
    });

    test('getResolvedTimeEntry returns null project/task when IDs have no match', () async {
      final (bloc, pts) = await _buildDeps(
        entries: [_entry('e1', projectId: 'unknown-p', taskId: 'unknown-t')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      final result = resolver.getResolvedTimeEntry('e1');

      expect(result, isNotNull);
      expect(result!.project, isNull);
      expect(result.task, isNull);
      expect(result.projectName, 'No Project');
      expect(result.taskTitle, 'Unassigned Task');
      resolver.dispose();
      await bloc.close();
    });

    test('getResolvedTimeEntries returns one resolved entry per stored entry', () async {
      final (bloc, pts) = await _buildDeps(
        entries: [_entry('e1'), _entry('e2')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getResolvedTimeEntries(), hasLength(2));
      resolver.dispose();
      await bloc.close();
    });
  });

  group('EntityResolver - Task resolution', () {
    test('getResolvedTask returns null for an unknown taskId', () async {
      final (bloc, pts) = await _buildDeps();
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getResolvedTask('nonexistent'), isNull);
      resolver.dispose();
      await bloc.close();
    });

    test('getResolvedTask resolves project and collects time entries', () async {
      final (bloc, pts) = await _buildDeps(
        entries: [_entry('e1', projectId: 'p1', taskId: 't1')],
        projects: [_project('p1', name: 'Alpha')],
        tasks: [_task('t1', 'p1', title: 'First Task')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      final result = resolver.getResolvedTask('t1');

      expect(result, isNotNull);
      expect(result!.title, 'First Task');
      expect(result.projectName, 'Alpha');
      expect(result.timeEntries, hasLength(1));
      resolver.dispose();
      await bloc.close();
    });
  });

  group('EntityResolver - Project resolution', () {
    test('getResolvedProject returns null for an unknown projectId', () async {
      final (bloc, pts) = await _buildDeps();
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getResolvedProject('nonexistent'), isNull);
      resolver.dispose();
      await bloc.close();
    });

    test('getResolvedProject includes nested tasks and time entries', () async {
      final (bloc, pts) = await _buildDeps(
        entries: [_entry('e1', projectId: 'p1', taskId: 't1')],
        projects: [_project('p1', name: 'Alpha')],
        tasks: [_task('t1', 'p1')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      final result = resolver.getResolvedProject('p1');

      expect(result, isNotNull);
      expect(result!.name, 'Alpha');
      expect(result.tasks, hasLength(1));
      expect(result.timeEntries, hasLength(1));
      resolver.dispose();
      await bloc.close();
    });
  });

  group('EntityResolver - Name helpers', () {
    test('getProjectName returns the name for a known projectId', () async {
      final (bloc, pts) = await _buildDeps(
        projects: [_project('p1', name: 'Beta')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getProjectName('p1'), 'Beta');
      resolver.dispose();
      await bloc.close();
    });

    test('getProjectName returns "No Project" for null or unknown id', () async {
      final (bloc, pts) = await _buildDeps();
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getProjectName(null), 'No Project');
      expect(resolver.getProjectName('unknown'), 'No Project');
      resolver.dispose();
      await bloc.close();
    });

    test('getTaskName returns the title for a known taskId', () async {
      final (bloc, pts) = await _buildDeps(
        tasks: [_task('t1', 'p1', title: 'Design')],
      );
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getTaskName('t1'), 'Design');
      resolver.dispose();
      await bloc.close();
    });

    test('getTaskName returns "No Task" for null or unknown id', () async {
      final (bloc, pts) = await _buildDeps();
      final resolver = EntityResolver(bloc: bloc, projectTaskState: pts);

      expect(resolver.getTaskName(null), 'No Task');
      expect(resolver.getTaskName('unknown'), 'No Task');
      resolver.dispose();
      await bloc.close();
    });
  });
}
