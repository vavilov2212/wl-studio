import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';

enum MiniPanelCommand {
  focusComment,
  acceptComment,
  dismissComment,
  autoDismissComment,
}

class MiniTrackerState {
  final bool isRunning;
  final TimeEntry? activeEntry;
  final List<TimeEntry> allEntries;
  final List<Task> tasks;
  final List<Project> projects;
  final int lastTimestamp;

  const MiniTrackerState({
    this.isRunning = false,
    this.activeEntry,
    this.allEntries = const [],
    this.tasks = const [],
    this.projects = const [],
    this.lastTimestamp = 0,
  });

  MiniTrackerState copyWith({
    bool? isRunning,
    TimeEntry? activeEntry,
    List<TimeEntry>? allEntries,
    List<Task>? tasks,
    List<Project>? projects,
    int? lastTimestamp,
  }) {
    return MiniTrackerState(
      isRunning: isRunning ?? this.isRunning,
      activeEntry: activeEntry ?? this.activeEntry,
      allEntries: allEntries ?? this.allEntries,
      tasks: tasks ?? this.tasks,
      projects: projects ?? this.projects,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
    );
  }
}

class MiniTrackerCubit extends Cubit<MiniTrackerState> {
  MiniTrackerCubit() : super(const MiniTrackerState());

  final _commandController = StreamController<MiniPanelCommand>.broadcast();

  Stream<MiniPanelCommand> get commands => _commandController.stream;

  void emitCommand(MiniPanelCommand command) {
    _commandController.add(command);
  }

  @override
  Future<void> close() {
    _commandController.close();
    return super.close();
  }

  void updateFromSnapshot(TimerSnapshot snapshot) {
    if (snapshot.timestamp < state.lastTimestamp) return;
    emit(
      state.copyWith(
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
}
