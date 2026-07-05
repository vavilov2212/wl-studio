import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/home/presentation/components/dashboard_charts_section.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../../helpers/test_fakes.dart';

class _FakeProjectRepository implements ProjectRepository {
  final List<Project> _store;
  _FakeProjectRepository(this._store);
  @override
  Future<List<Project>> getAll() async => _store;
  @override
  Future<Project?> getById(String id) async =>
      _store.where((p) => p.id == id).firstOrNull;
  @override
  Future<void> insert(Project project) async => _store.add(project);
  @override
  Future<void> update(Project project) async {}
  @override
  Future<void> delete(String id) async {}
}

class _FakeTaskRepository implements TaskRepository {
  final List<Task> _store;
  _FakeTaskRepository(this._store);
  @override
  Future<List<Task>> getAll() async => _store;
  @override
  Future<List<Task>> getByProjectId(String projectId) async =>
      _store.where((t) => t.projectId == projectId).toList();
  @override
  Future<Task?> getById(String id) async =>
      _store.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> insert(Task task) async => _store.add(task);
  @override
  Future<void> update(Task task) async {}
  @override
  Future<void> delete(String id) async {}
}

Widget _wrap(Widget child, {required TimeTrackerBloc bloc, required ProjectTaskState state}) {
  return MultiProvider(
    providers: [
      BlocProvider<TimeTrackerBloc>.value(value: bloc),
      ChangeNotifierProvider<ProjectTaskState>.value(value: state),
      ChangeNotifierProvider<EntityResolver>(
        create: (_) => EntityResolver(bloc: bloc, projectTaskState: state),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightThemeData,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows empty state when there are no time entries', (tester) async {
    final repository = FakeTimeEntryRepository();
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([]),
      taskRepository: _FakeTaskRepository([]),
      clock: SystemClock(),
    );

    await tester.pumpWidget(
      _wrap(const DashboardChartsSection(), bloc: bloc, state: projectState),
    );
    await tester.pumpAndSettle();

    expect(find.text('No time logged for this period.'), findsOneWidget);
  });

  testWidgets('switching to bar view renders a BarChart instead of donuts', (tester) async {
    final repository = FakeTimeEntryRepository();
    final now = DateTime.now();
    repository.seed(TimeEntry(
      id: 'e1',
      projectId: 'p1',
      taskId: 't1',
      startAt: now.subtract(const Duration(hours: 1)),
      endAt: now,
      status: TimeEntryStatus.stopped,
    ));
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([
        Project(id: 'p1', name: 'Project p1', description: '', createdAt: now),
      ]),
      taskRepository: _FakeTaskRepository([
        Task(
          id: 't1',
          projectId: 'p1',
          title: 'Task t1',
          description: '',
          status: TaskStatus.open,
          createdAt: now,
        ),
      ]),
      clock: SystemClock(),
    );

    await tester.pumpWidget(
      _wrap(const DashboardChartsSection(), bloc: bloc, state: projectState),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.donut_large_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No time logged for this period.'), findsNothing);
  });
}
