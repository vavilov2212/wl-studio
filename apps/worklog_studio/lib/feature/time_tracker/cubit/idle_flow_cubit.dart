import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

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

  const IdleFlowAwaitingResolution({
    required this.idleStartTime,
    required this.idleSeconds,
    this.taskId,
    this.projectId,
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
      required void Function(String taskName) onLogToTask,
    }) showResolutionWindow,
    int thresholdSeconds = 600,
  })  : _idleMonitor = idleMonitor,
        _bloc = bloc,
        _repository = repository,
        _reloadReminderInterval = reloadReminderInterval,
        _showResolutionWindow = showResolutionWindow,
        _thresholdSeconds = thresholdSeconds,
        super(const IdleFlowIdle()) {
    _idleSub = idleMonitor.onIdleEvent.listen(_onIdleEvent);
    _blocSub = bloc.stream.listen(_onBlocState);
  }

  final IdleMonitor _idleMonitor;
  final TimeTrackerBloc _bloc;
  final TimeEntryRepository _repository;
  final Future<void> Function() _reloadReminderInterval;
  final void Function({
    required int idleMinutes,
    required void Function() onKeep,
    required void Function() onDiscard,
    required void Function(String taskName) onLogToTask,
  }) _showResolutionWindow;
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
      if (this.state is IdleFlowAwaitingResolution ||
          this.state is IdleFlowResolved) {
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
      ));
    } else if (event is UserReturnedFromIdle) {
      final s = state;
      if (s is! IdleFlowAwaitingResolution) return;
      _showResolutionWindow(
        idleMinutes: s.idleSeconds ~/ 60,
        onKeep: _onKeep,
        onDiscard: _onDiscard,
        onLogToTask: _onLogToTask,
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

    final active = await _repository.getActive();
    if (active == null) return;

    await _repository.update(active.copyWith(
      endAt: idleStart,
      status: TimeEntryStatus.stopped,
    ));
    await _repository.insert(TimeEntry(
      id: _uuid.v4(),
      taskId: taskId,
      projectId: projectId,
      startAt: DateTime.now(),
      status: TimeEntryStatus.running,
    ));

    _bloc.add(const TimeTrackerEvent.loaded());
    _reloadReminderInterval();
    emit(const IdleFlowResolved());
  }

  // Logs idle time to a named task: stops the current entry at idleStart,
  // creates a stopped entry covering the idle window, then restarts the
  // original task. All three repository writes are sequential and atomic
  // from the cubit's perspective.
  Future<void> _onLogToTask(String taskName) async {
    final s = state;
    if (s is! IdleFlowAwaitingResolution) return;
    final taskId = s.taskId;
    final projectId = s.projectId;
    final idleStart = s.idleStartTime;
    final idleEnd = DateTime.now();

    final active = await _repository.getActive();
    if (active == null) return;

    await _repository.update(active.copyWith(
      endAt: idleStart,
      status: TimeEntryStatus.stopped,
    ));
    await _repository.insert(TimeEntry(
      id: _uuid.v4(),
      comment: taskName,
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
