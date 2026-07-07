import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/project_task_state.dart';

class TrackerPanelState {
  final String draftComment;
  const TrackerPanelState({this.draftComment = ''});

  @override
  bool operator ==(Object other) =>
      other is TrackerPanelState && other.draftComment == draftComment;

  @override
  int get hashCode => draftComment.hashCode;
}

class TrackerPanelCubit extends Cubit<TrackerPanelState> {
  final TimeTrackerBloc _timeTrackerBloc;
  final ProjectTaskState _projectTaskState;
  late final StreamSubscription<TimeTrackerBlocState> _sub;

  TrackerPanelCubit({
    required TimeTrackerBloc timeTrackerBloc,
    required ProjectTaskState projectTaskState,
  })  : _timeTrackerBloc = timeTrackerBloc,
        _projectTaskState = projectTaskState,
        super(const TrackerPanelState()) {
    _sub = timeTrackerBloc.stream.listen(_onTimeTrackerState);
    _onTimeTrackerState(timeTrackerBloc.state);
  }

  void _onTimeTrackerState(TimeTrackerBlocState trackerState) {
    final entry = trackerState.activeEntryOrNull;
    if (entry != null) {
      _projectTaskState.updateDraft(
        projectId: entry.projectId,
        taskId: entry.taskId,
        comment: entry.comment ?? '',
      );
      emit(TrackerPanelState(draftComment: entry.comment ?? ''));
    }
  }

  void startTimer() {
    _timeTrackerBloc.add(
      TimeTrackerStarted(
        projectId: _projectTaskState.draftProjectId,
        taskId: _projectTaskState.draftTaskId,
        comment: state.draftComment.isNotEmpty ? state.draftComment : null,
      ),
    );
  }

  void stopTimer() {
    _timeTrackerBloc.add(TimeTrackerStopped());
    _projectTaskState.clearDraft();
    emit(const TrackerPanelState());
  }

  void updateProject(String? projectId, {required bool isRunning}) {
    _projectTaskState.updateDraft(projectId: projectId);
    if (isRunning) {
      _timeTrackerBloc.add(
        TimeTrackerActiveEntryUpdated(
          projectId: projectId,
          taskId: _projectTaskState.draftTaskId,
          comment: state.draftComment,
        ),
      );
    }
  }

  void updateTask(String? taskId, {required bool isRunning}) {
    if (taskId == null) {
      _projectTaskState.updateDraft(clearTaskId: true);
    } else {
      _projectTaskState.updateDraft(taskId: taskId);
    }
    if (isRunning) {
      _timeTrackerBloc.add(
        TimeTrackerActiveEntryUpdated(
          projectId: _projectTaskState.draftProjectId,
          taskId: taskId,
          comment: state.draftComment,
        ),
      );
    }
  }

  void updateComment(String comment, {required bool isRunning}) {
    emit(TrackerPanelState(draftComment: comment));
    if (isRunning) {
      _timeTrackerBloc.add(
        TimeTrackerActiveEntryUpdated(
          projectId: _projectTaskState.draftProjectId,
          taskId: _projectTaskState.draftTaskId,
          comment: comment,
        ),
      );
    }
  }

  Future<void> createProject(String name, {required bool isRunning}) async {
    final newProject = await _projectTaskState.createProject(name, '');
    _projectTaskState.updateDraft(projectId: newProject.id);
    if (isRunning) {
      _timeTrackerBloc.add(
        TimeTrackerActiveEntryUpdated(
          projectId: newProject.id,
          taskId: _projectTaskState.draftTaskId,
          comment: state.draftComment,
        ),
      );
    }
  }

  Future<void> createTask(String name, {required bool isRunning}) async {
    final projectId = _projectTaskState.draftProjectId;
    if (projectId == null) return;
    final newTask = await _projectTaskState.createTask(projectId, name, '');
    _projectTaskState.updateDraft(taskId: newTask.id);
    if (isRunning) {
      _timeTrackerBloc.add(
        TimeTrackerActiveEntryUpdated(
          projectId: projectId,
          taskId: newTask.id,
          comment: state.draftComment,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
