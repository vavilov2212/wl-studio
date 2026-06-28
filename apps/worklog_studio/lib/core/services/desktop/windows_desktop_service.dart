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
  int? _popoverWindowId;
  bool _isPopoverVisible = false;
  bool _isPopover = false;
  bool _followerReady = false;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

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
      isPopoverOpen: () => _isPopoverVisible,
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
    await _ensurePopoverWindowExists();
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
    // _isPopoverVisible only ever gets corrected by our own hidePopover()
    // call. If the user destroyed the popover via its native close button
    // instead, _isPopoverVisible is left stuck at true even though nothing
    // is on screen - reconcile against the plugin's live-window list before
    // deciding which branch to take, or the first click after a close-via-X
    // would silently call hidePopover() on an already-dead window (a no-op)
    // instead of actually reopening it.
    debugPrint('WindowsDesktopService: togglePopover called, _isPopoverVisible=$_isPopoverVisible');
    await _reconcilePopoverState();
    debugPrint('WindowsDesktopService: after reconcile, _isPopoverVisible=$_isPopoverVisible _popoverWindowId=$_popoverWindowId');
    if (_isPopoverVisible) {
      await hidePopover();
    } else {
      await showPopover();
      await requestFocusComment();
    }
  }

  @override
  Future<void> showPopover() => _showPopover(_computeFrameNearTray);

  /// Used by [ReminderService], which fires unattended on a timer rather
  /// than from a direct user click - there is no extra context here that
  /// would make a live tray-icon lookup any more trustworthy than usual,
  /// so this always anchors to the fixed screen-corner position instead
  /// of the icon-relative one [showPopover] uses.
  Future<void> showPopoverNearScreenCorner() => _showPopover(_computeFrameFixedCorner);

  Future<void> _showPopover(Future<Rect> Function() computeFrame) async {
    // See togglePopover()'s comment: the popover's native window has a
    // titlebar close button that the desktop_multi_window plugin gives no
    // way to suppress or intercept on Windows, so the user can destroy the
    // underlying window/engine at any time outside our control. Reusing a
    // destroyed window id is a silent no-op on the native side, which would
    // otherwise leave the popover permanently unopenable.
    await _reconcilePopoverState();
    await _ensurePopoverWindowExists();

    if (_popoverWindowId == null) {
      debugPrint('WindowsDesktopService: showPopover aborted - no popover window available');
      return;
    }

    try {
      final frame = await computeFrame();
      debugPrint('WindowsDesktopService: showPopover computed frame=$frame');
      final controller = WindowController.fromWindowId(_popoverWindowId!);
      await controller.setFrame(frame);
      await controller.show();
      _isPopoverVisible = true;
      debugPrint('WindowsDesktopService: showPopover completed successfully, windowId=$_popoverWindowId');
    } catch (e) {
      debugPrint('WindowsDesktopService: error showing popover - $e');
    }
  }

  Future<void> _reconcilePopoverState() async {
    if (_popoverWindowId != null && !await _isPopoverWindowAlive()) {
      _popoverWindowId = null;
      _isPopoverVisible = false;
    }
  }

  /// `getAllSubWindowIds()` has a native list-encoding bug on some Windows
  /// builds (throws `RangeError` on every call, not just when something is
  /// actually wrong), so it cannot be trusted as a liveness signal here -
  /// see the removed previous implementation's history for that dead end.
  ///
  /// Instead, this sends a harmless targeted IPC call straight to
  /// [_popoverWindowId]. The native plugin's `HandleWindowChannelCall`
  /// looks the id up in its own window map *before* trying to reach the
  /// follower engine at all, and replies with the exact error
  /// `PlatformException(code: '-1', message: 'target window not found.')`
  /// only when that id has actually been erased from the map - which only
  /// happens via the native `OnWindowDestroy` callback, i.e. the window is
  /// genuinely gone (closed via its native titlebar X button, since the
  /// plugin gives us no way to intercept that). Any other failure (e.g. the
  /// follower engine exists but hasn't finished registering its method
  /// handler yet) is inconclusive, not proof of death - treating it as
  /// "alive" avoids the previous bug where any probe hiccup forced a
  /// brand-new popover engine (a multi-second Firebase/DB cold boot) on
  /// every single toggle.
  Future<bool> _isPopoverWindowAlive() async {
    try {
      await DesktopMultiWindow.invokeMethod(_popoverWindowId!, 'livenessPing', null);
      return true;
    } on PlatformException catch (e) {
      if (e.code == '-1' && e.message == 'target window not found.') {
        debugPrint('WindowsDesktopService: popover window $_popoverWindowId confirmed destroyed - $e');
        return false;
      }
      debugPrint('WindowsDesktopService: inconclusive liveness probe, assuming alive - $e');
      return true;
    } catch (e) {
      debugPrint('WindowsDesktopService: inconclusive liveness probe, assuming alive - $e');
      return true;
    }
  }

  Future<void>? _creationInFlight;

  /// Ensures a popover engine exists, creating one if necessary - without
  /// showing it. Used both to pre-warm (startup, and after the watchdog
  /// detects a close-via-X) and as the creation step inside `showPopover()`.
  ///
  /// Concurrent callers share the same in-flight `createWindow()` call
  /// instead of each starting their own: a user-initiated `showPopover()`
  /// and the 1s watchdog's pre-warm tick can otherwise both observe
  /// `_popoverWindowId == null` at the same time (the create call takes
  /// long enough to boot a whole engine) and each create their own window.
  /// Whichever one's create call resolves *second* would then silently
  /// overwrite `_popoverWindowId` with its own (different, never-shown)
  /// window id - leaving the leader pointing at a hidden window while the
  /// one actually on screen never receives any further snapshots, focus
  /// requests, or hide/show calls. Funnelling every creation through this
  /// one in-flight future makes that race impossible: only one
  /// `createWindow()` call is ever outstanding, and every other caller
  /// just awaits its result.
  Future<void> _ensurePopoverWindowExists() async {
    if (_popoverWindowId != null) return;
    if (_creationInFlight != null) {
      await _creationInFlight;
      return;
    }
    final completer = Completer<void>();
    _creationInFlight = completer.future;
    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({}));
      _popoverWindowId = window.windowId;
      debugPrint('WindowsDesktopService: created popover window id=${window.windowId}');
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to create popover window - $e');
    } finally {
      _creationInFlight = null;
      completer.complete();
    }
  }

  /// Polls popover liveness so a close-via-X gets noticed - and a
  /// replacement engine gets pre-warmed - without waiting for the user to
  /// try reopening it first. Skips the check entirely while the popover is
  /// actually visible, since there is nothing to detect in that case.
  void _startPrewarmWatchdog() {
    _prewarmWatchdog?.cancel();
    _prewarmWatchdog = Timer.periodic(_prewarmCheckInterval, (_) => _checkAndRewarmPopover());
  }

  Future<void> _checkAndRewarmPopover() async {
    if (_popoverWindowId == null) {
      await _ensurePopoverWindowExists();
      return;
    }
    // No "skip while visible" shortcut here on purpose: _isPopoverVisible
    // is only ever corrected by our own hidePopover()/reconcile calls, not
    // by any native close callback, so right after a close-via-X it stays
    // stuck at true forever. Trusting it here would make the watchdog skip
    // its own check permanently the moment it's needed most.
    final alive = await _isPopoverWindowAlive();
    if (!alive) {
      debugPrint('WindowsDesktopService: watchdog detected popover destroyed via X - re-warming');
      _popoverWindowId = null;
      _isPopoverVisible = false;
      _followerReady = false;
      await _ensurePopoverWindowExists();
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

  bool _pendingFocusComment = false;

  /// Asks the follower (popover) engine to put the comment field into edit
  /// mode and request keyboard focus. If the popover isn't ready yet (e.g.
  /// it was just created and hasn't sent `miniReady`), the request is
  /// deferred and replayed once `miniReady` arrives - see
  /// [_handleIncomingIpcMessage]'s `'miniReady'` case.
  Future<void> requestFocusComment() async {
    if (_followerReady && _popoverWindowId != null) {
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
    if (_popoverWindowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(_popoverWindowId!, method, arguments);
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
      return 'tray';
    }
    return 'main';
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
          _followerReady = true;
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
          _followerReady = false;

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
