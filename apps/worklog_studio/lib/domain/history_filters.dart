import 'resolved_time_entry.dart';

class HistoryFilters {
  final Set<String> taskIds;
  final Set<String> projectIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const HistoryFilters({
    this.taskIds = const {},
    this.projectIds = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive =>
      taskIds.isNotEmpty || projectIds.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (taskIds.isNotEmpty ? 1 : 0) +
      (projectIds.isNotEmpty ? 1 : 0) +
      (dateFrom != null ? 1 : 0);
}

List<ResolvedTimeEntry> applyHistoryFilters(
  List<ResolvedTimeEntry> entries,
  HistoryFilters filters,
) {
  return entries.where((entry) {
    if (filters.taskIds.isNotEmpty && !filters.taskIds.contains(entry.taskId)) {
      return false;
    }
    if (filters.projectIds.isNotEmpty &&
        !filters.projectIds.contains(entry.projectId)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        entry.startAt.year,
        entry.startAt.month,
        entry.startAt.day,
      );
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final to = DateTime(
        filters.dateTo!.year,
        filters.dateTo!.month,
        filters.dateTo!.day,
      );
      if (day.isBefore(from) || day.isAfter(to)) return false;
    }
    return true;
  }).toList();
}
