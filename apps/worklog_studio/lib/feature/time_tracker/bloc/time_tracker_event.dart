part of 'time_tracker_bloc.dart';

@freezed
sealed class TimeTrackerEvent with _$TimeTrackerEvent {
  const TimeTrackerEvent._();

  /// Triggers initialization or full reload of all time entries.
  const factory TimeTrackerEvent.loaded() = TimeTrackerLoaded;

  /// Starts a new time entry. If a timer is already running, it is stopped first.
  const factory TimeTrackerEvent.started({
    String? projectId,
    String? taskId,
    String? comment,
  }) = TimeTrackerStarted;

  /// Stops the currently active time entry.
  const factory TimeTrackerEvent.stopped() = TimeTrackerStopped;

  /// Updates the project, task, or comment on the currently running entry.
  const factory TimeTrackerEvent.activeEntryUpdated({
    String? projectId,
    String? taskId,
    String? comment,
  }) = TimeTrackerActiveEntryUpdated;

  /// Deletes a time entry by its ID.
  const factory TimeTrackerEvent.entryDeleted(String id) =
      TimeTrackerEntryDeleted;

  /// Creates a new (historical) time entry without affecting the running timer.
  const factory TimeTrackerEvent.entryCreated(TimeEntry entry) =
      TimeTrackerEntryCreated;

  /// Persists changes to an existing time entry.
  const factory TimeTrackerEvent.entryUpdated(TimeEntry entry) =
      TimeTrackerEntryUpdated;
}
