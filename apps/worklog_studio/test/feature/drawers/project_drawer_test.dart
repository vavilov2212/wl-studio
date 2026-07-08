import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_drawer.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../../helpers/test_fakes.dart';

void main() {
  final kNow = DateTime(2025, 1, 1, 9, 0, 0);

  late FakeClock clock;
  late FakeTimeEntryRepository timeRepo;
  late FakeProjectRepository projectRepo;
  late FakeTaskRepository taskRepo;
  late TimeTrackerBloc bloc;
  late ProjectTaskState state;
  late bool closed;

  setUp(() {
    clock = FakeClock(kNow);
    timeRepo = FakeTimeEntryRepository();
    projectRepo = FakeProjectRepository();
    taskRepo = FakeTaskRepository();
    bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: timeRepo, clock: clock),
      idleMonitor: null,
    );
    state = ProjectTaskState(
      projectRepository: projectRepo,
      taskRepository: taskRepo,
      clock: clock,
    );
    closed = false;
  });

  tearDown(() async {
    await bloc.close();
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AppNavigationController>(
          create: (_) => AppNavigationController(),
        ),
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

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Project buildProject() => Project(
        id: 'p1',
        name: 'Alpha',
        description: 'First project',
        createdAt: kNow,
      );

  testWidgets('create mode shows the Not saved yet info bar', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(wrap(
      ProjectDrawer(project: null, isOpen: true, onClose: () => closed = true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Not saved yet'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('create mode saves a new project via ProjectTaskState',
      (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(wrap(
      ProjectDrawer(project: null, isOpen: true, onClose: () => closed = true),
    ));
    await tester.pumpAndSettle();

    // Enter edit mode on the name InlineField, type a name, save.
    await tester.tap(find.text('Enter project name...').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'My Project');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(projectRepo.all, hasLength(1));
    expect(projectRepo.all.first.name, 'My Project');
    expect(closed, isTrue);
  });

  testWidgets('edit mode shows project name and no Not saved yet bar',
      (tester) async {
    useLargeSurface(tester);
    final project = buildProject();
    await projectRepo.insert(project);
    await state.loadData();

    await tester.pumpWidget(wrap(
      ProjectDrawer(
        project: project,
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Not saved yet'), findsNothing);
  });

  testWidgets('delete flow: confirmation then removal via ProjectTaskState',
      (tester) async {
    useLargeSurface(tester);
    final project = buildProject();
    await projectRepo.insert(project);
    await state.loadData();

    await tester.pumpWidget(wrap(
      ProjectDrawer(
        project: project,
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this project?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(projectRepo.all, isEmpty);
    expect(closed, isTrue);
  });

  testWidgets('delete flow: cancel dismisses the confirmation',
      (tester) async {
    useLargeSurface(tester);
    final project = buildProject();
    await projectRepo.insert(project);
    await state.loadData();

    await tester.pumpWidget(wrap(
      ProjectDrawer(
        project: project,
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this project?'), findsNothing);
    expect(projectRepo.all, hasLength(1));
    expect(closed, isFalse);
  });
}
