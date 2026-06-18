import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// macOS implementation of [IDesktopPlatformService].
///
/// Manages the native tray icon, the popover panel (mini tracker), and the
/// bidirectional IPC channel between the main and popover Flutter engines.
///
/// This file contains **zero Windows-specific code**. All macOS-native Swift
/// calls are routed through [_channel] exactly as they were before the
/// refactor — behaviour is unchanged.
class MacOSDesktopService implements IDesktopPlatformService {
  MacOSDesktopService._();

  static final MacOSDesktopService _instance = MacOSDesktopService._();
  factory MacOSDesktopService() => _instance;

  // ── IPC channel (mirrors native IpcRouter.swift) ─────────────────────────

  static const _channel = MethodChannel('worklog_studio/ipc');

  // ── Internal state ────────────────────────────────────────────────────────

  final _navigationStreamController = StreamController<String>.broadcast();

  TimeTrackerBloc? _leaderBloc;
  StreamSubscription<TimeTrackerBlocState>? _blocSubscription;
  EntityResolver? _resolver;
  ProjectTaskState? _projectTaskState;

  MiniTrackerCubit? _followerCubit;

  bool _isInitialized = false;
  bool _isPopover = false;
  bool _followerReady = false;

  // ── IDesktopPlatformService ───────────────────────────────────────────────

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  @override
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
    if (_isInitialized) return;

    _isPopover = false;
    _leaderBloc = bloc;
    _resolver = resolver;
    _projectTaskState = projectTaskState;

    _blocSubscription = bloc.stream.listen((state) {
      _updateTray(state);
      _broadcastSnapshotIfReady(state);
    });

    _projectTaskState?.addListener(() {
      if (_leaderBloc != null) {
        _broadcastSnapshotIfReady(_leaderBloc!.state);
      }
    });

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessage') {
        _handleIncomingIpcMessage(call.arguments);
      }
    });

    _isInitialized = true;
    _updateTray(bloc.state);
  }

  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {
    if (_isInitialized) return;

    _isPopover = true;
    _followerCubit = cubit;

    try {
      await _channel.invokeMethod('subscribe', {'topic': 'timer_snapshot'});
    } catch (e) {
      debugPrint('MacOSDesktopService: failed to subscribe topic — $e');
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessage') {
        _handleIncomingIpcMessage(call.arguments);
      }
    });

    _isInitialized = true;

    try {
      await _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'miniReady',
        'payload': null,
      });
    } catch (e) {
      debugPrint('MacOSDesktopService: handshake miniReady failed — $e');
    }
  }

  @override
  Future<void> togglePopover() async {
    await _channel.invokeMethod('toggle');
  }

  @override
  Future<void> showPopover() async {
    await _channel.invokeMethod('show');
  }

  @override
  Future<void> hidePopover() async {
    try {
      await _channel.invokeMethod('hide');
      if (_isPopover) {
        await _channel.invokeMethod('sendMessage', {
          'target': 'main',
          'method': 'miniClosed',
          'payload': null,
        });
      }
    } catch (e) {
      debugPrint('MacOSDesktopService: error closing panel — $e');
    }
  }

  @override
  void openMainWindowFromTray({String? route}) {
    if (!_isPopover) return;
    try {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'openMainWindow',
        'payload': {'route': route},
      });
    } catch (e) {
      debugPrint('MacOSDesktopService: failed to open main window — $e');
    }
  }

  @override
  void dispatchAction(TimerAction action) {
    if (!_isPopover) return;
    try {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'dispatchAction',
        'payload': action.toJson(),
      });
    } catch (e) {
      debugPrint('MacOSDesktopService: failed to dispatch action — $e');
    }
  }

  @override
  Future<String> resolveStartupRole() async {
    try {
      final engineInfo = await _channel
          .invokeMapMethod<String, dynamic>('getEngineInfo')
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () {
              debugPrint('MacOSDesktopService: getEngineInfo timed out');
              return {'role': 'main'};
            },
          );
      return engineInfo?['role'] as String? ?? 'main';
    } catch (e) {
      debugPrint('MacOSDesktopService: failed to fetch engine info — $e');
      return 'main';
    }
  }

  @override
  void dispose() {
    _blocSubscription?.cancel();
    if (_isPopover) {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'miniClosed',
        'payload': null,
      });
    }
    _channel.invokeMethod('deregister');
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _handleIncomingIpcMessage(dynamic arguments) {
    if (arguments == null) return;
    try {
      final argsMap = Map<String, dynamic>.from(arguments as Map);
      final method = argsMap['method'] as String?;
      final payload = argsMap['payload'];

      switch (method) {
        case 'miniReady':
          _followerReady = true;
          if (_leaderBloc != null) {
            _broadcastSnapshotIfReady(_leaderBloc!.state);
          }

        case 'openMainWindow':
          _channel.invokeMethod('focusMainWindow');
          if (payload != null && payload is Map) {
            final route = payload['route'] as String?;
            if (route != null) {
              _navigationStreamController.add(route);
            }
          }

        case 'miniClosed':
        case 'miniClosed_native':
          _followerReady = false;

        case 'dispatchAction':
          if (payload != null) {
            final actionMap = Map<String, dynamic>.from(payload as Map);
            final action = TimerAction.fromJson(actionMap);
            _handleFollowerAction(action);
          }

        case 'broadcastSnapshot':
          if (payload != null) {
            final snapshotMap = Map<String, dynamic>.from(
              jsonDecode(payload as String),
            );
            final snapshot = TimerSnapshot.fromJson(snapshotMap);
            _followerCubit?.updateFromSnapshot(snapshot);
          }
      }
    } catch (e) {
      debugPrint('MacOSDesktopService: IPC message handling failed — $e');
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
    }
  }

  void _broadcastSnapshotIfReady(TimeTrackerBlocState state) {
    if (!_followerReady) return;

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
      _channel.invokeMethod('sendMessage', {
        'target': 'topic:timer_snapshot',
        'method': 'broadcastSnapshot',
        'payload': jsonStr,
      });
    } catch (e) {
      debugPrint('MacOSDesktopService: failed to broadcast snapshot — $e');
    }
  }

  void _updateTray(TimeTrackerBlocState state) {
    final isRunning = state.isRunning;
    final activeEntry = state.activeEntryOrNull;
    final resolver = _resolver;

    String title = '';
    if (isRunning && activeEntry != null && resolver != null) {
      final projectName = resolver.getProjectName(activeEntry.projectId);
      final taskName = resolver.getTaskName(activeEntry.taskId);
      title = '$projectName - $taskName';
    }

    final isDev = appEnvironment.config.flavor == Flavor.development;
    final iconName = isRunning
        ? (isDev ? 'AppIconRunningDev' : 'AppIconRunning')
        : 'AppIcon';

    try {
      _channel.invokeMethod('updateTray', {'title': title, 'icon': iconName});
    } on MissingPluginException {
      debugPrint(
        'MacOSDesktopService: MissingPluginException — channel not ready for updateTray',
      );
    } catch (e) {
      debugPrint('MacOSDesktopService: error calling updateTray — $e');
    }
  }
}
