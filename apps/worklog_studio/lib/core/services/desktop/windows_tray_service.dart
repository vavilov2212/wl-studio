import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Windows-only service that manages the system tray icon and window lifecycle.
///
/// Responsibilities:
///  - Intercept the close button → hide window (minimize to tray).
///  - Left-click tray icon → restore + focus main window.
///  - Right-click tray icon → show context menu with tracker state.
///  - Sync tray icon and context menu with [TimeTrackerBloc] state.
class WindowsTrayService with TrayListener, WindowListener {
  static final WindowsTrayService _instance = WindowsTrayService._internal();
  factory WindowsTrayService() => _instance;
  WindowsTrayService._internal();

  TimeTrackerBloc? _bloc;
  EntityResolver? _resolver;
  StreamSubscription<TimeTrackerBlocState>? _blocSub;
  Future<void> Function()? _onTrayClick;

  bool _isInitialized = false;
  bool _firstMinimize = true;

  // ─── Public API ────────────────────────────────────────────────────────────

  Future<void> init(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState, {
    Future<void> Function()? onTrayClick,
  }) async {
    if (!Platform.isWindows) return;
    if (_isInitialized) return;
    _isInitialized = true;

    _bloc = bloc;
    _resolver = resolver;
    _onTrayClick = onTrayClick;

    // --- window_manager setup ---
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options);
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    // --- tray_manager setup ---
    trayManager.addListener(this);
    await _initTrayIcon(isRunning: false);
    await _rebuildContextMenu(bloc.state);

    // --- subscribe to BLoC ---
    _blocSub = bloc.stream.listen(_onBlocState);
  }

  Future<void> dispose() async {
    _blocSub?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }

  // ─── WindowListener ────────────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    // Intercept close → hide to tray instead of terminating.
    await windowManager.hide();

    if (_firstMinimize) {
      _firstMinimize = false;
      // Tooltip already communicates the tray presence; a native notification
      // could be added here via local_notifier if desired.
      debugPrint('WindowsTrayService: app minimized to tray for the first time');
    }
  }

  // ─── TrayListener ──────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() async {
    // Left-click: open the popover if a hook is wired (Windows mini panel),
    // otherwise fall back to restoring the main window.
    if (_onTrayClick != null) {
      await _onTrayClick!();
    } else {
      await restoreWindow();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    // Right-click: show context menu (populated with current state).
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'stop_tracking':
        _bloc?.add(TimeTrackerStopped());
      case 'open':
        restoreWindow();
      case 'quit':
        _quit();
    }
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  void _onBlocState(TimeTrackerBlocState state) {
    _initTrayIcon(isRunning: state.isRunning);
    _rebuildContextMenu(state);
  }

  Future<void> _initTrayIcon({required bool isRunning}) async {
    try {
      final isDev = appEnvironment.config.flavor == Flavor.development;
      final suffix = isDev ? '_dev' : '';
      final iconAsset = isRunning
          ? 'assets/app_icon_running$suffix.ico'
          : 'assets/app_icon_idle$suffix.ico';
      await trayManager.setIcon(iconAsset);
      final tooltip = isRunning ? 'worklog studio — tracking' : 'worklog studio';
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      // Fallback: .ico not found — likely not yet converted from PNG.
      // The tray will show a blank icon until .ico files are added.
      debugPrint('WindowsTrayService: tray icon error — $e');
      debugPrint(
        'Ensure assets/app_icon_idle.ico and assets/app_icon_running.ico '
        'exist (convert from existing PNGs).',
      );
    }
  }

  Future<void> _rebuildContextMenu(TimeTrackerBlocState state) async {
    final isRunning = state.isRunning;
    final activeEntry = state.activeEntryOrNull;
    final resolver = _resolver;

    final items = <MenuItem>[];

    // ── Tracker status row ──
    if (isRunning && activeEntry != null && resolver != null) {
      final projectName = resolver.getProjectName(activeEntry.projectId);
      final taskName = resolver.getTaskName(activeEntry.taskId);
      items.add(MenuItem(
        label: '$taskName  •  $projectName',
        disabled: true,
      ));
      items.add(MenuItem.separator());
      items.add(MenuItem(
        key: 'stop_tracking',
        label: 'Stop Tracking',
      ));
    } else {
      items.add(MenuItem(
        label: 'Not tracking',
        disabled: true,
      ));
    }

    items.add(MenuItem.separator());
    items.add(MenuItem(key: 'open', label: 'Open worklog studio'));
    items.add(MenuItem.separator());
    items.add(MenuItem(key: 'quit', label: 'Quit'));

    await trayManager.setContextMenu(Menu(items: items));
  }

  Future<void> restoreWindow() async {
    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      await windowManager.show();
    }
    // Bring to foreground reliably on Windows 10/11.
    await windowManager.focus();
    final isMin = await windowManager.isMinimized();
    if (isMin) {
      await windowManager.restore();
    }
    // Belt-and-suspenders: brief always-on-top flash forces the window
    // to the foreground even when another app holds focus.
    await windowManager.setAlwaysOnTop(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await windowManager.setAlwaysOnTop(false);
  }

  Future<void> _quit() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
