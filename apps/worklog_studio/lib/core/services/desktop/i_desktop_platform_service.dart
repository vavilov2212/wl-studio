import 'dart:async';

import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';

/// Abstract contract for all desktop-platform window/tray services.
///
/// Each platform provides its own concrete implementation:
///  - [MacOSDesktopService]   — popover panel + native IPC channel
///  - [WindowsDesktopService] — tray icon + window_manager lifecycle
///  - [NoOpDesktopService]    — silent stub for non-desktop targets
///
/// Call sites (app.dart, runner.dart, MiniTrackerCubit) depend only on this
/// interface, never on a concrete platform class.
abstract interface class IDesktopPlatformService {
  // ── Leader (main window) ──────────────────────────────────────────────────

  /// Initialise the service from the main application window.
  ///
  /// Must be called once after the widget tree is fully mounted so that
  /// [bloc], [resolver], and [projectTaskState] are already live.
  Future<void> initLeader(
    TimeTrackerBloc bloc,
    EntityResolver resolver,
    ProjectTaskState projectTaskState,
  );

  // ── Follower (popover / mini panel, macOS only) ───────────────────────────

  /// Initialise the service from the tray-popover window (macOS only).
  ///
  /// No-op on platforms that do not have a secondary popover window.
  Future<void> initFollower(MiniTrackerCubit cubit);

  // ── Navigation stream ─────────────────────────────────────────────────────

  /// Emits route strings that the main navigator should push.
  ///
  /// Populated when the tray/popover requests a specific screen be shown.
  /// Returns an empty stream on platforms that do not support this.
  Stream<String> get navigationStream;

  // ── Popover control (macOS only) ──────────────────────────────────────────

  /// Toggle popover visibility. No-op on Windows / non-popover platforms.
  Future<void> togglePopover();

  /// Show popover. No-op on Windows / non-popover platforms.
  Future<void> showPopover();

  /// Hide popover and notify the leader. No-op on Windows / non-popover platforms.
  Future<void> hidePopover();

  // ── Window-from-tray (macOS popover only) ─────────────────────────────────

  /// Ask the leader to focus the main window and optionally navigate to [route].
  ///
  /// Called from the follower/popover side. No-op on platforms without an IPC
  /// channel between two Flutter engines.
  void openMainWindowFromTray({String? route});

  // ── Action dispatch (macOS popover follower only) ─────────────────────────

  /// Send a timer action from the follower to the leader over IPC.
  ///
  /// No-op unless the current process is the macOS tray-popover follower.
  void dispatchAction(covariant dynamic action);

  // ── Activity prompt ───────────────────────────────────────────────────────

  /// Ask the leader to open the dedicated activity prompt window.
  ///
  /// Called from a follower/popover (e.g. the mini panel's button). On
  /// Windows the activity prompt is a native Win32 window owned by the leader
  /// process, so only an IPC request is needed from the follower side.
  void requestActivityPrompt();

  // ── Startup role detection ────────────────────────────────────────────────

  /// Resolve the startup role of this process from its raw startup [args].
  ///
  /// Returns `'tray'` when this process is a secondary popover engine
  /// (macOS only); `'main'` otherwise. Implementations that have no
  /// secondary-engine concept (Windows, no-op) always return `'main'`.
  Future<String> resolveStartupRole(List<String> args);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Release all resources (subscriptions, tray icon, IPC handlers).
  void dispose();
}
