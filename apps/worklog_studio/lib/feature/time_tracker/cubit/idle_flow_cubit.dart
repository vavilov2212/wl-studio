import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

// -- Data --------------------------------------------------------------------

/// Carries the user's task/project/comment selection from the Flutter dialog
/// back into the cubit so the idle time entry can be created correctly.
class IdleTaskSelection {
  final String? taskId;
  final String? projectId;
  final String? comment;

  const IdleTaskSelection({this.taskId, this.projectId, this.comment});
}

// -- State --------------------------------------------------------------------

sealed class IdleFlowState {
  const IdleFlowState();
}

class IdleFlowIdle extends IdleFlowState {
  const IdleFlowIdle();
}

class IdleFlowAwaitingResolution extends IdleFlowState {
  final DateTime idleStartTime;
  final String? taskId;
  final String? projectId;
  final int idleSeconds;
  final String? entryId;

  const IdleFlowAwaitingResolution({
    required this.idleStartTime,
    required this.idleSeconds,
    this.taskId,
    this.projectId,
    this.entryId,
  });
}

class IdleFlowResolved extends IdleFlowState {
  const IdleFlowResolved();
}

// -- Cubit --------------------------------------------------------------------

class IdleFlowCubit extends Cubit<IdleFlowState> {
  IdleFlowCubit({
    required IdleMonitor idleMonitor,
    required TimeTrackerBloc bloc,
    required TimeEntryRepository repository,
    required Future<void> Function() reloadReminderInterval,
    required void Function({
      required int idleMinutes,
      required void Function() onKeep,
      required void Function() onDiscard,
      required void Function() onRequestLogToTask,
    }) showResolutionWindow,
    void Function()? hideResolutionWindow,
    // Shows a Flutter dialog for task/project/comment selection.
    // Returns null when the user dismisses without confirming.
    Future<IdleTaskSelection?> Function()? showTaskSelectionDialog,
    int thresholdSeconds = 600,
    DateTime Function()? now,
  })  : _idleMonitor = idleMonitor,
        _bloc = bloc,
        _repository = repository,
        _reloadReminderInterval = reloadReminderInterval,
        _showResolutionWindow = showResolutionWindow,
        _hideResolutionWindow = hideResolutionWindow,
        _showTaskSelectionDialog = showTaskSelectionDialog,
        _thresholdSeconds = thresholdSeconds,
        _now = now ?? DateTime.now,
        super(const IdleFlowIdle()) {
    _idleSub = idleMonitor.onIdleEvent.listen(_onIdleEvent);
    _blocSub = bloc.stream.listen(_onBlocState);
    if (bloc.state.isRunning) {
      _monitorRunning = true;
      idleMonitor.start(thresholdSeconds: thresholdSeconds);
    }
  }

  final IdleMonitor _idleMonitor;
  final TimeTrackerBloc _bloc;
  final TimeEntryRepository _repository;
  final Future<void> Function() _reloadReminderInterval;
  final void Function({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function() onRequestLogToTask,
  }) _showResolutionWindow;
  final void Function()? _hideResolutionWindow;
  final Future<IdleTaskSelection?> Function()? _showTaskSelectionDialog;
  final DateTime Function() _now;
  int _thresholdSeconds;

  StreamSubscription<IdleEvent>? _idleSub;
  StreamSubscription<TimeTrackerBlocState>? _blocSub;
  bool _monitorRunning = false;

  final _uuid = const Uuid();

  void updateThreshold(int thresholdSeconds) {
    _thresholdSeconds = thresholdSeconds;
    if (_monitorRunning) {
      _idleMonitor.start(thresholdSeconds: thresholdSeconds);
    }
  }

  void _onBlocState(TimeTrackerBlocState state) {
    if (state.isRunning && !_monitorRunning) {
      _monitorRunning = true;
      _idleMonitor.start(thresholdSeconds: _thresholdSeconds);
    } else if (!state.isRunning && _monitorRunning) {
      _monitorRunning = false;
      _idleMonitor.stop();
      if (this.state is IdleFlowAwaitingResolution) {
        // User stopped the timer while the resolution window was still open -
        // hide the window and reset. Do NOT reset when already Resolved: the
        // bloc briefly emits a non-running loading state during the reload that
        // follows resolution, and we must not let that undo the resolved state.
        _hideResolutionWindow?.call();
        emit(const IdleFlowIdle());
      }
    }
  }

  void _onIdleEvent(IdleEvent event) {
    if (event is IdleThresholdReached) {
      if (!_bloc.state.isRunning) return;
      if (state is IdleFlowAwaitingResolution) return;
      final active = _bloc.state.activeEntryOrNull;
      emit(IdleFlowAwaitingResolution(
        idleStartTime: event.timestamp.subtract(
          Duration(seconds: event.idleSeconds),
        ),
        idleSeconds: event.idleSeconds,
        taskId: active?.taskId,
        projectId: active?.projectId,
        entryId: active?.id,
      ));
    } else if (event is UserReturnedFromIdle) {
      final s = state;
      if (s is! IdleFlowAwaitingResolution) return;
      // Show the actual total idle duration (from when idle started until now),
      // not just the threshold value. The user could have been away longer than
      // the threshold before the window appeared.
      final actualIdleMinutes = _now().difference(s.idleStartTime).inMinutes;
      _showResolutionWindow(
        idleMinutes: actualIdleMinutes < 1 ? 1 : actualIdleMinutes,
        onKeep: _onKeep,
        onDiscard: _onDiscard,
        onRequestLogToTask: _onRequestLogToTask,
      );
    }
  }

  void _onKeep() {
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  // Discards idle time: stops the current entry at the idle start, then
  // immediately restarts a new entry for the same task. Operations go directly
  // to the repository so they execute strictly in sequence, then a single
  // TimeTrackerLoaded event syncs the bloc state from the new repo contents.
  Future<void> _onDiscard() async {
    final s = state;
    if (s is! IdleFlowAwaitingResolution) return;
    final taskId = s.taskId;
    final projectId = s.projectId;
    final idleStart = s.idleStartTime;

    final currentActive = await _repository.getActive();
    if (currentActive == null ||
        (s.entryId != null && currentActive.id != s.entryId)) {
      emit(const IdleFlowResolved());
      return;
    }

    await _repository.update(currentActive.copyWith(
      endAt: idleStart,
      status: TimeEntryStatus.stopped,
    ));
    await _repository.insert(TimeEntry(
      id: _uuid.v4(),
      taskId: taskId,
      projectId: projectId,
      startAt: _now(),
      status: TimeEntryStatus.running,
    ));

    _bloc.add(const TimeTrackerEvent.loaded());
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  // Opens a Flutter task-selection dialog. If the user confirms, logs the idle
  // window as a separate stopped entry linked to the chosen task/project and
  // restarts the original task. If the user dismisses, falls back to "keep".
  Future<void> _onRequestLogToTask() async {
    final s = state;
    if (s is! IdleFlowAwaitingResolution) return;

    if (_showTaskSelectionDialog == null) {
      _onKeep();
      return;
    }

    final selection = await _showTaskSelectionDialog();
    if (selection == null) {
      _onKeep();
      return;
    }

    await _logIdleTimeToSelection(s, selection);
  }

  Future<void> _logIdleTimeToSelection(
    IdleFlowAwaitingResolution s,
    IdleTaskSelection selection,
  ) async {
    final taskId = s.taskId;
    final projectId = s.projectId;
    final idleStart = s.idleStartTime;
    final idleEnd = _now();

    final currentActive = await _repository.getActive();
    if (currentActive == null ||
        (s.entryId != null && currentActive.id != s.entryId)) {
      emit(const IdleFlowResolved());
      return;
    }

    await _repository.update(currentActive.copyWith(
      endAt: idleStart,
      status: TimeEntryStatus.stopped,
    ));
    await _repository.insert(TimeEntry(
      id: _uuid.v4(),
      taskId: selection.taskId,
      projectId: selection.projectId,
      comment: selection.comment,
      startAt: idleStart,
      endAt: idleEnd,
      status: TimeEntryStatus.stopped,
    ));
    await _repository.insert(TimeEntry(
      id: _uuid.v4(),
      taskId: taskId,
      projectId: projectId,
      startAt: idleEnd,
      status: TimeEntryStatus.running,
    ));

    _bloc.add(const TimeTrackerEvent.loaded());
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  @override
  Future<void> close() {
    _idleSub?.cancel();
    _blocSub?.cancel();
    return super.close();
  }
}
