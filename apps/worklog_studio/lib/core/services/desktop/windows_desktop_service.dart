import 'dart:async';

import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows implementation of [IDesktopPlatformService].
///
/// Delegates all tray icon and window lifecycle work to [WindowsTrayService],
/// which already owns that logic cleanly. This class is a thin adapter that
/// satisfies the shared interface so that call sites remain platform-agnostic.
///
/// This file contains **zero macOS-specific code**.
class WindowsDesktopService implements IDesktopPlatformService {
  WindowsDesktopService._();

  static final WindowsDesktopService _instance = WindowsDesktopService._();
  factory WindowsDesktopService() => _instance;

  final _navigationStreamController = StreamController<String>.broadcast();

  // ── IDesktopPlatformService ───────────────────────────────────────────────

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  @override
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
    await WindowsTrayService().init(bloc, resolver, projectTaskState);
  }

  /// Windows does not have a secondary popover engine — no-op.
  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {}

  /// Windows does not use a popover panel — no-op.
  @override
  Future<void> togglePopover() async {}

  /// Windows does not use a popover panel — no-op.
  @override
  Future<void> showPopover() async {}

  /// Windows does not use a popover panel — no-op.
  @override
  Future<void> hidePopover() async {}

  /// Windows has no IPC channel between two Flutter engines — no-op.
  @override
  void openMainWindowFromTray({String? route}) {}

  /// Windows has no follower process that dispatches actions — no-op.
  @override
  void dispatchAction(dynamic action) {}

  /// Windows always runs as the main window — returns `'main'` immediately.
  @override
  Future<String> resolveStartupRole() async => 'main';

  @override
  void dispose() {
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }
}
