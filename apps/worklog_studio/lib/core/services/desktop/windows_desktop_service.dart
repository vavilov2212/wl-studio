import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows implementation of [IDesktopPlatformService].
///
/// Owns a secondary `desktop_multi_window` engine that hosts the mini
/// tracker popover, mirroring the role [MacOSDesktopService] plays for its
/// native NSPanel popover - but using the `desktop_multi_window` plugin's
/// own inter-window channel instead of a hand-rolled native `MethodChannel`.
///
/// This file contains zero macOS-specific code.
class WindowsDesktopService implements IDesktopPlatformService {
  WindowsDesktopService._();

  static final WindowsDesktopService _instance = WindowsDesktopService._();
  factory WindowsDesktopService() => _instance;

  static const _popoverSize = Size(360, 520);

  final _navigationStreamController = StreamController<String>.broadcast();

  TimeTrackerBloc? _leaderBloc;
  ProjectTaskState? _projectTaskState;
  StreamSubscription<TimeTrackerBlocState>? _blocSubscription;

  MiniTrackerCubit? _followerCubit;

  int? _ownWindowId;
  int? _popoverWindowId;
  bool _isPopoverVisible = false;
  bool _isPopover = false;
  bool _followerReady = false;

  /// Exposed for unit tests only.
  @visibleForTesting
  int? get ownWindowIdForTesting => _ownWindowId;

  // ── IDesktopPlatformService ───────────────────────────────────────────────

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  @override
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
    _leaderBloc = bloc;
    _projectTaskState = projectTaskState;

    await WindowsTrayService().init(
      bloc,
      resolver,
      projectTaskState,
      onTrayClick: togglePopover,
    );

    _blocSubscription = bloc.stream.listen((state) {
      _broadcastSnapshotIfReady(state);
    });

    projectTaskState.addListener(() {
      if (_leaderBloc != null) {
        _broadcastSnapshotIfReady(_leaderBloc!.state);
      }
    });

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });
  }

  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {
    _isPopover = true;
    _followerCubit = cubit;

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });

    try {
      await DesktopMultiWindow.invokeMethod(0, 'miniReady', null);
    } catch (e) {
      debugPrint('WindowsDesktopService: handshake miniReady failed - $e');
    }
  }

  @override
  Future<void> togglePopover() async {
    // _isPopoverVisible only ever gets corrected by our own hidePopover()
    // call. If the user destroyed the popover via its native close button
    // instead, _isPopoverVisible is left stuck at true even though nothing
    // is on screen - reconcile against the plugin's live-window list before
    // deciding which branch to take, or the first click after a close-via-X
    // would silently call hidePopover() on an already-dead window (a no-op)
    // instead of actually reopening it.
    await _reconcilePopoverState();
    if (_isPopoverVisible) {
      await hidePopover();
    } else {
      await showPopover();
    }
  }

  @override
  Future<void> showPopover() async {
    // See togglePopover()'s comment: the popover's native window has a
    // titlebar close button that the desktop_multi_window plugin gives no
    // way to suppress or intercept on Windows, so the user can destroy the
    // underlying window/engine at any time outside our control. Reusing a
    // destroyed window id is a silent no-op on the native side, which would
    // otherwise leave the popover permanently unopenable.
    await _reconcilePopoverState();

    final wasNewWindow = _popoverWindowId == null;
    try {
      final frame = await _computeFrame();
      if (_popoverWindowId == null) {
        final window = await DesktopMultiWindow.createWindow(jsonEncode({}));
        _popoverWindowId = window.windowId;
        await window.setFrame(frame);
        await window.show();
      } else {
        final controller = WindowController.fromWindowId(_popoverWindowId!);
        await controller.setFrame(frame);
        await controller.show();
      }
      _isPopoverVisible = true;
    } catch (e) {
      debugPrint('WindowsDesktopService: error showing popover - $e');
      if (wasNewWindow) {
        _popoverWindowId = null;
      }
    }
  }

  Future<void> _reconcilePopoverState() async {
    if (_popoverWindowId != null && !await _isPopoverWindowAlive()) {
      _popoverWindowId = null;
      _isPopoverVisible = false;
    }
  }

  Future<bool> _isPopoverWindowAlive() async {
    try {
      final aliveIds = await DesktopMultiWindow.getAllSubWindowIds();
      return aliveIds.contains(_popoverWindowId);
    } catch (e) {
      debugPrint('WindowsDesktopService: error checking popover liveness - $e');
      return false;
    }
  }

  @override
  Future<void> hidePopover() async {
    if (_popoverWindowId != null) {
      try {
        await WindowController.fromWindowId(_popoverWindowId!).hide();
        _followerReady = false;
      } catch (e) {
        debugPrint('WindowsDesktopService: error hiding popover - $e');
      }
    }
    _isPopoverVisible = false;
  }

  @override
  void openMainWindowFromTray({String? route}) {
    if (!_isPopover) return;
    try {
      DesktopMultiWindow.invokeMethod(0, 'openMainWindow', {'route': route});
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to open main window - $e');
    }
  }

  @override
  void dispatchAction(covariant dynamic action) {
    if (!_isPopover || action is! TimerAction) return;
    try {
      DesktopMultiWindow.invokeMethod(0, 'dispatchAction', action.toJson());
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to dispatch action - $e');
    }
  }

  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = int.tryParse(args[1]);
      return 'tray';
    }
    return 'main';
  }

  @override
  void dispose() {
    _blocSubscription?.cancel();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Rect> _computeFrame() async {
    final trayBounds =
        await trayManager.getBounds() ?? const Rect.fromLTWH(0, 0, 32, 32);
    return computePopoverFrame(
      trayBounds: trayBounds,
      popoverSize: _popoverSize,
    );
  }

  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
  ) async {
    try {
      switch (method) {
        case 'miniReady':
          _followerReady = true;
          if (_leaderBloc != null) {
            await _broadcastSnapshotIfReady(_leaderBloc!.state);
          }

        case 'openMainWindow':
          await WindowsTrayService().restoreWindow();
          if (arguments is Map) {
            final route = arguments['route'] as String?;
            if (route != null) {
              _navigationStreamController.add(route);
            }
          }

        case 'miniClosed':
          _followerReady = false;

        case 'dispatchAction':
          if (arguments != null) {
            final actionMap = Map<String, dynamic>.from(arguments as Map);
            final action = TimerAction.fromJson(actionMap);
            _handleFollowerAction(action);
          }

        case 'broadcastSnapshot':
          if (arguments != null) {
            final snapshotMap = Map<String, dynamic>.from(
              jsonDecode(arguments as String),
            );
            final snapshot = TimerSnapshot.fromJson(snapshotMap);
            _followerCubit?.updateFromSnapshot(snapshot);
          }
      }
    } catch (e) {
      debugPrint('WindowsDesktopService: IPC message handling failed - $e');
    }
  }

  void _handleFollowerAction(TimerAction action) {
    if (_leaderBloc == null) return;

    final isCurrentlyRunning = _leaderBloc!.state.isRunning;

    if (action.type == TimerActionType.start) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
        Future.delayed(const Duration(milliseconds: 200), () {
          _leaderBloc!.add(
            TimeTrackerStarted(
              projectId: action.projectId,
              taskId: action.taskId,
              comment: action.comment,
            ),
          );
        });
      } else {
        _leaderBloc!.add(
          TimeTrackerStarted(
            projectId: action.projectId,
            taskId: action.taskId,
            comment: action.comment,
          ),
        );
      }
    } else if (action.type == TimerActionType.stop) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
      }
    } else if (action.type == TimerActionType.updateComment) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerActiveEntryUpdated(comment: action.comment));
      }
    }
  }

  Future<void> _broadcastSnapshotIfReady(TimeTrackerBlocState state) async {
    if (!_followerReady || _popoverWindowId == null) return;

    final snapshot = TimerSnapshot(
      isRunning: state.isRunning,
      activeEntry: state.activeEntryOrNull,
      entries: state.allEntries,
      tasks: _projectTaskState?.tasks ?? [],
      projects: _projectTaskState?.projects ?? [],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final jsonStr = jsonEncode(snapshot.toJson());
      await DesktopMultiWindow.invokeMethod(
        _popoverWindowId!,
        'broadcastSnapshot',
        jsonStr,
      );
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot - $e');
    }
  }

  // ── Test seams ─────────────────────────────────────────────────────────────

  @visibleForTesting
  void setLeaderBlocForTesting(TimeTrackerBloc bloc) => _leaderBloc = bloc;

  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) =>
      _handleIncomingIpcMessage(method, arguments);
}
