part of 'time_tracker_bloc.dart';

@freezed
class TimeTrackerBlocState with _$TimeTrackerBlocState {
  const TimeTrackerBlocState._();

  /// No data loaded; initial state before the first [TimeTrackerLoaded] event.
  const factory TimeTrackerBlocState.idle() = _TimeTrackerIdleState;

  /// A load or mutation operation is in flight.
  const factory TimeTrackerBlocState.loading() = _TimeTrackerLoadingState;

  /// Entries are loaded and no timer is running.
  const factory TimeTrackerBlocState.loaded({
    @Default([]) List<TimeEntry> entries,
    TimeEntry? activeEntry,
  }) = _TimeTrackerLoadedState;

  /// A timer is actively running.
  const factory TimeTrackerBlocState.running({
    @Default([]) List<TimeEntry> entries,
    required TimeEntry activeEntry,
  }) = _TimeTrackerRunningState;

  /// An error occurred during an operation. Previous entries and active entry
  /// are preserved so the UI can remain functional while showing the error.
  const factory TimeTrackerBlocState.error({
    required Object errorHandler,
    @Default([]) List<TimeEntry> entries,
    TimeEntry? activeEntry,
  }) = _TimeTrackerErrorState;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  bool get isRunning => this is _TimeTrackerRunningState;

  TimeEntry? get activeEntryOrNull {
    return when(
      idle: () => null,
      loading: () => null,
      loaded: (entries, activeEntry) => activeEntry,
      running: (entries, activeEntry) => activeEntry,
      error: (errorHandler, entries, activeEntry) => activeEntry,
    );
  }

  List<TimeEntry> get allEntries {
    return when(
      idle: () => [],
      loading: () => [],
      loaded: (entries, activeEntry) => entries,
      running: (entries, activeEntry) => entries,
      error: (errorHandler, entries, activeEntry) => entries,
    );
  }
}
