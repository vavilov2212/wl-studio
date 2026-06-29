import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/managed_popover_window.dart';
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
  bool _isPopover = false;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

  late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
    role: 'miniPanel',
    computeFrame: _computeFrameNearTray,
  );

  Timer? _prewarmWatchdog;
  static const _prewarmCheckInterval = Duration(seconds: 1);

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

    _hotkeyService = HotkeyService(
      registrar: HotkeyManagerRegistrar(),
      getSetting: _settingsRepository.getString,
      setSetting: _settingsRepository.setString,
      onToggle: togglePopover,
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
      isPopoverOpen: () => _miniPanelWindow.isVisible,
      onFire: () async {
        await showPopoverNearScreenCorner();
        await requestFocusComment();
      },
      onAutoDismiss: autoDismissCurrentComment,
    );
    await _reminderService!.init();
    if (GetIt.I.isRegistered<ReminderService>()) {
      GetIt.I.unregister<ReminderService>();
    }
    GetIt.I.registerSingleton<ReminderService>(_reminderService!);

    // Boot the popover engine now, hidden, so the *first* open is instant
    // instead of paying the multi-second Firebase/DB cold-boot cost the
    // moment the user actually asks for it.
    await _miniPanelWindow.ensureExists();
    _startPrewarmWatchdog();
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
    await _miniPanelWindow.reconcile();
    if (_miniPanelWindow.isVisible) {
      await hidePopover();
    } else {
      await showPopover();
      await requestFocusComment();
    }
  }

  @override
  Future<void> showPopover() => _miniPanelWindow.show();

  /// Used by [ReminderService], which fires unattended on a timer rather
  /// than from a direct user click - there is no extra context here that
  /// would make a live tray-icon lookup any more trustworthy than usual,
  /// so this always anchors to the fixed screen-corner position instead
  /// of the icon-relative one [showPopover] uses.
  Future<void> showPopoverNearScreenCorner() =>
      _miniPanelWindow.show(frameOverride: _computeFrameFixedCorner);

  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(
      _prewarmCheckInterval,
      (_) => _miniPanelWindow.checkAndRewarm(),
    );
  }

  @override
  Future<void> hidePopover() => _miniPanelWindow.hide();

  bool _pendingFocusComment = false;

  /// Asks the follower (popover) engine to put the comment field into edit
  /// mode and request keyboard focus. If the popover isn't ready yet (e.g.
  /// it was just created and hasn't sent `miniReady`), the request is
  /// deferred and replayed once `miniReady` arrives - see
  /// [_handleIncomingIpcMessage]'s `'miniReady'` case.
  Future<void> requestFocusComment() async {
    if (_miniPanelWindow.followerReady && _miniPanelWindow.windowId != null) {
      await _invokeFollower('focusComment', null);
    } else {
      _pendingFocusComment = true;
    }
  }

  /// Tells the follower to commit its current comment edit (if any), then
  /// hides the popover. The actual `TimerAction.updateComment` dispatch (if
  /// the comment changed) arrives asynchronously afterward over the existing
  /// `dispatchAction` channel - the popover engine stays alive while hidden,
  /// so this is safe even though we don't wait for it here.
  Future<void> acceptCurrentComment() async {
    await _invokeFollower('acceptComment', null);
    await hidePopover();
  }

  /// Tells the follower to discard its current comment edit (reverting the
  /// field to the last persisted value), then hides the popover.
  Future<void> dismissCurrentComment() async {
    await _invokeFollower('dismissComment', null);
    await hidePopover();
  }

  /// Tells the follower the reminder popover timed out automatically (as
  /// opposed to a user-initiated dismiss). Unlike [dismissCurrentComment],
  /// this preserves any unsaved comment edit by committing it instead of
  /// discarding it - see [MiniPanelCommand.autoDismissComment].
  Future<void> autoDismissCurrentComment() async {
    await _invokeFollower('autoDismissComment', null);
    await hidePopover();
  }

  Future<void> _invokeFollower(String method, dynamic arguments) async {
    if (_miniPanelWindow.windowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(_miniPanelWindow.windowId!, method, arguments);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to invoke follower "$method" - $e');
    }
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
      return _followerRole(args) == 'activity' ? 'tray:activity' : 'tray';
    }
    return 'main';
  }

  /// Reads the `role` field out of `createWindow()`'s payload (`args[2]`,
  /// per `desktop_multi_window`'s documented argument list), defaulting to
  /// `'miniPanel'` for a missing, empty, or malformed payload.
  String _followerRole(List<String> args) {
    if (args.length < 3) return 'miniPanel';
    try {
      final payload = jsonDecode(args[2]) as Map<String, dynamic>;
      return payload['role'] as String? ?? 'miniPanel';
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to parse follower role payload - $e');
      return 'miniPanel';
    }
  }

  @override
  void dispose() {
    _prewarmWatchdog?.cancel();
    _hotkeyService?.dispose();
    _reminderService?.dispose();
    _blocSubscription?.cancel();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Used by [showPopover] - the user just clicked the tray icon or
  /// pressed the toggle hotkey, so a live tray-icon position is worth
  /// asking for. Falls back to the fixed corner (see
  /// [_computeFrameFixedCorner]) when the live query looks degenerate.
  Future<Rect> _computeFrameNearTray() async {
    final rawBounds = await trayManager.getBounds();
    final view = PlatformDispatcher.instance.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    final frame = computePopoverFrame(
      trayBounds: _sanitizeTrayBounds(rawBounds, screenSize),
      popoverSize: _popoverSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  /// `trayManager.getBounds()` only catches the fully-degenerate
  /// (near-zero) case - a plausible-looking but still wrong rect (wrong
  /// X, or wrong Y entirely off the taskbar) slips through this check.
  /// `_computeFrameNearTray` is only used for direct user actions
  /// (tray click, toggle hotkey), where a bad reading is an occasional
  /// annoyance the user can immediately retry. [showPopoverNearScreenCorner]
  /// (used by the unattended reminder) skips the live query altogether.
  Rect _sanitizeTrayBounds(Rect? rawBounds, Size screenSize) {
    if (rawBounds != null && rawBounds.width > 1 && rawBounds.height > 1) {
      return rawBounds;
    }
    return _fixedTrayAnchor(screenSize);
  }

  /// Used by [showPopoverNearScreenCorner] - fired unattended by
  /// [ReminderService], where there is no live tray-icon position worth
  /// trusting any more than usual, so this skips `trayManager.getBounds()`
  /// entirely and always anchors to a fixed synthetic point near the
  /// screen's bottom-right corner, where the system tray conventionally
  /// lives.
  Future<Rect> _computeFrameFixedCorner() async {
    final view = PlatformDispatcher.instance.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    final frame = computePopoverFrame(
      trayBounds: _fixedTrayAnchor(screenSize),
      popoverSize: _popoverSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  Rect _fixedTrayAnchor(Size screenSize) {
    return Rect.fromLTWH(screenSize.width - 32, screenSize.height - 32, 32, 32);
  }

  Future<void> _handleIncomingIpcMessage(
    String? method,
    dynamic arguments,
  ) async {
    try {
      switch (method) {
        case 'miniReady':
          _miniPanelWindow.followerReady = true;
          if (_leaderBloc != null) {
            await _broadcastSnapshotIfReady(_leaderBloc!.state);
          }
          if (_pendingFocusComment) {
            _pendingFocusComment = false;
            await _invokeFollower('focusComment', null);
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
          _miniPanelWindow.followerReady = false;

        case 'focusComment':
          _followerCubit?.emitCommand(MiniPanelCommand.focusComment);

        case 'acceptComment':
          _followerCubit?.emitCommand(MiniPanelCommand.acceptComment);

        case 'dismissComment':
          _followerCubit?.emitCommand(MiniPanelCommand.dismissComment);

        case 'autoDismissComment':
          _followerCubit?.emitCommand(MiniPanelCommand.autoDismissComment);

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
    if (!_miniPanelWindow.followerReady || _miniPanelWindow.windowId == null) return;

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
        _miniPanelWindow.windowId!,
        'broadcastSnapshot',
        jsonStr,
      );
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to broadcast snapshot - $e');
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
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) =>
      _handleIncomingIpcMessage(method, arguments);
}
