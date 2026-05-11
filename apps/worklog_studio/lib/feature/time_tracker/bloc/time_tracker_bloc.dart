import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';

part 'time_tracker_bloc.freezed.dart'; // <-- Генерируемый файл Freezed
part 'time_tracker_event.dart'; // <-- Часть определения событий
part 'time_tracker_state.dart'; // <-- Часть определения состояний

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
    // <-- ИСПРАВЛЕНО: Начальное состояние
    on<TimeTrackerLoaded>(_onLoaded);
    on<TimeTrackerStarted>(_onStarted);
    on<TimeTrackerStopped>(_onStopped);
    on<TimeTrackerActiveEntryUpdated>(_onActiveEntryUpdated);
    on<TimeTrackerEntryDeleted>(_onEntryDeleted);
    on<TimeTrackerEntryCreated>(_onEntryCreated);
    on<TimeTrackerEntryUpdated>(_onEntryUpdated);

    _idleSubscription = _idleMonitor?.onIdleEvent.listen((event) {
      if (event is IdleThresholdReached) {
        if (state.isRunning) {
          add(TimeTrackerStopped());
        }
      }
    });
  }

  @override
  Future<void> close() {
    _idleSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoaded(
    TimeTrackerLoaded event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    emit(const TimeTrackerBlocState.loading()); // <-- ИСПРАВЛЕНО
    try {
      final entries = await _service.getAll();
      final active = await _service.getActive();

      if (active != null) {
        emit(
          TimeTrackerBlocState.running(entries: entries, activeEntry: active),
        ); // <-- ИСПРАВЛЕНО
      } else {
        emit(TimeTrackerBlocState.loaded(entries: entries)); // <-- ИСПРАВЛЕНО
      }
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО: Обработка ошибок
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries, // <-- ИСПРАВЛЕНО
          activeEntry: state.activeEntryOrNull, // <-- ИСПРАВЛЕНО
        ),
      );
    }
  }

  Future<void> _onStarted(
    TimeTrackerStarted event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (state.isRunning) return; // Feature: Idempotent action

    try {
      final active = await _service.start(
        projectId: event.projectId,
        taskId: event.taskId,
        comment: event.comment,
      );
      final entries = await _service.getAll();

      // Start idle monitoring (10 minutes)
      _idleMonitor?.start(thresholdSeconds: 600);

      emit(
        TimeTrackerBlocState.running(entries: entries, activeEntry: active),
      ); // <-- ИСПРАВЛЕНО
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }

  Future<void> _onStopped(
    TimeTrackerStopped event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (!state.isRunning) return; // Feature: Idempotent action

    try {
      await _service.stop();
      final entries = await _service.getAll();

      // Stop idle monitoring
      _idleMonitor?.stop();

      emit(TimeTrackerBlocState.loaded(entries: entries)); // <-- ИСПРАВЛЕНО
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }

  Future<void> _onActiveEntryUpdated(
    TimeTrackerActiveEntryUpdated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    if (state.activeEntryOrNull == null) return; // <-- ИСПРАВЛЕНО
    try {
      final active = await _service.updateActive(
        projectId: event.projectId,
        taskId: event.taskId,
        comment: event.comment,
      );
      final entries = await _service.getAll();

      emit(
        TimeTrackerBlocState.running(entries: entries, activeEntry: active),
      ); // <-- ИСПРАВЛЕНО
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }

  Future<void> _onEntryDeleted(
    TimeTrackerEntryDeleted event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    try {
      await _service.deleteEntry(event.id);
      final entries = await _service.getAll();
      final active = await _service
          .getActive(); // <-- ИСПРАВЛЕНО: Перезагружаем активную запись

      if (active != null) {
        emit(
          TimeTrackerBlocState.running(entries: entries, activeEntry: active),
        ); // <-- ИСПРАВЛЕНО
      } else {
        emit(TimeTrackerBlocState.loaded(entries: entries)); // <-- ИСПРАВЛЕНО
      }
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }

  Future<void> _onEntryCreated(
    TimeTrackerEntryCreated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    try {
      await _service.createEntry(event.entry);
      final entries = await _service.getAll();
      final active = await _service.getActive(); // <-- ИСПРАВЛЕНО

      if (active != null) {
        emit(
          TimeTrackerBlocState.running(entries: entries, activeEntry: active),
        ); // <-- ИСПРАВЛЕНО
      } else {
        emit(TimeTrackerBlocState.loaded(entries: entries)); // <-- ИСПРАВЛЕНО
      }
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }

  Future<void> _onEntryUpdated(
    TimeTrackerEntryUpdated event,
    Emitter<TimeTrackerBlocState> emit,
  ) async {
    try {
      await _service.updateEntry(event.entry);
      final entries = await _service.getAll();
      final active = await _service.getActive(); // <-- ИСПРАВЛЕНО

      if (active != null) {
        emit(
          TimeTrackerBlocState.running(entries: entries, activeEntry: active),
        ); // <-- ИСПРАВЛЕНО
      } else {
        emit(TimeTrackerBlocState.loaded(entries: entries)); // <-- ИСПРАВЛЕНО
      }
    } on Object catch (e) {
      // <-- ИСПРАВЛЕНО
      emit(
        TimeTrackerBlocState.error(
          errorHandler: e,
          entries: state.allEntries,
          activeEntry: state.activeEntryOrNull,
        ),
      );
    }
  }
}
