import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l/l.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_scope.dart';
import 'package:worklog_studio/feature/app/layout/app_shell.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_panel.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_panel_command_bus.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/history/bloc/history_bloc.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import 'package:worklog_studio/feature/projects/bloc/projects_bloc.dart';
import 'package:worklog_studio/feature/tasks/bloc/tasks_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/ui_kit/src/drawer/drawer_service.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';

import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_navigator_observer.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// ── Popover / mini-panel app (macOS tray engine only) ────────────────────────

class MiniApp extends StatelessWidget {
  const MiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MiniPanelCommandBus>(
          create: (_) => MiniPanelCommandBus(),
          dispose: (_, bus) => bus.dispose(),
        ),
        BlocProvider<MiniTrackerCubit>(
          create: (context) {
            final cubit = MiniTrackerCubit();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              DesktopServiceRegistry.instance.initFollower(cubit);
            });
            return cubit;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appEnvironment.config.lightTheme,
        darkTheme: appEnvironment.config.lightTheme,
        home: const Scaffold(
          // macOS NSPanel popover does not support DWM/layered transparency
          // the way the main window does - use MiniPanel's own card color
          // for an opaque background.
          backgroundColor: Color(0xFFf8fafc),
          body: MiniPanel(),
        ),
      ),
    );
  }
}

// ── Main application ──────────────────────────────────────────────────────────

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppNavigationController>(
          create: (_) => AppNavigationController(),
        ),
        ChangeNotifierProvider(create: (_) => DrawerHostController()),
        BlocProvider<HistoryBloc>(create: (_) => HistoryBloc()),
        BlocProvider<ReportsBloc>(create: (_) => ReportsBloc()),
        BlocProvider<TasksBloc>(create: (_) => TasksBloc()),
        BlocProvider<ProjectsBloc>(create: (_) => ProjectsBloc()),
        BlocProvider<TimeTrackerBloc>(
          create: (_) {
            final service = TimeTrackerService(
              repository: getIt<TimeEntryRepository>(),
              clock: SystemClock(),
            );

            final IdleMonitor idleMonitor = getIt<IdleMonitor>();

            final bloc = TimeTrackerBloc(
              service: service,
              idleMonitor: idleMonitor,
            )..add(TimeTrackerLoaded());
            return bloc;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => ProjectTaskState(
            projectRepository: getIt<ProjectRepository>(),
            taskRepository: getIt<TaskRepository>(),
            clock: SystemClock(),
          ),
        ),
        BlocProvider<TrackerPanelCubit>(
          create: (context) => TrackerPanelCubit(
            timeTrackerBloc: context.read<TimeTrackerBloc>(),
            projectTaskState: context.read<ProjectTaskState>(),
          ),
        ),
        ChangeNotifierProxyProvider2<
          TimeTrackerBloc,
          ProjectTaskState,
          EntityResolver
        >(
          create: (context) => EntityResolver(
            bloc: context.read<TimeTrackerBloc>(),
            projectTaskState: context.read<ProjectTaskState>(),
          ),
          update: (context, bloc, projectTaskState, resolver) {
            return resolver!..update(bloc, projectTaskState);
          },
        ),
      ],
      child: const _DesktopInitializationWrapper(
        child: _AppMaterialApp(),
      ),
    );
  }
}

// ── Desktop service initialisation ───────────────────────────────────────────

class _DesktopInitializationWrapper extends StatefulWidget {
  final Widget child;
  const _DesktopInitializationWrapper({required this.child});

  @override
  State<_DesktopInitializationWrapper> createState() =>
      _DesktopInitializationWrapperState();
}

class _DesktopInitializationWrapperState
    extends State<_DesktopInitializationWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<TimeTrackerBloc>();
      final resolver = context.read<EntityResolver>();
      final projectTaskState = context.read<ProjectTaskState>();
      // Platform-specific logic is fully encapsulated inside the service.
      DesktopServiceRegistry.instance.initLeader(bloc, resolver, projectTaskState);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Material app shell ────────────────────────────────────────────────────────

class _AppMaterialApp extends StatelessWidget {
  const _AppMaterialApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appEnvironment.config.flavor.appTitle,
      showPerformanceOverlay:
          _getDebugConfig(context)?.showPerformanceOverlay ?? false,
      debugShowMaterialGrid:
          _getDebugConfig(context)?.debugShowMaterialGrid ?? false,
      checkerboardRasterCacheImages:
          _getDebugConfig(context)?.checkerboardRasterCacheImages ?? false,
      checkerboardOffscreenLayers:
          _getDebugConfig(context)?.checkerboardOffscreenLayers ?? false,
      showSemanticsDebugger:
          _getDebugConfig(context)?.showSemanticsDebugger ?? false,
      debugShowCheckedModeBanner:
          _getDebugConfig(context)?.debugShowCheckedModeBanner ?? false,
      theme: appEnvironment.config.lightTheme,
      darkTheme: appEnvironment.config.lightTheme,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [AppBarNavigatorObserver()],
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final overlay = rootNavigatorKey.currentState?.overlay;
            if (overlay != null) {
              GetIt.I<DrawerService>().attachRoot(overlay);
            }
          } catch (e, s) {
            l.e(e, s);
          }
        });

        return AppBarScope(child: child!);
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const AppShell());
      },
    );
  }

  DebugOptions? _getDebugConfig(BuildContext context) =>
      appEnvironment.config.debugOptions;
}
