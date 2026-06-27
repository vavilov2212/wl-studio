import 'dart:async';

import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Silent no-op implementation of [IDesktopPlatformService].
///
/// Used on non-desktop platforms (web, mobile) or any platform that does not
/// yet have a concrete implementation. All methods are safe to call and do
/// nothing.
class NoOpDesktopService implements IDesktopPlatformService {
  /// Constructor available to subclasses (e.g. test fakes) that need to
  /// extend this no-op base without sharing its singleton instance.
  NoOpDesktopService.base();

  static final NoOpDesktopService _instance = NoOpDesktopService.base();

  /// Returns the shared singleton instance for production use.
  factory NoOpDesktopService() => _instance;

  final _navigationStreamController = StreamController<String>.broadcast();

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  @override
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {}

  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {}

  @override
  Future<void> togglePopover() async {}

  @override
  Future<void> showPopover() async {}

  @override
  Future<void> hidePopover() async {}

  @override
  void openMainWindowFromTray({String? route}) {}

  @override
  void dispatchAction(dynamic action) {}

  @override
  Future<String> resolveStartupRole(List<String> args) async => 'main';

  @override
  void dispose() {
    _navigationStreamController.close();
  }
}
