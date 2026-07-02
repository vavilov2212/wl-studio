import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/managed_popover_window.dart';
import 'package:worklog_studio/core/services/desktop/native_activity_window.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows implementation of [IDesktopPlatformService].
///
/// Owns:
/// - A [ManagedPopoverWindow] for the mini-tracker popover (Flutter engine,
///   [desktop_multi_window]).
/// - A [NativeActivityWindow] for the activity comment prompt - a pure Win32
///   HWND + EDIT control with no secondary Flutter engine, eliminating the
///   EGL context management crashes (flutter/flutter#155685) that plagued the
///   original [desktop_multi_window]-based approach.
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

  String? _ownWindowId;
  String? _mainWindowId;
  bool _isPopover = false;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

  late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
    role: 'miniPanel',
    computeFrame: _computeFrameNearTray,
    getMainWindowId: () => _ownWindowId,
    alwaysOnTop: true,
  );

  late final NativeActivityWindow _nativeActivityWindow = NativeActivityWindow(
    onAccept: _onActivityAccept,
    onDismiss: _onActivityDismiss,
  );

  Timer? _prewarmWatchdog;
  static const _prewarmCheckInterval = Duration(seconds: 1);

  /// Debounces rapid back-to-back BLoC emissions (e.g. stop+start restart
  /// sequence) into a single broadcast so the mini panel Flutter engine does
  /// not receive two render triggers in quick succession. Two rapid renders on
  /// a cold EGL surface trigger flutter/flutter#155685 ACCESS_VIOLATION.
  Timer? _broadcastDebounce;
  static const _broadcastDebounceDelay = Duration(milliseconds: 80);

  /// Prevents concurrent `_broadcastSnapshotTo` calls from the async BLoC
  /// stream listener. The latest state that arrives while a broadcast is
  /// already in-flight is buffered and sent once the in-flight call completes.
  bool _broadcastInFlight = false;
  TimeTrackerBlocState? _pendingBroadcast;

  /// Prevents concurrent executions of [acceptCurrentComment]. The global
  /// hotkey can fire multiple times in rapid succession; each one would
  /// otherwise start a new accept cycle while the first is still running.
  bool _acceptInFlight = false;

  /// Exposed for unit tests only.
  @visibleForTesting
  String? get ownWindowIdForTesting => _ownWindowId;

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

    final ownController = await WindowController.fromCurrentEngine();
    _ownWindowId = ownController.windowId;
    await ownController.setWindowMethodHandler((call) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });

    _hotkeyService = HotkeyService(
      registrar: HotkeyManagerRegistrar(),
      getSetting: _settingsRepository.getString,
      setSetting: _settingsRepository.setString,
      onToggle: toggleActivityPrompt,
      onAccept: acceptCurrentComment,
      onDismiss: dismissCurrentComment,
    );
    await _hotkeyService!.init();
    if (GetIt.I.isRegistered<HotkeyService>()) {
      GetIt.I.unregister<HotkeyService>();
    }
    GetIt.I.registerSingleton<HotkeyService>(_hotkeyService!);

    _reminderService = ReminderService(
      bloc: bloc,
      getSetting: _settingsRepository.getString,
      isPopoverOpen: () => _nativeActivityWindow.isVisible,
      onFire: () => showActivityPrompt(source: ActivityPromptSource.reminder),
      onAutoDismiss: autoDismissCurrentComment,
    );
    await _reminderService!.init();
    if (GetIt.I.isRegistered<ReminderService>()) {
      GetIt.I.unregister<ReminderService>();
    }
    GetIt.I.registerSingleton<ReminderService>(_reminderService!);

    // Pre-warm the mini panel engine so the first open is instant.
    await _miniPanelWindow.ensureExists();
    _startPrewarmWatchdog();
  }

  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {
    _isPopover = true;
    _followerCubit = cubit;

    if (_ownWindowId != null) {
      await WindowController.fromWindowId(_ownWindowId!).setWindowMethodHandler((call) async {
        await _handleIncomingIpcMessage(call.method, call.arguments);
        return null;
      });
    }

    if (_mainWindowId != null) {
      try {
        await WindowController.fromWindowId(_mainWindowId!).invokeMethod(
          'miniReady',
          {'fromWindowId': _ownWindowId},
        );
      } catch (e) {
        debugPrint('WindowsDesktopService: handshake miniReady failed - $e');
      }
    }
  }

  @override
  Future<void> togglePopover() async {
    await _miniPanelWindow.reconcile();
    if (_miniPanelWindow.isVisible) {
      await hidePopover();
    } else {
      await showPopover();
    }
  }

  @override
  Future<void> showPopover() => _miniPanelWindow.show();

  /// Shows the activity comment prompt - topmost, but without taking OS
  /// keyboard focus unless [source] is [ActivityPromptSource.manual] and the
  /// caller explicitly calls [toggleActivityPrompt] which then calls
  /// [NativeActivityWindow.activate]. A no-op if nothing is currently
  /// being tracked.
  Future<void> showActivityPrompt({
    ActivityPromptSource source = ActivityPromptSource.manual,
  }) async {
    if (_leaderBloc?.state.isRunning != true) return;
    final currentEntry = _leaderBloc?.state.activeEntryOrNull;
    final currentComment = currentEntry?.comment ?? '';
    final frame = await _computeActivityPromptFrame();
    final autoDismissAt = source == ActivityPromptSource.reminder
        ? DateTime.now().add(ReminderService.autoDismissDelay)
        : null;
    _nativeActivityWindow.show(
      currentComment: currentComment,
      frame: frame,
      activate: false,
      autoDismissAt: autoDismissAt,
    );
  }

  /// Toggle hotkey target - three states:
  /// - hidden -> show and grab OS focus (user just asked for it);
  /// - visible but not focused (reminder put it there) -> grab focus and
  ///   cancel the auto-dismiss countdown;
  /// - visible and already focused -> close it.
  Future<void> toggleActivityPrompt() async {
    if (!_nativeActivityWindow.isVisible) {
      await showActivityPrompt();
      _nativeActivityWindow.activate();
      _reminderService?.cancelAutoDismiss();
    } else if (!_nativeActivityWindow.isForeground) {
      _nativeActivityWindow.activate();
      _reminderService?.cancelAutoDismiss();
      _nativeActivityWindow.cancelCountdown();
    } else {
      _reminderService?.cancelAutoDismiss();
      _nativeActivityWindow.hide();
    }
  }

  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(_prewarmCheckInterval, (_) async {
      await _miniPanelWindow.checkAndRewarm();
    });
  }

  @override
  Future<void> hidePopover() => _miniPanelWindow.hide();

  /// Reads the current comment text from the native EDIT control, hides the
  /// window, then restarts the timer if the comment changed.
  Future<void> acceptCurrentComment() async {
    if (_acceptInFlight) return;
    _acceptInFlight = true;
    _reminderService?.cancelAutoDismiss();
    try {
      final currentEntry = _leaderBloc?.state.activeEntryOrNull;
      final currentComment = currentEntry?.comment ?? '';
      final newComment = _nativeActivityWindow.getText();
      _nativeActivityWindow.hide();
      if (newComment != currentComment) {
        _handleFollowerAction(
          TimerAction(
            type: TimerActionType.start,
            projectId: currentEntry?.projectId,
            taskId: currentEntry?.taskId,
            comment: newComment,
          ),
        );
      }
    } finally {
      _acceptInFlight = false;
    }
  }

  /// Hides the activity prompt, discarding any unsaved edit.
  Future<void> dismissCurrentComment() async {
    _reminderService?.cancelAutoDismiss();
    _nativeActivityWindow.hide();
  }

  /// Auto-dismiss path: commits any unsaved edit (unlike [dismissCurrentComment]
  /// which discards), matching the intent of the old [MiniPanelCommand.
  /// autoDismissComment] behavior.
  Future<void> autoDismissCurrentComment() async {
    final currentEntry = _leaderBloc?.state.activeEntryOrNull;
    final currentComment = currentEntry?.comment ?? '';
    final newComment = _nativeActivityWindow.getText();
    _nativeActivityWindow.hide();
    if (newComment != currentComment) {
      _handleFollowerAction(
        TimerAction(
          type: TimerActionType.start,
          projectId: currentEntry?.projectId,
          taskId: currentEntry?.taskId,
          comment: newComment,
        ),
      );
    }
  }

  // Called by [NativeActivityWindow.onAccept] after the window is hidden.
  void _onActivityAccept(String comment) {
    _acceptInFlight = false;
    _reminderService?.cancelAutoDismiss();
    final currentEntry = _leaderBloc?.state.activeEntryOrNull;
    final currentComment = currentEntry?.comment ?? '';
    if (comment != currentComment) {
      _handleFollowerAction(
        TimerAction(
          type: TimerActionType.start,
          projectId: currentEntry?.projectId,
          taskId: currentEntry?.taskId,
          comment: comment,
        ),
      );
    }
  }

  // Called by [NativeActivityWindow.onDismiss] - window already hidden.
  void _onActivityDismiss() {
    _reminderService?.cancelAutoDismiss();
  }

  void _invokeMain(String method, [dynamic arguments]) {
    if (_mainWindowId == null) return;
    WindowController.fromWindowId(_mainWindowId!).invokeMethod(method, arguments);
  }

  @override
  void openMainWindowFromTray({String? route}) {
    if (!_isPopover) return;
    try {
      _invokeMain('openMainWindow', {'route': route});
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to open main window - $e');
    }
  }

  @override
  void dispatchAction(covariant dynamic action) {
    if (!_isPopover || action is! TimerAction) return;
    try {
      _invokeMain('dispatchAction', action.toJson());
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to dispatch action - $e');
    }
  }

  @override
  void requestActivityPrompt() {
    if (!_isPopover) return;
    try {
      _invokeMain('requestActivityPrompt', null);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to request activity prompt - $e');
    }
  }

  @override
  Future<String> resolveStartupRole(List<String> args) async {
    if (args.firstOrNull == 'multi_window' && args.length >= 2) {
      _ownWindowId = args[1];
      final payload = _parseFollowerPayload(args.length >= 3 ? args[2] : '{}');
      _mainWindowId = payload['mainWindowId'] as String?;
      return 'tray';
    }
    return 'main';
  }

  Map<String, dynamic> _parseFollowerPayload(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to parse follower payload - $e');
      return {};
    }
  }

  @override
  void dispose() {
    _prewarmWatchdog?.cancel();
    _broadcastDebounce?.cancel();
    _hotkeyService?.dispose();
    _reminderService?.dispose();
    _blocSubscription?.cancel();
    _nativeActivityWindow.dispose();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// `screen_retriever` queries the actual display directly, so popovers
  /// center/clamp against the real screen regardless of the main window size.
  Future<Size> _screenSize() async {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      return display.size;
    } catch (e) {
      debugPrint('WindowsDesktopService: getPrimaryDisplay failed, falling back to view size - $e');
      final view = PlatformDispatcher.instance.views.first;
      return view.physicalSize / view.devicePixelRatio;
    }
  }

  Future<Rect> _computeFrameNearTray() async {
    final rawBounds = await trayManager.getBounds();
    final screenSize = await _screenSize();
    final frame = computePopoverFrame(
      trayBounds: _sanitizeTrayBounds(rawBounds, screenSize),
      popoverSize: _popoverSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  Rect _sanitizeTrayBounds(Rect? rawBounds, Size screenSize) {
    if (rawBounds != null && rawBounds.width > 1 && rawBounds.height > 1) {
      return rawBounds;
    }
    return _fixedTrayAnchor(screenSize);
  }

  Rect _fixedTrayAnchor(Size screenSize) {
    return Rect.fromLTWH(screenSize.width - 32, screenSize.height - 32, 32, 32);
  }

  Future<Rect> _computeActivityPromptFrame() async {
    final screenSize = await _screenSize();
    final frame = computeActivityPromptFrame(
      screenSize: screenSize,
      promptSize: NativeActivityWindow.windowSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
  ) async {
    try {
      switch (method) {
        case 'miniReady':
          final fromWindowId = arguments is Map ? arguments['fromWindowId'] as String? : null;
          if (_miniPanelWindow.windowId == fromWindowId) {
            _miniPanelWindow.followerReady = true;
            if (_leaderBloc != null) {
              await _broadcastSnapshotTo(_miniPanelWindow, _leaderBloc!.state);
            }
          }

        case 'openMainWindow':
          await WindowsTrayService().restoreWindow();
          if (arguments is Map) {
            final route = arguments['route'] as String?;
            if (route != null) {
              _navigationStreamController.add(route);
            }
          }

        case 'requestActivityPrompt':
          await toggleActivityPrompt();

        case 'miniClosed':
          final fromWindowIdClosed = arguments is Map ? arguments['fromWindowId'] as String? : null;
          if (_miniPanelWindow.windowId == fromWindowIdClosed) {
            _miniPanelWindow.followerReady = false;
          }

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
        // flutter_bloc processes different event types concurrently, so
        // adding TimeTrackerStarted immediately would race against the
        // in-flight TimeTrackerStopped handler and see isRunning=true,
        // returning as a no-op. Instead, wait for the bloc to emit a
        // non-running state before dispatching the start.
        _leaderBloc!.add(TimeTrackerStopped());
        _leaderBloc!.stream
            .firstWhere((s) => !s.isRunning)
            .then((_) => _leaderBloc?.add(
                  TimeTrackerStarted(
                    projectId: action.projectId,
                    taskId: action.taskId,
                    comment: action.comment,
                  ),
                ))
            .catchError((_) {});
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

  void _broadcastSnapshotIfReady(TimeTrackerBlocState state) {
    _pendingBroadcast = state;
    _broadcastDebounce?.cancel();
    _broadcastDebounce = Timer(_broadcastDebounceDelay, _flushBroadcast);
  }

  Future<void> _flushBroadcast() async {
    if (_broadcastInFlight) return;
    _broadcastInFlight = true;
    try {
      while (_pendingBroadcast != null) {
        final toSend = _pendingBroadcast!;
        _pendingBroadcast = null;
        if (_miniPanelWindow.followerReady && _miniPanelWindow.windowId != null) {
          await _broadcastSnapshotTo(_miniPanelWindow, toSend);
        }
      }
    } finally {
      _broadcastInFlight = false;
    }
  }

  Future<void> _broadcastSnapshotTo(
    ManagedPopoverWindow window,
    TimeTrackerBlocState state,
  ) async {
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
      await WindowController.fromWindowId(window.windowId!).invokeMethod('broadcastSnapshot', jsonStr);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot to ${window.role} - $e');
    }
  }

  // ── Test seams ─────────────────────────────────────────────────────────────

  @visibleForTesting
  Rect fixedTrayAnchorForTesting(Size screenSize) => _fixedTrayAnchor(screenSize);

  @visibleForTesting
  Rect sanitizeTrayBoundsForTesting(Rect? rawBounds, Size screenSize) =>
      _sanitizeTrayBounds(rawBounds, screenSize);

  @visibleForTesting
  void setLeaderBlocForTesting(TimeTrackerBloc bloc) => _leaderBloc = bloc;

  @visibleForTesting
  void setFollowerCubitForTesting(MiniTrackerCubit cubit) =>
      _followerCubit = cubit;

  @visibleForTesting
  ManagedPopoverWindow get miniPanelWindowForTesting => _miniPanelWindow;

  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) =>
      _handleIncomingIpcMessage(method, arguments);
}
