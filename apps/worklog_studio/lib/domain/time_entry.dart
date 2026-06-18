enum TimeEntryStatus { running, stopped }

class TimeEntry {
  final String id;
  final String? projectId;
  final String? taskId;
  final String? comment;
  final DateTime startAt;
  final DateTime? endAt;
  final TimeEntryStatus status;

  const TimeEntry({
    required this.id,
    this.projectId,
    this.taskId,
    this.comment,
    required this.startAt,
    required this.status,
    this.endAt,
  });

  bool get isAssigned => projectId != null && taskId != null;

  bool get isRunning => status == TimeEntryStatus.running;

  Duration duration(DateTime now) {
    final effectiveEnd = endAt ?? now;
    return effectiveEnd.difference(startAt);
  }

  TimeEntry copyWith({
    String? id,
    String? projectId,
    String? taskId,
    String? comment,
    DateTime? startAt,
    DateTime? endAt,
    TimeEntryStatus? status,
  }) {
    return TimeEntry(
      id: id == null || id.isEmpty == true ? this.id : id,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      comment: comment ?? this.comment,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
    );
  }
}
