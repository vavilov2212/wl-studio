import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/home/presentation/components/dashboard_charts_section.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
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

Widget _wrap(
  Widget child, {
  required TimeTrackerBloc bloc,
  required ProjectTaskState state,
  ReportsBloc? reportsBloc,
}) {
  return MultiProvider(
    providers: [
      BlocProvider<TimeTrackerBloc>.value(value: bloc),
      if (reportsBloc != null) BlocProvider<ReportsBloc>.value(value: reportsBloc),
      Provider<AppNavigationController>(create: (_) => AppNavigationController()),
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
    final today = DateTime.now();
    // Use a fixed mid-morning time so startAt is always within the current week,
    // regardless of what hour CI runs (avoids Monday-midnight week-boundary failures).
    final startAt = DateTime(today.year, today.month, today.day, 10, 0);
    repository.seed(TimeEntry(
      id: 'e1',
      projectId: 'p1',
      taskId: 't1',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      status: TimeEntryStatus.stopped,
    ));
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([
        Project(id: 'p1', name: 'Project p1', description: '', createdAt: today),
      ]),
      taskRepository: _FakeTaskRepository([
        Task(
          id: 't1',
          projectId: 'p1',
          title: 'Task t1',
          description: '',
          status: TaskStatus.open,
          createdAt: today,
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

  testWidgets('open-in-reports button demonstrates the configured view and syncs ReportsBloc',
      timeout: const Timeout(Duration(seconds: 60)), (tester) async {
    final repository = FakeTimeEntryRepository();
    final today = DateTime.now();
    final startAt = DateTime(today.year, today.month, today.day, 10, 0);
    repository.seed(TimeEntry(
      id: 'e1',
      projectId: 'p1',
      taskId: 't1',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      status: TimeEntryStatus.stopped,
    ));
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([
        Project(id: 'p1', name: 'Project p1', description: '', createdAt: today),
      ]),
      taskRepository: _FakeTaskRepository([]),
      clock: SystemClock(),
    );
    final reportsBloc = ReportsBloc();
    // Closing a Bloc inside the testWidgets FakeAsync zone never completes;
    // addTearDown runs after the fake zone and closes it safely.
    addTearDown(reportsBloc.close);

    await tester.pumpWidget(
      _wrap(
        const DashboardChartsSection(),
        bloc: bloc,
        state: projectState,
        reportsBloc: reportsBloc,
      ),
    );
    await tester.pumpAndSettle();

    // Switch the dashboard to the bar view first.
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    // The tooltip spells out that the configured view carries over.
    final tooltipFinder = find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message ?? '').contains('Open in Reports'),
    );
    expect(tooltipFinder, findsOneWidget);
    expect(
      tester.widget<Tooltip>(tooltipFinder).message,
      contains('bar chart'),
    );

    // Tapping mirrors the dashboard charts state into ReportsBloc.
    await tester.tap(find.byIcon(Icons.open_in_new_rounded));
    await tester.pumpAndSettle();

    expect(reportsBloc.state.view, DashboardChartView.bar);
    expect(reportsBloc.state.period, DashboardPeriod.week);
  });
}
