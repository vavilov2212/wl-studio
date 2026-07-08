import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_drawer.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../../helpers/test_fakes.dart';

void main() {
  final kNow = DateTime(2025, 1, 1, 9, 0, 0);

  late FakeClock clock;
  late FakeTimeEntryRepository timeRepo;
  late TimeTrackerBloc bloc;
  late ProjectTaskState state;
  late bool closed;

  setUp(() {
    clock = FakeClock(kNow);
    timeRepo = FakeTimeEntryRepository();
    state = ProjectTaskState(
      projectRepository: FakeProjectRepository(),
      taskRepository: FakeTaskRepository(),
      clock: clock,
    );
    closed = false;
  });

  tearDown(() async {
    await bloc.close();
  });

  // The bloc must be constructed INSIDE the testWidgets body: creating it in
  // setUp binds its event-processing machinery to the real async zone, and
  // events added during the FakeAsync test body then complete only after the
  // test's expectations have already run.
  void initBloc() {
    bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: timeRepo, clock: clock),
      idleMonitor: null,
    );
  }

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
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  TimeEntry buildEntry() => TimeEntry(
        id: 'e1',
        comment: 'Fixing the widget tests',
        startAt: kNow.subtract(const Duration(hours: 1)),
        endAt: kNow,
        status: TimeEntryStatus.stopped,
      );

  testWidgets('create mode shows the Not saved yet info bar', (tester) async {
    useLargeSurface(tester);
    initBloc();
    await tester.pumpWidget(wrap(
      TimeEntryDrawer(
        resolvedEntry: null,
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Not saved yet'), findsOneWidget);
  });

  testWidgets('create mode Save dispatches TimeTrackerEntryCreated',
      (tester) async {
    useLargeSurface(tester);
    initBloc();
    bloc.add(TimeTrackerLoaded());
    await tester.pumpWidget(wrap(
      TimeEntryDrawer(
        resolvedEntry: null,
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(timeRepo.all, hasLength(1));
    expect(timeRepo.all.first.status, TimeEntryStatus.stopped);
  });

  testWidgets('edit mode shows the entry comment and no info bar',
      (tester) async {
    useLargeSurface(tester);
    initBloc();
    final entry = buildEntry();
    await timeRepo.insert(entry);

    await tester.pumpWidget(wrap(
      TimeEntryDrawer(
        resolvedEntry: ResolvedTimeEntry(entry: entry),
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fixing the widget tests'), findsWidgets);
    expect(find.text('Not saved yet'), findsNothing);
  });

  testWidgets('delete flow: confirmation then TimeTrackerEntryDeleted',
      (tester) async {
    useLargeSurface(tester);
    initBloc();
    final entry = buildEntry();
    await timeRepo.insert(entry);

    await tester.pumpWidget(wrap(
      TimeEntryDrawer(
        resolvedEntry: ResolvedTimeEntry(entry: entry),
        isOpen: true,
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this time entry?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(timeRepo.all, isEmpty);
    expect(closed, isTrue);
  });

  testWidgets('delete flow: cancel dismisses the confirmation',
      (tester) async {
    useLargeSurface(tester);
    initBloc();
    final entry = buildEntry();
    await timeRepo.insert(entry);

    await tester.pumpWidget(wrap(
      TimeEntryDrawer(
        resolvedEntry: ResolvedTimeEntry(entry: entry),
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

    expect(find.text('Delete this time entry?'), findsNothing);
    expect(timeRepo.all, hasLength(1));
    expect(closed, isFalse);
  });
}
