import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/task.dart';

class TasksFilters {
  final Set<String> projectIds;
  final Set<TaskStatus> statuses;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const TasksFilters({
    this.projectIds = const {},
    this.statuses = const {},
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive =>
      projectIds.isNotEmpty || statuses.isNotEmpty || dateFrom != null;

  int get activeCount =>
      (projectIds.isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (dateFrom != null ? 1 : 0);
}

List<ResolvedTask> applyTasksFilters(
  List<ResolvedTask> tasks,
  TasksFilters filters,
) {
  return tasks.where((task) {
    if (filters.projectIds.isNotEmpty &&
        !filters.projectIds.contains(task.projectId)) {
      return false;
    }
    if (filters.statuses.isNotEmpty && !filters.statuses.contains(task.status)) {
      return false;
    }
    if (filters.dateFrom != null && filters.dateTo != null) {
      final day = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
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
