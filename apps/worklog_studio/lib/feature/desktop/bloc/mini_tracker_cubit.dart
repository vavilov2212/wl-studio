import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/desktop/data/ipc_models.dart';

part 'mini_tracker_cubit.freezed.dart';

/// Commands sent from the leader to the mini panel follower's cubit so the
/// mini panel widget can respond to hotkeys and IPC-triggered focus changes
/// without requiring the widget to poll or use a separate channel.
enum MiniPanelCommand {
  /// Seeds the comment field text and selection without requesting OS keyboard
  /// focus. Used when a passive trigger (e.g. a reminder timer) shows the
  /// panel. Text is ready so the user can start typing the moment they
  /// explicitly bring the window into focus.
  seedComment,
  /// Seeds the comment field text, select-all, AND requests Flutter/OS
  /// keyboard focus - used when the user explicitly activates the panel
  /// via the toggle hotkey or a button.
  focusComment,
  acceptComment,
  dismissComment,
  autoDismissComment,
}

@freezed
abstract class MiniTrackerState with _$MiniTrackerState {
  const MiniTrackerState._();
  const factory MiniTrackerState({
    @Default(false) bool isRunning,
    TimeEntry? activeEntry,
    @Default([]) List<TimeEntry> allEntries,
    @Default([]) List<Task> tasks,
    @Default([]) List<Project> projects,
    @Default(0) int lastTimestamp,
  }) = _MiniTrackerState;
}

class MiniTrackerCubit extends Cubit<MiniTrackerState> {
  MiniTrackerCubit() : super(const MiniTrackerState());

  void updateFromSnapshot(TimerSnapshot snapshot) {
    if (snapshot.timestamp < state.lastTimestamp) return;
    emit(
      MiniTrackerState(
        isRunning: snapshot.isRunning,
        activeEntry: snapshot.activeEntry,
        allEntries: snapshot.entries,
        tasks: snapshot.tasks,
        projects: snapshot.projects,
        lastTimestamp: snapshot.timestamp,
      ),
    );
  }

  void startTimer({String? projectId, String? taskId, String? comment}) {
    if (state.isRunning &&
        state.activeEntry?.projectId == projectId &&
        state.activeEntry?.taskId == taskId) {
      return;
    }

    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(
        type: TimerActionType.start,
        projectId: projectId,
        taskId: taskId,
        comment: comment,
      ),
    );
  }

  void stopTimer() {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(type: TimerActionType.stop),
    );
  }

  void updateComment(String comment) {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(type: TimerActionType.updateComment, comment: comment),
    );
  }

  /// Stops the current time entry and starts a fresh one with the same
  /// project and task but a new comment. Unlike [startTimer], this bypasses
  /// the "already tracking same task" guard - the caller has determined that
  /// the comment change represents a new activity, so a new entry boundary
  /// is always required.
  void restartWithComment(String? projectId, String? taskId, String comment) {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(
        type: TimerActionType.start,
        projectId: projectId,
        taskId: taskId,
        comment: comment,
      ),
    );
  }

  /// Asks the leader to open or toggle the native activity prompt window.
  /// A no-op when nothing is currently being tracked.
  void requestActivityPrompt() {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.requestActivityPrompt();
  }
}
