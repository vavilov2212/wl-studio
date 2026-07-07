import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

enum HistorySortField { date, duration, taskProjectName }

List<ResolvedTimeEntry> applyHistorySort(
  List<ResolvedTimeEntry> entries,
  HistorySortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedTimeEntry>.from(entries);
  final sign = direction == SortDirection.desc ? -1 : 1;

  switch (field) {
    case HistorySortField.date:
      sorted.sort((a, b) {
        if (a.isRunning && !b.isRunning) return -1;
        if (!a.isRunning && b.isRunning) return 1;
        return sign * a.startAt.compareTo(b.startAt);
      });
    case HistorySortField.duration:
      final now = DateTime.now();
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
    case HistorySortField.taskProjectName:
      sorted.sort(
        (a, b) =>
            sign * a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase()),
      );
  }

  return sorted;
}
