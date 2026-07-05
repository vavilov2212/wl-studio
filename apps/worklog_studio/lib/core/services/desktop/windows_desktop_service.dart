import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/native_activity_window.dart';
import 'package:worklog_studio/core/services/desktop/native_mini_panel.dart';
import 'package:worklog_studio/core/services/desktop/windows_tray_service.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows implementation of [IDesktopPlatformService].
///
/// Owns:
/// - A [NativeMiniPanel] for the tray-click mini panel - a GDI-painted Win32
///   window with no secondary Flutter engine, eliminating the EGL context
///   race crashes (flutter/flutter#155685) from the old desktop_multi_window
///   approach.
/// - A [NativeActivityWindow] for the activity comment prompt - a pure Win32
///   HWND + EDIT control, same reasoning.
class WindowsDesktopService implements IDesktopPlatformService {
  WindowsDesktopService._();

  static final WindowsDesktopService _instance = WindowsDesktopService._();
  factory WindowsDesktopService() => _instance;

  final _navigationStreamController = StreamController<String>.broadcast();

  TimeTrackerBloc? _leaderBloc;
  ProjectTaskState? _projectTaskState;
  StreamSubscription<TimeTrackerBlocState>? _blocSubscription;

  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;

  /// Prevents concurrent executions of [acceptCurrentComment].
  bool _acceptInFlight = false;

  late final NativeMiniPanel _nativePanel = NativeMiniPanel(
    onStop: () => _handleFollowerAction(
      TimerAction(type: TimerActionType.stop),
    ),
    onStart: (entry) => _handleFollowerAction(
      TimerAction(
        type: TimerActionType.start,
        projectId: entry.projectId,
        taskId: entry.taskId,
        comment: entry.comment,
      ),
    ),
    onSwitchActivity: () async {
      _nativePanel.hide();
      await showActivityPrompt();
      _nativeActivityWindow.activate();
      _reminderService?.cancelAutoDismiss();
    },
    onOpenMainApp: () {
      _nativePanel.hide();
      WindowsTrayService().restoreWindow();
    },
  );

  late final NativeActivityWindow _nativeActivityWindow = NativeActivityWindow(
    onAccept: _onActivityAccept,
    onDismiss: _onActivityDismiss,
  );

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
      _nativePanel.update(_buildDisplayState(state));
    });

    projectTaskState.addListener(() {
      if (_leaderBloc != null) {
        _nativePanel.update(_buildDisplayState(_leaderBloc!.state));
      }
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
  }

  /// No-op on Windows - there is no secondary Flutter engine.
  @override
  Future<void> initFollower(MiniTrackerCubit cubit) async {}

  @override
  Future<void> togglePopover() async {
    if (_nativePanel.isVisible) {
      _nativePanel.hide();
    } else {
      final (ax, ay) = await _trayAnchorPoint();
      _nativePanel.show(ax, ay);
    }
  }

  @override
  Future<void> showPopover() async {
    final (ax, ay) = await _trayAnchorPoint();
    _nativePanel.show(ax, ay);
  }

  @override
  Future<void> hidePopover() async => _nativePanel.hide();

  /// Shows the activity comment prompt. A no-op if nothing is currently
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
  /// - hidden -> show and grab OS focus;
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

  /// Auto-dismiss path: commits any unsaved edit.
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

  void _onActivityDismiss() {
    _reminderService?.cancelAutoDismiss();
  }

  /// No-op on Windows - everything is in-process; the mini panel callbacks
  /// call [_handleFollowerAction] directly.
  @override
  void openMainWindowFromTray({String? route}) {}

  /// No-op on Windows - the mini panel's [NativeMiniPanel.onStart] /
  /// [onStop] callbacks call [_handleFollowerAction] directly.
  @override
  void dispatchAction(covariant dynamic action) {}

  /// No-op on Windows - [NativeMiniPanel.onSwitchActivity] calls
  /// [toggleActivityPrompt] directly.
  @override
  void requestActivityPrompt() {}

  /// Always returns `'main'` - there is no secondary Flutter engine on Windows.
  @override
  Future<String> resolveStartupRole(List<String> args) async => 'main';

  @override
  void dispose() {
    _hotkeyService?.dispose();
    _reminderService?.dispose();
    _blocSubscription?.cancel();
    _nativePanel.dispose();
    _nativeActivityWindow.dispose();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _handleFollowerAction(TimerAction action) {
    if (_leaderBloc == null) return;

    final isCurrentlyRunning = _leaderBloc!.state.isRunning;

    if (action.type == TimerActionType.start) {
      if (isCurrentlyRunning) {
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

  /// Builds a [MiniPanelDisplayState] from the current BLoC state and the
  /// project/task catalogue. Badge colours are computed here (on the Dart/
  /// Flutter side) so the GDI painter needs no Flutter imports.
  MiniPanelDisplayState _buildDisplayState(TimeTrackerBlocState state) {
    final activeEntry = state.activeEntryOrNull;

    String? activeTitle;
    String? activeSubtitle;
    if (activeEntry != null) {
      final task = _projectTaskState?.tasks
          .firstWhereOrNull((t) => t.id == activeEntry.taskId);
      final project = _projectTaskState?.projects
          .firstWhereOrNull((p) => p.id == activeEntry.projectId);
      // The session card renders task, project, and comment as three
      // separate lines (with placeholders when missing), so no fallback
      // chain here - each field carries exactly its own value.
      activeTitle = task?.title;
      activeSubtitle = project?.name;
    }

    // Deduplicated recent entries, newest-first, skipping the active one.
    final seen = <String>{};
    final recentEntries = <MiniPanelEntry>[];

    for (final entry in state.allEntries) {
      if (entry.id == activeEntry?.id) continue;
      final key =
          '${entry.projectId}|${entry.taskId}|${entry.comment ?? ''}';
      if (!seen.add(key)) continue;
      if (recentEntries.length >= MiniPanelMetrics.maxEntries) break;

      final task = _projectTaskState?.tasks
          .firstWhereOrNull((t) => t.id == entry.taskId);
      final project = _projectTaskState?.projects
          .firstWhereOrNull((p) => p.id == entry.projectId);

      final title = (entry.comment?.isNotEmpty == true)
          ? entry.comment!
          : (task?.title ?? project?.name ?? 'Untitled');

      final idForColor = entry.taskId ?? entry.projectId ?? entry.id;
      final (bgColor, fgColor) = BadgeUtils.getBadgeColor(idForColor);
      final initials = task != null
          ? BadgeUtils.getTaskInitials(task.title, project?.name ?? '')
          : (project != null
              ? BadgeUtils.getProjectInitials(project.name)
              : '--');

      recentEntries.add(MiniPanelEntry(
        id: entry.id,
        title: title,
        subtitle: project?.name,
        projectId: entry.projectId,
        taskId: entry.taskId,
        comment: entry.comment,
        badgeBg: _toColorRef(bgColor),
        badgeFg: _toColorRef(fgColor),
        badgeText: initials,
      ));
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    Duration todayDur = Duration.zero;
    Duration weekDur = Duration.zero;
    for (final e in state.allEntries) {
      final d = e.duration(now);
      if (!e.startAt.isBefore(todayStart)) todayDur += d;
      if (!e.startAt.isBefore(weekStart)) weekDur += d;
    }

    return MiniPanelDisplayState(
      isRunning: state.isRunning,
      activeTitle: activeTitle,
      activeSubtitle: activeSubtitle,
      activeComment: (activeEntry?.comment?.isNotEmpty == true)
          ? activeEntry!.comment
          : null,
      timerStartAt: activeEntry?.startAt,
      entries: recentEntries,
      todayDuration: todayDur,
      weekDuration: weekDur,
    );
  }

  /// Converts a Flutter [Color] to a Win32 COLORREF (0x00BBGGRR).
  static int _toColorRef(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return r | (g << 8) | (b << 16);
  }

  Future<Size> _screenSize() async {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      return display.size;
    } catch (e) {
      debugPrint(
          'WindowsDesktopService: getPrimaryDisplay failed, falling back - $e');
      final view = PlatformDispatcher.instance.views.first;
      return view.physicalSize / view.devicePixelRatio;
    }
  }

  Future<(int, int)> _trayAnchorPoint() async {
    final rawBounds = await trayManager.getBounds();
    final screenSize = await _screenSize();
    final bounds = _sanitizeTrayBounds(rawBounds, screenSize);
    return (
      (bounds.left + bounds.width / 2).round(),
      bounds.top.round(),
    );
  }

  Rect _sanitizeTrayBounds(Rect? rawBounds, Size screenSize) {
    if (rawBounds != null && rawBounds.width > 1 && rawBounds.height > 1) {
      return rawBounds;
    }
    return _fixedTrayAnchor(screenSize);
  }

  Rect _fixedTrayAnchor(Size screenSize) =>
      Rect.fromLTWH(screenSize.width - 32, screenSize.height - 32, 32, 32);

  Future<Rect> _computeActivityPromptFrame() async {
    final screenSize = await _screenSize();
    final frame = computeActivityPromptFrame(
      screenSize: screenSize,
      promptSize: NativeActivityWindow.windowSize,
    );
    return clampFrameToScreen(frame, screenSize);
  }

  // ── Test seams ─────────────────────────────────────────────────────────────

  @visibleForTesting
  Rect fixedTrayAnchorForTesting(Size screenSize) =>
      _fixedTrayAnchor(screenSize);

  @visibleForTesting
  Rect sanitizeTrayBoundsForTesting(Rect? rawBounds, Size screenSize) =>
      _sanitizeTrayBounds(rawBounds, screenSize);

  @visibleForTesting
  void setLeaderBlocForTesting(TimeTrackerBloc bloc) => _leaderBloc = bloc;

  /// Simulates an incoming action from the mini panel (for testing
  /// [_handleFollowerAction] without a real Win32 window).
  @visibleForTesting
  Future<void> handleIncomingIpcMessageForTesting(
    String method,
    dynamic arguments,
  ) async {
    if (method == 'dispatchAction' && arguments != null) {
      final action =
          TimerAction.fromJson(Map<String, dynamic>.from(arguments as Map));
      _handleFollowerAction(action);
    }
  }
}
