import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';

part 'time_tracker_bloc.freezed.dart';
part 'time_tracker_event.dart';
part 'time_tracker_state.dart';

class TimeTrackerBloc extends Bloc<TimeTrackerEvent, TimeTrackerBlocState> {
  final TimeTrackerService _service;
  final IdleMonitor? _idleMonitor;
  StreamSubscription<IdleEvent>? _idleSubscription;

  TimeTrackerBloc({
    required TimeTrackerService service,
    IdleMonitor? idleMonitor,
  }) : _service = service,
       _idleMonitor = idleMonitor,
       super(const TimeTrackerBlocState.idle()) {
    on<TimeTrackerLoaded>(_onLoaded);
    on<TimeTrackerStarted>(_onStarted);
    on<TimeTrackerStopped>(_onStopped);
    on<TimeTrackerActiveEntryUpdated>(_onActiveEntryUpdated);
    on<TimeTrackerEntryDeleted>(_onEntryDeleted);
    on<TimeTrackerEntryCreated>(_onEntryCreated);
    on<TimeTrackerEntryUpdated>(_onEntryUpdated);

    _idleSubscription = _idleMonitor?.onIdleEvent.listen((event) {
      if (event is IdleThresholdReached && state.isRunning) {
        add(TimeTrackerStopped());
      }
    });
  }

  @override
  Future<void> close() {
    _idleSubscription?.cancel();
    return super.close();
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onLoaded(
    TimeTrackerLoaded event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    emit(const TimeTrackerBlocState.loading());
    await _reloadAndEmit(emit);
  }

  Future<void> _onStarted(
    TimeTrackerStarted event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    final wasRunning = state.isRunning;
    await _reloadAndEmit(emit, () async {
      if (wasRunning) {
        await _service.stop();
        _idleMonitor?.stop();
      }
      await _service.start(
        projectId: event.projectId,
        taskId: event.taskId,
        comment: event.comment,
      );
      _idleMonitor?.start(thresholdSeconds: 600);
    });
  }

  Future<void> _onStopped(
    TimeTrackerStopped event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (!state.isRunning) return;
    await _reloadAndEmit(emit, () async {
      await _service.stop();
      _idleMonitor?.stop();
    });
  }

  Future<void> _onActiveEntryUpdated(
    TimeTrackerActiveEntryUpdated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (state.activeEntryOrNull == null) return;
    await _reloadAndEmit(emit, () => _service.updateActive(
      projectId: event.projectId,
      taskId: event.taskId,
      comment: event.comment,
    ));
  }

  Future<void> _onEntryDeleted(
    TimeTrackerEntryDeleted event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    await _reloadAndEmit(emit, () => _service.deleteEntry(event.id));
  }

  Future<void> _onEntryCreated(
    TimeTrackerEntryCreated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    await _reloadAndEmit(emit, () => _service.createEntry(event.entry));
  }

  Future<void> _onEntryUpdated(
    TimeTrackerEntryUpdated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    await _reloadAndEmit(emit, () => _service.updateEntry(event.entry));
  }

  // ── Core reload helper ─────────────────────────────────────────────────────

  /// Executes an optional [operation], then reloads entries + active entry
  /// from the service and emits the appropriate state.
  ///
  /// On success:
  ///   - active entry present → [TimeTrackerBlocState.running]
  ///   - no active entry      → [TimeTrackerBlocState.loaded]
  ///
  /// On any error: emits [TimeTrackerBlocState.error] preserving the last
  /// known entries and active entry for context.
  Future<void> _reloadAndEmit(
    Emitter<TimeTrackerBlocState> emit, [
    Future<void> Function()? operation,
  ]) async {
    try {
      await operation?.call();
      final entries = await _service.getAll();
      final active = await _service.getActive();

      if (active != null) {
        emit(TimeTrackerBlocState.running(entries: entries, activeEntry: active));
      } else {
        emit(TimeTrackerBlocState.loaded(entries: entries));
      }
    } on Object catch (e) {
      emit(TimeTrackerBlocState.error(
        errorHandler: e,
        entries: state.allEntries,
        activeEntry: state.activeEntryOrNull,
      ));
    }
  }
}
