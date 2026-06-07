import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';

class DesktopService {
  static final DesktopService _instance = DesktopService._internal();
  factory DesktopService() => _instance;
  DesktopService._internal();

  static const _channel = MethodChannel('worklog_studio/ipc');

  final _navigationStreamController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationStreamController.stream;

  TimeTrackerBloc? _leaderBloc;
  StreamSubscription<TimeTrackerBlocState>? _blocSubscription;
  EntityResolver? _resolver;
  ProjectTaskState? _projectTaskState;

  MiniTrackerCubit? _followerCubit;

  bool _isInitialized = false;
  bool _isPopover = false;

  // We no longer strictly need _followerReady for broadcasting if we let subscriptions handle it natively,
  // but keeping it ensures we don't spam IPC when no tray is awake to render.
  bool _followerReady = false;

  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  ) async {
    // ── Windows: delegate entirely to WindowsTrayService ──
    if (Platform.isWindows) {
      await WindowsTrayService().init(bloc, resolver, projectTaskState);
      return;
    }

    if (!Platform.isMacOS) return;
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

  Future<void> initFollower(MiniTrackerCubit cubit) async {
    if (!Platform.isMacOS) return;
    if (_isInitialized) return;

    _isPopover = true;
    _followerCubit = cubit;

    // Subscribe to topics
    try {
      await _channel.invokeMethod('subscribe', {'topic': 'timer_snapshot'});
    } catch (e) {
      debugPrint("Failed to subscribe topic: $e");
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessage') {
        _handleIncomingIpcMessage(call.arguments);
      }
    });

    _isInitialized = true;

    // Handshake back to main via role targeting
    try {
      await _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'miniReady',
        'payload': null,
      });
    } catch (e) {
      debugPrint("Handshake miniReady failed: $e");
    }
  }

  void _handleIncomingIpcMessage(dynamic arguments) {
    if (arguments == null) return;
    try {
      final argsMap = Map<String, dynamic>.from(arguments as Map);
      final method = argsMap['method'] as String?;
      final payload = argsMap['payload'];

      if (method == 'miniReady') {
        _followerReady = true;
        if (_leaderBloc != null) {
          _broadcastSnapshotIfReady(_leaderBloc!.state);
        }
      } else if (method == 'openMainWindow') {
        _channel.invokeMethod('focusMainWindow');
        if (payload != null && payload is Map) {
          final route = payload['route'] as String?;
          if (route != null) {
            _navigationStreamController.add(route);
          }
        }
      } else if (method == 'miniClosed') {
        _followerReady = false;
      } else if (method == 'miniClosed_native') {
        _followerReady = false; // System triggered collapse
      } else if (method == 'dispatchAction') {
        if (payload != null) {
          final actionMap = Map<String, dynamic>.from(payload as Map);
          final action = TimerAction.fromJson(actionMap);
          _handleFollowerAction(action);
        }
      } else if (method == 'broadcastSnapshot') {
        if (payload != null) {
          final snapshotMap = Map<String, dynamic>.from(
            jsonDecode(payload as String),
          );
          final snapshot = TimerSnapshot.fromJson(snapshotMap);
          _followerCubit?.updateFromSnapshot(snapshot);
        }
      }
    } catch (e) {
      debugPrint("IPC onMessage handling failed: $e");
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

  void openMainWindowFromTray({String? route}) {
    if (!_isPopover) return;
    try {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'openMainWindow',
        'payload': {'route': route},
      });
    } catch (e) {
      debugPrint("Failed to open main window: $e");
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
      // Broadcast via topic
      _channel.invokeMethod('sendMessage', {
        'target': 'topic:timer_snapshot',
        'method': 'broadcastSnapshot',
        'payload': jsonStr,
      });
    } catch (e) {
      debugPrint("Failed to broadcast snapshot: $e");
    }
  }

  void dispatchAction(TimerAction action) {
    if (!_isPopover) return; // Only follower dispatches
    try {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'dispatchAction',
        'payload': action.toJson(),
      });
    } catch (e) {
      debugPrint("Failed to dispatch action: $e");
    }
  }

  void _updateTray(TimeTrackerBlocState state) {
    final isRunning = state.isRunning;
    final activeEntry = state.activeEntryOrNull;
    final resolver = _resolver;

    String title = "";
    if (isRunning && activeEntry != null && resolver != null) {
      final projectName = resolver.getProjectName(activeEntry.projectId);
      final taskName = resolver.getTaskName(activeEntry.taskId);
      title = "$projectName - $taskName";
    }

    final iconName = isRunning ? "AppIconRunning" : "AppIcon";

    try {
      // Native commands skip prefix intentionally as handled inside IpcRouter's default block
      _channel.invokeMethod('updateTray', {'title': title, 'icon': iconName});
    } on MissingPluginException {
      debugPrint(
        'MissingPluginException: Channel not ready yet for updateTray',
      );
    } catch (e) {
      debugPrint('Error calling updateTray: $e');
    }
  }

  Future<void> togglePopover() async {
    await _channel.invokeMethod('toggle');
  }

  Future<void> showPopover() async {
    await _channel.invokeMethod('show');
  }

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
      debugPrint('Error closing panel: $e');
    }
  }

  void dispose() {
    _blocSubscription?.cancel();
    if (_isPopover) {
      _channel.invokeMethod('sendMessage', {
        'target': 'main',
        'method': 'miniClosed',
        'payload': null,
      });
    }
    _channel.invokeMethod('deregister'); // Cleanup from router registry
  }
}
