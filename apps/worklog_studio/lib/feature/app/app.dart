import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l/l.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/data/sqlite/sqlite_time_entry_repository.dart';
import 'package:worklog_studio/data/sqlite/sqlite_project_repository.dart';
import 'package:worklog_studio/data/sqlite/sqlite_task_repository.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_scope.dart';
import 'package:worklog_studio/feature/app/layout/app_shell.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_panel.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/ui_kit/src/drawer/drawer_service.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service.dart';

import 'layout/app_bar/app_bar_navigator_observer.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MiniApp extends StatelessWidget {
  const MiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MiniTrackerCubit>(
      create: (context) {
        final cubit = MiniTrackerCubit();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DesktopService().initFollower(cubit);
        });
        return cubit;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appEnvironment.config.lightTheme,
        darkTheme: appEnvironment.config.lightTheme,
        home: const Scaffold(
          backgroundColor: Colors.transparent,
          body: MiniPanel(),
        ),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  final String? initialRoute;
  const MainApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider<TimeTrackerBloc>(
          create: (_) {
            final clock = SystemClock();
            final repository = SqliteTimeEntryRepository();
            final service = TimeTrackerService(
              repository: repository,
              clock: clock,
            );

            IdleMonitor? idleMonitor;
            try {
              idleMonitor = getIt<IdleMonitor>();
            } catch (_) {}

            final bloc = TimeTrackerBloc(
              service: service,
              idleMonitor: idleMonitor,
            )..add(TimeTrackerLoaded());
            return bloc;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final clock = SystemClock();
            final projectRepo = SqliteProjectRepository();
            final taskRepo = SqliteTaskRepository();
            return ProjectTaskState(
              projectRepository: projectRepo,
              taskRepository: taskRepo,
              clock: clock,
            );
          },
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
      child: _DesktopInitializationWrapper(
        child: _AppMaterialApp(initialRoute: initialRoute),
      ),
    );
  }
}

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
      DesktopService().initLeader(bloc, resolver, projectTaskState);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppMaterialApp extends StatelessWidget {
  final String? initialRoute;
  const _AppMaterialApp({this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: initialRoute ?? '/',
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
